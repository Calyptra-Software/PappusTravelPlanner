import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'cost_dao.g.dart';

@DriftAccessor(
  tables: [
    Costs,
    CostReasons,
    People,
    CostBeneficiaries,
    ItineraryItems,
    ItemGroups,
    Alternatives,
    Currencies,
  ],
)
class CostDao extends DatabaseAccessor<AppDatabase> with _$CostDaoMixin {
  CostDao(super.db);

  /// All costs for a trip, oldest first, whichever way they are attached: to one
  /// of the trip's itinerary items, to a group of its items, or to the trip
  /// directly. The left joins let a single query reach every kind — a cost
  /// matches when its item, its group, or the cost itself belongs to the trip.
  ///
  /// Includes costs hanging off alternative branches that were *not* chosen —
  /// the timeline shows them, so each branch can be priced and compared. Only
  /// the totals must leave them out; see [watchCountedCostsForTrip].
  Stream<List<Cost>> watchCostsForTrip(int tripId) {
    final query =
        select(costs).join([
            leftOuterJoin(
              itineraryItems,
              itineraryItems.id.equalsExp(costs.itemId),
            ),
            leftOuterJoin(itemGroups, itemGroups.id.equalsExp(costs.groupId)),
          ])
          ..where(_belongsToTrip(tripId))
          ..orderBy([OrderingTerm(expression: costs.createdAt)]);
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(costs)).toList(),
    );
  }

  /// The costs of a trip that actually count: [watchCostsForTrip] minus the ones
  /// attached to an alternative branch that was not chosen. This is what the
  /// trip's total and its expense splitting are computed from — the roads not
  /// taken must not inflate the budget.
  ///
  /// Transfers ([Costs.isTransfer]) are included: they are what settles the
  /// balances, so the splitting must see them. Leaving them out of the *spend*
  /// figures is `computeTripStats`'s job, not this query's.
  Stream<List<Cost>> watchCountedCostsForTrip(int tripId) {
    final query =
        select(costs).join([
            leftOuterJoin(
              itineraryItems,
              itineraryItems.id.equalsExp(costs.itemId),
            ),
            leftOuterJoin(itemGroups, itemGroups.id.equalsExp(costs.groupId)),
            leftOuterJoin(
              alternatives,
              alternatives.id.equalsExp(itineraryItems.alternativeId),
            ),
          ])
          ..where(_belongsToTrip(tripId) & _countsTowardTotals())
          ..orderBy([OrderingTerm(expression: costs.createdAt)]);
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(costs)).toList(),
    );
  }

  /// Whether a cost belongs to [tripId], whichever way it is attached.
  Expression<bool> _belongsToTrip(int tripId) =>
      itineraryItems.tripId.equals(tripId) |
      itemGroups.tripId.equals(tripId) |
      costs.tripId.equals(tripId);

  /// Whether a cost counts toward its trip's totals: a trip-level cost always
  /// does; an item's cost does when the item is *live* (loose, or in the chosen
  /// branch of its decision); and a group's shared cost does when the group has
  /// a live member — a group never straddles two branches, so any member answers
  /// for all of them.
  ///
  /// Requires [alternatives] to be left-joined on the item's branch. The group
  /// case can't use that join (a group cost has no item row), so it re-reaches
  /// the group's members through a correlated subquery instead — joining them
  /// directly would fan a cost out into one row per member and double-count it.
  Expression<bool> _countsTowardTotals() {
    final itemIsLive =
        costs.itemId.isNotNull() &
        (itineraryItems.alternativeId.isNull() |
            alternatives.chosen.equals(true));
    return costs.tripId.isNotNull() | itemIsLive | _groupHasLiveMember();
  }

  Expression<bool> _groupHasLiveMember() {
    final member = alias(itineraryItems, 'group_member');
    final branch = alias(alternatives, 'member_branch');
    final query =
        selectOnly(member).join([
            leftOuterJoin(branch, branch.id.equalsExp(member.alternativeId)),
          ])
          ..addColumns([member.id])
          ..where(
            member.groupId.equalsExp(costs.groupId) &
                (member.alternativeId.isNull() | branch.chosen.equals(true)),
          );
    return costs.groupId.isNotNull() & existsQuery(query);
  }

  /// Per-currency cost totals for every trip, keyed by trip id and then by
  /// currency **code** (amounts stay in minor units). Reaches costs the same
  /// three ways as [watchCostsForTrip] — attached to an item, a group, or the
  /// trip directly — resolving each cost's trip from whichever link it has, and
  /// leaving out the costs of unchosen alternative branches (see
  /// [_countsTowardTotals]) as well as transfers (money moved between people is
  /// not money spent — see [Costs.isTransfer]). Powers the total shown on each
  /// overview card in one query instead of a stream per trip. Trips with no
  /// costs are absent from the map.
  ///
  /// The currency is joined in and keyed by its code rather than its row id so
  /// the result reads the same way `sumByCurrency` does, and so a card can label
  /// a total without a second lookup.
  Stream<Map<int, Map<String, int>>> watchTotalsByTrip() {
    final query = select(costs).join([
      leftOuterJoin(itineraryItems, itineraryItems.id.equalsExp(costs.itemId)),
      leftOuterJoin(itemGroups, itemGroups.id.equalsExp(costs.groupId)),
      leftOuterJoin(
        alternatives,
        alternatives.id.equalsExp(itineraryItems.alternativeId),
      ),
      innerJoin(currencies, currencies.id.equalsExp(costs.currency)),
    ])..where(_countsTowardTotals() & costs.isTransfer.equals(false));
    return query.watch().map((rows) {
      final byTrip = <int, Map<String, int>>{};
      for (final row in rows) {
        final cost = row.readTable(costs);
        final tripId =
            cost.tripId ??
            row.readTableOrNull(itineraryItems)?.tripId ??
            row.readTableOrNull(itemGroups)?.tripId;
        if (tripId == null) continue;
        final totals = byTrip.putIfAbsent(tripId, () => {});
        totals.update(
          row.readTable(currencies).code,
          (v) => v + cost.amountMinor,
          ifAbsent: () => cost.amountMinor,
        );
      }
      return byTrip;
    });
  }

  Future<int> addCost(CostsCompanion cost) => into(costs).insert(cost);

  Future<bool> updateCost(Cost cost) => update(costs).replace(cost);

  Future<int> deleteCost(int id) =>
      (delete(costs)..where((c) => c.id.equals(id))).go();

  /// Remembers a reason label for reuse; a no-op if it already exists. Leaves
  /// an existing reason's icon untouched.
  Future<void> upsertReason(String label) {
    return into(costReasons).insert(
      CostReasonsCompanion.insert(label: label),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// All saved reason labels, alphabetical.
  Stream<List<String>> watchReasons() {
    return (select(costReasons)
          ..orderBy([(r) => OrderingTerm(expression: r.label)]))
        .watch()
        .map((rows) => rows.map((r) => r.label).toList());
  }

  /// All saved reasons with their icons, alphabetical by label. Used by the
  /// settings management list and by the chip's label -> icon lookup.
  Stream<List<CostReason>> watchReasonRows() {
    return (select(
      costReasons,
    )..orderBy([(r) => OrderingTerm(expression: r.label)])).watch();
  }

  /// Creates the reason if needed and sets its icon (null = default icon).
  Future<void> setReasonIcon(String label, int? iconId) {
    return into(costReasons).insert(
      CostReasonsCompanion.insert(label: label, iconId: Value(iconId)),
      onConflict: DoUpdate(
        (_) => CostReasonsCompanion(iconId: Value(iconId)),
        target: [costReasons.label],
      ),
    );
  }

  /// Forgets a saved reason. Existing costs keep their stored reason text.
  Future<int> deleteReason(String label) =>
      (delete(costReasons)..where((r) => r.label.equals(label))).go();

  // --- beneficiaries (who a cost was paid for) ---

  /// The people a cost was paid for, alphabetical by name.
  Stream<List<Person>> watchBeneficiaries(int costId) {
    final query =
        select(people).join([
            innerJoin(
              costBeneficiaries,
              costBeneficiaries.personId.equalsExp(people.id),
            ),
          ])
          ..where(costBeneficiaries.costId.equals(costId))
          ..orderBy([OrderingTerm(expression: people.name)]);
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(people)).toList(),
    );
  }

  /// Beneficiary links for every cost in a trip, keyed by cost id, so statistics
  /// can compute each expense's split in a single pass instead of one stream per
  /// cost. Mirrors [watchCostsForTrip]'s reach: costs on the trip's itinerary
  /// items and trip-level costs alike. Costs with no beneficiaries are absent
  /// from the map.
  Stream<Map<int, List<Person>>> watchBeneficiariesForTrip(int tripId) {
    final query =
        select(costBeneficiaries).join([
            innerJoin(costs, costs.id.equalsExp(costBeneficiaries.costId)),
            innerJoin(people, people.id.equalsExp(costBeneficiaries.personId)),
            leftOuterJoin(
              itineraryItems,
              itineraryItems.id.equalsExp(costs.itemId),
            ),
            leftOuterJoin(itemGroups, itemGroups.id.equalsExp(costs.groupId)),
          ])
          ..where(
            itineraryItems.tripId.equals(tripId) |
                itemGroups.tripId.equals(tripId) |
                costs.tripId.equals(tripId),
          )
          ..orderBy([OrderingTerm(expression: people.name)]);
    return query.watch().map((rows) {
      final byCost = <int, List<Person>>{};
      for (final row in rows) {
        final costId = row.readTable(costBeneficiaries).costId;
        byCost.putIfAbsent(costId, () => []).add(row.readTable(people));
      }
      return byCost;
    });
  }

  /// Replaces a cost's beneficiaries with exactly [names], creating any missing
  /// people in the shared roster. Runs in a transaction so the set is never left
  /// half-updated.
  Future<void> setBeneficiaries(int costId, List<String> names) async {
    await transaction(() async {
      final ids = <int>[];
      for (final name in names) {
        await into(people).insert(
          PeopleCompanion.insert(name: name),
          mode: InsertMode.insertOrIgnore,
        );
        final person = await (select(
          people,
        )..where((p) => p.name.equals(name))).getSingle();
        ids.add(person.id);
      }
      if (ids.isEmpty) {
        await (delete(
          costBeneficiaries,
        )..where((cb) => cb.costId.equals(costId))).go();
        return;
      }
      // Drop links no longer wanted, then add the new ones (ignoring dupes).
      await (delete(
            costBeneficiaries,
          )..where((cb) => cb.costId.equals(costId) & cb.personId.isNotIn(ids)))
          .go();
      for (final id in ids) {
        await into(costBeneficiaries).insert(
          CostBeneficiariesCompanion.insert(costId: costId, personId: id),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  // --- people (settings) ---

  /// Remembers a person for reuse; a no-op if they already exist.
  Future<void> upsertPerson(String name) {
    return into(people).insert(
      PeopleCompanion.insert(name: name),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// All saved people, alphabetical.
  Stream<List<String>> watchPeople() {
    return (select(people)..orderBy([(p) => OrderingTerm(expression: p.name)]))
        .watch()
        .map((rows) => rows.map((p) => p.name).toList());
  }

  /// All saved people as rows (carrying their id and [Person.isMe] flag),
  /// alphabetical. Used by the settings list to show and set who "me" is.
  Stream<List<Person>> watchPeopleRows() {
    return (select(
      people,
    )..orderBy([(p) => OrderingTerm(expression: p.name)])).watch();
  }

  /// The person the user has marked as themselves, or null if none is set.
  Stream<Person?> watchMePerson() {
    return (select(people)
          ..where((p) => p.isMe.equals(true))
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Marks [personId] as the "me" person, clearing any previous one. Passing
  /// null just clears the flag so no one is "me". Runs in a transaction so at
  /// most one person is ever flagged.
  Future<void> setMePerson(int? personId) async {
    await transaction(() async {
      await (update(people)..where((p) => p.isMe.equals(true))).write(
        const PeopleCompanion(isMe: Value(false)),
      );
      if (personId != null) {
        await (update(people)..where((p) => p.id.equals(personId))).write(
          const PeopleCompanion(isMe: Value(true)),
        );
      }
    });
  }

  /// Forgets a saved person. Existing costs keep their stored payer text.
  Future<int> deletePerson(String name) =>
      (delete(people)..where((p) => p.name.equals(name))).go();

  /// Renames a saved person [from] -> [to], repointing every cost they paid so
  /// all appearances follow. If [to] already exists the two are merged: the
  /// costs are repointed and the old name is dropped. Runs in a transaction so
  /// costs never end up pointing at a forgotten payer.
  Future<void> renamePerson(String from, String to) async {
    if (from == to) return;
    await transaction(() async {
      await (update(costs)..where((c) => c.paidBy.equals(from))).write(
        CostsCompanion(paidBy: Value(to)),
      );
      final targetExists = await (select(
        people,
      )..where((p) => p.name.equals(to))).getSingleOrNull();
      if (targetExists != null) {
        await (delete(people)..where((p) => p.name.equals(from))).go();
      } else {
        await (update(people)..where((p) => p.name.equals(from))).write(
          PeopleCompanion(name: Value(to)),
        );
      }
    });
  }

  /// Renames a saved reason [from] -> [to], repointing every cost that uses it
  /// so all appearances follow. If [to] already exists the two are merged: the
  /// costs are repointed and the old label is dropped (the existing label keeps
  /// its icon). Runs in a transaction so costs never end up orphaned.
  Future<void> renameReason(String from, String to) async {
    if (from == to) return;
    await transaction(() async {
      await (update(costs)..where((c) => c.reason.equals(from))).write(
        CostsCompanion(reason: Value(to)),
      );
      final targetExists = await (select(
        costReasons,
      )..where((r) => r.label.equals(to))).getSingleOrNull();
      if (targetExists != null) {
        await (delete(costReasons)..where((r) => r.label.equals(from))).go();
      } else {
        await (update(costReasons)..where((r) => r.label.equals(from))).write(
          CostReasonsCompanion(label: Value(to)),
        );
      }
    });
  }
}
