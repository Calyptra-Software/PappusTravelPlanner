import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:travelplanner/features/transport_search/data/motis_client.dart';
import 'package:travelplanner/features/transport_search/data/motis_parser.dart';
import 'package:travelplanner/features/transport_search/domain/journey_options.dart';
import 'package:travelplanner/features/transport_search/domain/transit_filter.dart';
import 'package:travelplanner/features/transport_search/domain/transit_mode.dart';
import 'package:travelplanner/features/transport_search/domain/transport_place.dart';

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
