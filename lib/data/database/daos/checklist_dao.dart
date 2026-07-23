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

  // --- moving and copying between trips ---

  /// Moves a whole checklist to [tripId], appended after that trip's lists.
  ///
  /// Its entries come along untouched — ticks included: it is the same list,
  /// relocated, so what was already done stays done. (Compare [copyChecklist],
  /// where a *new* list starts from scratch.)
  Future<void> moveChecklist(int checklistId, int tripId) {
    return transaction(() async {
      final sortOrder = await nextChecklistSortOrder(tripId);
      await (update(checklists)..where((c) => c.id.equals(checklistId))).write(
        ChecklistsCompanion(tripId: Value(tripId), sortOrder: Value(sortOrder)),
      );
    });
  }

  /// Copies a checklist to [tripId] — the list, its name (unless [title]
  /// overrides it) and every entry — and returns the new list's id.
  ///
  /// **Ticks are not copied.** A tick records that this was packed, on that
  /// trip; carrying it over would hand you a packing list that claims to be
  /// already done. Reusing last summer's list is the whole point of copying one,
  /// and it is only reusable empty.
  Future<int> copyChecklist(int checklistId, int tripId, {String? title}) {
    return transaction(() async {
      final source = await (select(
        checklists,
      )..where((c) => c.id.equals(checklistId))).getSingle();
      final sortOrder = await nextChecklistSortOrder(tripId);
      final copyId = await into(checklists).insert(
        ChecklistsCompanion.insert(
          tripId: tripId,
          title: Value(title ?? source.title),
          sortOrder: Value(sortOrder),
        ),
      );
      final entries =
          await (select(checklistItems)
                ..where((c) => c.checklistId.equals(checklistId))
                ..orderBy([
                  (c) => OrderingTerm(expression: c.sortOrder),
                  (c) => OrderingTerm(expression: c.createdAt),
                ]))
              .get();
      for (var i = 0; i < entries.length; i++) {
        await into(checklistItems).insert(
          ChecklistItemsCompanion.insert(
            checklistId: copyId,
            label: entries[i].label,
            sortOrder: Value(i),
          ),
        );
      }
      return copyId;
    });
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
