import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/clock.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../../attachments/application/attachment_providers.dart';
import '../../attachments/presentation/attachment_sheet.dart';
import '../../attachments/presentation/gallery_screen.dart';
import '../../attachments/trip_gallery.dart';
import '../photo_clusters.dart';
import '../../itinerary/application/itinerary_providers.dart';
import '../../itinerary/application/transport_mode_providers.dart';
import '../../itinerary/live_items.dart';
import '../../itinerary/now_marker.dart';
import '../../itinerary/widgets/transport_mode.dart';
import '../../trips/application/trip_providers.dart';
import '../basemap.dart';
import '../finite_camera.dart';
import '../map_features.dart';
import '../widgets/device_location_overlay.dart';
import '../widgets/map_overlays.dart';
import 'map_item_sheet.dart';

/// A trip on a map: its places as pins, its transport legs as lines between
/// their ends, and — on today — the entry that is under way, marked as the
/// timeline marks it.
///
/// Everything drawn is derived from the itinerary, so the screen needs no query
/// of its own. Tapping a marker opens a *reading* of that entry, and the one
/// button there hands editing on to the form that owns it — the single exception
/// being the color the entry is drawn in, which is about this screen and nothing
/// else (see `MapItemSheet`).
class TripMapScreen extends ConsumerWidget {
  const TripMapScreen({super.key, required this.tripId});

  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final itemsAsync = ref.watch(itineraryProvider(tripId));
    final chosen = ref.watch(chosenBranchIdsProvider(tripId));
    final trip = ref.watch(tripProvider(tripId)).value;

    // A routine has no "today": its entries sit on ordinal days anchored to a
    // fixed date, so asking where "now" falls in them would answer about 1970.
    final isRoutine = trip?.kind == TripKind.routine;
    final now = isRoutine ? null : ref.watch(nowProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mapTitle)),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(l10n.genericError('$error'))),
        data: (items) {
          final live = liveItems(items, chosen);
          // Read once and used twice: the marker needs its thumbnail, and the
          // pure layer needs the rows to decide which of them the plan still
          // admits to.
          final photos =
              ref.watch(tripPhotoMarkersProvider(tripId)).value ??
              const <Attachment>[];
          final features = tripMapFeatures(
            live,
            happeningItemId: _happeningItemId(live, now),
            // A leg that was actually recorded draws what was recorded; the
            // straight segment between its ends was only ever the best the plan
            // could say. Empty while the stream is still opening, so the map
            // draws the plan first and sharpens rather than waiting.
            tracks: ref.watch(tripTracksProvider(tripId)).value ?? const {},
            // The pictures that carry a position. Unfiltered on the way in —
            // which of them belong to the plan as it stands is decided by
            // `tripMapFeatures` against the same live entries everything else
            // here is drawn from.
            photos: photos,
          );
          if (features.isEmpty) return _EmptyMap(l10n: l10n);
          return _MapView(
            features: features,
            itemsById: {for (final item in live) item.id: item},
            // Keyed by id so a marker, which carries one and nothing else, can
            // find the thumbnail it is drawn from — the same arrangement the
            // entries use.
            photosById: {for (final photo in photos) photo.id: photo},
            basemap: kDefaultBasemap,
            // The trip's own accent, the same one its card, its header, its
            // calendar bar and its PDF are drawn in — the map was the one place
            // still using the app's theme color, which says nothing about
            // *which* trip is on screen. It also settles the all-trips map: one
            // rule, and every line there is already identifiable.
            accent: trip == null ? null : Color(trip.colorValue),
          );
        },
      ),
    );
  }

  /// Which entry is under way, by the same rule the timeline uses.
  ///
  /// `nowMarkerForItems` reads a single day, so it is asked about today's live
  /// entries only; on any other day nothing is under way. A marker that is a
  /// *line* rather than a happening entry has no place here — a map has slots
  /// but no gaps between them — so only [NowMarker.happening] is used.
  int? _happeningItemId(List<ItineraryItem> live, DateTime? now) {
    if (now == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    final todays = [
      for (final i in live)
        if (i.date == today) i,
    ];
    if (todays.isEmpty) return null;
    final marker = nowMarkerForItems(todays, now.hour * 60 + now.minute);
    if (marker == null || !marker.happening) return null;
    return todays[marker.index].id;
  }
}

class _MapView extends ConsumerStatefulWidget {
  const _MapView({
    required this.features,
    required this.itemsById,
    required this.photosById,
    required this.basemap,
    this.accent,
  });

