import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:travelplanner/data/database/stopovers.dart';
import 'package:travelplanner/features/transport_search/data/motis_parser.dart';
import 'package:travelplanner/features/transport_search/data/trip_relocation.dart';
import 'package:travelplanner/features/transport_search/domain/journey.dart';

/// The departure board at Hamburg-Harburg from 08:13Z on 15 November 2026, as
/// Transitous answered it on 2026-11-14 (`center` + `radius=50`). Berlin is +1
/// in November, so 08:13Z is 09:13 on the board.
List<StopDeparture> _board() => parseStopTimesResponse(
  jsonDecode(
    File('test/fixtures/motis_stoptimes_harburg.json').readAsStringSync(),
  ),
);

final _day = DateTime(2026, 11, 15);

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('parseStopTimesResponse', () {
    test('reads each departure with its trip id, label and zone', () {
      final board = _board();

      expect(board, hasLength(10));
      final ice = board.first;
      expect(ice.name, 'ICE 585');
      expect(ice.tripId, '20261115_07:04_de-DELFI_3478804983');
      expect(ice.scheduledDeparture, DateTime.utc(2026, 11, 15, 8, 13));
      expect(ice.timeZone, 'Europe/Berlin');
      // A regional train is labelled as the plan labels it, number and all,
      // which is what an import stored as the leg's title.
      expect(board.map((d) => d.name), contains('RB31 (81617)'));
    });

    test('an arrival with nothing leaving is not a departure', () {
      final board = parseStopTimesResponse({
        'stopTimes': [
          {
            'tripId': 't',
            'displayName': 'RE 1',
            'place': {'scheduledArrival': '2026-11-15T08:00:00Z'},
          },
        ],
      });
      expect(board, isEmpty);
    });
  });

  group('relocatedTripId', () {
    test('the one departure with the leg\'s line at its minute', () {
      expect(
        relocatedTripId(
          departures: _board(),
          line: 'ICE 585',
          date: _day,
          startMinutes: 9 * 60 + 13,
        ),
        '20261115_07:04_de-DELFI_3478804983',
      );
    });

    test('the right line at another minute is another run', () {
      // ICE 787 leaves an hour later on the same line; a leg planned onto the
      // 09:13 must not take its delays.
      expect(
        relocatedTripId(
          departures: _board(),
          line: 'ICE 787',
          date: _day,
          startMinutes: 9 * 60 + 13,
        ),
        isNull,
      );
    });

    test('the right minute under another name is another service', () {
      // A title edited by hand, or a renumbered train: nothing is guessed.
      expect(
        relocatedTripId(
          departures: _board(),
          line: 'ICE 1',
          date: _day,
          startMinutes: 9 * 60 + 13,
        ),
        isNull,
      );
      expect(
        relocatedTripId(
          departures: _board(),
          line: null,
          date: _day,
          startMinutes: 9 * 60 + 13,
        ),
        isNull,
      );
    });

    test('the same minute on another day is another run', () {
      expect(
        relocatedTripId(
          departures: _board(),
          line: 'ICE 585',
          date: DateTime(2026, 11, 16),
          startMinutes: 9 * 60 + 13,
        ),
        isNull,
      );
    });

    test('two different runs that both match are not told apart', () {
      final twin = StopDeparture(
        tripId: 'another',
        name: 'ICE 585',
        scheduledDeparture: DateTime.utc(2026, 11, 15, 8, 13),
        timeZone: 'Europe/Berlin',
      );
      expect(
        relocatedTripId(
          departures: [..._board(), twin],
          line: 'ICE 585',
          date: _day,
          startMinutes: 9 * 60 + 13,
        ),
        isNull,
      );
    });

    test('one run listed twice is still one run', () {
      // `exactRadius=false` lets the router list the same departure under the
      // station and under one of its platforms.
      final board = _board();
      expect(
        relocatedTripId(
          departures: [...board, board.first],
          line: 'ICE 585',
          date: _day,
          startMinutes: 9 * 60 + 13,
        ),
        '20261115_07:04_de-DELFI_3478804983',
      );
    });
  });

  group('relocationWindowStart', () {
    test('reads the planned minute in the zone of the leg\'s stops', () {
      final start = relocationWindowStart(
        date: _day,
        startMinutes: 9 * 60 + 13,
        stopovers: const [
          Stopover(
            name: 'Lüneburg',
            minutes: 9 * 60 + 30,
            timeZone: 'Europe/Berlin',
          ),
        ],
      );
      // 09:13 in Berlin is 08:13Z, and the board is read from a little before.
      expect(
        start,
        DateTime.utc(2026, 11, 15, 8, 13).subtract(kRelocationSlack),
      );
    });

    test('the stop nearest the boarding station decides the zone', () {
      // Boarding in Lisbon off a run that started in Madrid: the last stop
      // before boarding is the one sharing its zone.
      final start = relocationWindowStart(
        date: DateTime(2026, 7, 1),
        startMinutes: 12 * 60,
        stopovers: const [],
        run: const RunStops(
          before: [
            Stopover(name: 'Madrid', minutes: 300, timeZone: 'Europe/Madrid'),
            Stopover(
              name: 'Entroncamento',
              minutes: 600,
              timeZone: 'Europe/Lisbon',
            ),
          ],
        ),
      );
      // 12:00 in Lisbon (+1 in July) is 11:00Z.
      expect(start, DateTime.utc(2026, 7, 1, 11).subtract(kRelocationSlack));
    });
  });
}
