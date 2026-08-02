import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../trips/application/trip_providers.dart';
import '../trip_stats.dart';
import 'currency_providers.dart';

/// A trip's costs bucketed by how they attach: to a single itinerary item
/// ([byItem]), to a group of items sharing one expense ([byGroup]), or to the
/// trip as a whole ([tripLevel]). Each cost lands in exactly one bucket, so
/// concatenating all three yields every cost once — no double counting.
typedef TripCosts = ({
  Map<int, List<Cost>> byItem,
  Map<int, List<Cost>> byGroup,
  List<Cost> tripLevel,
});

/// Costs for a trip, bucketed by their attachment ([TripCosts]). Includes the
/// costs of alternative branches that were not chosen, so each branch can show
/// its own price — anything that sums money instead wants
/// [countedCostsProvider].
final costsForTripProvider = StreamProvider.autoDispose.family<TripCosts, int>((
  ref,
  tripId,
) {
  return ref.watch(repositoryProvider).watchCostsForTrip(tripId).map((costs) {
    final byItem = <int, List<Cost>>{};
    final byGroup = <int, List<Cost>>{};
    final tripLevel = <Cost>[];
    for (final cost in costs) {
      if (cost.groupId != null) {
        byGroup.putIfAbsent(cost.groupId!, () => []).add(cost);
      } else if (cost.itemId != null) {
        byItem.putIfAbsent(cost.itemId!, () => []).add(cost);
      } else {
        tripLevel.add(cost);
      }
    }
    return (byItem: byItem, byGroup: byGroup, tripLevel: tripLevel);
  });
});

/// The costs of a trip that count toward its money: everything except the costs
/// of alternative branches that were not chosen. Backs the trip's total and its
/// statistics, so an option considered and dropped never inflates the budget.
final countedCostsProvider = StreamProvider.autoDispose.family<List<Cost>, int>(
  (ref, tripId) {
    return ref.watch(repositoryProvider).watchCountedCostsForTrip(tripId);
  },
);

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

/// Saved people as rows (with their id and `isMe` flag), for the settings list.
final peopleRowsProvider = StreamProvider.autoDispose<List<Person>>((ref) {
  return ref.watch(repositoryProvider).watchPeopleRows();
});

/// The person the user has marked as themselves, or null if none is set. Used
/// to filter the trip overview down to "my" expenses.
final mePersonProvider = StreamProvider.autoDispose<Person?>((ref) {
  return ref.watch(repositoryProvider).watchMePerson();
});

/// The people a cost was paid for, keyed by cost id.
final costBeneficiariesProvider = StreamProvider.autoDispose
    .family<List<Person>, int>((ref, costId) {
      return ref.watch(repositoryProvider).watchBeneficiaries(costId);
    });

/// Beneficiary split for every cost in a trip, keyed by cost id. Backs the
/// statistics screen so it can compute shares without one stream per cost.
final tripBeneficiariesProvider = StreamProvider.autoDispose
    .family<Map<int, List<Person>>, int>((ref, tripId) {
      return ref.watch(repositoryProvider).watchBeneficiariesForTrip(tripId);
    });

/// Per-currency expense statistics for a trip: category breakdown, per-person
/// paid/share/balance, and settle-up suggestions. Derives from the trip's
/// counted costs (the chosen plan — see [countedCostsProvider]), their
/// beneficiary split, and the participant roster (the fallback split for costs
/// with no explicit beneficiaries).
final tripStatsProvider = Provider.autoDispose.family<TripStats, int>((
  ref,
  tripId,
) {
  final costs = ref.watch(countedCostsProvider(tripId)).value;
  final beneficiaries = ref.watch(tripBeneficiariesProvider(tripId)).value;
  final participants = ref.watch(tripParticipantsProvider(tripId)).value;
  final book = ref.watch(currencyBookProvider);
  if (costs == null) return const TripStats([]);
  return computeTripStats(costs, beneficiaries ?? const {}, [
    for (final p in participants ?? const <Person>[]) p.name,
  ], book);
});

