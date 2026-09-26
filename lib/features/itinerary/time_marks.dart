import '../../data/database/app_database.dart';
import 'entry_times.dart';

/// How an itinerary entry's times read once the actual ones are recorded. Pure
/// (like `day_blocks.dart` and `now_marker.dart`), because the same rule is
/// rendered twice: as coloured spans in the timeline
/// (`widgets/item_times.dart`) and as markup on the Android home-screen widget
/// (`home_widget/widget_payload.dart`).

/// One end of an entry's range as it is shown: the [minutes] to print, the
/// [day] they fall on counted from the entry's own date (a night train's
/// arrival is day 1), and the [delta] — how far the actual time missed the
/// planned one — or null when there is nothing to compare.
///
/// The time printed is always the **planned** one: the actual is what the delta
/// already says, and printing both only says it twice. The exception is an
/// actual time recorded against no plan, which has nothing to be late for and so
/// takes the plan's place, alone.
///
/// Both come off the entry's minute line (`entry_times.dart`), so a departure
/// planned for 23:55 that left at 00:10 reads "(+15)" and not "(−23:45)".
typedef TimeMark = ({int minutes, int day, int? delta});

/// The ends of [item]'s range worth printing, in order (start, then end). Empty
/// when the entry carries no time at all.
List<TimeMark> timeMarks(ItineraryItem item) {
  final times = item.times;
  return [
    ?_mark(times.plannedStart, times.actualStart),
    ?_mark(times.plannedEnd, times.actualEnd),
  ];
}

TimeMark? _mark(int? planned, int? actual) {
  final at = planned ?? actual;
  if (at == null) return null;
  final delta = (planned == null || actual == null) ? null : actual - planned;
  return (minutes: minuteOfLine(at), day: dayOfLine(at), delta: delta);
}

/// The end of [item]'s range alone, as [timeMarks] would print it, or null when
/// the entry has no end — what the day an entry runs into shows of it.
TimeMark? endMark(ItineraryItem item) {
  final times = item.times;
  return _mark(times.plannedEnd, times.actualEnd);
}
