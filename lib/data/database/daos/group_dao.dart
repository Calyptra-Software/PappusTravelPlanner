import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'group_dao.g.dart';

/// Manages [ItemGroups]: bundling adjacent itinerary items so they share a
/// single expense (e.g. a train ticket covering several legs). Also owns
/// [ItineraryItems] and [Costs] so grouping operations that re-point items and
/// costs run in one transaction.
@DriftAccessor(tables: [ItemGroups, ItineraryItems, Costs])
class GroupDao extends DatabaseAccessor<AppDatabase> with _$GroupDaoMixin {
  GroupDao(super.db);

  /// All groups for a trip, keyed by id, so the UI can resolve an item's group
  /// (label, collapsed state) without one stream per group.
  Stream<Map<int, ItemGroup>> watchGroupsForTrip(int tripId) {
    return (select(itemGroups)..where((g) => g.tripId.equals(tripId)))
        .watch()
        .map((rows) => {for (final g in rows) g.id: g});
  }

  /// Puts two items into the same group and returns the resulting group id.
  /// Creates a group if neither is grouped yet, extends the existing one if just
  /// one is, and merges the two groups (moving the second's members and costs
  /// into the first, then deleting it) if both already belong to different
  /// groups. Adjacency is the caller's concern — this only wires up membership.
  Future<int> groupItems(int firstItemId, int secondItemId) {
    return transaction(() async {
      final first = await _item(firstItemId);
      final second = await _item(secondItemId);
      final ga = first.groupId;
      final gb = second.groupId;

      if (ga != null && gb != null) {
        if (ga == gb) return ga;
        // Merge gb into ga: repoint its members and any shared costs, drop it.
        await (update(itineraryItems)..where((i) => i.groupId.equals(gb)))
            .write(ItineraryItemsCompanion(groupId: Value(ga)));
        await (update(costs)..where((c) => c.groupId.equals(gb)))
            .write(CostsCompanion(groupId: Value(ga)));
        await (delete(itemGroups)..where((g) => g.id.equals(gb))).go();
        return ga;
      }

      final target = ga ??
          gb ??
          await into(itemGroups)
              .insert(ItemGroupsCompanion.insert(tripId: first.tripId));
      await (update(itineraryItems)
            ..where((i) => i.id.isIn([firstItemId, secondItemId])))
          .write(ItineraryItemsCompanion(groupId: Value(target)));
      return target;
    });
  }

  /// Removes a single item from its group. A group with fewer than two members
  /// left is dissolved (its lone member is freed and any shared costs are
  /// preserved by re-pointing them to that member — see [_dissolveIfDegenerate]).
  Future<void> removeFromGroup(int itemId) {
    return transaction(() async {
      final item = await _item(itemId);
      final groupId = item.groupId;
      if (groupId == null) return;
      await (update(itineraryItems)..where((i) => i.id.equals(itemId)))
          .write(const ItineraryItemsCompanion(groupId: Value(null)));
      await _dissolveIfDegenerate(groupId);
    });
  }

  /// Fully dissolves a group: frees all its members and deletes it. Any shared
  /// costs are kept, re-pointed to the group's first remaining member so the
  /// expense isn't lost with the group (they would otherwise cascade-delete).
  Future<void> dissolveGroup(int groupId) {
    return transaction(() async {
      await _preserveCosts(groupId);
      await (update(itineraryItems)..where((i) => i.groupId.equals(groupId)))
          .write(const ItineraryItemsCompanion(groupId: Value(null)));
      await (delete(itemGroups)..where((g) => g.id.equals(groupId))).go();
    });
  }

  /// Deletes an itinerary item, then tidies its former group the same way
  /// [removeFromGroup] does: a group left with fewer than two members is
  /// dissolved, its shared costs preserved on the remaining member (or dropped
  /// with the group when none remain). Without this, deleting grouped items
  /// would strand the group and its expenses — counted in the trip total but
  /// attached to nothing visible.
  Future<void> deleteItem(int itemId) {
    return transaction(() async {
      final item = await (select(itineraryItems)
            ..where((i) => i.id.equals(itemId)))
          .getSingleOrNull();
      final groupId = item?.groupId;
      await (delete(itineraryItems)..where((i) => i.id.equals(itemId))).go();
      if (groupId != null) await _dissolveIfDegenerate(groupId);
    });
  }

  /// Sets a group's display name (null/empty clears it, falling back to the
  /// default label in the UI).
  Future<void> setGroupLabel(int groupId, String? label) {
    final trimmed = label?.trim();
    return (update(itemGroups)..where((g) => g.id.equals(groupId))).write(
      ItemGroupsCompanion(
        label: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
      ),
    );
  }

  /// Marks a group collapsed or expanded in the overview.
  Future<void> setGroupCollapsed(int groupId, bool collapsed) {
    return (update(itemGroups)..where((g) => g.id.equals(groupId)))
        .write(ItemGroupsCompanion(collapsed: Value(collapsed)));
  }

  Future<ItineraryItem> _item(int id) =>
      (select(itineraryItems)..where((i) => i.id.equals(id))).getSingle();

  /// Dissolves [groupId] when it no longer holds at least two members, so a
  /// group of one is never left dangling. Preserves its costs first.
  Future<void> _dissolveIfDegenerate(int groupId) async {
    final members = await _members(groupId);
    if (members.length >= 2) return;
    await _preserveCosts(groupId, members: members);
    await (update(itineraryItems)..where((i) => i.groupId.equals(groupId)))
        .write(const ItineraryItemsCompanion(groupId: Value(null)));
    await (delete(itemGroups)..where((g) => g.id.equals(groupId))).go();
  }

  /// Re-points a group's shared costs onto its first member (by day/sort/time)
  /// so they survive the group's deletion. A no-op when the group has no members
  /// left — in that case the costs cascade-delete with the group, as there is
  /// nowhere to attach them.
  Future<void> _preserveCosts(int groupId, {List<ItineraryItem>? members}) async {
    final list = members ?? await _members(groupId);
    if (list.isEmpty) return;
    await (update(costs)..where((c) => c.groupId.equals(groupId))).write(
      CostsCompanion(groupId: const Value(null), itemId: Value(list.first.id)),
    );
  }

  /// A group's members in itinerary order (day, then manual sort, then time).
  Future<List<ItineraryItem>> _members(int groupId) {
    return (select(itineraryItems)
          ..where((i) => i.groupId.equals(groupId))
          ..orderBy([
            (i) => OrderingTerm(expression: i.date),
            (i) => OrderingTerm(expression: i.sortOrder),
            (i) => OrderingTerm(
                  expression: i.startMinutes,
                  nulls: NullsOrder.last,
                ),
          ]))
        .get();
  }
}
