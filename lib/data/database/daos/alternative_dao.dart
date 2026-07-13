import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'alternative_dao.g.dart';

/// Manages [AlternativeSets] and [Alternatives]: competing versions of one
/// stretch of a day, of which exactly one is chosen (and, once the day is over,
/// marked as the one actually done).
///
/// Two invariants are maintained here rather than in the schema:
///
/// - **At most one branch per set is chosen**, and exactly one is whenever the
///   set has any branches at all — mirroring how [CostDao.setMePerson] keeps a
///   single [People.isMe]. A set without a chosen branch would leave the day with
///   nothing to show and its costs counting toward nothing.
/// - **A set always holds at least two branches.** One left with a single branch
///   is no longer a decision, so it is flattened: that branch's items are
///   promoted back to loose items in the day and the set disappears — the mirror
///   image of [GroupDao]'s dissolving of a degenerate group.
///
/// Also owns [ItineraryItems] so moving items into and out of branches, and
/// re-numbering the day around them, runs in one transaction.
@DriftAccessor(tables: [AlternativeSets, Alternatives, ItineraryItems])
class AlternativeDao extends DatabaseAccessor<AppDatabase>
    with _$AlternativeDaoMixin {
  AlternativeDao(super.db);

  /// All of a trip's decision points, keyed by id, so the timeline can place
  /// each one in its day without a stream per set.
  Stream<Map<int, AlternativeSet>> watchSetsForTrip(int tripId) {
    return (select(alternativeSets)..where((s) => s.tripId.equals(tripId)))
        .watch()
        .map((rows) => {for (final s in rows) s.id: s});
  }

  /// The branches of every set in a trip, keyed by set id and in swipe order.
  /// Sets with no branches (transient at most) are absent from the map.
  Stream<Map<int, List<Alternative>>> watchBranchesForTrip(int tripId) {
    final query = select(alternatives).join([
      innerJoin(
        alternativeSets,
        alternativeSets.id.equalsExp(alternatives.setId),
      ),
    ])
      ..where(alternativeSets.tripId.equals(tripId))
      ..orderBy([OrderingTerm(expression: alternatives.sortOrder)]);
    return query.watch().map((rows) {
      final bySet = <int, List<Alternative>>{};
      for (final row in rows) {
        final branch = row.readTable(alternatives);
        bySet.putIfAbsent(branch.setId, () => []).add(branch);
      }
      return bySet;
    });
  }

  /// Turns an existing item into a decision point: the item — together with its
  /// whole group, if it is grouped, since a group never straddles two branches —
  /// moves into a first branch, which is chosen, and an empty second branch is
  /// added for the alternative the user is about to plan. Returns the new set's
  /// id.
  ///
  /// The set takes over the item's slot in the day, so the surrounding entries
  /// keep their order. Throws if the item is already inside a branch, or if it
  /// belongs to a group spanning several days — branches are day-scoped, so such
  /// a group has no single day to sit on.
  Future<int> createSetFromItem(int itemId, {String? label}) {
    return transaction(() async {
      final item = await _item(itemId);
      if (item.alternativeId != null) {
        throw ArgumentError.value(
          itemId,
          'itemId',
          'Item is already inside a branch.',
        );
      }
      final members =
          item.groupId == null ? [item] : await _groupMembers(item.groupId!);
      if (members.map((m) => m.date).toSet().length > 1) {
        throw ArgumentError.value(
          itemId,
          'itemId',
          'A group spanning several days cannot become an alternative.',
        );
      }

      final anchor = members.first;
      final setId = await into(alternativeSets).insert(
        AlternativeSetsCompanion.insert(
          tripId: item.tripId,
          date: anchor.date,
          sortOrder: Value(anchor.sortOrder),
          label: Value(_clean(label)),
        ),
      );
      final chosen = await into(alternatives).insert(
        AlternativesCompanion.insert(
          setId: setId,
          sortOrder: const Value(0),
          chosen: const Value(true),
        ),
      );
      await into(alternatives).insert(
        AlternativesCompanion.insert(setId: setId, sortOrder: const Value(1)),
      );
      // Inside a branch, sortOrder orders the items within that branch.
      for (var i = 0; i < members.length; i++) {
        await (update(itineraryItems)
              ..where((it) => it.id.equals(members[i].id)))
            .write(ItineraryItemsCompanion(
          alternativeId: Value(chosen),
          sortOrder: Value(i),
        ));
      }
      return setId;
    });
  }

  /// Adds a further, empty branch at the end of a set. Returns its id.
  Future<int> addAlternative(int setId, {String? label}) {
    return transaction(() async {
      final maxExpr = alternatives.sortOrder.max();
      final query = selectOnly(alternatives)
        ..addColumns([maxExpr])
        ..where(alternatives.setId.equals(setId));
      final row = await query.getSingleOrNull();
      final next = (row?.read(maxExpr) ?? -1) + 1;
      return into(alternatives).insert(
        AlternativesCompanion.insert(
          setId: setId,
          sortOrder: Value(next),
          label: Value(_clean(label)),
        ),
      );
    });
  }

  /// Selects the branch the plan follows, clearing the set's previous choice.
  /// This is what moves the trip's totals: only the chosen branch's costs count.
  Future<void> chooseAlternative(int alternativeId) {
    return transaction(() async {
      final branch = await _alternative(alternativeId);
      await (update(alternatives)..where((a) => a.setId.equals(branch.setId)))
          .write(const AlternativesCompanion(chosen: Value(false)));
      await (update(alternatives)..where((a) => a.id.equals(alternativeId)))
          .write(const AlternativesCompanion(chosen: Value(true)));
    });
  }

  /// Deletes a branch **and every item in it** (a branch's items exist only as
  /// part of it), then tidies the set: one left with a single branch is
  /// flattened back into the day, and one that just lost its chosen branch
  /// falls back to its first.
  Future<void> deleteAlternative(int alternativeId) {
    return transaction(() async {
      final branch = await _alternative(alternativeId);
      // Items (and, through them, their costs) cascade with the branch.
      await (delete(alternatives)..where((a) => a.id.equals(alternativeId)))
          .go();
      await _tidySet(branch.setId);
    });
  }

  /// Resolves a decision by keeping one branch and discarding the rest: its
  /// items become ordinary items of the day again, in the set's old slot, and
  /// the set — with every other branch and their items — is deleted.
  ///
  /// The destructive way to settle a decision: use it once an option is not just
  /// chosen but the others are no longer worth keeping. Simply leaving the set in
  /// place, with the option that happened chosen, keeps the roads not taken.
  Future<void> keepOnly(int alternativeId) {
    return transaction(() async => _flatten(await _alternative(alternativeId)));
  }

  /// Discards a whole decision: the set, all its branches and all their items
  /// (and those items' costs). Nothing is promoted back into the day.
  Future<int> deleteSet(int setId) =>
      (delete(alternativeSets)..where((s) => s.id.equals(setId))).go();

  /// Moves a set to another slot in its day, when the timeline's blocks — that
  /// day's loose items and decisions alike — are dragged into a new order.
  Future<void> setSortOrder(int setId, int sortOrder) {
    return (update(alternativeSets)..where((s) => s.id.equals(setId)))
        .write(AlternativeSetsCompanion(sortOrder: Value(sortOrder)));
  }

  /// Sets a set's display name (null/empty clears it, falling back to the
  /// default label in the UI).
  Future<void> setSetLabel(int setId, String? label) {
    return (update(alternativeSets)..where((s) => s.id.equals(setId)))
        .write(AlternativeSetsCompanion(label: Value(_clean(label))));
  }

  /// Sets a branch's display name (null/empty falls back to "Option A/B/C").
  Future<void> setAlternativeLabel(int alternativeId, String? label) {
    return (update(alternatives)..where((a) => a.id.equals(alternativeId)))
        .write(AlternativesCompanion(label: Value(_clean(label))));
  }

  // --- internals ---

  /// Promotes [branch]'s items back into the day as loose items, then deletes
  /// the set (cascading every other branch and its items).
  ///
  /// The set held one slot in the day's ordering space but its items need one
  /// each, so the day's later entries — loose items and other sets alike — are
  /// shifted up to make room, keeping the day's order intact.
  Future<void> _flatten(Alternative branch) async {
    final set = await _set(branch.setId);
    final members = await _branchItems(branch.id);

    final shift = members.length - 1;
    if (shift > 0) {
      await customUpdate(
        'UPDATE itinerary_items SET sort_order = sort_order + ? '
        'WHERE trip_id = ? AND date = ? AND alternative_id IS NULL '
        'AND sort_order > ?',
        variables: [
          Variable.withInt(shift),
          Variable.withInt(set.tripId),
          Variable.withDateTime(set.date),
          Variable.withInt(set.sortOrder),
        ],
        updates: {itineraryItems},
      );
      await customUpdate(
        'UPDATE alternative_sets SET sort_order = sort_order + ? '
        'WHERE trip_id = ? AND date = ? AND sort_order > ?',
        variables: [
          Variable.withInt(shift),
          Variable.withInt(set.tripId),
          Variable.withDateTime(set.date),
          Variable.withInt(set.sortOrder),
        ],
        updates: {alternativeSets},
      );
    }

    // Detach the items *before* dropping the set, or they would cascade with it.
    for (var i = 0; i < members.length; i++) {
      await (update(itineraryItems)..where((it) => it.id.equals(members[i].id)))
          .write(ItineraryItemsCompanion(
        alternativeId: const Value(null),
        sortOrder: Value(set.sortOrder + i),
      ));
    }
    await (delete(alternativeSets)..where((s) => s.id.equals(set.id))).go();
  }

  /// Restores the set's invariants after a branch was removed: no branches left
  /// means the set goes; a single branch left means it is no longer a decision
  /// and is flattened back into the day; and a set whose chosen branch is gone
  /// falls back to its first, so there is always exactly one chosen.
  Future<void> _tidySet(int setId) async {
    final branches = await _branches(setId);
    if (branches.isEmpty) {
      await (delete(alternativeSets)..where((s) => s.id.equals(setId))).go();
      return;
    }
    if (branches.length == 1) {
      await _flatten(branches.single);
      return;
    }
    if (!branches.any((b) => b.chosen)) {
      await (update(alternatives)..where((a) => a.id.equals(branches.first.id)))
          .write(const AlternativesCompanion(chosen: Value(true)));
    }
  }

  Future<ItineraryItem> _item(int id) =>
      (select(itineraryItems)..where((i) => i.id.equals(id))).getSingle();

  Future<Alternative> _alternative(int id) =>
      (select(alternatives)..where((a) => a.id.equals(id))).getSingle();

  Future<AlternativeSet> _set(int id) =>
      (select(alternativeSets)..where((s) => s.id.equals(id))).getSingle();

  /// A set's branches in swipe order.
  Future<List<Alternative>> _branches(int setId) {
    return (select(alternatives)
          ..where((a) => a.setId.equals(setId))
          ..orderBy([(a) => OrderingTerm(expression: a.sortOrder)]))
        .get();
  }

  /// A branch's items in timeline order.
  Future<List<ItineraryItem>> _branchItems(int alternativeId) {
    return (select(itineraryItems)
          ..where((i) => i.alternativeId.equals(alternativeId))
          ..orderBy([
            (i) => OrderingTerm(expression: i.sortOrder),
            (i) => OrderingTerm(
                  expression: i.startMinutes,
                  nulls: NullsOrder.last,
                ),
          ]))
        .get();
  }

  /// A group's members in itinerary order (day, then manual sort, then time).
  Future<List<ItineraryItem>> _groupMembers(int groupId) {
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

  String? _clean(String? label) {
    final trimmed = label?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
