import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
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
