import '../../data/database/app_database.dart';
import 'entry_times.dart';

/// When a run of entries (a group) is planned to take place: from the earliest
/// planned start to the latest planned end, on the run's own minute line.
typedef RunSpan = ({int? start, int? end, int endDayOffset});

/// The planned span of [items], the members of one run, in order.
///
/// Each member is placed through [entryTimes], so an end after midnight counts
/// as later than one before it and comes back with its day ([endDayOffset]).
/// A member without a planned time adds nothing, and a run with no planned time
/// at all has none to say (null). Actual times are not read: a collapsed run
/// says what is planned, the way its members' rows lead with the plan.
RunSpan? runSpan(List<ItineraryItem> items) {
  int? start;
  int? end;
  for (final item in items) {
    final times = entryTimes(
      startMinutes: item.startMinutes,
      endMinutes: item.endMinutes,
      endDayOffset: item.endDayOffset,
    );
    for (final minute in [times.plannedStart, times.plannedEnd]) {
      if (minute == null) continue;
      if (start == null || minute < start) start = minute;
      if (end == null || minute > end) end = minute;
    }
  }
  if (start == null || end == null) return null;
  // A run of one timed moment has a start and no span.
  if (start == end) return (start: start, end: null, endDayOffset: 0);
  return (
    start: start,
    end: end % kMinutesPerDay,
    endDayOffset: end ~/ kMinutesPerDay,
  );
}
