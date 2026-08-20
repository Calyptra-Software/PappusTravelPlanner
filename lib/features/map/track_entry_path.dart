import 'dart:collection';

import '../../core/format/date_format.dart';
import '../../data/database/app_database.dart';
import '../itinerary/day_blocks.dart';

/// **One path through the plan**, which is what a recording can have covered.
///
/// A decision is a fork in the day, so a line that was actually walked followed
/// exactly one of its options — never two, and never half of each. That is the
/// whole of this file: the picker is handed a single path rather than every
/// entry the trip has ever held, and the option each decision contributes is a
/// choice made *for this import*, not the trip's own.
///
/// It also fixes an ordering that was quietly wrong. The picker used to list
/// `ItineraryDao.itemsFor` as it came — ordered by date and `sortOrder` — but a
/// branch item's `sortOrder` orders it *within its branch* and shares no
/// ordering space with the day's loose entries, exactly as [itemsInDayOrder]
/// warns. A branch's first entry therefore jumped ahead of the loose ones it
/// comes after, and since the recording is divided between the chosen entries
/// **in the order they are handed over**, the line was cut in the wrong places
/// — silently, and visibly only weeks later on the map.
///
/// Pure, like `day_blocks.dart` and `live_items.dart`, so the path can be tested
/// without a database or a widget tree.
sealed class TrackPathRow {
  const TrackPathRow();
}

/// The day the rows below it sit on.
final class TrackPathDay extends TrackPathRow {
  const TrackPathDay(this.day);

  final DateTime day;
}

/// A decision the path passes through, and which of its options it takes.
///
/// Present even when the option it takes holds nothing: it carries the switch,
/// and an empty option must not be a place the path gets stuck.
final class TrackPathDecision extends TrackPathRow {
  const TrackPathDecision({
    required this.set,
    required this.branches,
    required this.selected,
    required this.chosen,
  });

  final AlternativeSet set;

  /// Every option, in swipe order — what the switch offers.
  final List<Alternative> branches;

  /// The option this path takes.
  final Alternative selected;

  /// The option the *trip* follows. Equal to [selected] unless the user has
  /// pointed this import at a road not taken, which is worth saying out loud.
  final Alternative chosen;

  int get selectedIndex => branches.indexWhere((b) => b.id == selected.id);
}

/// An entry the recording may have covered — the only kind of row that is
/// ticked.
final class TrackPathEntry extends TrackPathRow {
  const TrackPathEntry(this.item);

  final ItineraryItem item;

  /// Whether it sits inside an option rather than loose on its day.
  bool get inOption => item.alternativeId != null;
}

/// The plan as one path, in the order the timeline reads it.
///
/// [branchBySet] overrides which option a decision contributes, keyed by set id;
/// a decision missing from it contributes the option the trip has chosen, which
/// is the ordinary case and the one every import took before options could be
/// switched at all.
List<TrackPathRow> buildTrackEntryPath({
  required List<ItineraryItem> items,
  required Map<int, AlternativeSet> sets,
  required Map<int, List<Alternative>> branchesBySet,
  Map<int, int> branchBySet = const {},
}) {
  final rows = <TrackPathRow>[];
  for (final day in _days(items, sets)) {
    final blocks = buildDayBlocks(
      day: day,
      items: items,
      sets: sets,
      branchesBySet: branchesBySet,
    );
    if (blocks.isEmpty) continue;
    rows.add(TrackPathDay(day));
    for (final block in blocks) {
      switch (block) {
        case ItemBlock(:final item):
          rows.add(TrackPathEntry(item));
        case GroupBlock(:final items):
          rows.addAll(items.map(TrackPathEntry.new));
        case DecisionBlock(:final set, :final branches, :final itemsByBranch):
          final chosen = block.chosen;
          final wanted = branchBySet[set.id];
          final selected = branches.firstWhere(
            (b) => b.id == wanted,
            orElse: () => chosen,
          );
          rows.add(
            TrackPathDecision(
              set: set,
              branches: branches,
              selected: selected,
              chosen: chosen,
            ),
          );
          final inOption =
              itemsByBranch[selected.id] ?? const <ItineraryItem>[];
          rows.addAll(inOption.map(TrackPathEntry.new));
      }
    }
  }
  return rows;
}

/// The entries of [rows], in path order — what a run is picked from, and the
/// order the recording is divided in.
List<ItineraryItem> pathEntries(List<TrackPathRow> rows) => [
  for (final row in rows)
    if (row is TrackPathEntry) row.item,
];

/// Which option each of [items]' decisions must contribute for all of them to be
/// on the path — the entry point's say in where the picker opens.
///
/// A leg inside an option is reached from that option's own form, so opening the
/// picker on the *chosen* option would leave the very entry the import was
/// started from off the list.
Map<int, int> pathThrough(
  List<ItineraryItem> items,
  Map<int, List<Alternative>> branchesBySet,
) {
  final setOfBranch = {
    for (final entry in branchesBySet.entries)
      for (final branch in entry.value) branch.id: entry.key,
  };
  final path = <int, int>{};
  for (final item in items) {
    final branchId = item.alternativeId;
    if (branchId == null) continue;
    final setId = setOfBranch[branchId];
    if (setId != null) path[setId] = branchId;
  }
  return path;
}

/// The days the plan has anything on, earliest first.
///
/// Unlike the timeline's, this list does not run the trip's whole date range: an
/// empty day is a slot to plan into, and there is nothing there for a recording
/// to have covered.
List<DateTime> _days(List<ItineraryItem> items, Map<int, AlternativeSet> sets) {
  final days = SplayTreeSet<DateTime>();
  // An entry inside an option belongs to the day of its decision, not to its own
  // date, so it can never pull a day into existence on its own.
  for (final item in items) {
    if (item.alternativeId == null) days.add(normalizeDay(item.date));
  }
  for (final set in sets.values) {
    days.add(normalizeDay(set.date));
  }
  return days.toList();
}
