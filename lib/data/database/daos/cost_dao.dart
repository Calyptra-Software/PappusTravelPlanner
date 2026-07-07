import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'cost_dao.g.dart';

@DriftAccessor(
    tables: [Costs, CostReasons, People, CostBeneficiaries, ItineraryItems])
class CostDao extends DatabaseAccessor<AppDatabase> with _$CostDaoMixin {
  CostDao(super.db);

  /// All costs for a trip, oldest first: both those attached to the trip's
  /// itinerary items and trip-level costs attached to the trip directly. The
  /// left join lets a single query pick up trip-level costs (no matching item)
  /// alongside item costs.
  Stream<List<Cost>> watchCostsForTrip(int tripId) {
    final query = select(costs).join([
      leftOuterJoin(itineraryItems, itineraryItems.id.equalsExp(costs.itemId)),
    ])
      ..where(
        itineraryItems.tripId.equals(tripId) | costs.tripId.equals(tripId),
      )
      ..orderBy([OrderingTerm(expression: costs.createdAt)]);
    return query.watch().map(
          (rows) => rows.map((row) => row.readTable(costs)).toList(),
        );
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
    return (select(costReasons)
          ..orderBy([(r) => OrderingTerm(expression: r.label)]))
        .watch();
  }

  /// Creates the reason if needed and sets its icon (null = default icon).
  Future<void> setReasonIcon(String label, int? iconId) {
    return into(costReasons).insert(
      CostReasonsCompanion.insert(label: label, iconId: Value(iconId)),
      onConflict: DoUpdate((_) =>
          CostReasonsCompanion(iconId: Value(iconId)),
          target: [costReasons.label]),
    );
  }

  /// Forgets a saved reason. Existing costs keep their stored reason text.
  Future<int> deleteReason(String label) =>
      (delete(costReasons)..where((r) => r.label.equals(label))).go();

  // --- beneficiaries (who a cost was paid for) ---

  /// The people a cost was paid for, alphabetical by name.
  Stream<List<Person>> watchBeneficiaries(int costId) {
    final query = select(people).join([
      innerJoin(
        costBeneficiaries,
        costBeneficiaries.personId.equalsExp(people.id),
      ),
    ])
      ..where(costBeneficiaries.costId.equals(costId))
      ..orderBy([OrderingTerm(expression: people.name)]);
    return query
        .watch()
        .map((rows) => rows.map((row) => row.readTable(people)).toList());
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
        final person = await (select(people)..where((p) => p.name.equals(name)))
            .getSingle();
        ids.add(person.id);
      }
      if (ids.isEmpty) {
        await (delete(costBeneficiaries)..where((cb) => cb.costId.equals(costId)))
            .go();
        return;
      }
      // Drop links no longer wanted, then add the new ones (ignoring dupes).
      await (delete(costBeneficiaries)
            ..where(
                (cb) => cb.costId.equals(costId) & cb.personId.isNotIn(ids)))
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
      await (update(costs)..where((c) => c.paidBy.equals(from)))
          .write(CostsCompanion(paidBy: Value(to)));
      final targetExists =
          await (select(people)..where((p) => p.name.equals(to)))
              .getSingleOrNull();
      if (targetExists != null) {
        await (delete(people)..where((p) => p.name.equals(from))).go();
      } else {
        await (update(people)..where((p) => p.name.equals(from)))
            .write(PeopleCompanion(name: Value(to)));
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
      await (update(costs)..where((c) => c.reason.equals(from)))
          .write(CostsCompanion(reason: Value(to)));
      final targetExists = await (select(costReasons)
            ..where((r) => r.label.equals(to)))
          .getSingleOrNull();
      if (targetExists != null) {
        await (delete(costReasons)..where((r) => r.label.equals(from))).go();
      } else {
        await (update(costReasons)..where((r) => r.label.equals(from)))
            .write(CostReasonsCompanion(label: Value(to)));
      }
    });
  }
}
