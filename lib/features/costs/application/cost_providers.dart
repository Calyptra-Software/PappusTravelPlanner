import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';

/// Costs for a trip, grouped by the itinerary item they belong to.
final costsForTripProvider =
    StreamProvider.autoDispose.family<Map<int, List<Cost>>, int>((ref, tripId) {
  return ref.watch(repositoryProvider).watchCostsForTrip(tripId).map((costs) {
    final byItem = <int, List<Cost>>{};
    for (final cost in costs) {
      byItem.putIfAbsent(cost.itemId, () => []).add(cost);
    }
    return byItem;
  });
});

/// Saved reason labels for the reuse dropdown.
final reasonsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  return ref.watch(repositoryProvider).watchReasons();
});

final costControllerProvider =
    Provider<CostController>((ref) => CostController(ref));

/// Adds/edits/deletes costs, remembering each reason for reuse.
class CostController {
  CostController(this._ref);
  final Ref _ref;

  Future<void> addCost({
    required int itemId,
    required int amountMinor,
    required Currency currency,
    required String reason,
  }) async {
    final repo = _ref.read(repositoryProvider);
    await repo.upsertReason(reason);
    await repo.addCost(CostsCompanion.insert(
      itemId: itemId,
      amountMinor: amountMinor,
      currency: currency,
      reason: reason,
    ));
  }

  Future<void> updateCost(
    Cost existing, {
    required int amountMinor,
    required Currency currency,
    required String reason,
  }) async {
    final repo = _ref.read(repositoryProvider);
    await repo.upsertReason(reason);
    await repo.updateCost(existing.copyWith(
      amountMinor: amountMinor,
      currency: currency,
      reason: reason,
    ));
  }

  Future<void> deleteCost(int id) =>
      _ref.read(repositoryProvider).deleteCost(id);
}
