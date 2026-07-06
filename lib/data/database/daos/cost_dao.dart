import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'cost_dao.g.dart';

@DriftAccessor(tables: [Costs, CostReasons, ItineraryItems])
class CostDao extends DatabaseAccessor<AppDatabase> with _$CostDaoMixin {
  CostDao(super.db);

  /// All costs belonging to a trip's itinerary items, oldest first.
  Stream<List<Cost>> watchCostsForTrip(int tripId) {
    final query = select(costs).join([
      innerJoin(itineraryItems, itineraryItems.id.equalsExp(costs.itemId)),
    ])
      ..where(itineraryItems.tripId.equals(tripId))
      ..orderBy([OrderingTerm(expression: costs.createdAt)]);
    return query.watch().map(
          (rows) => rows.map((row) => row.readTable(costs)).toList(),
        );
  }

  Future<int> addCost(CostsCompanion cost) => into(costs).insert(cost);

  Future<bool> updateCost(Cost cost) => update(costs).replace(cost);

  Future<int> deleteCost(int id) =>
      (delete(costs)..where((c) => c.id.equals(id))).go();

  /// Remembers a reason label for reuse; a no-op if it already exists.
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
}
