import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'checklist_dao.g.dart';

@DriftAccessor(tables: [Checklists, ChecklistItems])
class ChecklistDao extends DatabaseAccessor<AppDatabase>
    with _$ChecklistDaoMixin {
  ChecklistDao(super.db);

  // --- checklists ---

  /// A trip's checklists, in manual then creation order.
  Stream<List<Checklist>> watchChecklists(int tripId) {
    return (select(checklists)
          ..where((c) => c.tripId.equals(tripId))
          ..orderBy([
            (c) => OrderingTerm(expression: c.sortOrder),
            (c) => OrderingTerm(expression: c.createdAt),
          ]))
        .watch();
  }

  Future<int> addChecklist(ChecklistsCompanion checklist) =>
      into(checklists).insert(checklist);

  Future<bool> updateChecklist(Checklist checklist) =>
      update(checklists).replace(checklist);

  Future<int> deleteChecklist(int id) =>
      (delete(checklists)..where((c) => c.id.equals(id))).go();

  /// Next sort order for a new checklist within a trip (appended to the end).
  Future<int> nextChecklistSortOrder(int tripId) async {
    final maxExpr = checklists.sortOrder.max();
    final query = selectOnly(checklists)
      ..addColumns([maxExpr])
      ..where(checklists.tripId.equals(tripId));
    final row = await query.getSingleOrNull();
    return (row?.read(maxExpr) ?? -1) + 1;
  }

  // --- items ---

  /// A checklist's items, in manual then creation order.
  Stream<List<ChecklistItem>> watchItems(int checklistId) {
    return (select(checklistItems)
          ..where((c) => c.checklistId.equals(checklistId))
          ..orderBy([
            (c) => OrderingTerm(expression: c.sortOrder),
            (c) => OrderingTerm(expression: c.createdAt),
          ]))
        .watch();
  }

  Future<int> addItem(ChecklistItemsCompanion item) =>
      into(checklistItems).insert(item);

  Future<bool> updateItem(ChecklistItem item) =>
      update(checklistItems).replace(item);

  Future<int> deleteItem(int id) =>
      (delete(checklistItems)..where((c) => c.id.equals(id))).go();

  /// Next sort order for a new item within a checklist (appended to the end).
  Future<int> nextItemSortOrder(int checklistId) async {
    final maxExpr = checklistItems.sortOrder.max();
    final query = selectOnly(checklistItems)
      ..addColumns([maxExpr])
      ..where(checklistItems.checklistId.equals(checklistId));
    final row = await query.getSingleOrNull();
    return (row?.read(maxExpr) ?? -1) + 1;
  }
}
