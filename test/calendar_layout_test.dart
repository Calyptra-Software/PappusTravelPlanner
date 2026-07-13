import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/features/trips/calendar_layout.dart';

void main() {
  Trip trip({required int id, DateTime? start, DateTime? end}) => Trip(
    id: id,
    title: 'Trip $id',
    destination: '',
    startDate: start,
    endDate: end,
    colorValue: 0xFF00695C,
    createdAt: DateTime(2026, 1, 1),
  );

  // Monday-start week for July 2026: the 1st is a Wednesday.
  const mondayFirst = 1;

  group('tripSpan', () {
    test('undated trips have no span', () {
      expect(tripSpan(trip(id: 1)), isNull);
    });

    test('a single set date collapses to one day', () {
      final span = tripSpan(trip(id: 1, start: DateTime(2026, 7, 5)));
      expect(span!.start, DateTime(2026, 7, 5));
      expect(span.end, DateTime(2026, 7, 5));
    });

    test('time component is stripped', () {
      final span = tripSpan(
        trip(
          id: 1,
          start: DateTime(2026, 7, 5, 14, 30),
          end: DateTime(2026, 7, 8, 9),
        ),
      );
      expect(span!.start, DateTime(2026, 7, 5));
      expect(span.end, DateTime(2026, 7, 8));
    });
  });

  group('monthGridStart', () {
    test('backs up to the first weekday of the containing week', () {
      // July 2026, Monday-start: 1st is Wed, so the grid starts Mon Jun 29.
      expect(
        monthGridStart(DateTime(2026, 7), mondayFirst),
        DateTime(2026, 6, 29),
      );
    });

    test('sunday-start grid', () {
      // Sunday before Wed Jul 1 is Jun 28.
      expect(monthGridStart(DateTime(2026, 7), 0), DateTime(2026, 6, 28));
    });
  });

  group('buildMonthGrid', () {
    test('produces six weeks of seven days each', () {
      final weeks = buildMonthGrid(DateTime(2026, 7), const [], mondayFirst);
      expect(weeks, hasLength(6));
      expect(weeks.every((w) => w.days.length == 7), isTrue);
    });

    test('undated trips never appear on the grid', () {
      final weeks = buildMonthGrid(DateTime(2026, 7), [
        trip(id: 1),
      ], mondayFirst);
      expect(weeks.every((w) => w.spans.isEmpty), isTrue);
    });

    test('a trip within one week spans the right columns', () {
      // Jul 1 (Wed) .. Jul 3 (Fri). Monday-start week => cols 2..4.
      final weeks = buildMonthGrid(DateTime(2026, 7), [
        trip(id: 1, start: DateTime(2026, 7, 1), end: DateTime(2026, 7, 3)),
      ], mondayFirst);
      final span = weeks.expand((w) => w.spans).single;
      expect(span.startCol, 2);
      expect(span.endCol, 4);
      expect(span.continuesLeft, isFalse);
      expect(span.continuesRight, isFalse);
      expect(span.lane, 0);
    });

    test('a trip crossing a week boundary is clipped and flagged', () {
      // Jul 4 (Sat) .. Jul 8 (Wed) crosses the Sun/Mon boundary.
      final weeks = buildMonthGrid(DateTime(2026, 7), [
        trip(id: 1, start: DateTime(2026, 7, 4), end: DateTime(2026, 7, 8)),
      ], mondayFirst);
      final segments = weeks.expand((w) => w.spans).toList();
      expect(segments, hasLength(2));
      final first = segments.firstWhere((s) => s.continuesRight);
      final second = segments.firstWhere((s) => s.continuesLeft);
      expect(first.endCol, 6); // runs to end of its week
      expect(second.startCol, 0); // resumes at the start of the next
    });

    test('overlapping trips are packed into separate lanes', () {
      final weeks = buildMonthGrid(DateTime(2026, 7), [
        trip(id: 1, start: DateTime(2026, 7, 1), end: DateTime(2026, 7, 3)),
        trip(id: 2, start: DateTime(2026, 7, 2), end: DateTime(2026, 7, 4)),
      ], mondayFirst);
      final spans = weeks.expand((w) => w.spans).toList();
      final lanes = {for (final s in spans) s.trip.id: s.lane};
      expect(lanes[1], isNot(lanes[2]));
    });

    test('non-overlapping trips reuse the same lane', () {
      final weeks = buildMonthGrid(DateTime(2026, 7), [
        trip(id: 1, start: DateTime(2026, 7, 1), end: DateTime(2026, 7, 2)),
        trip(id: 2, start: DateTime(2026, 7, 4), end: DateTime(2026, 7, 5)),
      ], mondayFirst);
      // Both fall in the same week row; being disjoint they share lane 0.
      final week = weeks.firstWhere((w) => w.spans.length == 2);
      expect(week.spans.every((s) => s.lane == 0), isTrue);
      expect(week.laneCount, 1);
    });
  });

  group('overflowByColumn', () {
    test('counts bars hidden beyond the visible lanes', () {
      final weeks = buildMonthGrid(DateTime(2026, 7), [
        for (var i = 0; i < 4; i++)
          trip(
            id: i + 1,
            start: DateTime(2026, 7, 1),
            end: DateTime(2026, 7, 1),
          ),
      ], mondayFirst);
      final week = weeks.firstWhere((w) => w.spans.isNotEmpty);
      // Four bars stacked on Jul 1 (col 2); showing 2 lanes hides 2.
      final overflow = overflowByColumn(week, 2);
      expect(overflow[2], 2);
      expect(overflow.where((c) => c > 0), hasLength(1));
    });
  });
}
