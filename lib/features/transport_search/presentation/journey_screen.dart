import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/clock.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../data/database/track_points.dart';
import '../../../l10n/app_localizations.dart';
import '../../itinerary/application/itinerary_providers.dart';
import '../../itinerary/application/transport_mode_providers.dart';
import '../../itinerary/live_items.dart';
import '../../itinerary/now_marker.dart';
import '../../map/basemap_provider.dart';
import '../../map/widgets/map_overlays.dart';
import '../../trips/application/trip_providers.dart';
import '../../trips/planned_journey.dart';
import '../application/transport_search_controller.dart';
import '../data/journey_view_items.dart';
import '../data/motis_client.dart' show TransportSearchException;
import 'connection_search_sheet.dart';
import 'journey_destination.dart';
import 'journey_map.dart';
import 'journey_sheet.dart';
import 'run_button.dart';

/// Opens a journey the trip already holds on its own screen: the run of legs
/// bundled as [groupId], or the lone leg [itemId].
///
/// A route rather than a sheet, because the screen carries a map, and a sheet
/// answers a vertical drag by closing, which is the gesture that pans one.
Future<void> openJourney(
  BuildContext context, {
  required int tripId,
  int? groupId,
  int? itemId,
}) => context.push(
  Uri(
    path: '/trip/$tripId/journey',
    queryParameters: {
      if (groupId != null) 'group': '$groupId' else 'item': '$itemId',
    },
  ).toString(),
);

/// Reads a journey the trip already holds: a map of it above, and below, in a
/// panel that can be pulled up over the map, the journey leg by leg with its
/// stops, the run around each leg, and its changes.
///
/// Its unit is the **group**: importing a connection bundles each day's run of
/// legs into one (they share a ticket), so a group already *is* a journey, and
/// asking for one by [groupId] asks for exactly the run that was added. A leg
/// standing on its own is asked for by [itemId] instead. Nothing else is a
/// journey: a decision's option is a plan, and a day is a day.
///
/// It watches the trip's items rather than taking a snapshot, so a leg refreshed
/// from inside the screen redraws in place — the refresh writes to the database
/// and the screen is reading it.
///
/// Beside reading it, the screen is where a run is **looked up again**: one
/// button searches the timetable for these same endpoints on this same day and
/// offers to swap the legs for what actually runs. That is the way back for a
/// plan copied from a routine whose journeys were never looked up — the lookup
/// used to happen once, at the moment the trip was stamped out, and never
/// again — and equally for a connection that has since been cancelled or
/// missed. Per journey rather than per trip, because that is the unit the
/// question arises in.
class JourneyScreen extends ConsumerStatefulWidget {
  const JourneyScreen({
    super.key,
    required this.tripId,
    this.groupId,
    this.itemId,
  });

  final int tripId;
  final int? groupId;
  final int? itemId;

