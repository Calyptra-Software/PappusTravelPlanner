import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'cost_dao.g.dart';

@DriftAccessor(tables: [Costs, CostReasons, ItineraryItems])
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
}
