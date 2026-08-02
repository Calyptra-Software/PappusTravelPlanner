import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:travelplanner/core/app_info.dart';
import 'package:travelplanner/features/transport_search/data/motis_client.dart';
import 'package:travelplanner/features/transport_search/data/motis_parser.dart';
import 'package:travelplanner/features/transport_search/domain/journey_options.dart';
import 'package:travelplanner/features/transport_search/domain/transit_filter.dart';
import 'package:travelplanner/features/transport_search/domain/transit_mode.dart';
import 'package:travelplanner/features/transport_search/domain/transport_place.dart';
import 'package:travelplanner/features/transport_search/domain/via_stop.dart';

String _fixture(String name) => File('test/fixtures/$name').readAsStringSync();

dynamic _decode(String s) => jsonDecode(s);

/// Tells [MockClient]'s `Response(String, …)` to encode the body as UTF-8 (it
/// defaults to latin1, which mangles non-ASCII station names). The real service
/// sends UTF-8 bytes, which the client decodes as such.
const _jsonUtf8 = {'content-type': 'application/json; charset=utf-8'};

void main() {
  group('transitModeFromMotis', () {
    test('maps the granular rail vocabulary', () {
      expect(transitModeFromMotis('HIGHSPEED_RAIL'), TransitMode.highSpeedRail);
      expect(transitModeFromMotis('NIGHT_RAIL'), TransitMode.nightRail);
      expect(transitModeFromMotis('REGIONAL_RAIL'), TransitMode.regionalRail);
      expect(transitModeFromMotis('SUBURBAN'), TransitMode.suburban);
    });

    test('maps street and vehicle modes', () {
      expect(transitModeFromMotis('WALK'), TransitMode.walk);
      expect(transitModeFromMotis('COACH'), TransitMode.coach);
      expect(transitModeFromMotis('SUBWAY'), TransitMode.subway);
      expect(transitModeFromMotis('FERRY'), TransitMode.ferry);
    });

    test('is case-insensitive and falls back to other', () {
      expect(transitModeFromMotis('coach'), TransitMode.coach);
      expect(transitModeFromMotis('SOMETHING_NEW'), TransitMode.other);
    });
  });

  group('parseGeocodeResponse', () {
    test('decodes stops with coordinates, area and timezone', () {
      final places = parseGeocodeResponse(
        _decode(_fixture('motis_geocode_hamburg.json')),
      );

      expect(places, hasLength(3));
      final first = places.first;
      expect(first.name, 'Hauptbahnhof/ZOB');
      expect(first.kind, PlaceKind.stop);
      expect(first.id, startsWith('at-Railway'));
      expect(first.lat, closeTo(53.5525, 0.01));
      expect(first.lon, closeTo(10.0081, 0.01));
      expect(first.timeZone, 'Europe/Berlin');
      expect(first.area, 'Hamburg'); // the geocoder's `default` area
    });
  });

  group('parsePlanResponse (overnight Hamburg -> Wien)', () {
    test('decodes the itinerary, legs and modes', () {
      final results = parsePlanResponse(
        _decode(_fixture('motis_plan_overnight.json')),
      );

      expect(results.options, hasLength(1));
      final opt = results.options.single;
      expect(opt.transfers, 2);
      expect(opt.legs, hasLength(6));
      expect(opt.legs.map((l) => l.mode), [
        TransitMode.highSpeedRail,
        TransitMode.walk,
        TransitMode.coach,
        TransitMode.walk,
        TransitMode.coach,
        TransitMode.walk,
      ]);
    });

    test('times are UTC instants; no real-time => no actual', () {
      final opt = parsePlanResponse(
        _decode(_fixture('motis_plan_overnight.json')),
      ).options.single;

      expect(opt.departure.isUtc, isTrue);
      expect(
        opt.departure.isAtSameMomentAs(DateTime.utc(2026, 7, 27, 16, 34)),
        isTrue,
      );
      expect(
        opt.arrival.isAtSameMomentAs(DateTime.utc(2026, 7, 28, 4, 46)),
        isTrue,
      );

      final firstLeg = opt.legs.first;
      expect(firstLeg.line, 'ICE 607');
      expect(firstLeg.from.name, 'Hamburg Hbf');
      expect(firstLeg.from.timeZone, 'Europe/Berlin');
      expect(firstLeg.realTime, isFalse);
      expect(firstLeg.from.actual, isNull); // realTime == false
      expect(firstLeg.from.lat, closeTo(53.55, 0.1));
    });

    test('a walking transfer has no line', () {
      final opt = parsePlanResponse(
        _decode(_fixture('motis_plan_overnight.json')),
      ).options.single;
      final walk = opt.legs.firstWhere((l) => l.mode == TransitMode.walk);
      expect(walk.line, isNull);
    });

    test('the overnight coach leg crosses midnight in UTC', () {
      // The mapper turns this into spansNextDay; here we just confirm the raw
      // departure/arrival land on different calendar days, and the two ends can
      // sit in different time zones.
      final opt = parsePlanResponse(
        _decode(_fixture('motis_plan_overnight.json')),
      ).options.single;
      final coach = opt.legs.firstWhere((l) => l.mode == TransitMode.coach);
      expect(coach.from.scheduled.day, 27);
      expect(coach.to.scheduled.day, 28);
      expect(opt.legs.last.to.timeZone, 'Europe/Vienna');
    });

    test('carries the cursors for the windows either side', () {
      final results = parsePlanResponse(
        _decode(_fixture('motis_plan_overnight.json')),
      );
      expect(results.earlierCursor, 'EARLIER|1785168000');
      expect(results.laterCursor, 'LATER|1785181920');
    });

    test('reads the direct (no-transit) options beside the timetable', () {
      // A fast walker on a short hop: transit slower than the fastest direct
      // connection is cut off during routing, so `itineraries` comes back empty
      // and the whole answer is the walk.
      final results = parsePlanResponse({
        'itineraries': <dynamic>[],
        'direct': [
          {
            'duration': 720,
            'startTime': '2026-07-28T09:00:00Z',
            'endTime': '2026-07-28T09:12:00Z',
            'transfers': 0,
            'legs': [
              {
                'mode': 'WALK',
                'realTime': false,
                'from': {'name': 'START', 'departure': '2026-07-28T09:00:00Z'},
                'to': {'name': 'END', 'arrival': '2026-07-28T09:12:00Z'},
              },
            ],
          },
        ],
        'nextPageCursor': 'LATER|1',
      });

      expect(results.options, isEmpty);
      expect(results.direct, hasLength(1));
      expect(results.direct.single.duration, const Duration(minutes: 12));
      expect(results.direct.single.legs.single.mode, TransitMode.walk);
    });

    test('a leg carries the stops it calls at between its ends', () {
      // Recorded from Transitous with `detailedLegs=false` — the app's own
      // query — which strips the route geometry but leaves the stops: the whole
      // reason the preview can list them without a second request.
      final option = parsePlanResponse(
        _decode(_fixture('motis_plan_stops.json')),
      ).options.single;
      final leg = option.legs.firstWhere((l) => l.mode != TransitMode.walk);

      expect(leg.stops.map((s) => s.name), [
        'Büchen',
        'Ludwigslust Bahnhof',
        'Wittenberge, Bahnhof',
      ]);
      // Departures, as UTC instants with the stop's own zone beside them.
      expect(
        leg.stops.first.scheduledDeparture,
        DateTime.utc(2026, 8, 3, 9, 37),
      );
      expect(leg.stops.first.timeZone, 'Europe/Berlin');
      expect(leg.stops.every((s) => !s.cancelled), isTrue);
      // The ends of the leg are not stopovers of it.
      expect(leg.stops.map((s) => s.name), isNot(contains(leg.from.name)));
    });

    test('a long-distance leg is labelled by its train, not its line', () {
      // DELFI files a German long-distance leg's `routeShortName` as the ICE
      // *line* — "11" is the corridor, shared with every other ICE down it —
      // while the train number, the one thing that names this run, is the
      // router's own `displayName`.
      final option = parsePlanResponse(
        _decode(_fixture('motis_plan_stops.json')),
      ).options.single;
      final leg = option.legs.firstWhere((l) => l.mode != TransitMode.walk);

      expect(leg.line, 'ICE 2591');
    });

    test('a stop carries its live departure, on the leg\'s realTime terms', () {
      Map<String, dynamic> plan(bool realTime) => {
        'itineraries': [
          {
            'duration': 3600,
            'startTime': '2026-08-03T09:13:00Z',
            'endTime': '2026-08-03T10:13:00Z',
            'transfers': 0,
            'legs': [
              {
                'mode': 'HIGHSPEED_RAIL',
                'realTime': realTime,
                'from': {
                  'name': 'Hamburg Hbf',
                  'scheduledDeparture': '2026-08-03T09:13:00Z',
                  'departure': '2026-08-03T09:13:00Z',
                },
                'to': {
                  'name': 'Berlin Hbf',
                  'scheduledArrival': '2026-08-03T10:13:00Z',
                  'arrival': '2026-08-03T10:13:00Z',
                },
                'intermediateStops': [
                  {
                    'name': 'Büchen',
                    'tz': 'Europe/Berlin',
                    'scheduledDeparture': '2026-08-03T09:37:00Z',
                    'departure': '2026-08-03T09:42:00Z',
                  },
                ],
              },
            ],
          },
        ],
      };

      final live = parsePlanResponse(plan(true)).options.single.legs.single;
      expect(
        live.stops.single.actualDeparture,
        DateTime.utc(2026, 8, 3, 9, 42),
      );

      // Without real-time the service repeats the plan as if it were live;
      // reading it would record an on-time stop nobody has confirmed.
      final scheduled = parsePlanResponse(
        plan(false),
      ).options.single.legs.single;
      expect(scheduled.stops.single.actualDeparture, isNull);
      expect(
        scheduled.stops.single.scheduledDeparture,
        DateTime.utc(2026, 8, 3, 9, 37),
      );
    });

    test('a stop the service skips comes through flagged', () {
      final leg = parsePlanResponse({
        'itineraries': [
          {
            'duration': 3600,
            'startTime': '2026-07-30T20:28:00Z',
            'endTime': '2026-07-30T21:28:00Z',
            'transfers': 0,
            'legs': [
              {
                'mode': 'HIGHSPEED_RAIL',
                'realTime': true,
                'from': {
                  'name': 'Hamburg Hbf',
                  'scheduledDeparture': '2026-07-30T20:28:00Z',
                  'departure': '2026-07-30T20:49:00Z',
                },
                'to': {
                  'name': 'Hannover Hbf',
                  'scheduledArrival': '2026-07-30T21:28:00Z',
                  'arrival': '2026-07-30T22:13:00Z',
                },
                'intermediateStops': [
                  {
                    'name': 'Lüneburg',
                    'tz': 'Europe/Berlin',
                    'cancelled': true,
                    'scheduledDeparture': '2026-07-30T20:55:00Z',
                    'departure': '2026-07-30T20:55:00Z',
                  },
                ],
              },
            ],
          },
        ],
      }).options.single.legs.single;

      expect(leg.stops.single.cancelled, isTrue);
    });

    test('a leg the service gave no stops for simply has none', () {
      final option = parsePlanResponse(
        _decode(_fixture('motis_plan_overnight.json')),
      ).options.single;
      expect(option.legs.every((leg) => leg.stops.isEmpty), isTrue);
    });

    test('a missing or empty cursor is no cursor', () {
      final results = parsePlanResponse({
        'itineraries': <dynamic>[],
        'previousPageCursor': '',
      });
      expect(results.options, isEmpty);
      expect(results.earlierCursor, isNull);
      expect(results.laterCursor, isNull);
    });
  });

  group('MotisTransportSearch (over a mocked http client)', () {
    test('searchPlaces builds the geocode request and parses it', () async {
      late http.Request seen;
      final client = MotisTransportSearch(
        httpClient: MockClient((req) async {
          seen = req;
          return http.Response(
            _fixture('motis_geocode_hamburg.json'),
            200,
            headers: _jsonUtf8,
          );
        }),
      );

      final places = await client.searchPlaces('Hamburg Hbf');

      expect(places, hasLength(3));
      expect(seen.url.path, '/api/v1/geocode');
      expect(seen.url.queryParameters['text'], 'Hamburg Hbf');
      expect(seen.headers['User-Agent'], isNotEmpty);
    });

    // The service's usage policy asks each request to name the application,
    // the version of the client and a way of contact. All three, or the header
    // does not do the job it is sent for.
    test('the User-Agent names the app, its version and a contact', () async {
      late http.Request seen;
      final client = MotisTransportSearch(
        userAgent: buildUserAgent('9.9.9+42'),
        httpClient: MockClient((req) async {
          seen = req;
          return http.Response(
            _fixture('motis_geocode_hamburg.json'),
            200,
            headers: _jsonUtf8,
          );
        }),
      );

      await client.searchPlaces('Hamburg Hbf');

      expect(
        seen.headers['User-Agent'],
        'TravelPlanner/9.9.9+42 ($kAppContact)',
      );
      expect(kAppContact, contains('@'));
    });

    test('a client built without one still identifies itself', () async {
      late http.Request seen;
      final client = MotisTransportSearch(
        httpClient: MockClient((req) async {
          seen = req;
          return http.Response(
            _fixture('motis_geocode_hamburg.json'),
            200,
            headers: _jsonUtf8,
          );
        }),
      );

      await client.searchPlaces('Hamburg Hbf');

      final userAgent = seen.headers['User-Agent'];
      expect(userAgent, startsWith('$kAppName/'));
      expect(userAgent, contains(kAppContact));
    });

    test('every endpoint asks for the same language', () async {
      final seen = <Uri>[];
      final client = MotisTransportSearch(
        language: 'nl',
        httpClient: MockClient((req) async {
          seen.add(req.url);
          return http.Response(
            // Every endpoint here is only asked for its query, not its body;
            // the trip fixture parses as all three shapes' worth of JSON.
            req.url.path.endsWith('geocode')
                ? _fixture('motis_geocode_hamburg.json')
                : req.url.path.endsWith('trip')
                ? _fixture('motis_trip.json')
                : _fixture('motis_plan_overnight.json'),
            200,
            headers: _jsonUtf8,
          );
        }),
      );

      await client.searchPlaces('Hamburg Hbf');
      await client.journeys(
        fromId: 'A',
        toId: 'B',
        time: DateTime.utc(2026, 7, 27, 18),
      );
      await client.tripStops('T1');

      // A leg imported in one language and refreshed in another would leave
      // the live refresh's name fallback comparing two spellings of one stop.
      expect(seen.map((u) => u.path), [
        '/api/v1/geocode',
        '/api/v6/plan',
        '/api/v6/trip',
      ]);
      expect(
        seen.map((u) => u.queryParameters['language']),
        everyElement('nl'),
      );
    });

    test('journeys builds the plan request and parses it', () async {
      late http.Request seen;
      final client = MotisTransportSearch(
        httpClient: MockClient((req) async {
          seen = req;
          return http.Response(
            _fixture('motis_plan_overnight.json'),
            200,
            headers: _jsonUtf8,
          );
        }),
      );

      final results = await client.journeys(
        fromId: 'A',
        toId: 'B',
        time: DateTime.utc(2026, 7, 27, 18),
      );

      expect(results.options, hasLength(1));
      expect(seen.url.path, '/api/v6/plan');
      expect(seen.url.queryParameters['fromPlace'], 'A');
      expect(seen.url.queryParameters['toPlace'], 'B');
      expect(seen.url.queryParameters['arriveBy'], 'false');
      expect(seen.url.queryParameters['time'], '2026-07-27T18:00:00Z');
      // Unrestricted and unpaged: neither parameter is sent at all.
      expect(seen.url.queryParameters, isNot(contains('transitModes')));
      expect(seen.url.queryParameters, isNot(contains('pageCursor')));
    });

    test('a restricted search names the modes it allows', () async {
      late http.Request seen;
      final client = MotisTransportSearch(
        httpClient: MockClient((req) async {
          seen = req;
          return http.Response(
            _fixture('motis_plan_overnight.json'),
            200,
            headers: _jsonUtf8,
          );
        }),
      );

      await client.journeys(
        fromId: 'A',
        toId: 'B',
        time: DateTime.utc(2026, 7, 27, 18),
        options: const JourneySearchOptions(
          modes: {TransitFilter.longDistanceRail, TransitFilter.ferry},
        ),
      );

      expect(
        seen.url.queryParameters['transitModes'],
        'HIGHSPEED_RAIL,LONG_DISTANCE,NIGHT_RAIL,FERRY',
      );
    });

    test('transfer and interchange limits go on the wire as asked', () async {
      late http.Request seen;
      final client = MotisTransportSearch(
        httpClient: MockClient((req) async {
          seen = req;
          return http.Response(
            _fixture('motis_plan_overnight.json'),
            200,
            headers: _jsonUtf8,
          );
        }),
      );

      await client.journeys(
        fromId: 'A',
        toId: 'B',
        time: DateTime.utc(2026, 7, 27, 18),
        options: const JourneySearchOptions(
          minTransferMinutes: 12,
          maxTransfers: 0,
        ),
      );

      expect(seen.url.queryParameters['minTransferTime'], '12');
      // "Direct only" is a real restriction; it must survive as 0 rather than
      // being mistaken for "unset". It only means this from plan v3 on.
      expect(seen.url.queryParameters['maxTransfers'], '0');
      expect(seen.url.path, '/api/v6/plan');
    });

    test('a via stop travels with the stay it was given', () async {
      late http.Request seen;
      final client = MotisTransportSearch(
        httpClient: MockClient((req) async {
          seen = req;
          return http.Response(
            _fixture('motis_plan_overnight.json'),
            200,
            headers: _jsonUtf8,
          );
        }),
      );

      await client.journeys(
        fromId: 'A',
        toId: 'B',
        time: DateTime.utc(2026, 7, 27, 18),
        via: const ViaStops([ViaStop(id: 'V', minimumStayMinutes: 120)]),
      );

      expect(seen.url.queryParameters['via'], 'V');
      expect(seen.url.queryParameters['viaMinimumStay'], '120');
    });

    test('two via stops keep the order they are visited in', () async {
      late http.Request seen;
      final client = MotisTransportSearch(
        httpClient: MockClient((req) async {
          seen = req;
          return http.Response(
            _fixture('motis_plan_overnight.json'),
            200,
            headers: _jsonUtf8,
          );
        }),
      );

      await client.journeys(
        fromId: 'A',
        toId: 'B',
        time: DateTime.utc(2026, 7, 27, 18),
        via: const ViaStops([
          ViaStop(id: 'V1', minimumStayMinutes: 30),
          ViaStop(id: 'V2', minimumStayMinutes: 120),
        ]),
      );

      // One comma-joined list each (the spec's `explode: false`), the second
      // parallel to the first.
      expect(seen.url.queryParameters['via'], 'V1,V2');
      expect(seen.url.queryParameters['viaMinimumStay'], '30,120');
    });

    test('a stay on the second stop still states the first one', () async {
      late http.Request seen;
      final client = MotisTransportSearch(
        httpClient: MockClient((req) async {
          seen = req;
          return http.Response(
            _fixture('motis_plan_overnight.json'),
            200,
            headers: _jsonUtf8,
          );
        }),
      );

      await client.journeys(
        fromId: 'A',
        toId: 'B',
        time: DateTime.utc(2026, 7, 27, 18),
        via: const ViaStops([
          ViaStop(id: 'V1'),
          ViaStop(id: 'V2', minimumStayMinutes: 120),
        ]),
      );

      // The arrays are parallel: sending only the stay that was asked for would
      // pin those two hours on the *first* stop.
      expect(seen.url.queryParameters['viaMinimumStay'], '0,120');
    });

    test('a via stop with no minimum stay says only where', () async {
      late http.Request seen;
      final client = MotisTransportSearch(
        httpClient: MockClient((req) async {
          seen = req;
          return http.Response(
            _fixture('motis_plan_overnight.json'),
            200,
            headers: _jsonUtf8,
          );
        }),
      );

      await client.journeys(
        fromId: 'A',
        toId: 'B',
        time: DateTime.utc(2026, 7, 27, 18),
        via: const ViaStops([ViaStop(id: 'V')]),
      );

      expect(seen.url.queryParameters['via'], 'V');
      // The service's own default, and it means something — the traveller may
      // stay on the same vehicle through the via — so it is left to say itself.
      expect(seen.url.queryParameters, isNot(contains('viaMinimumStay')));
    });

    test('no via stop, nothing about one on the wire', () async {
      late http.Request seen;
      final client = MotisTransportSearch(
        httpClient: MockClient((req) async {
          seen = req;
          return http.Response(
            _fixture('motis_plan_overnight.json'),
            200,
            headers: _jsonUtf8,
          );
        }),
      );

      await client.journeys(
        fromId: 'A',
        toId: 'B',
        time: DateTime.utc(2026, 7, 27, 18),
      );

      expect(seen.url.queryParameters, isNot(contains('via')));
      expect(seen.url.queryParameters, isNot(contains('viaMinimumStay')));
    });

    test('a slow walker also gets the time to be slow in', () async {
      late http.Request seen;
      final client = MotisTransportSearch(
        httpClient: MockClient((req) async {
          seen = req;
          return http.Response(
            _fixture('motis_plan_overnight.json'),
            200,
            headers: _jsonUtf8,
          );
        }),
      );

      // Half the normal speed: 2.25 km/h = 0.625 m/s, everything walking twice
      // as long, every walking budget twice as big.
      await client.journeys(
        fromId: 'A',
        toId: 'B',
        time: DateTime.utc(2026, 7, 27, 18),
        options: const JourneySearchOptions(
          walkingSpeedKmh: kNormalWalkingSpeedKmh / 2,
        ),
      );

      final q = seen.url.queryParameters;
      expect(q['pedestrianSpeed'], '0.625');
      // `pedestrianSpeed` does not touch footpaths inside a station; only this
      // does.
      expect(q['transferTimeFactor'], '2.00');
      // Without these, the walk to the first stop stops fitting in the default
      // 900 s and the search silently returns nothing at all.
      expect(q['maxPreTransitTime'], '1800');
      expect(q['maxPostTransitTime'], '1800');
      expect(q['maxDirectTime'], '3600');
    });

    test(
      'a fast walker never buys a tighter change than the timetable',
      () async {
        late http.Request seen;
        final client = MotisTransportSearch(
          httpClient: MockClient((req) async {
            seen = req;
            return http.Response(
              _fixture('motis_plan_overnight.json'),
              200,
              headers: _jsonUtf8,
            );
          }),
        );

        await client.journeys(
          fromId: 'A',
          toId: 'B',
          time: DateTime.utc(2026, 7, 27, 18),
          options: const JourneySearchOptions(walkingSpeedKmh: 6.5),
        );

        final q = seen.url.queryParameters;
        expect(q['pedestrianSpeed'], (6.5 / 3.6).toStringAsFixed(3));
        // A factor below 1.0 is declared unsupported, and shrinking the minimum
        // interchange time is the wrong direction to gamble in. Budgets stay at
        // the server's defaults too — a fast walker needs no extra allowance.
        expect(q, isNot(contains('transferTimeFactor')));
        expect(q, isNot(contains('maxPreTransitTime')));
        expect(q, isNot(contains('maxDirectTime')));
      },
    );

    test('a bike travels to the first stop, and no further', () async {
      late http.Request seen;
      final client = MotisTransportSearch(
        httpClient: MockClient((req) async {
          seen = req;
          return http.Response(
            _fixture('motis_plan_overnight.json'),
            200,
            headers: _jsonUtf8,
          );
        }),
      );

      await client.journeys(
        fromId: 'A',
        toId: 'B',
        time: DateTime.utc(2026, 7, 27, 18),
        options: const JourneySearchOptions(byBike: true, cyclingSpeedKmh: 18),
      );

      final q = seen.url.queryParameters;
      expect(q['directModes'], 'WALK,BIKE');
      expect(q['preTransitModes'], 'WALK,BIKE');
      // A bike left at the station is not waiting at the far end.
      expect(q['postTransitModes'], 'WALK');
      expect(q['cyclingSpeed'], (18 / 3.6).toStringAsFixed(3));
      expect(q, isNot(contains('requireBikeTransport')));
    });

    test(
      'a bike that comes along rides both ends and filters the trains',
      () async {
        late http.Request seen;
        final client = MotisTransportSearch(
          httpClient: MockClient((req) async {
            seen = req;
            return http.Response(
              _fixture('motis_plan_overnight.json'),
              200,
              headers: _jsonUtf8,
            );
          }),
        );

        await client.journeys(
          fromId: 'A',
          toId: 'B',
          time: DateTime.utc(2026, 7, 27, 18),
          options: const JourneySearchOptions(byBike: true, bikeOnBoard: true),
        );

        final q = seen.url.queryParameters;
        expect(q['postTransitModes'], 'WALK,BIKE');
        expect(q['requireBikeTransport'], 'true');
      },
    );

    test('no bike, nothing said about bikes', () async {
      late http.Request seen;
      final client = MotisTransportSearch(
        httpClient: MockClient((req) async {
          seen = req;
          return http.Response(
            _fixture('motis_plan_overnight.json'),
            200,
            headers: _jsonUtf8,
          );
        }),
      );

      await client.journeys(
        fromId: 'A',
        toId: 'B',
        time: DateTime.utc(2026, 7, 27, 18),
      );

      final q = seen.url.queryParameters;
      for (final key in [
        'directModes',
        'preTransitModes',
        'postTransitModes',
        'cyclingSpeed',
        'requireBikeTransport',
      ]) {
        expect(
          q,
          isNot(contains(key)),
          reason: '$key should be left to default',
        );
      }
    });

    test('step-free travel routes the transfers as well as the walk', () async {
      late http.Request seen;
      final client = MotisTransportSearch(
        httpClient: MockClient((req) async {
          seen = req;
          return http.Response(
            _fixture('motis_plan_overnight.json'),
            200,
            headers: _jsonUtf8,
          );
        }),
      );

      await client.journeys(
        fromId: 'A',
        toId: 'B',
        time: DateTime.utc(2026, 7, 27, 18),
        options: const JourneySearchOptions(wheelchair: true),
      );

      final q = seen.url.queryParameters;
      expect(q['pedestrianProfile'], 'WHEELCHAIR');
      // Not decoration: the profile only reaches the routing engine — and only
      // then filters out services marked inaccessible — when transfers are
      // routed. Sending the profile alone would leave the in-station footpaths
      // on foot times and the inaccessible trains in the results.
      expect(q['useRoutedTransfers'], 'true');
    });

    test('nothing said about accessibility when it is not asked for', () async {
      late http.Request seen;
      final client = MotisTransportSearch(
        httpClient: MockClient((req) async {
          seen = req;
          return http.Response(
            _fixture('motis_plan_overnight.json'),
            200,
            headers: _jsonUtf8,
          );
        }),
      );

      await client.journeys(
        fromId: 'A',
        toId: 'B',
        time: DateTime.utc(2026, 7, 27, 18),
      );

      final q = seen.url.queryParameters;
      expect(q, isNot(contains('pedestrianProfile')));
      expect(q, isNot(contains('useRoutedTransfers')));
    });

    test('a chosen walking budget is sent exactly, never scaled', () async {
      late http.Request seen;
      final client = MotisTransportSearch(
        httpClient: MockClient((req) async {
          seen = req;
          return http.Response(
            _fixture('motis_plan_overnight.json'),
            200,
            headers: _jsonUtf8,
          );
        }),
      );

      await client.journeys(
        fromId: 'A',
        toId: 'B',
        time: DateTime.utc(2026, 7, 27, 18),
        options: const JourneySearchOptions(
          // Slow enough that the automatic budgets would be doubled…
          walkingSpeedKmh: kNormalWalkingSpeedKmh / 2,
          // …but these were asked for, so they stand as asked.
          maxPreTransitMinutes: 10,
          maxDirectMinutes: 45,
        ),
      );

      final q = seen.url.queryParameters;
      expect(q['maxPreTransitTime'], '600');
      expect(q['maxDirectTime'], '2700');
      // The one left automatic still gets the slow walker's stretch.
      expect(q['maxPostTransitTime'], '1800');
    });

    test('automatic budgets say nothing at a normal pace', () async {
      late http.Request seen;
      final client = MotisTransportSearch(
        httpClient: MockClient((req) async {
          seen = req;
          return http.Response(
            _fixture('motis_plan_overnight.json'),
            200,
            headers: _jsonUtf8,
          );
        }),
      );

      await client.journeys(
        fromId: 'A',
        toId: 'B',
        time: DateTime.utc(2026, 7, 27, 18),
      );

      final q = seen.url.queryParameters;
      expect(q, isNot(contains('maxPreTransitTime')));
      expect(q, isNot(contains('maxPostTransitTime')));
      expect(q, isNot(contains('maxDirectTime')));
    });

    test('no route shapes or walking directions are asked for', () async {
      final seen = <Uri>[];
      final client = MotisTransportSearch(
        httpClient: MockClient((req) async {
          seen.add(req.url);
          return http.Response(
            req.url.path.endsWith('trip')
                ? _fixture('motis_trip.json')
                : _fixture('motis_plan_overnight.json'),
            200,
            headers: _jsonUtf8,
          );
        }),
      );

      // Both endpoints that offer the choice: the plan, and the trip query
      // behind the refresh button — where the polyline is most of the payload.
      await client.journeys(
        fromId: 'A',
        toId: 'B',
        time: DateTime.utc(2026, 7, 27, 18),
      );
      await client.tripStops('T1');

      expect(
        seen.map((u) => u.queryParameters['detailedLegs']),
        everyElement('false'),
      );
    });

    test('dropping the detail costs nothing that is read', () {
      // The fixtures carry full detail; parsing has to stand on the fields that
      // survive without it, so that the request above cannot quietly break the
      // live refresh, which finds its stops among `intermediateStops`.
      final stripped = _decode(_fixture('motis_trip.json')) as Map;
      for (final leg in stripped['legs'] as List) {
        (leg as Map)
          ..remove('steps')
          ..['legGeometry'] = {'points': '', 'length': 0, 'precision': 5};
      }

      final stops = parseTripResponse(stripped);

      expect(stops, isNotEmpty);
      expect(stops.first.scheduledDeparture, isNotNull);
      expect(stops.last.scheduledArrival, isNotNull);
    });

    test('a page cursor rides along with the original query', () async {
      late http.Request seen;
      final client = MotisTransportSearch(
        httpClient: MockClient((req) async {
          seen = req;
          return http.Response(
            _fixture('motis_plan_overnight.json'),
            200,
            headers: _jsonUtf8,
          );
        }),
      );

      await client.journeys(
        fromId: 'A',
        toId: 'B',
        time: DateTime.utc(2026, 7, 27, 18),
        pageCursor: 'LATER|1785181920',
      );

      expect(seen.url.queryParameters['pageCursor'], 'LATER|1785181920');
      // The cursor is only meaningful beside the query that produced it.
      expect(seen.url.queryParameters['fromPlace'], 'A');
      expect(seen.url.queryParameters['time'], '2026-07-27T18:00:00Z');
    });

    test('a non-200 becomes a TransportSearchException', () async {
      final client = MotisTransportSearch(
        httpClient: MockClient((req) async => http.Response('nope', 500)),
      );
      expect(
        () => client.searchPlaces('x'),
        throwsA(isA<TransportSearchException>()),
      );
    });
  });
}