/// Expense statistics pooled across **all** trips — the overall overview. Each
/// trip is computed on its own (so costs still fall back to their own trip's
/// participants) and the results are merged; see [mergeTripStats].
final allTripsStatsProvider = Provider.autoDispose<TripStats>((ref) {
  final trips = ref.watch(tripListProvider).value ?? const <Trip>[];
  return mergeTripStats([
    // Routines are left out: a routine's costs are a *fare*, the price this
    // ride costs, not money that was spent. They are copied onto each trip
    // stamped out of it, and counting the template as well would charge the
    // user for a journey they had merely described.
    for (final trip in trips)
      if (trip.kind != TripKind.routine) ref.watch(tripStatsProvider(trip.id)),
  ], ref.watch(currencyBookProvider));
});

final costControllerProvider = Provider<CostController>(
  (ref) => CostController(ref),
);

/// Adds/edits/deletes costs, remembering each reason for reuse.
class CostController {
  CostController(this._ref);
  final Ref _ref;

  /// Adds a cost attached to an itinerary item ([itemId]), a group of items
  /// sharing one expense ([groupId]), or the whole trip ([tripId]). Exactly one
  /// should be provided. [currencyId] is a `Currencies` row id — the currencies
  /// are user-managed, so an expense points at one rather than naming it.
  Future<void> addCost({
    int? itemId,
    int? groupId,
    int? tripId,
    required int amountMinor,
    required int currencyId,
    required String reason,
    String? paidBy,
    List<String> paidFor = const [],
    bool paid = false,
  }) async {
    final repo = _ref.read(repositoryProvider);
    await repo.upsertReason(reason);
    if (paidBy != null && paidBy.isNotEmpty) await repo.upsertPerson(paidBy);
    final id = await repo.addCost(
      CostsCompanion.insert(
        itemId: Value(itemId),
        groupId: Value(groupId),
        tripId: Value(tripId),
        amountMinor: amountMinor,
        currency: currencyId,
        reason: reason,
        paidBy: Value(paidBy),
        paid: Value(paid),
      ),
    );
    await repo.setBeneficiaries(id, paidFor);
  }

  Future<void> updateCost(
    Cost existing, {
    required int amountMinor,
    required int currencyId,
    required String reason,
    String? paidBy,
    List<String> paidFor = const [],
    bool paid = false,
  }) async {
    final repo = _ref.read(repositoryProvider);
    await repo.upsertReason(reason);
    if (paidBy != null && paidBy.isNotEmpty) await repo.upsertPerson(paidBy);
    await repo.updateCost(
      existing.copyWith(
        amountMinor: amountMinor,
        currency: currencyId,
        reason: reason,
        paidBy: Value(paidBy),
        paid: paid,
      ),
    );
    await repo.setBeneficiaries(existing.id, paidFor);
  }

  // --- transfers (settling up between people) ---

  /// Records [from] handing [amountMinor] to [to] on trip [tripId]: a transfer,
  /// not an expense (see [Costs.isTransfer]). It carries no category — a
  /// repayment isn't a kind of spending — and is stored already settled, since
  /// recording it says the money has changed hands. The receiver is stored as
  /// the row's single beneficiary, which is what shifts their balance.
  Future<void> addTransfer({
    required int tripId,
    required int amountMinor,
    required int currencyId,
    required String from,
    required String to,
  }) async {
    final repo = _ref.read(repositoryProvider);
    await repo.upsertPerson(from);
    await repo.upsertPerson(to);
    final id = await repo.addCost(
      CostsCompanion.insert(
        tripId: Value(tripId),
        amountMinor: amountMinor,
        currency: currencyId,
        reason: '',
        paidBy: Value(from),
        paid: const Value(true),
        isTransfer: const Value(true),
      ),
    );
    await repo.setBeneficiaries(id, [to]);
  }

  /// Edits a recorded transfer, keeping it a transfer.
  Future<void> updateTransfer(
    Cost existing, {
    required int amountMinor,
    required int currencyId,
    required String from,
    required String to,
  }) async {
    final repo = _ref.read(repositoryProvider);
    await repo.upsertPerson(from);
    await repo.upsertPerson(to);
    await repo.updateCost(
      existing.copyWith(
        amountMinor: amountMinor,
        currency: currencyId,
        reason: '',
        paidBy: Value(from),
        paid: true,
        isTransfer: true,
      ),
    );
    await repo.setBeneficiaries(existing.id, [to]);
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

  /// Marks [personId] as the "me" person (clearing any previous), or clears the
  /// flag entirely when passed null.
  Future<void> setMePerson(int? personId) =>
      _ref.read(repositoryProvider).setMePerson(personId);
}
