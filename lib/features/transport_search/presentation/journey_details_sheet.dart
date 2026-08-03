import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../itinerary/application/itinerary_providers.dart';
import '../../itinerary/application/transport_mode_providers.dart';
import '../../trips/application/trip_providers.dart';
import '../../trips/planned_journey.dart';
import '../data/journey_view_items.dart';
import 'connection_search_sheet.dart';
import 'journey_sheet.dart';

/// Reads a journey the trip already holds — the sheet the connection was
/// imported through, opened again on what the import wrote.
///
/// Its unit is the **group**: importing a connection bundles each day's run of
/// legs into one (they share a ticket), so a group already *is* a journey, and
/// asking for one by [groupId] asks for exactly the run that was added. A leg
/// standing on its own is asked for by [itemId] instead. Nothing else is a
/// journey: a decision's option is a plan, and a day is a day.
///
/// It watches the trip's items rather than taking a snapshot, so a leg refreshed
/// from inside the sheet redraws in place — the refresh writes to the database
/// and the sheet is reading it.
///
/// Beside reading it, the sheet is where a run is **looked up again**: one
/// button searches the timetable for these same endpoints on this same day and
/// offers to swap the legs for what actually runs. That is the way back for a
/// plan copied from a routine whose journeys were never looked up — the lookup
/// used to happen once, at the moment the trip was stamped out, and never
/// again — and equally for a connection that has since been cancelled or
/// missed. Per journey rather than per trip, because that is the unit the
/// question arises in.
Future<void> showJourneyDetailsSheet(
  BuildContext context, {
  required int tripId,
  int? groupId,
  int? itemId,
  String? title,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => JourneyDetailsSheet(
    tripId: tripId,
    groupId: groupId,
    itemId: itemId,
    title: title,
  ),
);

class JourneyDetailsSheet extends ConsumerWidget {
  const JourneyDetailsSheet({
    super.key,
    required this.tripId,
    this.groupId,
    this.itemId,
    this.title,
  });

  final int tripId;
  final int? groupId;
  final int? itemId;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itineraryProvider(tripId)).value ?? const [];
    final modesById = ref.watch(transportModesByIdProvider);
    final journey = [
      for (final item in items)
        if (groupId != null ? item.groupId == groupId : item.id == itemId) item,
    ];
    // A routine's plan has no dates to search on — its days are ordinals
    // anchored in 1970 — so looking one up here would ask the timetable about a
    // day no train has ever run on. Importing *into* a routine goes the other
    // way round (search a real date, rebase the answer); that is
    // `ConnectionSearchSheet.intoRoutine`'s job, not this button's.
    final isRoutine =
        ref.watch(tripProvider(tripId)).value?.kind == TripKind.routine;
    // The run as something searchable: one journey, since these items are one
    // group (or one lone leg), and none at all when its ends can no longer be
    // addressed to the router — a hand-entered leg is offered nothing.
    final planned = isRoutine ? null : plannedJourneys(journey).firstOrNull;
    return JourneySheet(
      view: journeyViewFromItems(journey, modesById),
      title: title,
      modesById: modesById,
      itemsById: {for (final item in journey) item.id: item},
      onFindConnection: planned == null
          ? null
          : () => _findConnection(context, planned),
    );
  }

  /// Opens the connection search **for this run**: the same form the journey was
  /// imported through, starting on its ends, its day and its departure.
  ///
  /// The search sheet rather than one silent request, because the question is
  /// usually not quite the old one — the 07:32 was cancelled, or the afternoon
  /// will do instead — and because a list of departures is what a traveller
  /// chooses from. It owns everything from there: the query, the results, the
  /// preview, and the swap. This sheet only closes behind it, onto the timeline
  /// where the new legs now are: the ones it was reading have been deleted, a
  /// lone leg's id along with them.
  Future<void> _findConnection(
    BuildContext context,
    PlannedJourney journey,
  ) async {
    final navigator = Navigator.of(context);
    final replaced = await showConnectionSearchSheet(
      context,
      tripId: tripId,
      day: journey.date,
      replacing: journey,
    );
    if (replaced && navigator.canPop()) navigator.pop();
  }
}

/// Whether [item] has a journey worth reading on its own — i.e. whether the
/// timeline should offer the sheet on the tile rather than only on its group.
///
/// A grouped leg is covered by its group's own button, and a hand-entered leg
/// has nothing the tile does not already show. What is left is a leg the
/// **search** put there, which is asked in the same terms the refresh button
/// asks it (`sourceTripId`) rather than by whether stops came back: a service
/// the feed lists no intermediate stops for is still an imported journey, with
/// its platforms, its direction and its delays to read — and a run of them that
/// is later ungrouped must not leave some legs with a way in and others without.
bool hasStandaloneJourney(ItineraryItem item) =>
    item.groupId == null &&
    item.kind == ItemKind.transport &&
    (item.sourceTripId != null ||
        (item.stopovers != null && item.stopovers!.isNotEmpty));

/// Whether the group [groupId] reads as a journey: it has to be got somewhere by
/// something. A group of places — several museums on one ticket — is a bundle of
/// entries, not a journey, and is offered nothing.
bool groupHasJourney(Iterable<ItineraryItem> members, int groupId) => members
    .any((item) => item.groupId == groupId && item.kind == ItemKind.transport);
