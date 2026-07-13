import '../../core/format/date_format.dart';
import '../../data/database/app_database.dart';

/// A day of the itinerary reads as a list of **blocks**: either a single item
/// sitting directly on the day, or a whole decision — a set of competing
/// alternatives, of which one is chosen — occupying one slot. Both share the
/// day's ordering space, so dragging reorders blocks, not the items hidden
/// inside a branch.
///
/// Pure (like `trip_stats.dart` and `live_items.dart`), so the assembly is
/// unit-testable without a database or a widget tree.
sealed class DayBlock {
  const DayBlock();

  /// The block's slot within its day.
  int get sortOrder;
}

/// One itinerary item sitting directly on the day (not inside any branch).
final class ItemBlock extends DayBlock {
  const ItemBlock(this.item);

  final ItineraryItem item;

  @override
  int get sortOrder => item.sortOrder;
}

/// A decision on the day: its branches in swipe order, each with its items.
final class DecisionBlock extends DayBlock {
  const DecisionBlock({
    required this.set,
    required this.branches,
    required this.itemsByBranch,
  });

  final AlternativeSet set;

  /// The competing options, in the order they are swiped through.
  final List<Alternative> branches;

  /// Each branch's items, in branch order. A branch with nothing planned yet is
  /// present with an empty list.
  final Map<int, List<ItineraryItem>> itemsByBranch;

  /// The branch the plan currently follows. `AlternativeDao` keeps exactly one
  /// chosen, but fall back to the first so a malformed set still renders.
  Alternative get chosen =>
      branches.firstWhere((b) => b.chosen, orElse: () => branches.first);

  @override
  int get sortOrder => set.sortOrder;
}

/// Assembles [day]'s blocks, in the order they are shown.
///
/// [items] is a trip's whole itinerary (loose items *and* branch items, as
/// `itineraryProvider` yields it), already ordered by day / sort / time; [sets]
/// and [branchesBySet] are the trip's decisions. A set's branch items are found
/// through their branch, not their date, so they follow the decision they belong
/// to.
List<DayBlock> buildDayBlocks({
  required DateTime day,
  required List<ItineraryItem> items,
  required Map<int, AlternativeSet> sets,
  required Map<int, List<Alternative>> branchesBySet,
}) {
  final itemsByBranch = <int, List<ItineraryItem>>{};
  final blocks = <DayBlock>[];

  for (final item in items) {
    final branchId = item.alternativeId;
    if (branchId != null) {
      itemsByBranch.putIfAbsent(branchId, () => []).add(item);
    } else if (normalizeDay(item.date) == day) {
      blocks.add(ItemBlock(item));
    }
  }

  for (final set in sets.values) {
    if (normalizeDay(set.date) != day) continue;
    final branches = branchesBySet[set.id] ?? const [];
    // A set with no branches is transient at most (the DAO dissolves one that
    // loses its last branch); skip it rather than render an empty card.
    if (branches.isEmpty) continue;
    blocks.add(DecisionBlock(
      set: set,
      branches: branches,
      itemsByBranch: {
        for (final branch in branches)
          branch.id: itemsByBranch[branch.id] ?? const [],
      },
    ));
  }

  blocks.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return blocks;
}
