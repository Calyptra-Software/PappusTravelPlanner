import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/route_plan.dart';
import '../../../data/repositories/trip_repository.dart';
import '../data/saved_tour.dart';
import 'route_planner_screen.dart';

/// Whether [item] is a leg the route planner made, and so opens its route in
/// the planner. A place of a tour does not: the route is offered where it is
/// read as one, on the run's label or on a leg standing alone.
bool isPlannedLeg(ItineraryItem item) =>
    decodeRoutePlan(item.routePlan)?.isLeg ?? false;

/// Opens the planner on the saved route [item] belongs to. Saving there
/// replaces the route's entries.
///
/// When the route cannot be read back (a way of travel this version does not
/// know), the snack bar says so rather than the button doing nothing.
Future<void> editSavedRoute(
  BuildContext context,
  WidgetRef ref,
  ItineraryItem item,
) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  final saved = await loadSavedRoute(ref.read(repositoryProvider), item);
  if (!navigator.mounted) return;
  if (saved == null) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.routeEditUnavailable)));
    return;
  }
  await planRoute(
    navigator.context,
    tripId: item.tripId,
    day: item.date,
    color: saved.color,
    editing: saved.tour,
  );
}

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
