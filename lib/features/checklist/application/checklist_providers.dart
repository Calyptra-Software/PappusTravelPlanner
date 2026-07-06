import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';

/// The checklist items for a trip, in manual then creation order.
final checklistProvider =
    StreamProvider.autoDispose.family<List<ChecklistItem>, int>((ref, tripId) {
  return ref.watch(repositoryProvider).watchChecklist(tripId);
});

final checklistControllerProvider =
    Provider<ChecklistController>((ref) => ChecklistController(ref));

/// Adds, toggles, edits and removes a trip's checklist items.
class ChecklistController {
  ChecklistController(this._ref);
  final Ref _ref;

  /// Appends a new unchecked item with [label] to the trip's checklist.
  Future<void> add(int tripId, String label) async {
    final repo = _ref.read(repositoryProvider);
    final sortOrder = await repo.nextChecklistSortOrder(tripId);
    await repo.addChecklistItem(ChecklistItemsCompanion.insert(
      tripId: tripId,
      label: label,
      sortOrder: Value(sortOrder),
    ));
  }

  Future<void> setDone(ChecklistItem item, bool done) =>
      _ref.read(repositoryProvider).updateChecklistItem(
            item.copyWith(done: done),
          );

  Future<void> rename(ChecklistItem item, String label) =>
      _ref.read(repositoryProvider).updateChecklistItem(
            item.copyWith(label: label),
          );

  Future<void> delete(int id) =>
      _ref.read(repositoryProvider).deleteChecklistItem(id);

  /// Sets a custom heading for the trip's checklist. A blank value restores the
  /// default label.
  Future<void> setTitle(int tripId, String? title) {
    final trimmed = title?.trim();
    return _ref.read(repositoryProvider).setChecklistTitle(
          tripId,
          (trimmed == null || trimmed.isEmpty) ? null : trimmed,
        );
  }

  /// Persists a new order after a drag-and-drop, writing only the items whose
  /// position actually changed.
  Future<void> reorder(
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
