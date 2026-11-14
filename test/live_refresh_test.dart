import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:travelplanner/data/database/stopovers.dart';
import 'package:travelplanner/features/transport_search/data/live_refresh.dart';
import 'package:travelplanner/features/transport_search/data/motis_parser.dart';
import 'package:travelplanner/features/transport_search/domain/journey.dart';

// Berlin is +2 in July, so all local times below are UTC + 2h.
List<TripStop> _tripStops() => parseTripResponse(
  jsonDecode(File('test/fixtures/motis_trip.json').readAsStringSync()),
);

void main() {
  setUpAll(tzdata.initializeTimeZones);
  final day = DateTime(2026, 7, 26);

  group('parseTripResponse', () {
    test('reads the ordered stops with planned and real-time values', () {
      final stops = _tripStops();
      expect(stops.first.name, 'Hamburg Hbf');
      expect(stops.last.name, 'München Hbf');
      // A stop with a real delay: Berlin Hbf departs 6 min late.
      final berlin = stops.firstWhere((s) => s.name.contains('Berlin'));
      expect(berlin.scheduledDeparture, DateTime.utc(2026, 7, 26, 16, 29));
      expect(berlin.departure, DateTime.utc(2026, 7, 26, 16, 35));
    });
  });

  group('refreshedStopovers', () {
    test('reads each stop\'s delay off the same live trip', () {
      // The leg runs Hamburg -> München; Berlin Hbf is one of the stops it
      // passes through, and the live trip has it leaving 6 min late.
      final stops = refreshedStopovers(
        stops: _tripStops(),
        stopovers: const [
          Stopover(name: 'S+U Berlin Hauptbahnhof', minutes: 18 * 60 + 29),
        ],
        date: day,
      );

      expect(stops.single.delayMinutes, 6);
      // The plan is left exactly as it was; the miss rides beside it.
      expect(stops.single.minutes, 18 * 60 + 29);
    });

    test('a stop the trip says nothing about keeps no delay', () {
      final stops = refreshedStopovers(
        stops: _tripStops(),
        stopovers: const [
          Stopover(name: 'Nowhere', minutes: 5, delayMinutes: 12),
        ],
        date: day,
      );

      // We have just asked, and the answer no longer mentions it: the old
      // figure is not evidence of anything.
      expect(stops.single.delayMinutes, isNull);
      expect(stops.single.name, 'Nowhere');
    });
  });

  group('refreshedStopovers and cancellations', () {
    /// A train that is running — late — but has dropped two of its stops, which
    /// is exactly how a partial cancellation reads on the wire: the trip carries
    /// real-time, and the skipped stops go on reporting their planned times.
    List<TripStop> partlyCancelled() => parseTripResponse({
      'legs': [
        {
          'realTime': true,
          'from': {
            'name': 'Hamburg Hbf',
            'tz': 'Europe/Berlin',
            'scheduledDeparture': '2026-07-26T20:28:00Z',
            'departure': '2026-07-26T20:49:00Z', // +21
          },
          'intermediateStops': [
            {
              'name': 'Lüneburg',
              'tz': 'Europe/Berlin',
              'cancelled': true,
              'scheduledDeparture': '2026-07-26T21:00:00Z',
              'departure': '2026-07-26T21:00:00Z', // the plan, repeated
            },
            {
              'name': 'Celle',
              'tz': 'Europe/Berlin',
              'scheduledDeparture': '2026-07-26T21:30:00Z',
              'departure': '2026-07-26T22:15:00Z', // +45
            },
          ],
          'to': {
            'name': 'Hannover Hbf',
            'tz': 'Europe/Berlin',
            'scheduledArrival': '2026-07-26T22:00:00Z',
            'arrival': '2026-07-26T22:45:00Z',
          },
        },
      ],
    });

    test('a stop the train now skips is flagged, not timed', () {
      final stops = refreshedStopovers(
        stops: partlyCancelled(),
        stopovers: const [
          Stopover(name: 'Lüneburg', minutes: 23 * 60), // 23:00 local
          Stopover(name: 'Celle', minutes: 23 * 60 + 30),
        ],
        date: day,
      );

      // The skipped stop reports its planned departure unchanged, which would
      // otherwise read as a confident "on time" for a train passing straight
      // through it.
      expect(stops.first.cancelled, isTrue);
      expect(stops.first.delayMinutes, isNull);
      // The stop it does still call at is timed as usual.
      expect(stops.last.cancelled, isFalse);
      expect(stops.last.delayMinutes, 45);
    });

    test('a stop that is running again loses the flag', () {
      final stops = refreshedStopovers(
        stops: partlyCancelled(),
        stopovers: const [
          Stopover(name: 'Celle', minutes: 23 * 60 + 30, cancelled: true),
        ],
        date: day,
      );

      expect(stops.single.cancelled, isFalse);
      expect(stops.single.delayMinutes, 45);
    });
  });

  group('refreshedActualTimes', () {
    test('reads actual departure/arrival for the whole leg', () {
      final r = refreshedActualTimes(
        stops: _tripStops(),
        date: day,
        startMinutes: 16 * 60 + 34, // Hamburg 16:34 local
        endMinutes: 23 * 60 + 10, // München 23:10 local
        endDayOffset: 0,
        fromName: 'Hamburg Hbf',
        toName: 'München Hbf',
      )!;
      // Hamburg is on time; München arrives 1 min early (21:09Z -> 23:09).
      expect(r.actualStartMinutes, 16 * 60 + 34);
      expect(r.actualEndMinutes, 23 * 60 + 9);
    });

    test('surfaces a mid-trip delay at the boarding stop', () {
      final r = refreshedActualTimes(
        stops: _tripStops(),
        date: day,
        startMinutes: 18 * 60 + 29, // Berlin Hbf 18:29 local (planned)
        endMinutes: 23 * 60 + 10,
        endDayOffset: 0,
        fromName: 'S+U Berlin Hauptbahnhof',
        toName: 'München Hbf',
      )!;
      expect(r.actualStartMinutes, 18 * 60 + 35); // 18:35 -> +6 min
    });

    test('ignores a trip with no real-time (a train that already ran)', () {
      // realTime:false — the live fields equal the plan; parseTripResponse nulls
      // them, so no false "confirmed on time" is written.
      final stops = parseTripResponse({
        'legs': [
          {
            'realTime': false,
            'from': {
              'name': 'A',
              'tz': 'Europe/Berlin',
              'scheduledDeparture': '2026-07-26T14:00:00Z',
              'departure': '2026-07-26T14:00:00Z',
            },
            'intermediateStops': [],
            'to': {
              'name': 'B',
              'tz': 'Europe/Berlin',
              'scheduledArrival': '2026-07-26T15:00:00Z',
              'arrival': '2026-07-26T15:00:00Z',
            },
          },
        ],
      });
      expect(stops.first.departure, isNull);
      final r = refreshedActualTimes(
        stops: stops,
        date: day,
        startMinutes: 16 * 60, // 14:00Z -> 16:00 local
        endMinutes: 17 * 60,
        endDayOffset: 0,
        fromName: 'A',
        toName: 'B',
      );
      expect(r, isNull);
    });

    test('returns null when no stop matches (schedule changed)', () {
      final r = refreshedActualTimes(
        stops: _tripStops(),
        date: day,
        startMinutes: 5 * 60, // nothing departs at 05:00
        endMinutes: 6 * 60,
        endDayOffset: 0,
        fromName: 'Nowhere',
        toName: 'Elsewhere',
      );
      expect(r, isNull);
    });
  });

  group('cancellation', () {
    /// Only the stops a leg actually uses matter: a trip cancelled between two
    /// other stations still runs for someone boarding outside that stretch.
    List<TripStop> stops({
      bool boardCancelled = false,
      bool alightCancelled = false,
      bool middleCancelled = false,
    }) => [
      TripStop(
        name: 'A',
        timeZone: 'Europe/Berlin',
        scheduledDeparture: DateTime.utc(2026, 7, 26, 14),
        cancelled: boardCancelled,
      ),
      TripStop(
        name: 'M',
        timeZone: 'Europe/Berlin',
        scheduledArrival: DateTime.utc(2026, 7, 26, 14, 30),
        scheduledDeparture: DateTime.utc(2026, 7, 26, 14, 31),
        cancelled: middleCancelled,
      ),
      TripStop(
        name: 'B',
        timeZone: 'Europe/Berlin',
        scheduledArrival: DateTime.utc(2026, 7, 26, 15),
        cancelled: alightCancelled,
      ),
    ];

    RefreshedTimes? refresh(List<TripStop> s) => refreshedActualTimes(
      stops: s,
      date: DateTime(2026, 7, 26),
      startMinutes: 16 * 60,
      endMinutes: 17 * 60,
      endDayOffset: 0,
      fromName: 'A',
      toName: 'B',
    );

    test('a skipped boarding stop strands the leg', () {
      final result = refresh(stops(boardCancelled: true));

      expect(result, isNotNull);
      expect(result!.cancelled, isTrue);
      // Cancelled trips carry no real-time, so there is nothing to write.
      expect(result.actualStartMinutes, isNull);
      expect(result.actualEndMinutes, isNull);
    });

    test('a skipped alighting stop strands it just as much', () {
      expect(refresh(stops(alightCancelled: true))!.cancelled, isTrue);
    });

    test('a stop skipped in between is not this leg\'s problem', () {
      // The traveller boards at A and alights at B; what the train does at M
      // does not concern them.
      expect(refresh(stops(middleCancelled: true)), isNull);
    });
  });

  group('runStopsAround', () {
    // A live answer for ICE 585, Rostock -> München, recorded on 2026-11-14 for
    // the next morning (no real-time yet). Berlin is +1 in November. The leg
    // boards at Hamburg-Harburg (09:13) and gets off at Lüneburg (09:28), so the
    // run has four stops before it and seven after.
    List<TripStop> fullRun() => parseTripResponse(
      jsonDecode(
        File('test/fixtures/motis_trip_full_run.json').readAsStringSync(),
      ),
    );
    final travelDay = DateTime(2026, 11, 15);

    RunStops? around(
      List<TripStop> stops, {
      int start = 9 * 60 + 13,
      int end = 9 * 60 + 28,
      DateTime? date,
    }) => runStopsAround(
      stops: stops,
      date: date ?? travelDay,
      startMinutes: start,
      endMinutes: end,
      endDayOffset: 0,
      fromName: 'Hamburg-Harburg',
      toName: 'Lüneburg',
    );

    test('splits the run at the leg\'s two ends', () {
      final run = around(fullRun())!;

      expect(run.before.map((s) => s.name), [
        'Rostock Hauptbahnhof',
        'Schwerin Hauptbahnhof',
        'Büchen',
        'Bergedorf',
      ]);
      expect(run.after.map((s) => s.name), [
        'Hannover Hauptbahnhof',
        'Göttingen',
        'Kassel Bahnhof Wilhelmshöhe',
        'Fulda Bahnhof',
        'Würzburg Hbf',
        'Nürnberg Hbf',
        'München Hbf',
      ]);
    });

    test('each stop keeps its time, position, zone and dwell', () {
      final run = around(fullRun())!;

      // The origin has no arrival, so no dwell; it is timed by its departure.
      final rostock = run.before.first;
      expect(rostock.minutes, 7 * 60 + 4);
      expect(rostock.dayOffset, 0);
      expect(rostock.dwellMinutes, isNull);
      expect(rostock.lat, closeTo(54.0787, 1e-4));
      expect(rostock.lon, closeTo(12.1308, 1e-4));
      expect(rostock.timeZone, 'Europe/Berlin');

      final schwerin = run.before[1];
      expect(schwerin.minutes, 7 * 60 + 55);
      expect(schwerin.dwellMinutes, 2);

      // The terminus has no departure, so it is timed by its arrival.
      final munich = run.after.last;
      expect(munich.minutes, 15 * 60 + 25);
      expect(munich.dwellMinutes, isNull);

      // A train that has not run yet carries no live figure anywhere.
      expect(
        [...run.before, ...run.after].map((s) => s.delayMinutes),
        everyElement(isNull),
      );
    });

    test('a leg that is the whole run has nothing around it', () {
      final run = runStopsAround(
        stops: fullRun(),
        date: travelDay,
        startMinutes: 7 * 60 + 4,
        endMinutes: 15 * 60 + 25,
        endDayOffset: 0,
        fromName: 'Rostock Hauptbahnhof',
        toName: 'München Hbf',
      )!;

      expect(run.isEmpty, isTrue);
    });

    test('a leg the run cannot be lined up with gets no run', () {
      // Neither end found by time or by name: the timetable has moved on.
      expect(
        runStopsAround(
          stops: fullRun(),
          date: travelDay,
          startMinutes: 9 * 60,
          endMinutes: 10 * 60,
          endDayOffset: 0,
          fromName: 'Elsewhere',
          toName: 'Nowhere',
        ),
        isNull,
      );
    });

    test('ends found the wrong way round give no run', () {
      // A leg stored backwards against this run (getting off before boarding)
      // must not be split at a guess.
      expect(
        runStopsAround(
          stops: fullRun(),
          date: travelDay,
          startMinutes: 9 * 60 + 30,
          endMinutes: 9 * 60 + 8,
          endDayOffset: 0,
          fromName: 'Lüneburg',
          toName: 'Hamburg-Harburg',
        ),
        isNull,
      );
    });

    test('a stop called at the day before boarding is a day earlier', () {
      // A night train left at 22:30 and the traveler boards at 01:10.
      final stops = parseTripResponse({
        'legs': [
          {
            'realTime': true,
            'from': {
              'name': 'Origin',
              'tz': 'Europe/Berlin',
              'scheduledDeparture': '2026-07-25T20:30:00Z', // 22:30 on the 25th
              'departure': '2026-07-25T20:42:00Z', // +12
            },
            'intermediateStops': [
              {
                'name': 'Board',
                'tz': 'Europe/Berlin',
                'scheduledArrival': '2026-07-25T23:08:00Z',
                'scheduledDeparture':
                    '2026-07-25T23:10:00Z', // 01:10 on the 26th
              },
            ],
            'to': {
              'name': 'Alight',
              'tz': 'Europe/Berlin',
              'scheduledArrival': '2026-07-26T04:00:00Z', // 06:00
            },
          },
        ],
      });

      final run = runStopsAround(
        stops: stops,
        date: day,
        startMinutes: 70,
        endMinutes: 6 * 60,
        endDayOffset: 0,
        fromName: 'Board',
        toName: 'Alight',
      )!;

      expect(run.before.single.name, 'Origin');
      expect(run.before.single.minutes, 22 * 60 + 30);
      expect(run.before.single.dayOffset, -1);
      expect(run.before.single.delayMinutes, 12);
      expect(run.after, isEmpty);
    });
  });

  group('refreshedStopovers fills in what an older import lacks', () {
    test('a stop stored without a position learns it from the trip', () {
      final stops = refreshedStopovers(
        stops: parseTripResponse(
          jsonDecode(
            File('test/fixtures/motis_trip_full_run.json').readAsStringSync(),
          ),
        ),
        // Bergedorf as an import from before positions were kept stored it.
        stopovers: const [Stopover(name: 'Bergedorf', minutes: 8 * 60 + 48)],
        date: DateTime(2026, 11, 15),
      );

      final bergedorf = stops.single;
      expect(bergedorf.lat, closeTo(53.4898, 1e-4));
      expect(bergedorf.lon, closeTo(10.2062, 1e-4));
      expect(bergedorf.timeZone, 'Europe/Berlin');
      expect(bergedorf.dwellMinutes, 4);
    });
  });
}
