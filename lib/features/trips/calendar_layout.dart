import '../../core/format/date_format.dart';
import '../../data/database/app_database.dart';

/// Pure layout maths for the month-grid calendar, kept database- and
/// widget-free so it can be unit-tested (see `test/calendar_layout_test.dart`).
///
/// A trip is drawn as a horizontal bar spanning its days. Within a single week
/// row, overlapping trips are stacked into *lanes* so their bars never collide.

/// A trip clipped to one week row, positioned by day column and lane.
class CalendarSpan {
  CalendarSpan({
    required this.trip,
    required this.startCol,
    required this.endCol,
    required this.continuesLeft,
    required this.continuesRight,
    required this.lane,
  });

  final Trip trip;

  /// First/last day column the bar occupies within the week, 0–6 inclusive.
  final int startCol;
  final int endCol;

  /// The trip extends beyond this week to the left/right (draw a flat cap
  /// there instead of a rounded one).
  final bool continuesLeft;
  final bool continuesRight;

  /// Stack row this bar sits in; 0 is the topmost.
  final int lane;

  int get columnSpan => endCol - startCol + 1;
}

/// The bars for one week plus how many lanes they needed.
class CalendarWeek {
  CalendarWeek({
    required this.days,
    required this.spans,
    required this.laneCount,
  });

  /// The seven day cells of this week (normalized to midnight).
  final List<DateTime> days;
  final List<CalendarSpan> spans;
  final int laneCount;
}

/// The start/end a trip is drawn with. A trip with only one date set is drawn
/// as a single-day marker; a fully undated trip returns null (never on grid).
({DateTime start, DateTime end})? tripSpan(Trip trip) {
  final start = trip.startDate ?? trip.endDate;
  final end = trip.endDate ?? trip.startDate;
  if (start == null || end == null) return null;
  return (start: normalizeDay(start), end: normalizeDay(end));
}

/// The first day cell of the month grid: the start of the week containing the
/// first of [month]. [firstWeekday] is 0=Sunday…6=Saturday (as returned by
/// `MaterialLocalizations.firstDayOfWeekIndex`).
DateTime monthGridStart(DateTime month, int firstWeekday) {
  final first = DateTime(month.year, month.month, 1);
  // Dart weekday is 1=Mon…7=Sun; convert to 0=Sun…6=Sat to match firstWeekday.
  final dow = first.weekday % 7;
  final back = (dow - firstWeekday + 7) % 7;
  return first.subtract(Duration(days: back));
}

/// Builds the weeks of [month]'s grid, laying out [trips] into non-overlapping
/// lanes per week. Trips are clipped to each week and sorted so longer, earlier
/// bars settle into the top lanes. Undated trips are skipped.
List<CalendarWeek> buildMonthGrid(
  DateTime month,
  List<Trip> trips,
  int firstWeekday,
) {
  final gridStart = monthGridStart(month, firstWeekday);
  // Six week rows always cover any month regardless of length/offset.
  final weeks = <CalendarWeek>[];
  final spans = <({DateTime start, DateTime end, Trip trip})>[];
  for (final trip in trips) {
    final span = tripSpan(trip);
    if (span != null) {
      spans.add((start: span.start, end: span.end, trip: trip));
    }
  }

  for (var w = 0; w < 6; w++) {
    final weekStart = gridStart.add(Duration(days: w * 7));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final days = [for (var d = 0; d < 7; d++) weekStart.add(Duration(days: d))];

    // Trips intersecting this week, clipped to it.
    final clipped = <CalendarSpan>[];
    for (final s in spans) {
      if (s.end.isBefore(weekStart) || s.start.isAfter(weekEnd)) continue;
      final startCol = s.start.isBefore(weekStart)
          ? 0
          : s.start.difference(weekStart).inDays;
      final endCol = s.end.isAfter(weekEnd)
          ? 6
          : s.end.difference(weekStart).inDays;
      clipped.add(
        CalendarSpan(
          trip: s.trip,
          startCol: startCol,
          endCol: endCol,
          continuesLeft: s.start.isBefore(weekStart),
          continuesRight: s.end.isAfter(weekEnd),
          lane: 0,
        ),
      );
    }

    // Greedy lane packing: earliest-starting, then longest, first. Because the
    // list is start-sorted, a lane is free when its last bar ended before us.
    clipped.sort((a, b) {
      final byStart = a.startCol.compareTo(b.startCol);
      if (byStart != 0) return byStart;
      return b.columnSpan.compareTo(a.columnSpan);
    });
    final laneEnds = <int>[]; // last endCol placed in each lane
    final placed = <CalendarSpan>[];
    for (final span in clipped) {
      var lane = laneEnds.indexWhere((end) => end < span.startCol);
      if (lane == -1) {
        lane = laneEnds.length;
        laneEnds.add(span.endCol);
      } else {
        laneEnds[lane] = span.endCol;
      }
      placed.add(
        CalendarSpan(
          trip: span.trip,
          startCol: span.startCol,
          endCol: span.endCol,
          continuesLeft: span.continuesLeft,
          continuesRight: span.continuesRight,
          lane: lane,
        ),
      );
    }

    weeks.add(
      CalendarWeek(days: days, spans: placed, laneCount: laneEnds.length),
    );
  }
  return weeks;
}

/// Per-day-column count of bars hidden because their lane is at or beyond
/// [visibleLanes], for the "+N more" markers. Index is the 0–6 column.
List<int> overflowByColumn(CalendarWeek week, int visibleLanes) {
  final counts = List<int>.filled(7, 0);
  for (final span in week.spans) {
    if (span.lane < visibleLanes) continue;
    for (var col = span.startCol; col <= span.endCol; col++) {
      counts[col]++;
    }
  }
  return counts;
}
