import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
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

  group('refreshedActualTimes', () {
    test('reads actual departure/arrival for the whole leg', () {
      final r = refreshedActualTimes(
        stops: _tripStops(),
        date: day,
        startMinutes: 16 * 60 + 34, // Hamburg 16:34 local
        endMinutes: 23 * 60 + 10, // München 23:10 local
        spansNextDay: false,
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
        spansNextDay: false,
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
        spansNextDay: false,
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
        spansNextDay: false,
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
      spansNextDay: false,
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
}
