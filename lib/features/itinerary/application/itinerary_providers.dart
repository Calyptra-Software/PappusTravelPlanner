import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';

/// Live itinerary items for a trip, already ordered by day / sort / time.
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
