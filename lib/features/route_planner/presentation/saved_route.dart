import 'package:material_ui/material_ui.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/route_plan.dart';
import '../../../data/repositories/trip_repository.dart';
import '../data/saved_tour.dart';

/// Whether [item] was made by the route planner, and so may be opened in it.
bool hasRoutePlan(ItineraryItem item) =>
    decodeRoutePlan(item.routePlan) != null;

/// Reads the tour [item] belongs to out of the trip as it stands now, with the
/// color its trip draws in. Null when there is none the planner can open.
///
/// Read once and not watched: it is asked on a press, and what it answers is
/// handed to a screen that keeps its own copy to edit.
Future<({SavedTour tour, Color color})?> loadSavedRoute(
  TripRepository repository,
  ItineraryItem item,
) async {
  final items = await repository.itemsFor(item.tripId);
  // The row as it is now; the one handed in may be a snapshot.
  final current = items.where((entry) => entry.id == item.id).firstOrNull;
  if (current == null) return null;
  final members = tourItemsAround(items, current);
  if (members.isEmpty) return null;
  final tracks = await repository.tracksOfItems([
    for (final member in members) member.id,
  ]);
  final tour = savedTourOf(
    members,
    (itemId) => [
      for (final track in tracks)
        if (track.itemId == itemId) track,
    ],
  );
  final trip = await repository.findTrip(item.tripId);
  if (tour == null || trip == null) return null;
  return (tour: tour, color: Color(trip.colorValue));
}