  @override
  ConsumerState<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends ConsumerState<JourneyScreen> {
  /// The legs (by item id) whose run outside them is on screen. Only while
  /// the screen is open: it opens on the journey's own route every time, and
  /// the run is asked for leg by leg.
  final Set<int> _shown = {};

  /// The legs whose run is being fetched.
  final Set<int> _loading = {};

  /// What could not be had for a leg's run, said under its button.
  final Map<int, String> _problems = {};

  /// The route of each shown leg's whole run, decoded: what the map cuts the
  /// parts outside the leg from.
  final Map<int, List<LatLng>> _shapes = {};

  /// Where the map is to look when a run has just been put on it.
  final ValueNotifier<List<LatLng>?> _fit = ValueNotifier(null);

  /// The time the vehicles are placed at, every second while the screen is
  /// open. Handed down as a listenable so a tick moves the vehicles and
  /// rebuilds nothing else.
  final ValueNotifier<DateTime?> _clock = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    ref.listenManual(secondClockProvider, (_, next) {
      if (next.value case final now?) _clock.value = now;
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _fit.dispose();
    _clock.dispose();
    super.dispose();
  }

  /// Shows the run around [item], or puts it away again.
  ///
  /// Showing it asks [TransportSearchController.showRun], which sends a request
  /// only for what is not to hand; then the map is framed on the whole run once,
  /// since most of it lies outside what the screen opened on. Putting it away
  /// leaves the camera where it is.
  Future<void> _toggleRun(ItineraryItem item) async {
    final id = item.id;
    if (_shown.contains(id)) {
      setState(() {
        _shown.remove(id);
        _problems.remove(id);
      });
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading.add(id);
      _problems.remove(id);
    });
    RunShown? shown;
    String? problem;
    try {
      shown = await ref.read(transportSearchControllerProvider).showRun(item);
    } on TransportSearchException catch (e) {
      problem = e.statusCode == 404
          ? l10n.connectionRunNotFound
          : l10n.connectionRunError;
    } on Exception {
      problem = l10n.connectionRunError;
    }
    final stops = shown?.stops;
    List<LatLng>? shape;
    if (stops == null) {
      problem ??= l10n.connectionRunNotFound;
    } else {
      final encoded = shown?.shape;
      try {
        shape = encoded == null
            ? null
            : decodeTrackPoints(encoded, precision: kRoutedShapePrecision);
      } on FormatException {
        shape = null;
      }
      if (shape == null) problem = l10n.connectionRunShapeUnavailable;
    }
    if (!mounted) return;
    setState(() {
      _loading.remove(id);
      if (problem != null) _problems[id] = problem;
      if (stops != null) {
        _shown.add(id);
        if (shape != null) _shapes[id] = shape;
      }
    });
    if (stops == null) return;
    _fit.value = [
      ...?shape,
      if (shape == null) ...[
        for (final stop in [...stops.before, ...stops.after])
          if (stop.lat != null && stop.lon != null)
            LatLng(stop.lat!, stop.lon!),
        if (item.fromLat != null && item.fromLon != null)
          LatLng(item.fromLat!, item.fromLon!),
        if (item.toLat != null && item.toLon != null)
          LatLng(item.toLat!, item.toLon!),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tripId = widget.tripId;
    final l10n = AppLocalizations.of(context);
    final itemsAsync = ref.watch(itineraryProvider(tripId));
    final modesById = ref.watch(transportModesByIdProvider);
    final trip = ref.watch(tripProvider(tripId)).value;
    final groupId = widget.groupId;
    final label = groupId == null
        ? null
        : ref.watch(groupsProvider(tripId)).value?[groupId]?.label;
    // A routine's own days are ordinals anchored in 1970, which no timetable
    // answers for — so its run is re-routed the way one is imported into it: the
    // search is made on a real date and the answer laid back onto the plan day
    // (`ConnectionSearchSheet.intoRoutine`). A template is as worth re-routing as
    // an outing: the 07:32 being retired changes every morning from now on.
    // It also has no today, so nothing on it is under way.
    final isRoutine = trip?.kind == TripKind.routine;
    final now = isRoutine ? null : ref.watch(nowProvider).value;
    final chosen = ref.watch(chosenBranchIdsProvider(tripId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          label != null && label.isNotEmpty ? label : l10n.journeyTitle,
        ),
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(l10n.genericError('$error'))),
        data: (items) {
          final journey = [
            for (final item in items)
              if (groupId != null
                  ? item.groupId == groupId
                  : item.id == widget.itemId)
                item,
          ];
          // Its legs were replaced, or the entry deleted, while this was open.
          if (journey.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l10n.journeyGone, textAlign: TextAlign.center),
              ),
            );
          }
          // The run as the search form takes it: one journey, since these
          // items are one group (or one lone leg). Not `plannedJourneys`, which
          // would drop a run whose ends carry no id — hand-entered, or an import
          // that lost one. Here that is not a dead end but the form's first
          // question, answered by picking the station from the geocoder.
          final planned = plannedJourneyOf(journey);
          final find = planned == null
              ? null
              : () => _findConnection(context, planned, intoRoutine: isRoutine);
          // By the rule the trip's map uses, read over the whole day, so the
          // leg red here is the one red there.
          final happening = happeningItemIdAt(liveItems(items, chosen), now);
          final accent = trip == null ? null : Color(trip.colorValue);
          // A routine has no today for a vehicle to be anywhere on.
          final clock = isRoutine ? null : _clock;
          return _JourneyLayout(
            map: (panelExtent) => JourneyMap(
              tripId: tripId,
              legs: [
                for (final item in journey)
                  if (item.kind == ItemKind.transport) item,
              ],
              happeningItemId: happening,
              accent: accent,
              panelExtent: panelExtent,
              shownRuns: _shown,
              runShapes: _shapes,
              fitTo: _fit,
              clock: clock,
            ),
            panel: [
              JourneyHeader(view: journeyViewFromItems(journey, modesById)),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: JourneyRows(
                  view: journeyViewFromItems(journey, modesById),
                  modesById: modesById,
                  itemsById: {for (final item in journey) item.id: item},
                  // A run of one leg has nothing to offer per leg that the
                  // journey's own button does not already do to the same row.
                  onFindLegConnection:
                      planned == null || planned.legs.length < 2
                      ? null
                      : (leg) => _findLegConnection(
                          context,
                          journey,
                          leg,
                          intoRoutine: isRoutine,
                        ),
                  onReplanFrom: planned == null || planned.legs.length < 2
                      ? null
                      : (arriving) => _replanFrom(
                          context,
                          journey,
                          arriving,
                          intoRoutine: isRoutine,
                        ),
                  shownRuns: _shown,
                  clock: clock,
                  happeningItemId: happening,
                  accent: accent,
                  runControl: (item) => RunButton(
                    shown: _shown.contains(item.id),
                    loading: _loading.contains(item.id),
                    problem: _problems[item.id],
                    onPressed: () => _toggleRun(item),
                  ),
                ),
              ),
              if (find != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.travel_explore),
                    label: Text(l10n.connectionsFindForLeg),
                    onPressed: find,
                  ),
                ),
            ],
          );
        },
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
  /// preview, and the swap. This screen only closes behind it, onto the timeline
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
      destination: ReplaceRun(
        tripId: widget.tripId,
        day: journey.date,
        journey: journey,
        departFromMinutes: departFromMinutes,
        intoRoutine: intoRoutine,
      ),
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

  /// The same search for **the rest of the run** after [arriving], from the
  /// change it arrives at: the connection there was missed, so everything from
  /// here to the destination has to move, and nothing before it.
  ///
  /// It starts from the arrival, actual or planned (`arrivalSeedMinutes`), not
  /// from the departure that was just missed. Like the leg's own search, only
  /// the legs searched for are replaced, and the group, its ticket and its slot
  /// survive.
  Future<void> _replanFrom(
    BuildContext context,
    List<ItineraryItem> run,
    ItineraryItem arriving, {
    bool intoRoutine = false,
  }) async {
    final rest = journeyAfter(run, arriving);
    if (rest == null) return;
    await _findConnection(
      context,
      rest,
      intoRoutine: intoRoutine,
      departFromMinutes: arrivalSeedMinutes(arriving, rest.date),
    );
  }
}

