import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';

/// Live list of all trips for the overview screen.
final tripListProvider = StreamProvider.autoDispose<List<Trip>>((ref) {
  return ref.watch(repositoryProvider).watchTrips();
});

/// Live single trip, keyed by id, for the detail and edit screens.
final tripProvider =
    StreamProvider.autoDispose.family<Trip, int>((ref, id) {
  return ref.watch(repositoryProvider).watchTrip(id);
});

/// Live participants for a trip, keyed by trip id.
final tripParticipantsProvider =
    StreamProvider.autoDispose.family<List<Person>, int>((ref, tripId) {
  return ref.watch(repositoryProvider).watchParticipants(tripId);
});
