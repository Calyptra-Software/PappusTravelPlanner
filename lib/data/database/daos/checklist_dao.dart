import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'checklist_dao.g.dart';

@DriftAccessor(tables: [ChecklistItems])
class ChecklistDao extends DatabaseAccessor<AppDatabase>
    with _$ChecklistDaoMixin {
  ChecklistDao(super.db);

  /// All checklist items for a trip, in manual order then creation order.
  Stream<List<ChecklistItem>> watchChecklist(int tripId) {
    return (select(checklistItems)
          ..where((c) => c.tripId.equals(tripId))
          ..orderBy([
            (c) => OrderingTerm(expression: c.sortOrder),
            (c) => OrderingTerm(expression: c.createdAt),
          ]))
        .watch();
  }

  Future<int> addChecklistItem(ChecklistItemsCompanion item) =>
      into(checklistItems).insert(item);

  Future<bool> updateChecklistItem(ChecklistItem item) =>
      update(checklistItems).replace(item);

  Future<int> deleteChecklistItem(int id) =>
      (delete(checklistItems)..where((c) => c.id.equals(id))).go();

  /// Next sort order for a new item within a trip (appended to the end).
  Future<int> nextSortOrder(int tripId) async {
    final maxExpr = checklistItems.sortOrder.max();
    final query = selectOnly(checklistItems)
      ..addColumns([maxExpr])
      ..where(checklistItems.tripId.equals(tripId));
    final row = await query.getSingleOrNull();
    final current = row?.read(maxExpr);
    return (current ?? -1) + 1;
  }
}
