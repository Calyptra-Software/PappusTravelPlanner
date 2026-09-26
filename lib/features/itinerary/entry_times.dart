import '../../core/format/civil_date.dart';
import '../../data/database/app_database.dart';

/// When an itinerary entry starts and ends, as **one** minute line.
///
/// An entry stores four times as minutes since midnight (0-1439) plus
/// `endDayOffset`, the number of days after its date that its end falls on.
/// Everything that measures an entry — how long a leg took, whether it is
/// under way, how late it ran, when a calendar event ends — needs those times
/// on one line instead, and used to derive it three different ways: the
/// now-marker read the overnight flag, the transport statistics guessed from an
/// end before its start, and the calendar export read neither and dropped the
/// end. This file is that derivation, once. Pure, so the rule is unit-tested
/// without a widget or a database.
///
/// The line counts minutes from midnight of the day the entry **starts** on:
/// 0 is that midnight, 1440 the next one, and an actual departure a few
/// minutes before a planned 00:05 is legitimately negative.

/// Minutes in a day, the step between two days on an entry's minute line.
const int kMinutesPerDay = 24 * 60;

/// Half a day: how far an actual time may lie from its planned one before it is
/// read as belonging to another day.
const int _halfDay = kMinutesPerDay ~/ 2;

/// [minutes], a time of day, placed on whichever day brings it nearest to
/// [reference], a point on an entry's minute line — within
/// [−12 h, +12 h) of it.
///
/// This is how an **actual** time finds its day, since only the planned end
/// carries one: an actual time is recorded against its planned counterpart and
/// is almost always minutes away from it. So a departure planned for 23:55 that
/// left at 00:10 ran fifteen minutes late rather than twenty-three hours and
/// forty-five minutes early. The rule is a heuristic and says so: a delay of
/// twelve hours or more is read as the nearer, wrong day. That was the trade
/// chosen over storing a day for each actual time too, which would have put two
/// more day fields in front of everyone recording that a train was late.
int foldNear(int minutes, int reference) =>
    reference + (minutes - reference + _halfDay) % kMinutesPerDay - _halfDay;

/// The day of an entry's minute line [minutes] falls on — 0 for its own date,
/// 1 for the day after. Floors, so a time just before its date's midnight is
/// day −1 rather than 0.
int dayOfLine(int minutes) =>
    (minutes - minutes % kMinutesPerDay) ~/ kMinutesPerDay;

/// The time of day [minutes] on an entry's minute line reads as (0-1439).
int minuteOfLine(int minutes) => minutes % kMinutesPerDay;

/// An entry's four times on its minute line; each null when it is not set.
typedef EntryTimes = ({
  int? plannedStart,
  int? plannedEnd,
  int? actualStart,
  int? actualEnd,
});

/// Places an entry's stored times on its minute line.
///
/// - The planned start is on the entry's own date, as stored.
/// - The planned end is [endDayOffset] days later.
/// - An actual time takes the day nearest its planned counterpart
///   ([foldNear]). Without one it has nothing to be near and stands where a
///   planned time would: an actual start on the date, an actual end on the end
///   day — which is what the form's end-day field sets when there is no plan.
EntryTimes entryTimes({
  int? startMinutes,
  int? endMinutes,
  int endDayOffset = 0,
  int? actualStartMinutes,
  int? actualEndMinutes,
}) {
  final endDay = endDayOffset * kMinutesPerDay;
  final plannedEnd = endMinutes == null ? null : endDay + endMinutes;
  return (
    plannedStart: startMinutes,
    plannedEnd: plannedEnd,
    actualStart: actualStartMinutes == null
        ? null
        : startMinutes == null
        ? actualStartMinutes
        : foldNear(actualStartMinutes, startMinutes),
    actualEnd: actualEndMinutes == null
        ? null
        : plannedEnd == null
        ? endDay + actualEndMinutes
        : foldNear(actualEndMinutes, plannedEnd),
  );
}

/// Whether an entry with these times ends before it starts — which, for an
/// entry with no end day set, means its end belongs to the next morning.
///
/// The **planned** end decides and is measured against the planned start (the
/// actual one standing in when there is none); the actual end decides only
/// where there is no planned one, and is measured against the actual start
/// first. That is the one rule for "an end on the wrong side of midnight":
/// the form applies it to suggest the next day, and the v40 migration and the
/// bundle import applied it to entries written before a day could be given.
bool endsBeforeStart(EntryTimes times) {
  final (:plannedStart, :plannedEnd, :actualStart, :actualEnd) = times;
  if (plannedEnd != null) {
    final start = plannedStart ?? actualStart;
    return start != null && plannedEnd < start;
  }
  if (actualEnd != null) {
    final start = actualStart ?? plannedStart;
    return start != null && actualEnd < start;
  }
  return false;
}

/// [endDayOffset] as stored, or 1 where it is 0 and the times say the entry
/// ends before it starts ([endsBeforeStart]) — the reading of a record written
/// before an end day could be given, when a hand-entered night train was saved
/// as ending the evening it left.
int settledEndDayOffset({
  int? startMinutes,
  int? endMinutes,
  required int endDayOffset,
  int? actualStartMinutes,
  int? actualEndMinutes,
}) {
  if (endDayOffset != 0) return endDayOffset;
  final times = entryTimes(
    startMinutes: startMinutes,
    endMinutes: endMinutes,
    actualStartMinutes: actualStartMinutes,
    actualEndMinutes: actualEndMinutes,
  );
  return endsBeforeStart(times) ? 1 : 0;
}

/// The calendar day [item]'s end falls on: its date, [endDayOffset] days on.
DateTime endDateOf(ItineraryItem item) => addDays(item.date, item.endDayOffset);

/// The calendar days an entry starting on [start] and ending [endDayOffset]
/// days later touches, [start] included — the days a plan's timeline has to
/// show for it. A night train is on the day it leaves *and* the morning it
/// arrives, and that morning is part of the trip whether or not anything else
/// is planned on it.
Iterable<DateTime> daysCovered(DateTime start, int endDayOffset) sync* {
  for (var i = 0; i <= endDayOffset; i++) {
    yield addDays(start, i);
  }
}

extension ItemEntryTimes on ItineraryItem {
  /// This entry's times on its minute line — see [entryTimes].
  EntryTimes get times => entryTimes(
    startMinutes: startMinutes,
    endMinutes: endMinutes,
    endDayOffset: endDayOffset,
    actualStartMinutes: actualStartMinutes,
    actualEndMinutes: actualEndMinutes,
  );
}
