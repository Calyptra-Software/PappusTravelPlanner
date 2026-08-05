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
    // A routine's own days are ordinals anchored in 1970, which no timetable
    // answers for — so its run is re-routed the way one is imported into it: the
    // search is made on a real date and the answer laid back onto the plan day
    // (`ConnectionSearchSheet.intoRoutine`). A template is as worth re-routing as
    // an outing: the 07:32 being retired changes every morning from now on.
    final isRoutine =
        ref.watch(tripProvider(tripId)).value?.kind == TripKind.routine;
    // The run as the search form takes it: one journey, since these items are
    // one group (or one lone leg). Not `plannedJourneys`, which would drop a run
    // whose ends carry no id — hand-entered, or an import that lost one. Here
    // that is not a dead end but the form's first question, answered by picking
    // the station from the geocoder.
    final planned = plannedJourneyOf(journey);
    return JourneySheet(
      view: journeyViewFromItems(journey, modesById),
      title: title,
      modesById: modesById,
      itemsById: {for (final item in journey) item.id: item},
      onFindConnection: planned == null
          ? null
          : () => _findConnection(context, planned, intoRoutine: isRoutine),
      // A run of one leg has nothing to offer per leg that the journey's own
      // button does not already do to the same row.
      onFindLegConnection: planned == null || planned.legs.length < 2
          ? null
          : (leg) => _findLegConnection(
              context,
              journey,
              leg,
              intoRoutine: isRoutine,
            ),
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
  /// On a **routine**, [intoRoutine] sends the form to a real date and rebases
  /// what it finds back onto [PlannedJourney.date] — the plan day these legs sit
  /// on, which is the rebase target rather than a day anything runs on.
  Future<void> _findConnection(
    BuildContext context,
    PlannedJourney journey, {
    int? departFromMinutes,
    bool intoRoutine = false,
  }) async {
    final navigator = Navigator.of(context);
    final replaced = await showConnectionSearchSheet(
      context,
      tripId: tripId,
      day: journey.date,
      replacing: journey,
      departFromMinutes: departFromMinutes,
      intoRoutine: intoRoutine,
    );
    if (replaced && navigator.canPop()) navigator.pop();
  }

  /// The same search for **one leg** of the run, from that leg's own card.
  ///
  /// The unit is the leg because that is what a journey already under way asks
  /// about: the first train came in twenty late, or the change turns out to be
  /// six minutes and not sixteen, and it is the *rest* of the journey that has to
  /// move — not the part already travelled. Only this leg's row is replaced (its
  /// slot, its group, the run's ticket all survive), and what is found may itself
  /// be several legs: a missed connection is often a different route.
  ///
  /// The time it starts from is where the traveller really is, not where the plan
  /// says: `departureSeedMinutes` prefers the previous leg's *actual* arrival, so
  /// a delay already recorded on the leg before does not have to be typed in again
  /// here. It is a seed on a form, not a decision — the field says so and can be
  /// changed.
  Future<void> _findLegConnection(
    BuildContext context,
    List<ItineraryItem> run,
    ItineraryItem leg, {
    bool intoRoutine = false,
  }) async {
    final journey = plannedJourneyOf([leg]);
    if (journey == null) return;
    await _findConnection(
      context,
      journey,
      intoRoutine: intoRoutine,
      departFromMinutes: departureSeedMinutes(run, leg),
    );
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
