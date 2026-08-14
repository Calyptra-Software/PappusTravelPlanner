import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/providers.dart';
import '../../../core/format/money_format.dart';
import '../../../data/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../itinerary/application/itinerary_providers.dart';
import '../basemap.dart';
import '../map_features.dart';
import '../widgets/map_overlays.dart';
import '../../trips/widgets/trip_card.dart';

/// Every trip the overview is currently showing, on one map.
///
/// A *view* of the overview rather than a screen of its own: it draws exactly
/// the trips handed to it, which are the ones `applyTripQuery` left visible. So
/// there is no second filter to build and none to keep in step — "only my walks,
/// this year" is already expressible, and the map inherits it by being given the
/// answer.
///
/// Each trip keeps its **own accent**, the color its card in the list beside
/// this one is already drawn in. That is what makes a hairball of lines
/// readable: a line identifies itself, and the map reads in the same colors the
/// list does.
class AllTripsMap extends ConsumerStatefulWidget {
  const AllTripsMap({
    super.key,
    required this.trips,
    required this.onOpenTrip,
    this.totalsByTrip = const {},
    this.tagsByTrip = const {},
    required this.book,
  });

  /// The visible trips, in the overview's own order.
  final List<Trip> trips;

  /// Opens a trip — the same navigation the list's cards do.
  final ValueChanged<Trip> onOpenTrip;

  /// What a trip's card in the list shows beside its name. Passed through rather
  /// than watched again, so a trip tapped here reads exactly as it does there —
  /// and so this stays a *view* of the overview rather than a second reader of
  /// the same data.
  final Map<int, Map<String, int>> totalsByTrip;
  final Map<int, List<Tag>> tagsByTrip;
  final CurrencyBook book;

  @override
  ConsumerState<AllTripsMap> createState() => _AllTripsMapState();
}

class _AllTripsMapState extends ConsumerState<AllTripsMap> {
  final MapController _controller = MapController();

  /// The set of trips the camera was last framed to.
  ///
  /// Re-framing on every rebuild would yank the camera back on every tick of the
  /// stream, which is the opposite of what someone panning around wants. But
  /// re-framing when the *selection* changes is the whole point: tapping a tag
  /// chip is an explicit act with an expectation attached, and narrowing to four
  /// commutes across one city while the map still shows all of Germany looks
  /// like nothing happened.
  Set<int>? _framedFor;

  /// Which line the last tap landed on, filled in by `PolylineLayer` before the
  /// gesture below reads it.
  final _lineHits = ValueNotifier<LayerHitResult<int>?>(null);

  @override
  void dispose() {
    _lineHits.dispose();
    super.dispose();
  }

  /// Brings [points] into view after the frame that changed them.
  ///
  /// Deferred, because the camera cannot be moved during a build — and skipped
  /// on the first one, where `initialCameraFit` has already done it.
  void _frame(List<LatLng> points, Set<int> tripIds) {
    final first = _framedFor == null;
    _framedFor = tripIds;
    if (first || points.length < 2) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(48),
        ),
      );
    });
  }

  /// What a trip is, in the words its card already uses.
  ///
  /// On *this* map the unit is the trip, not the entry: everything drawn belongs
  /// to one, and "which trip is that line" is the question a tangle of routes
  /// raises. So the sheet is the card itself — the same colour, dates, tags and
  /// total the list shows — and tapping it opens the trip, exactly as tapping
  /// the card does. (The single-trip map answers the other question, about one
  /// entry, with `MapItemSheet`.)
  void _showTrip(Trip trip) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: TripCard(
            trip: trip,
            tags: widget.tagsByTrip[trip.id] ?? const [],
            totals: widget.totalsByTrip[trip.id] ?? const {},
            book: widget.book,
            onTap: () {
              Navigator.of(context).pop();
              widget.onOpenTrip(trip);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    const basemap = kDefaultBasemap;

    final itemsAsync = ref.watch(positionedItemsProvider);
    final items = itemsAsync.value ?? const <ItineraryItem>[];

    // One reading per trip, so each keeps its own color; the query hands back
    // every trip's entries in one ordered list.
    final byTrip = <int, List<ItineraryItem>>{};
    for (final item in items) {
      byTrip.putIfAbsent(item.tripId, () => []).add(item);
    }
    final drawn = <(Trip, TripMapFeatures)>[
      for (final trip in widget.trips)
        if (byTrip[trip.id] case final tripItems?)
          (trip, tripMapFeatures(tripItems)),
    ];

    if (itemsAsync.isLoading && drawn.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (drawn.isEmpty) return _NothingToPlace(l10n: l10n);

    final points = [for (final (_, features) in drawn) ...features.allPoints];
    final tripsById = {for (final trip in widget.trips) trip.id: trip};
    final casing = theme.colorScheme.surface;

    final tripIds = {for (final (trip, _) in drawn) trip.id};
    if (_framedFor == null || !setEquals(_framedFor, tripIds)) {
      _frame(points, tripIds);
    }

    return Stack(
      // The map *fills* the stack; it does not size it — see the note in
      // `trip_map_screen.dart`: a loosely constrained map is laid out just to
      // measure the stack, and every layout rebuilds every layer inside it.
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            minZoom: kMinMapZoom,
            maxZoom: maxZoomOf(basemap),
            initialCenter: points.first,
            initialZoom: 4,
            initialCameraFit: points.length > 1
                ? CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(points),
                    padding: const EdgeInsets.all(48),
                  )
                : null,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            basemapTileLayer(basemap, ref.watch(appVersionProvider)),
            // Every trip's lines in one layer rather than one layer per trip:
            // flutter_map culls and simplifies per layer, and a hundred layers
            // of one line each would do that work a hundred times.
            GestureDetector(
              onTap: () {
                final hit = _lineHits.value;
                if (hit == null || hit.hitValues.isEmpty) return;
                final tripId = hit.hitValues.first;
                final trip = tripsById[tripId];
                if (trip != null) _showTrip(trip);
              },
              child: PolylineLayer(
                hitNotifier: _lineHits,
                polylines: [
                  for (final (trip, features) in drawn)
                    for (final path in features.paths)
                      for (final segment in path.segments)
                        Polyline(
                          points: segment,
                          strokeWidth: 3,
                          color: Color(trip.colorValue),
                          borderStrokeWidth: 2,
                          borderColor: casing,
                          // What a tap on this line means: the trip it belongs
                          // to. A leg would be the wrong unit here — every line
                          // on this map is one trip among many.
                          hitValue: trip.id,
                        ),
                ],
              ),
            ),
            MarkerLayer(
              markers: [
                for (final (trip, features) in drawn)
                  for (final pin in features.pins)
                    Marker(
                      point: pin.position,
                      width: 30,
                      height: 30,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showTrip(trip),
                        child: MapPlacePin(
                          color: Color(trip.colorValue),
                          size: 28,
                        ),
                      ),
                    ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 12,
          right: 12 + MediaQuery.paddingOf(context).right,
          child: MapZoomButtons(
            controller: _controller,
            basemap: basemap,
            zoomInTooltip: l10n.mapZoomIn,
            zoomOutTooltip: l10n.mapZoomOut,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: MapAttributionBar(basemap: basemap),
        ),
      ],
    );
  }
}

/// Shown when none of the visible trips has anything to place.
///
/// Distinct from the overview's own empty state: there may well be trips here,
/// they simply have no positions yet. Saying "no trips" would be wrong, and a
/// blank world map would look like a failure.
class _NothingToPlace extends StatelessWidget {
  const _NothingToPlace({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.mapNothingToShow,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.mapNothingToShowHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
