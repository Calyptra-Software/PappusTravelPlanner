import 'dart:math' as math;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/providers.dart';
import '../../../core/format/money_format.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../data/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../itinerary/application/itinerary_providers.dart';
import '../basemap.dart';
import '../finite_camera.dart';
import '../map_features.dart';
import '../pin_clusters.dart';
import '../widgets/device_location_overlay.dart';
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
  ///
  /// It takes *every* trip under the finger, because the tangle is the normal
  /// case rather than the awkward one: the same commute drawn twenty times lies
  /// exactly on itself, and a route shared for part of its length runs alongside
  /// its neighbours at any zoom that shows a country. Answering with whichever
  /// line happened to be drawn last is then a coin toss the user cannot see,
  /// and re-tapping does not reshuffle it — the trip they meant may be
  /// unreachable at that spot. So one trip opens its card directly, and several
  /// name themselves and let the tap be finished deliberately.
  void _showTrips(List<Trip> trips) {
    if (trips.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    showAppSheet<void>(
      context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Only when there is a choice to make: above a single card the
              // count would be a label reading "1 trip here" over the one thing
              // on screen.
              if (trips.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    l10n.mapTripsHere(trips.length),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: trips.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => TripCard(
                    trip: trips[i],
                    tags: widget.tagsByTrip[trips[i].id] ?? const [],
                    totals: widget.totalsByTrip[trips[i].id] ?? const {},
                    book: widget.book,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onOpenTrip(trips[i]);
                    },
                  ),
                ),
              ),
            ],
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
    // One stream for every trip's lines, keyed by entry — the same reason the
    // entries themselves come in one query rather than one per trip.
    final tracks = ref.watch(allTracksProvider(null)).value ?? const {};
    final drawn = <(Trip, TripMapFeatures)>[
      for (final trip in widget.trips)
        if (byTrip[trip.id] case final tripItems?)
          (trip, tripMapFeatures(tripItems, tracks: tracks)),
    ];

    if (itemsAsync.isLoading && drawn.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (drawn.isEmpty) return _NothingToPlace(l10n: l10n);

    final points = [for (final (_, features) in drawn) ...features.allPoints];
    final casing = theme.colorScheme.surface;

    final tripIds = {for (final (trip, _) in drawn) trip.id};
    if (_framedFor == null || !setEquals(_framedFor, tripIds)) {
      _frame(points, tripIds);
    }

    // The one other thing allowed to move this camera, and by the same rule the
    // framing follows: an explicit act with an expectation attached moves it,
    // a tick of the stream does not.
    listenForFirstFix(ref, (fix) => centerOnFix(_controller, fix));

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
            // A pinch can hand flutter_map a camera with a NaN in it, which makes
            // every marker read as visible in every neighboring world and hangs
            // the frame. See finite_camera.dart.
            cameraConstraint: const FiniteCamera(),
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
                if (hit == null) return;
                // A trip is drawn as many polylines — one per leg, more where a
                // leg is an arc or crosses the antimeridian — so the same id
                // comes back once per line under the finger. What the sheet
                // lists is trips, so they are folded down to one each, in the
                // overview's own order rather than in the order they were
                // drawn: the map is a view of that list, and a stable order is
                // one the user can learn.
                final ids = hit.hitValues.toSet();
                _showTrips([
                  for (final trip in widget.trips)
                    if (ids.contains(trip.id)) trip,
                ]);
              },
              child: PolylineLayer(
                hitNotifier: _lineHits,
                // Wider than the line is drawn, because the question this
                // answers is "which of these", and the lines that raise it are
                // the ones running alongside each other. flutter_map's default
                // hitbox is the stroke itself, which on a 3px line asks for a
                // precision no finger has.
                minimumHitbox: kLineHitbox,
                polylines: [
                  for (final (trip, features) in drawn)
                    for (final path in features.paths)
                      for (final segment in path.segments)
                        Polyline(
                          points: segment,
                          strokeWidth: 3,
                          // Broken for a line the router computed rather than one
                          // anybody followed — see `MapPath.dashed`.
                          pattern: path.dashed
                              ? StrokePattern.dashed(segments: const [7, 5])
                              : const StrokePattern.solid(),

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
            // The places, gathered so that none hides another — the same rule
            // the lines are hit-tested under, applied before they are drawn.
            _PinMarkers(
              pins: [
                for (final (trip, features) in drawn)
                  for (final pin in features.pins)
                    TripPin(trip: trip, pin: pin),
              ],
              onTap: _showTrips,
            ),
            // Above every trip's own marks: "where am I in all this" is asked
            // *of* them, so it must not end up under one.
            const DeviceLocationLayer(),
          ],
        ),
        Positioned(
          top: 12,
          right: 12 + MediaQuery.paddingOf(context).right,
          child: Column(
            children: [
              MapZoomButtons(
                controller: _controller,
                basemap: basemap,
                zoomInTooltip: l10n.mapZoomIn,
                zoomOutTooltip: l10n.mapZoomOut,
              ),
              const SizedBox(height: 8),
              const MapLocationButton(),
            ],
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

/// The color a mark gathering *several* trips is drawn in.
///
/// Not one of their accents: on this map a color is the statement "that is
/// trip A's", so wearing A's accent over a mark holding B and C as well would
/// be saying something false about two of them — and the color is the whole
/// reason a tangle of trips is readable here. A neutral says only "several",
/// which is what the count beside it says too, and the tap says the rest.
///
/// In map colours rather than theme ones, like the picker's mark and for the
/// same reason: raster tiles are pale in both themes, so a mark tinted by the
/// theme is a road.
const Color kMixedTripPinColor = Color(0xFF424242);

/// Every visible trip's places, gathered so that none hides another.
///
/// A layer of its own rather than markers among the rest, because it has to be
/// rebuilt whenever the camera moves: `MapCamera.of(context)` is what makes
/// that happen, and reading it here keeps the rest of the map from rebuilding
/// with it. The trip map's `_PhotoMarkers` is the same arrangement.
///
/// Which pins fall together is `clusterPins`, measured in screen pixels through
/// the camera's own projection — so zooming in pulls a cluster apart on its
/// own, with no threshold in metres to be wrong at some scale.
class _PinMarkers extends StatelessWidget {
  const _PinMarkers({required this.pins, required this.onTap});

  /// In the overview's order of trips, which is what makes a cluster keep the
  /// same face — and name its trips in the same order — as the map moves.
  final List<TripPin> pins;

  /// Handed every trip under the mark, once each: the same answer the lines
  /// give, since a pin hides its neighbours exactly as a line lies on one.
  final ValueChanged<List<Trip>> onTap;

  @override
  Widget build(BuildContext context) {
    if (pins.isEmpty) return const SizedBox.shrink();
    final camera = MapCamera.of(context);
    final clusters = clusterPins(
      pins,
      project: (entry) {
        final offset = camera.latLngToScreenOffset(entry.pin.position);
        return math.Point<double>(offset.dx, offset.dy);
      },
    );

    const size = 28.0;
    final box = pinBoxFor(size);

    return MarkerLayer(
      markers: [
        for (final cluster in clusters)
          Marker(
            point: cluster.representative.pin.position,
            width: cluster.count > 1 ? box.width : 30,
            height: cluster.count > 1 ? box.height : 30,
            // Aligned above the point so the pin's tip — its whole claim —
            // lands on it, gathered or not.
            alignment: Alignment.topCenter,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(cluster.trips),
              child: MapPlacePin(
                // A trip's accent while every place here is that trip's; a
                // neutral once the mark stands for several. Never the entry's
                // own color: on this map the color answers "which trip", which
                // is what makes it readable at all.
                color: switch (cluster.onlyTrip) {
                  final trip? => Color(trip.colorValue),
                  null => kMixedTripPinColor,
                },
                size: size,
                count: cluster.count,
              ),
            ),
          ),
      ],
    );
  }
}
