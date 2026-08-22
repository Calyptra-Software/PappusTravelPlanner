import 'package:drift/drift.dart';

import '../app_database.dart';
import '../item_copy.dart';
import '../tables.dart';

part 'group_dao.g.dart';

/// Manages [ItemGroups]: bundling adjacent itinerary items so they share a
/// single expense (e.g. a train ticket covering several legs). Also owns
/// [ItineraryItems] and [Costs] so grouping operations that re-point items and
/// costs run in one transaction.
@DriftAccessor(tables: [ItemGroups, ItineraryItems, Costs, Attachments])
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
  ///
  /// Throws if the two items sit in different alternative branches (or one in a
  /// branch and one loose): a group must lie entirely inside one branch or
  /// entirely outside, or whether its shared cost counts toward the trip would
  /// have no answer.
  Future<int> groupItems(int firstItemId, int secondItemId) {
    return transaction(() async {
      final first = await _item(firstItemId);
      final second = await _item(secondItemId);
      if (first.alternativeId != second.alternativeId) {
        throw ArgumentError('Cannot group items across alternative branches.');
      }
      final ga = first.groupId;
      final gb = second.groupId;

      if (ga != null && gb != null) {
        if (ga == gb) return ga;
        // Merge gb into ga: repoint its members and any shared costs, drop it.
        await (update(itineraryItems)..where((i) => i.groupId.equals(gb)))
            .write(ItineraryItemsCompanion(groupId: Value(ga)));
        await (update(costs)..where((c) => c.groupId.equals(gb))).write(
          CostsCompanion(groupId: Value(ga)),
        );
        await (delete(itemGroups)..where((g) => g.id.equals(gb))).go();
        return ga;
      }

      final target =
          ga ??
          gb ??
          await into(
            itemGroups,
          ).insert(ItemGroupsCompanion.insert(tripId: first.tripId));
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
      await (update(itineraryItems)..where((i) => i.id.equals(itemId))).write(
        const ItineraryItemsCompanion(groupId: Value(null)),
      );
      await _dissolveIfDegenerate(groupId);
    });
  }

  /// Fully dissolves a group: frees all its members and deletes it. Anything
  /// shared — the fare, and the files hung on the run itself — is kept,
  /// re-pointed to the group's first remaining member so it isn't lost with the
  /// group (it would otherwise cascade-delete).
  Future<void> dissolveGroup(int groupId) {
    return transaction(() async {
      await _preserveSharedThings(groupId);
      await (update(itineraryItems)..where((i) => i.groupId.equals(groupId)))
          .write(const ItineraryItemsCompanion(groupId: Value(null)));
      await (delete(itemGroups)..where((g) => g.id.equals(groupId))).go();
    });
  }

  /// Deletes a whole group **and its members**: the run goes, not just the
  /// bundle around it.
  ///
  /// The opposite of [dissolveGroup], which keeps the entries and only drops the
  /// bundling — so the money and the files are treated the opposite way too.
  /// There they are rescued onto the first surviving member; here nothing
  /// survives to carry them, so each member's own cascade with it and the run's
  /// shared ones cascade with the group. That is the honest reading: a ticket is
  /// not still paid for, nor worth keeping a photograph of, once every leg it
  /// covered has been deleted.
  Future<void> deleteGroup(int groupId) {
    return transaction(() async {
      await (delete(
        itineraryItems,
      )..where((i) => i.groupId.equals(groupId))).go();
      await (delete(itemGroups)..where((g) => g.id.equals(groupId))).go();
    });
  }

  /// Deletes an itinerary item, then tidies its former group the same way
  /// [removeFromGroup] does: a group left with fewer than two members is
  /// dissolved, its shared cost and files preserved on the remaining member (or
  /// dropped with the group when none remain). Without this, deleting grouped
  /// items would strand the group and its expenses — counted in the trip total
  /// but attached to nothing visible.
  Future<void> deleteItem(int itemId) {
    return transaction(() async {
      final item = await (select(
        itineraryItems,
      )..where((i) => i.id.equals(itemId))).getSingleOrNull();
      final groupId = item?.groupId;
      await (delete(itineraryItems)..where((i) => i.id.equals(itemId))).go();
      if (groupId != null) await _dissolveIfDegenerate(groupId);
    });
  }

  /// Moves a whole group to the end of another list — [day]'s loose items, or
  /// [alternativeId]'s option — with its members kept together and still
  /// grouped. This is how a bundle (a train journey on one ticket) relocates as
  /// a unit; moving a single member instead *leaves* the group (see
  /// [ItineraryDao.moveItem]).
  ///
  /// The shared cost rides along untouched: it hangs off the group, and the
  /// group survives the move. Members keep their order among themselves,
  /// appended after whatever the destination already holds.
  Future<void> moveGroup(
    int groupId, {
    required DateTime day,
    int? alternativeId,
  }) {
    return transaction(() async {
      final members = await _members(groupId);
      if (members.isEmpty) return;
      final base = alternativeId != null
          ? await attachedDatabase.itineraryDao.nextSortOrderInAlternative(
              alternativeId,
            )
          : await attachedDatabase.itineraryDao.nextSortOrder(
              members.first.tripId,
              day,
            );
      for (var i = 0; i < members.length; i++) {
        await (update(
          itineraryItems,
        )..where((it) => it.id.equals(members[i].id))).write(
          ItineraryItemsCompanion(
            date: Value(day),
            alternativeId: Value(alternativeId),
            sortOrder: Value(base + i),
          ),
        );
      }
    });
  }

  /// Copies a whole group to the end of [day] (or [alternativeId]'s option): a
  /// fresh group with the same name, holding a copy of each member. Returns the
  /// new group's id.
  ///
  /// As everywhere, a copy takes the **plan, not the money** — neither the
  /// members' own costs nor the group's shared cost come along ([copyItemPlan]).
  /// The copy is a bundle to price afresh, not a second claim on a payment that
  /// happened once.
  Future<int> copyGroup(
    int groupId, {
    required DateTime day,
    int? alternativeId,
  }) {
    return transaction(() async {
      final source = await _group(groupId);
      final members = await _members(groupId);
      final base = alternativeId != null
          ? await attachedDatabase.itineraryDao.nextSortOrderInAlternative(
              alternativeId,
            )
          : await attachedDatabase.itineraryDao.nextSortOrder(
              source.tripId,
              day,
            );
      final newGroupId = await into(itemGroups).insert(
        ItemGroupsCompanion.insert(
          tripId: source.tripId,
          label: Value(source.label),
        ),
      );
      for (var i = 0; i < members.length; i++) {
        final copy = await into(itineraryItems).insert(
          copyItemPlan(
            members[i],
            date: day,
            alternativeId: alternativeId,
            groupId: newGroupId,
            sortOrder: base + i,
          ),
        );
        // Each member brings the line it followed, as it brings its route.
        await attachedDatabase.trackDao.copyItemTracks(members[i].id, copy);
      }
      return newGroupId;
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
    return (update(itemGroups)..where((g) => g.id.equals(groupId))).write(
      ItemGroupsCompanion(collapsed: Value(collapsed)),
    );
  }

  Future<ItineraryItem> _item(int id) =>
      (select(itineraryItems)..where((i) => i.id.equals(id))).getSingle();

  Future<ItemGroup> _group(int id) =>
      (select(itemGroups)..where((g) => g.id.equals(id))).getSingle();

  /// Dissolves [groupId] when it no longer holds at least two members, so a
  /// group of one is never left dangling. Preserves what hangs on the run
  /// itself first — the fare and the shared files alike.
  Future<void> _dissolveIfDegenerate(int groupId) async {
    final members = await _members(groupId);
    if (members.length >= 2) return;
    await _preserveSharedThings(groupId, members: members);
    await (update(itineraryItems)..where((i) => i.groupId.equals(groupId)))
        .write(const ItineraryItemsCompanion(groupId: Value(null)));
    await (delete(itemGroups)..where((g) => g.id.equals(groupId))).go();
  }

  /// Re-points everything hanging on the group itself — its shared cost and its
  /// shared files — onto its first member (by day/sort/time), so they survive
  /// the group's deletion instead of cascading with it.
  ///
  /// **The fare and the ticket travel together**, because they are the same
  /// thing said twice: the price of the journey and the document proving it was
  /// bought. Ungrouping keeps the entries, so it has to keep what those entries
  /// paid for — a run whose photographed ticket vanished because somebody
  /// separated its legs would be the delete this act is advertised as *not*
  /// being. (Attachments were rescued only after the fact; the costs were right
  /// from the start, and one of the two being quietly destroyed is exactly the
  /// kind of inconsistency a comment like this exists to stop happening again.)
  ///
  /// A no-op when the group has no members left: there is nowhere to attach
  /// anything, and both cascade with the group — which is the honest reading,
  /// and the one [deleteGroup] relies on.
  Future<void> _preserveSharedThings(
    int groupId, {
    List<ItineraryItem>? members,
  }) async {
    final list = members ?? await _members(groupId);
    if (list.isEmpty) return;
    await (update(costs)..where((c) => c.groupId.equals(groupId))).write(
      CostsCompanion(groupId: const Value(null), itemId: Value(list.first.id)),
    );
    await (update(attachments)..where((a) => a.groupId.equals(groupId))).write(
      AttachmentsCompanion(
        groupId: const Value(null),
        itemId: Value(list.first.id),
      ),
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