/// The map filling the screen, with the journey in a panel over its lower part
/// that can be pulled up to read it or pushed down to see more of the map.
///
/// The map is not rebuilt as the panel moves: only the attribution follows the
/// panel's edge, so that the credit the tile sources require stays on screen.
class _JourneyLayout extends ConsumerStatefulWidget {
  const _JourneyLayout({required this.map, required this.panel});

  /// The map, given the share of the screen's height the panel covers, which
  /// follows the panel as it is dragged.
  final Widget Function(ValueListenable<double> panelExtent) map;
  final List<Widget> panel;

  @override
  ConsumerState<_JourneyLayout> createState() => _JourneyLayoutState();
}

class _JourneyLayoutState extends ConsumerState<_JourneyLayout> {
  /// What the panel covers when the screen opens: about half, so the map shows
  /// the journey and the panel its start.
  static const double _initialExtent = 0.45;
  static const double _minExtent = 0.15;

  /// Never the whole screen: a strip of map is left to drag it back down by.
  static const double _maxExtent = 0.9;

  final ValueNotifier<double> _extent = ValueNotifier(_initialExtent);

  @override
  void dispose() {
    _extent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final basemap = ref.watch(basemapProvider);
    final overlays = ref.watch(mapOverlaysProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.map(_extent),
            ValueListenableBuilder<double>(
              valueListenable: _extent,
              builder: (context, extent, child) => Positioned(
                left: 0,
                right: 0,
                bottom: height * extent,
                child: child!,
              ),
              // Without the system's bottom inset, which the bar adds for the
              // navigation bar when it sits at the foot of a screen. Here the
              // panel is below it, and the inset made the bar several lines
              // tall on a phone.
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: MapAttributionBar(basemap: basemap, overlays: overlays),
              ),
            ),
            NotificationListener<DraggableScrollableNotification>(
              onNotification: (notification) {
                _extent.value = notification.extent;
                return false;
              },
              child: DraggableScrollableSheet(
                initialChildSize: _initialExtent,
                minChildSize: _minExtent,
                maxChildSize: _maxExtent,
                snap: true,
                snapSizes: const [_initialExtent],
                builder: (context, controller) => Material(
                  color: theme.colorScheme.surface,
                  elevation: 3,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListView(
                    controller: controller,
                    padding: EdgeInsets.only(bottom: 16 + bottom),
                    children: [const _DragHandle(), ...widget.panel],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The bar at the top of the panel that says it can be dragged.
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      width: 32,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

/// Whether [item] has a journey worth reading on its own — i.e. whether the
/// timeline should offer the journey on the tile rather than only on its group.
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