  final TripMapFeatures features;

  /// The entries the markers stand for, keyed by id. A marker carries an id and
  /// nothing else, so what to *say* about it is looked up here rather than
  /// copied into the pure layer, which has no business knowing about labels.
  final Map<int, ItineraryItem> itemsById;

  /// The photo rows the markers stand for, keyed by id — their thumbnails, and
  /// what the sheet opened by a tap reads.
  final Map<int, Attachment> photosById;
  final Basemap basemap;

  /// The trip's accent color, or null while the trip is still loading (the
  /// items arrive on their own stream, so the map can be drawable a frame
  /// before the trip is). Falls back to the theme's primary, which is what this
  /// screen used before the accent reached it.
  final Color? accent;

  @override
  ConsumerState<_MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<_MapView> {
  final MapController _controller = MapController();

  /// Which line the last tap landed on, filled in by `PolylineLayer` before the
  /// gesture around it reads it — the same arrangement the all-trips map uses.
  final _lineHits = ValueNotifier<LayerHitResult<MapPath>?>(null);

  @override
  void dispose() {
    _lineHits.dispose();
    super.dispose();
  }

  /// What a marker is for: the entry behind it, in words.
  ///
  /// A map can only say *where* — the name, the times and the delay marks all
  /// live in the row it was drawn from, and a pin with no way to ask about it is
  /// a dot on a picture.
  void _showItem(int itemId, {int? trackId}) {
    final item = widget.itemsById[itemId];
    if (item == null) return;
    showAppSheet<void>(
      context,
      builder: (_) => MapItemSheet(item: item, highlightTrackId: trackId),
    );
  }

  /// What a tap on a *line* is for: the entry it belongs to, and — since a leg
  /// draws one line per stored track — which of that entry's lines it was.
  ///
  /// A marker answers for one entry because it is one entry's mark. A line is
  /// not: an out-and-back walk lies on itself, and neighbouring legs share their
  /// stretch of road at any zoom that shows a city. So every entry under the
  /// finger is offered (`pathsUnderTap`), one opens directly, and several name
  /// themselves and let the tap be finished deliberately — the rule the
  /// all-trips map already follows for trips.
  void _showLines(List<MapPath> hits) {
    if (hits.isEmpty) return;
    if (hits.length == 1) {
      _showItem(hits.single.itemId, trackId: hits.single.trackId);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final modes = ref.read(transportModesByIdProvider);
    showAppSheet<void>(
      context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.mapEntriesHere(hits.length),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              for (final (hit, ends) in [
                for (final hit in hits) (hit, _endsOf(hit)),
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    modes[hit.modeId]?.icon ?? kDefaultTransportModeIcon,
                  ),
                  // Named as the sheet behind this one names it, so the row and
                  // what it opens read the same.
                  title: Text(_labelOf(hit, l10n)),
                  subtitle: ends == null ? null : Text(ends),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showItem(hit.itemId, trackId: hit.trackId);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// What a photo marker is for.
  ///
  /// One picture opens the sheet that owns the acts on it — the same one the
  /// entry's form opens, since a photograph is one thing wherever it is reached
  /// from, and the position controls live there, which is what a pin was tapped
  /// to ask about. Several, gathered under one thumbnail, open the gallery
  /// instead: the question there is "what are these", and a sheet can only
  /// answer for one of them.
  void _showPhotos(PhotoCluster cluster) {
    final rows = [
      for (final photo in cluster.photos)
        ?widget.photosById[photo.attachmentId],
    ];
    if (rows.isEmpty) return;
    if (rows.length == 1) {
      showAttachmentSheet(context, rows.single);
      return;
    }
    showGallery(
      context,
      photos: [for (final row in rows) GalleryPhoto(attachment: row)],
    );
  }

  /// What to call the entry a hit belongs to: its own label, else its mode,
  /// else the placeholder the sheet uses when an entry has nothing to be called.
  String _labelOf(MapPath hit, AppLocalizations l10n) {
    final mode = ref.read(transportModesByIdProvider)[hit.modeId];
    return hit.label ?? mode?.label(l10n) ?? l10n.coordinatesNone;
  }

  /// The leg's two ends, where it has them — what tells two unlabeled legs of
  /// one trip apart when both are under the finger.
  String? _endsOf(MapPath hit) {
    final item = widget.itemsById[hit.itemId];
    if (item == null) return null;
    if (item.fromLocation == null && item.toLocation == null) return null;
    return '${item.fromLocation ?? '?'} → ${item.toLocation ?? '?'}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final features = widget.features;
    final basemap = widget.basemap;
    final modes = ref.watch(transportModesByIdProvider);
    final points = features.allPoints;
    final accent = widget.accent ?? theme.colorScheme.primary;

    // The map is put where the user is once, when the receiver first answers.
    // After that the mark moves and the camera does not — see
    // `listenForFirstFix`.
    listenForFirstFix(ref, (fix) => centerOnFix(_controller, fix));

    /// What one entry is drawn in: its own color when it has been given one,
    /// and the trip's accent otherwise — which is what an entry that carries
    /// none means, and what every entry meant before they could carry one.
    ///
    /// Being *under way* still outranks both: red is the app's one reserved
    /// color, said the same way in the timeline, the widget and here, and a
    /// user's choice must not be able to hide where they are.
    Color colorOf(int? colorValue, {required bool happening}) => happening
        ? theme.colorScheme.error
        : (colorValue == null ? accent : Color(colorValue));

    // A casing under every line. Map tiles are busy and any color, including
    // one the user picked, lands on something it disappears against sooner or
    // later; a stroke of the surface color underneath keeps the route readable
    // over forest, motorway and city block alike. It is what paper maps do, and
    // it is why the line reads as drawn *on* the map rather than as part of it.
    final casing = theme.colorScheme.surface;

    return Stack(
      // The map *fills* the stack; it does not size it. A stack measures its
      // non-positioned children to find its own size, so a loosely constrained
      // map has to be laid out for that — and every layout of a `FlutterMap`
      // re-runs its layout callback, which rebuilds every layer inside it,
      // markers included. Expanding hands the map tight constraints instead, so
      // the rebuild happens when the size actually changes rather than whenever
      // something above asks how big the map would like to be.
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
            // Framed to hold everything the trip touches. A single point has no
            // extent to fit, so it is centred at a street-level zoom instead.
            initialCameraFit: points.length > 1
                ? CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(points),
                    padding: const EdgeInsets.all(48),
                  )
                : null,
            initialCenter: points.isEmpty ? const LatLng(0, 0) : points.first,
            initialZoom: 13,
            maxZoom: maxZoomOf(basemap),
            interactionOptions: const InteractionOptions(
              // No rotation: every label the app draws is horizontal, and a map
              // turned by accident is a map the user has to put back.
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            basemapTileLayer(basemap, ref.watch(appVersionProvider)),
            GestureDetector(
              onTap: () {
                final hit = _lineHits.value;
                if (hit == null) return;
                _showLines(pathsUnderTap(hit.hitValues, features.paths));
              },
              child: PolylineLayer(
                hitNotifier: _lineHits,
                // Wider than the line is drawn: what "on this line" means has
                // to be a fingertip, and flutter_map's default hitbox is the
                // stroke itself. The same constant the all-trips map uses, for
                // the same reason.
                minimumHitbox: kLineHitbox,
                polylines: [
                  for (final path in features.paths)
                    for (final segment in path.segments)
                      Polyline(
                        points: segment,
                        strokeWidth: path.happening ? 5 : 3.5,
                        // Broken for a line the router computed rather than one
                        // anybody followed — see `MapPath.dashed`.
                        pattern: path.dashed
                            ? StrokePattern.dashed(segments: const [7, 5])
                            : const StrokePattern.solid(),

                        // Red for the leg under way, as everywhere else in the
                        // app; the entry's own color, or the trip's, for the rest.
                        color: colorOf(
                          path.colorValue,
                          happening: path.happening,
                        ),
                        borderStrokeWidth: 2,
                        borderColor: casing,
                        // Simplification is flutter_map's own, per frame: a
                        // great-circle arc carries vertices that are invisible at
                        // low zoom and matter when zoomed in.
                        useStrokeWidthInMeter: false,
                        // What a tap on this line means: this entry, and this
                        // one of its lines. A path is one stored line (or the
                        // straight segment where there is none), so the answer
                        // is as fine as what was drawn.
                        hitValue: path,
                      ),
                ],
              ),
            ),
            MarkerLayer(
              markers: [
                // One badge per entry, not per line: a leg recorded in three
                // segments is one leg, and it is `badged` that says which of
                // its paths wears the icon — the longest, where the icon sat
                // when a leg was a single path. Every path wearing one also
                // costs the line its taps, since a marker wins the hit test
                // against the line under it.
                for (final path in features.paths)
                  if (path.badged)
                    Marker(
                      point: path.anchor,
                      width: 28,
                      height: 28,
                      child: _Tappable(
                        // The badge is the *entry's* mark, so it answers for
                        // the entry and marks no line — which is exactly what
                        // it means when a leg's lines are listed unmarked.
                        onTap: () => _showItem(path.itemId),
                        child: _ModeBadge(
                          color: colorOf(
                            path.colorValue,
                            happening: path.happening,
                          ),
                          // The row's own icon, which for a built-in falls back
                          // to that built-in's default — the same resolution
                          // the timeline tile uses. Reading `iconId` directly
                          // instead gives every built-in the generic three
                          // dots, since a seeded row carries no id of its own.
                          icon:
                              modes[path.modeId]?.icon ??
                              kDefaultTransportModeIcon,
                        ),
                      ),
                    ),
                for (final pin in features.pins)
                  Marker(
                    point: pin.position,
                    // Aligned above the point so the pin's tip — its whole
                    // claim — lands on it.
                    width: 34,
                    height: 34,
                    alignment: Alignment.topCenter,
                    child: _Tappable(
                      onTap: () => _showItem(pin.itemId),
                      child: MapPlacePin(
                        color: colorOf(
                          pin.colorValue,
                          happening: pin.happening,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Photos in a layer of their own, above the plan rather than
            // among it: a picture is bigger than a pin and would cover the
            // entry it is about if the two were interleaved by list order.
            // Still below the device's mark, which has to stay findable.
            _PhotoMarkers(
              photos: features.photos,
              photosById: widget.photosById,
              colorOf: colorOf,
              onTap: _showPhotos,
            ),
            // Above the plan's own marks: the question it answers ("where am I
            // in all this") is asked *of* them, so it must not end up under one.
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

/// The transport mode, sitting on the middle of its leg.
///
/// Handed a resolved [color] rather than deciding one: which color a leg wears
/// — its own, the trip's, or the red of being under way — is settled once, where
/// the line is drawn, so the badge and the line it sits on cannot disagree.
class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

/// Shown when the trip has nothing to place.
///
/// A world map centred on nothing would look like a failure; saying what is
/// missing is both truer and actionable — the positions come from picking a
/// place on the map or from importing a connection, and neither has happened
/// here yet.
class _EmptyMap extends StatelessWidget {
  const _EmptyMap({required this.l10n});

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

/// A tap target around a marker.
///
/// `HitTestBehavior.opaque` so the whole box answers, not just the glyph's inked
/// pixels — a pin is mostly transparent, and a tap that has to land on the
/// stroke is a tap that misses.
class _Tappable extends StatelessWidget {
  const _Tappable({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: child,
  );
}

/// The trip's photographs, gathered so that none hides another.
///
/// A layer of its own rather than markers in the one above, because it has to
/// be rebuilt whenever the camera moves: `MapCamera.of(context)` is what makes
/// that happen, and reading it here keeps the rest of the map from rebuilding
/// with it.
///
/// Which pictures fall together is `clusterPhotos`, measured in screen pixels
/// through the camera's own projection — so zooming in pulls a cluster apart on
/// its own, with no threshold in metres to be wrong at some scale.
class _PhotoMarkers extends StatelessWidget {
  const _PhotoMarkers({
    required this.photos,
    required this.photosById,
    required this.colorOf,
    required this.onTap,
  });

  final List<MapPhoto> photos;
  final Map<int, Attachment> photosById;
  final Color Function(int? colorValue, {required bool happening}) colorOf;
  final ValueChanged<PhotoCluster> onTap;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();
    final camera = MapCamera.of(context);
    final clusters = clusterPhotos(
      photos,
      project: (photo) {
        final offset = camera.latLngToScreenOffset(photo.position);
        return math.Point<double>(offset.dx, offset.dy);
      },
    );

    return MarkerLayer(
      markers: [
        for (final cluster in clusters)
          Marker(
            point: cluster.representative.position,
            width: kPhotoMarkerSize + 8,
            height: kPhotoMarkerSize + 8,
            child: _Tappable(
              onTap: () => onTap(cluster),
              child: Center(
                child: MapPhotoMarker(
                  thumbnail: photosById[cluster.representative.attachmentId]
                      ?.thumbnail,
                  // A photo is never "under way": it records a moment that has
                  // passed, so it takes its entry's color or the trip's and
                  // never the reserved red.
                  color: colorOf(
                    cluster.representative.colorValue,
                    happening: false,
                  ),
                  count: cluster.count,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
