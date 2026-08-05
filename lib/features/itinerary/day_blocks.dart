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

/// A whole group — a run of entries sharing one ticket — occupying **one** slot.
///
/// A group is a single thing to the plan ("the train to Rome"), so it is a
/// single thing to the list: it drags as one, and no drag can take a leg out of
/// the middle of it. Its members are still reorderable among themselves, in the
/// run's own list, exactly as a decision's options are reordered inside their
/// card. That is the same rule as everywhere here — a drag reorders *within* a
/// list, and crossing between lists is the explicit move/copy.
///
/// The run takes as many sort orders as it has members (they are ordinary items
/// in the day's ordering space); [sortOrder] is the first one, which is the slot
/// the run occupies.
final class GroupBlock extends DayBlock {
  const GroupBlock({required this.groupId, required this.items});

  final int groupId;

  /// The run's members, in order. Never empty — a block is built only from
  /// entries that are there.
  final List<ItineraryItem> items;

  @override
  int get sortOrder => items.first.sortOrder;
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

/// [items] (one list, already in order) as blocks: a loose entry is one block,
/// and each group is one block holding its whole run.
///
/// Used for both lists a run can sit in — a day's loose entries, and one option
/// of a decision — so a group reads and drags the same way in either.
///
/// A group's members are collected by their `groupId` rather than by being
/// neighbours in the list. They *are* neighbours (a group is one contiguous run,
/// which is what `GroupDao.groupItems` builds and what this model then keeps
/// true), but a database written by an older version could hold a run some drag
/// had split; drawing that as two bands with one id — and the shared ticket
/// printed under each of them — is worse than closing the gap.
List<DayBlock> buildItemBlocks(List<ItineraryItem> items) {
  final blocks = <DayBlock>[];
  final runs = <int, List<ItineraryItem>>{};
  for (final item in items) {
    final groupId = item.groupId;
    if (groupId == null) {
      blocks.add(ItemBlock(item));
      continue;
    }
    final run = runs[groupId];
    if (run != null) {
      run.add(item);
      continue;
    }
    final members = [item];
    runs[groupId] = members;
    blocks.add(GroupBlock(groupId: groupId, items: members));
  }
  blocks.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return blocks;
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
  final loose = <ItineraryItem>[];

  for (final item in items) {
    final branchId = item.alternativeId;
    if (branchId != null) {
      itemsByBranch.putIfAbsent(branchId, () => []).add(item);
    } else if (normalizeDay(item.date) == day) {
      loose.add(item);
    }
  }

  final blocks = buildItemBlocks(loose);

  for (final set in sets.values) {
    if (normalizeDay(set.date) != day) continue;
    final branches = branchesBySet[set.id] ?? const [];
    // A set with no branches is transient at most (the DAO dissolves one that
    // loses its last branch); skip it rather than render an empty card.
    if (branches.isEmpty) continue;
    blocks.add(
      DecisionBlock(
        set: set,
        branches: branches,
        itemsByBranch: {
          for (final branch in branches)
            branch.id: itemsByBranch[branch.id] ?? const [],
        },
      ),
    );
  }

  blocks.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return blocks;
}

/// [blocks]' items as one flat list, in the order the day reads them: a loose
/// item in its slot, a whole run in the slot its group occupies, and a
/// decision's *chosen* option's items in the slot the decision occupies.
///
/// This is the only correct way to walk a day's live items in order. Filtering
/// the trip's items with `liveItems` keeps them sorted by `sortOrder`, but a
/// branch item's `sortOrder` orders it *within its branch* — it shares no
/// ordering space with the day's loose items, so a branch's first item would
/// jump ahead of the loose items it comes after.
List<ItineraryItem> itemsInDayOrder(List<DayBlock> blocks) => [
  for (final block in blocks)
    ...switch (block) {
      ItemBlock(:final item) => [item],
      GroupBlock(:final items) => items,
      DecisionBlock(:final chosen, :final itemsByBranch) =>
        itemsByBranch[chosen.id] ?? const <ItineraryItem>[],
    },
];
