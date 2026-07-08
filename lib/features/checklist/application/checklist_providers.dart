import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';

/// A trip's checklists, in manual then creation order.
final checklistsProvider =
    StreamProvider.autoDispose.family<List<Checklist>, int>((ref, tripId) {
  return ref.watch(repositoryProvider).watchChecklists(tripId);
});

/// The items of a single checklist, in manual then creation order.
final checklistItemsProvider =
    StreamProvider.autoDispose.family<List<ChecklistItem>, int>(
        (ref, checklistId) {
  return ref.watch(repositoryProvider).watchChecklistItems(checklistId);
});

final checklistControllerProvider =
    Provider<ChecklistController>((ref) => ChecklistController(ref));

/// Manages a trip's checklists and their items.
class ChecklistController {
  ChecklistController(this._ref);
  final Ref _ref;

  // --- checklists ---

  /// Appends a new checklist to a trip. A blank [title] leaves it unnamed, so
  /// the UI shows the default label until it is renamed.
  Future<void> addChecklist(int tripId, {String title = ''}) async {
    final repo = _ref.read(repositoryProvider);
    final sortOrder = await repo.nextChecklistSortOrder(tripId);
    await repo.addChecklist(ChecklistsCompanion.insert(
      tripId: tripId,
      title: Value(title.trim()),
      sortOrder: Value(sortOrder),
    ));
  }

  Future<void> renameChecklist(Checklist checklist, String title) =>
      _ref.read(repositoryProvider).updateChecklist(
            checklist.copyWith(title: title.trim()),
          );

  Future<void> deleteChecklist(int id) =>
      _ref.read(repositoryProvider).deleteChecklist(id);

  /// Persists whether a checklist card is shown collapsed.
  Future<void> setCollapsed(Checklist checklist, bool collapsed) =>
      _ref.read(repositoryProvider).updateChecklist(
            checklist.copyWith(collapsed: collapsed),
          );

  // --- items ---

  /// Appends a new unchecked item with [label] to [checklistId].
  Future<void> addItem(int checklistId, String label) async {
    final repo = _ref.read(repositoryProvider);
    final sortOrder = await repo.nextChecklistItemSortOrder(checklistId);
    await repo.addChecklistItem(ChecklistItemsCompanion.insert(
      checklistId: checklistId,
      label: label,
      sortOrder: Value(sortOrder),
    ));
  }

  Future<void> setDone(ChecklistItem item, bool done) =>
      _ref.read(repositoryProvider).updateChecklistItem(
            item.copyWith(done: done),
          );

  Future<void> renameItem(ChecklistItem item, String label) =>
      _ref.read(repositoryProvider).updateChecklistItem(
            item.copyWith(label: label),
          );

  Future<void> deleteItem(int id) =>
      _ref.read(repositoryProvider).deleteChecklistItem(id);

  /// Persists a new item order after a drag-and-drop, writing only the items
  /// whose position actually changed.
  Future<void> reorderItems(
    List<ChecklistItem> items,
    int oldIndex,
    int newIndex,
  ) async {
    final reordered = List<ChecklistItem>.of(items);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    final repo = _ref.read(repositoryProvider);
    for (var i = 0; i < reordered.length; i++) {
      if (reordered[i].sortOrder != i) {
        await repo.updateChecklistItem(reordered[i].copyWith(sortOrder: i));
      }
    }
  }
}
