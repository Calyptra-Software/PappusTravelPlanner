import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../live_items.dart';

/// Every itinerary item of a trip, already ordered by day / sort / time —
/// including the items of alternative branches that were not chosen (the
/// timeline needs them to draw the branch being looked at). For the plan as it
/// stands, filter with [liveItems] and [chosenBranchIdsProvider].
final itineraryProvider =
    StreamProvider.autoDispose.family<List<ItineraryItem>, int>((ref, tripId) {
  return ref.watch(repositoryProvider).watchItems(tripId);
});

/// The set of a trip's days (normalized to midnight) currently collapsed in the
/// overview. Days not in the set are expanded (the default).
final collapsedDaysProvider =
    StreamProvider.autoDispose.family<Set<DateTime>, int>((ref, tripId) {
  return ref.watch(repositoryProvider).watchCollapsedDays(tripId);
});

/// A trip's item groups, keyed by id, so the timeline and item sheet can resolve
/// an item's group (its label and collapsed state) by [ItineraryItem.groupId].
final groupsProvider =
    StreamProvider.autoDispose.family<Map<int, ItemGroup>, int>((ref, tripId) {
  return ref.watch(repositoryProvider).watchGroups(tripId);
});

/// A trip's decision points ([AlternativeSet]s), keyed by id, so the timeline can
/// place each one in its day.
final alternativeSetsProvider = StreamProvider.autoDispose
    .family<Map<int, AlternativeSet>, int>((ref, tripId) {
  return ref.watch(repositoryProvider).watchAlternativeSets(tripId);
});

/// The branches of each decision, keyed by set id and in swipe order.
final alternativeBranchesProvider = StreamProvider.autoDispose
    .family<Map<int, List<Alternative>>, int>((ref, tripId) {
  return ref.watch(repositoryProvider).watchAlternativeBranches(tripId);
});

/// The chosen branch of every decision in a trip — the ids that decide which
/// items are part of the plan as it stands (see [isLiveItem]).
final chosenBranchIdsProvider =
    Provider.autoDispose.family<Set<int>, int>((ref, tripId) {
  final branches = ref.watch(alternativeBranchesProvider(tripId)).value;
  return branches == null ? const {} : chosenBranchIds(branches);
});
