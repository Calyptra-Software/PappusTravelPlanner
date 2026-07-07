import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';

/// Item-attached costs grouped by item id, plus trip-level costs that aren't
/// tied to any item. Both count toward the trip's total.
typedef TripCosts = ({Map<int, List<Cost>> byItem, List<Cost> tripLevel});

/// Costs for a trip: grouped by the itinerary item they belong to, with
/// trip-level costs collected separately.
final costsForTripProvider =
    StreamProvider.autoDispose.family<TripCosts, int>((ref, tripId) {
  return ref.watch(repositoryProvider).watchCostsForTrip(tripId).map((costs) {
    final byItem = <int, List<Cost>>{};
    final tripLevel = <Cost>[];
    for (final cost in costs) {
      final itemId = cost.itemId;
      if (itemId == null) {
        tripLevel.add(cost);
      } else {
        byItem.putIfAbsent(itemId, () => []).add(cost);
      }
    }
    return (byItem: byItem, tripLevel: tripLevel);
  });
});

/// Saved reason labels for the reuse dropdown.
final reasonsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  return ref.watch(repositoryProvider).watchReasons();
});

/// Saved reasons with their icons, for the settings management list.
final reasonRowsProvider = StreamProvider.autoDispose<List<CostReason>>((ref) {
  return ref.watch(repositoryProvider).watchReasonRows();
});

/// Maps a reason label to its assigned icon id, so a cost (which stores its
/// reason as text) can resolve the icon to show on its chip.
final reasonIconsProvider = Provider.autoDispose<Map<String, int?>>((ref) {
  final rows = ref.watch(reasonRowsProvider).value ?? const [];
  return {for (final r in rows) r.label: r.iconId};
});

/// Saved people for the expense payer dropdown.
final peopleProvider = StreamProvider.autoDispose<List<String>>((ref) {
  return ref.watch(repositoryProvider).watchPeople();
});

final costControllerProvider =
    Provider<CostController>((ref) => CostController(ref));

/// Adds/edits/deletes costs, remembering each reason for reuse.
class CostController {
  CostController(this._ref);
  final Ref _ref;

  /// Adds a cost attached to an itinerary item ([itemId]) or, for costs that
  /// belong to the whole trip, to the trip directly ([tripId]). Exactly one
  /// should be provided.
  Future<void> addCost({
    int? itemId,
    int? tripId,
    required int amountMinor,
    required Currency currency,
    required String reason,
    String? paidBy,
  }) async {
    final repo = _ref.read(repositoryProvider);
    await repo.upsertReason(reason);
    if (paidBy != null && paidBy.isNotEmpty) await repo.upsertPerson(paidBy);
    await repo.addCost(CostsCompanion.insert(
      itemId: Value(itemId),
      tripId: Value(tripId),
      amountMinor: amountMinor,
      currency: currency,
      reason: reason,
      paidBy: Value(paidBy),
    ));
  }

  Future<void> updateCost(
    Cost existing, {
    required int amountMinor,
    required Currency currency,
    required String reason,
    String? paidBy,
  }) async {
    final repo = _ref.read(repositoryProvider);
    await repo.upsertReason(reason);
    if (paidBy != null && paidBy.isNotEmpty) await repo.upsertPerson(paidBy);
    await repo.updateCost(existing.copyWith(
      amountMinor: amountMinor,
      currency: currency,
      reason: reason,
      paidBy: Value(paidBy),
    ));
  }

  Future<void> deleteCost(int id) =>
      _ref.read(repositoryProvider).deleteCost(id);

  // --- reason management (settings) ---

  /// Adds a reusable reason (a no-op if it already exists), optionally with an
  /// icon assigned right away.
  Future<void> addReason(String label, {int? iconId}) async {
    final repo = _ref.read(repositoryProvider);
    if (iconId == null) {
      await repo.upsertReason(label);
    } else {
      await repo.setReasonIcon(label, iconId);
    }
  }

  Future<void> setReasonIcon(String label, int? iconId) =>
      _ref.read(repositoryProvider).setReasonIcon(label, iconId);

  Future<void> deleteReason(String label) =>
      _ref.read(repositoryProvider).deleteReason(label);

  /// Renames a reason, repointing every cost that uses it (see
  /// [TripRepository.renameReason]).
  Future<void> renameReason(String from, String to) =>
      _ref.read(repositoryProvider).renameReason(from, to);

  // --- people management (settings) ---

  /// Adds a reusable person (a no-op if they already exist).
  Future<void> addPerson(String name) =>
      _ref.read(repositoryProvider).upsertPerson(name);

  Future<void> deletePerson(String name) =>
      _ref.read(repositoryProvider).deletePerson(name);

  /// Renames a person, repointing every expense they paid (see
  /// [TripRepository.renamePerson]).
  Future<void> renamePerson(String from, String to) =>
      _ref.read(repositoryProvider).renamePerson(from, to);
}
