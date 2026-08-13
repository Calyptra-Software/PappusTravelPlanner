import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/clock.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../../itinerary/application/itinerary_providers.dart';
import '../../itinerary/application/transport_mode_providers.dart';
import '../../itinerary/live_items.dart';
import '../../itinerary/now_marker.dart';
import '../../itinerary/widgets/transport_mode.dart';
import '../../trips/application/trip_providers.dart';
import '../basemap.dart';
import '../map_features.dart';
import '../widgets/map_overlays.dart';
import 'map_item_sheet.dart';

/// A trip on a map: its places as pins, its transport legs as lines between
/// their ends, and — on today — the entry that is under way, marked as the
/// timeline marks it.
///
/// Everything drawn is derived from the itinerary, so the screen needs no query
/// of its own. It does not write either — tapping a marker opens a *reading* of
/// that entry, and the one button there hands the job on to the form that owns
/// it.
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
          final features = tripMapFeatures(
            live,
            happeningItemId: _happeningItemId(live, now),
          );
          if (features.isEmpty) return _EmptyMap(l10n: l10n);
          return _MapView(
            features: features,
            itemsById: {for (final item in live) item.id: item},
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
    required this.basemap,
    this.accent,
  });

  final TripMapFeatures features;

  /// The entries the markers stand for, keyed by id. A marker carries an id and
  /// nothing else, so what to *say* about it is looked up here rather than
  /// copied into the pure layer, which has no business knowing about labels.
  final Map<int, ItineraryItem> itemsById;
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

  /// What a marker is for: the entry behind it, in words.
  ///
  /// A map can only say *where* — the name, the times and the delay marks all
  /// live in the row it was drawn from, and a pin with no way to ask about it is
  /// a dot on a picture.
  void _showItem(int itemId) {
    final item = widget.itemsById[itemId];
    if (item == null) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => MapItemSheet(item: item),
    );
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

    // A casing under every line. Map tiles are busy and any color, including
    // one the user picked, lands on something it disappears against sooner or
    // later; a stroke of the surface color underneath keeps the route readable
    // over forest, motorway and city block alike. It is what paper maps do, and
    // it is why the line reads as drawn *on* the map rather than as part of it.
    final casing = theme.colorScheme.surface;

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            minZoom: kMinMapZoom,
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
            PolylineLayer(
              polylines: [
                for (final path in features.paths)
                  for (final segment in path.segments)
                    Polyline(
                      points: segment,
                      strokeWidth: path.happening ? 5 : 3.5,
                      // Red for the leg under way, as everywhere else in the
                      // app; the trip's own color for the rest.
                      color: path.happening ? theme.colorScheme.error : accent,
                      borderStrokeWidth: 2,
                      borderColor: casing,
                      // Simplification is flutter_map's own, per frame: a
                      // great-circle arc carries vertices that are invisible at
                      // low zoom and matter when zoomed in.
                      useStrokeWidthInMeter: false,
                    ),
              ],
            ),
            MarkerLayer(
              markers: [
                for (final path in features.paths)
                  Marker(
                    point: path.anchor,
                    width: 28,
                    height: 28,
                    child: _Tappable(
                      onTap: () => _showItem(path.itemId),
                      child: _ModeBadge(
                        accent: accent,
                        // The row's own icon, which for a built-in falls back to
                        // that built-in's default — the same resolution the
                        // timeline tile uses. Reading `iconId` directly instead
                        // gives every built-in the generic three dots, since a
                        // seeded row carries no id of its own.
                        icon:
                            modes[path.modeId]?.icon ??
                            kDefaultTransportModeIcon,
                        happening: path.happening,
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
                      child: _PlacePin(
                        accent: accent,
                        happening: pin.happening,
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

/// The transport mode, sitting on the middle of its leg.
class _ModeBadge extends StatelessWidget {
  const _ModeBadge({
    required this.icon,
    required this.accent,
    required this.happening,
  });

  final IconData icon;
  final Color accent;
  final bool happening;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = happening ? scheme.error : accent;
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

class _PlacePin extends StatelessWidget {
  const _PlacePin({required this.accent, required this.happening});

  final Color accent;
  final bool happening;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MapPlacePin(color: happening ? scheme.error : accent);
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
