import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../itinerary/application/itinerary_providers.dart';
import '../trip_kind.dart';
import '../../../data/database/app_database.dart';

/// Live list of all trips for the overview screen.
final tripListProvider = StreamProvider.autoDispose<List<Trip>>((ref) {
  return ref.watch(repositoryProvider).watchTrips();
});

/// Live single trip, keyed by id, for the detail and edit screens.
final tripProvider = StreamProvider.autoDispose.family<Trip, int>((ref, id) {
  return ref.watch(repositoryProvider).watchTrip(id);
});

/// Cost totals of every trip, keyed by trip id and then by currency code —
/// powers the total shown on each overview card.
final tripTotalsProvider =
    StreamProvider.autoDispose<Map<int, Map<String, int>>>((ref) {
      return ref.watch(repositoryProvider).watchTotalsByTrip();
    });

/// Live participants for a trip, keyed by trip id.
final tripParticipantsProvider = StreamProvider.autoDispose
    .family<List<Person>, int>((ref, tripId) {
      return ref.watch(repositoryProvider).watchParticipants(tripId);
    });

/// Live participants of every trip, keyed by trip id — powers the overview
/// participant filter.
final allParticipantsProvider =
    StreamProvider.autoDispose<Map<int, List<Person>>>((ref) {
      return ref.watch(repositoryProvider).watchAllParticipants();
    });

/// Every routine — the routine list and the "from routine…" picker. Kept apart
/// from [tripListProvider] because a routine is a template, not a trip: it has
/// no dates to sort or classify by, and the overview is about trips.
final routineListProvider = StreamProvider.autoDispose<List<Trip>>((ref) {
  return ref.watch(repositoryProvider).watchRoutines();
});

/// The user's whole tag roster, in their own order.
final tagListProvider = StreamProvider.autoDispose<List<Tag>>((ref) {
  return ref.watch(repositoryProvider).watchTags();
});

/// Every trip's tags, keyed by trip id — one query behind the overview's chip
/// rows and its tag filter.
final tagsByTripProvider = StreamProvider.autoDispose<Map<int, List<Tag>>>((
  ref,
) {
  return ref.watch(repositoryProvider).watchTagsByTrip();
});

/// One trip's tags, for its detail header and its edit form.
final tripTagsProvider = StreamProvider.autoDispose.family<List<Tag>, int>((
  ref,
  tripId,
) {
  return ref.watch(repositoryProvider).watchTagsForTrip(tripId);
});

/// How many days a routine's plan covers. A routine has no dates, so its length
/// is whatever its entries reach — see `RoutineDao.routineDays` for the rule.
///
/// Derived from the plan's own streams rather than queried once, so a day added
/// to a routine lengthens it on the spot — a header that only caught up on the
/// next visit was reporting a plan the screen was no longer showing.
final routineDaySpanProvider = Provider.autoDispose.family<int, int>((
  ref,
  routineId,
) {
  final items = ref.watch(itineraryProvider(routineId)).value ?? const [];
  final sets =
      ref.watch(alternativeSetsProvider(routineId)).value ??
      const <int, AlternativeSet>{};
  return routineDayCountOf(items, sets.values);
});
