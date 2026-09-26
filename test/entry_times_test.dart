import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/features/itinerary/entry_times.dart';

/// The one derivation of an entry's times on a single minute line — what the
/// timeline, the statistics, the calendar export and the journey sheet all read.
void main() {
  group('foldNear', () {
    test('a time already near its reference stays where it is', () {
      expect(foldNear(615, 600), 615);
      expect(foldNear(590, 600), 590);
    });

    test('a departure just past midnight is late, not a day early', () {
      // Planned 23:55, left at 00:10.
      expect(foldNear(10, 1435), 1450);
    });

    test('a departure just before midnight is early, not a day late', () {
      // Planned 00:05, left at 23:58 the evening before.
      expect(foldNear(1438, 5), -2);
    });

    test('an arrival on a later day is found near its planned one', () {
      // Planned 06:00 two days on; arrived 06:30.
      expect(foldNear(390, 2 * kMinutesPerDay + 360), 2 * kMinutesPerDay + 390);
    });

    test('the window is half a day either way, and no wider', () {
      // Eleven hours fifty-nine late is still late …
      expect(foldNear((600 + 719) % kMinutesPerDay, 600), 600 + 719);
      // … twelve hours is read as twelve hours early: the stated trade.
      expect(foldNear((600 + 720) % kMinutesPerDay, 600), 600 - 720);
    });
  });

  group('dayOfLine / minuteOfLine', () {
    test('split a point on the line into its day and its time', () {
      expect(dayOfLine(0), 0);
      expect(dayOfLine(1439), 0);
      expect(dayOfLine(1440), 1);
      expect(minuteOfLine(1440 + 432), 432);
      expect(dayOfLine(2 * kMinutesPerDay + 5), 2);
    });

    test('floor below midnight, so the evening before is day −1', () {
      expect(dayOfLine(-2), -1);
      expect(minuteOfLine(-2), 1438);
    });
  });

  group('entryTimes', () {
    test('an entry within one day reads as stored', () {
      final t = entryTimes(startMinutes: 540, endMinutes: 600);
      expect(t.plannedStart, 540);
      expect(t.plannedEnd, 600);
      expect(t.actualStart, isNull);
      expect(t.actualEnd, isNull);
    });

    test('the end is placed on its own day', () {
      final t = entryTimes(
        startMinutes: 1334,
        endMinutes: 432,
        endDayOffset: 1,
      );
      expect(t.plannedEnd, kMinutesPerDay + 432);
      final longer = entryTimes(
        startMinutes: 1334,
        endMinutes: 432,
        endDayOffset: 2,
      );
      expect(longer.plannedEnd, 2 * kMinutesPerDay + 432);
    });

    test('actual times take the day nearest their planned ones', () {
      final t = entryTimes(
        startMinutes: 1435,
        endMinutes: 360,
        endDayOffset: 1,
        actualStartMinutes: 10,
        actualEndMinutes: 1430,
      );
      expect(t.actualStart, 1450); // 00:10, fifteen minutes late.
      // 23:50 is six hours ten before the planned 06:00 and so read on the
      // evening before it, not the evening after.
      expect(t.actualEnd, 1430);
    });

    test('an arrival planned before midnight and made after it is late', () {
      final t = entryTimes(
        startMinutes: 1320,
        endMinutes: 1430,
        actualEndMinutes: 5,
      );
      expect(t.actualEnd! - t.plannedEnd!, 15);
    });

    test('an actual end with no plan stands on the end day', () {
      final t = entryTimes(
        endDayOffset: 1,
        actualStartMinutes: 1320,
        actualEndMinutes: 360,
      );
      expect(t.actualStart, 1320);
      expect(t.actualEnd, kMinutesPerDay + 360);
    });
  });

  group('endsBeforeStart', () {
    test('a night train without its day ends before it starts', () {
      expect(
        endsBeforeStart(entryTimes(startMinutes: 1320, endMinutes: 420)),
        isTrue,
      );
    });

    test('with its day it does not', () {
      expect(
        endsBeforeStart(
          entryTimes(startMinutes: 1320, endMinutes: 420, endDayOffset: 1),
        ),
        isFalse,
      );
    });

    test('an end equal to the start is a moment, not an error', () {
      expect(
        endsBeforeStart(entryTimes(startMinutes: 600, endMinutes: 600)),
        isFalse,
      );
    });

    test(
      'a planned end is measured against the actual start without a plan',
      () {
        expect(
          endsBeforeStart(
            entryTimes(endMinutes: 420, actualStartMinutes: 1320),
          ),
          isTrue,
        );
      },
    );

    test('an actual end decides only where there is no planned one', () {
      // A planned 09:00–10:00 with an actual end read near the plan is fine.
      expect(
        endsBeforeStart(
          entryTimes(startMinutes: 540, endMinutes: 600, actualEndMinutes: 590),
        ),
        isFalse,
      );
      expect(
        endsBeforeStart(
          entryTimes(actualStartMinutes: 1320, actualEndMinutes: 420),
        ),
        isTrue,
      );
    });

    test('with only one time there is nothing to be before', () {
      expect(endsBeforeStart(entryTimes(endMinutes: 420)), isFalse);
      expect(endsBeforeStart(entryTimes(startMinutes: 420)), isFalse);
      expect(endsBeforeStart(entryTimes()), isFalse);
    });
  });

  group('settledEndDayOffset', () {
    test('keeps a day that was given', () {
      expect(
        settledEndDayOffset(
          startMinutes: 540,
          endMinutes: 600,
          endDayOffset: 2,
        ),
        2,
      );
    });

    test('dates a hand-entered night train on the next morning', () {
      expect(
        settledEndDayOffset(
          startMinutes: 1320,
          endMinutes: 420,
          endDayOffset: 0,
        ),
        1,
      );
    });

    test('leaves an ordinary entry on its own day', () {
      expect(
        settledEndDayOffset(
          startMinutes: 540,
          endMinutes: 600,
          endDayOffset: 0,
        ),
        0,
      );
    });
  });

  test('daysCovered runs from the start through the end day', () {
    expect(daysCovered(DateTime(2026, 10, 24), 0), [DateTime(2026, 10, 24)]);
    expect(daysCovered(DateTime(2026, 10, 24), 2), [
      DateTime(2026, 10, 24),
      DateTime(2026, 10, 25),
      // Across the night the clocks go back, still the next midnight.
      DateTime(2026, 10, 26),
    ]);
  });
}
