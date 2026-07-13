import '../../data/database/app_database.dart';

/// How an itinerary entry's times read once the actual ones are recorded. Pure
/// (like `day_blocks.dart` and `now_marker.dart`), because the same rule is
/// rendered twice: as coloured spans in the timeline
/// (`widgets/item_times.dart`) and as markup on the Android home-screen widget
/// (`home_widget/widget_payload.dart`).

/// One end of an entry's range as it is shown: the [minutes] to print, and the
/// [delta] — how far the actual time missed the planned one — or null when there
/// is nothing to compare.
///
/// The time printed is always the **planned** one: the actual is what the delta
/// already says, and printing both only says it twice. The exception is an
/// actual time recorded against no plan, which has nothing to be late for and so
/// takes the plan's place, alone.
typedef TimeMark = ({int minutes, int? delta});

/// The ends of [item]'s range worth printing, in order (start, then end). Empty
/// when the entry carries no time at all.
List<TimeMark> timeMarks(ItineraryItem item) => [
  ?_mark(item.startMinutes, item.actualStartMinutes),
  ?_mark(item.endMinutes, item.actualEndMinutes),
];

TimeMark? _mark(int? planned, int? actual) {
  final minutes = planned ?? actual;
  if (minutes == null) return null;
  final delta = (planned == null || actual == null) ? null : actual - planned;
  return (minutes: minutes, delta: delta);
}
