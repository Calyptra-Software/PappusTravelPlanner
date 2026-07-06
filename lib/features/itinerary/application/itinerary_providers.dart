import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';

/// Live itinerary items for a trip, already ordered by day / sort / time.
final itineraryProvider =
    StreamProvider.autoDispose.family<List<ItineraryItem>, int>((ref, tripId) {
  return ref.watch(repositoryProvider).watchItems(tripId);
});
