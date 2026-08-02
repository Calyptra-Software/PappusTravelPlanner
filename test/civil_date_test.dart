import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/core/format/date_format.dart';

/// Every date in this app is a *civil* date — a day, not an instant — and the
/// arithmetic has to agree, because a local day is 23 or 25 hours across a
/// daylight-saving change. That is exactly the size of error that moves a
/// routine's day two onto day one.
void main() {
  group('addDays', () {
    test('moves whole calendar days', () {
      expect(addDays(DateTime(2026, 7, 30), 3), DateTime(2026, 8, 2));
      expect(addDays(DateTime(2026, 1, 1), -1), DateTime(2025, 12, 31));
      expect(addDays(DateTime(2026, 7, 30), 0), DateTime(2026, 7, 30));
    });

    test('crosses a spring-forward without losing the day', () {
      // Central Europe springs forward on 2026-03-29; that local day is 23
      // hours, so `add(Duration(days: 1))` from the 28th can land at 23:00 on
      // the 28th rather than midnight on the 29th.
      expect(addDays(DateTime(2026, 3, 28), 1), DateTime(2026, 3, 29));
      expect(addDays(DateTime(2026, 3, 28), 2), DateTime(2026, 3, 30));
      expect(addDays(DateTime(2026, 3, 29), 1), DateTime(2026, 3, 30));
    });

    test('crosses an autumn fall-back without gaining one', () {
      expect(addDays(DateTime(2026, 10, 24), 1), DateTime(2026, 10, 25));
      expect(addDays(DateTime(2026, 10, 25), 1), DateTime(2026, 10, 26));
    });

    test('the result is always a midnight, whatever went in', () {
      expect(addDays(DateTime(2026, 7, 30, 18, 42), 1), DateTime(2026, 7, 31));
    });
  });

  group('daysBetween', () {
    test('counts calendar days, signed', () {
      expect(daysBetween(DateTime(2026, 7, 30), DateTime(2026, 8, 2)), 3);
      expect(daysBetween(DateTime(2026, 8, 2), DateTime(2026, 7, 30)), -3);
      expect(daysBetween(DateTime(2026, 7, 30), DateTime(2026, 7, 30)), 0);
    });

    test('a short day still counts as one', () {
      expect(daysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 29)), 1);
      expect(daysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2);
    });

    test('ignores the time of day at either end', () {
      expect(
        daysBetween(DateTime(2026, 7, 30, 23, 59), DateTime(2026, 7, 31, 0, 1)),
        1,
      );
    });

    test('round-trips with addDays', () {
      final from = DateTime(2026, 3, 28);
      for (var n = -400; n <= 400; n += 37) {
        expect(daysBetween(from, addDays(from, n)), n);
      }
    });
  });

  group('tripDayCount', () {
    test('is inclusive of both ends', () {
      expect(tripDayCount(DateTime(2026, 7, 30), DateTime(2026, 7, 30)), 1);
      expect(tripDayCount(DateTime(2026, 7, 30), DateTime(2026, 8, 2)), 4);
    });

    test('a DST day does not shorten the trip', () {
      expect(tripDayCount(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 3);
    });

    test('is unanswerable without both dates', () {
      expect(tripDayCount(null, DateTime(2026, 7, 30)), isNull);
      expect(tripDayCount(DateTime(2026, 7, 30), null), isNull);
    });
  });
}
