import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../itinerary/application/itinerary_providers.dart';
import '../../itinerary/application/transport_mode_providers.dart';
import '../../itinerary/widgets/transport_mode.dart';
import '../../map/basemap_provider.dart';
import '../../map/finite_camera.dart';
import '../../map/map_features.dart';
import '../../map/widgets/device_location_overlay.dart';
import '../../map/widgets/map_overlays.dart';
import '../../map/widgets/map_style_button.dart';
import '../journey_map_features.dart';

/// The quiet color of what lies outside the traveler's legs: the run before
/// boarding and after getting off, and its stops. A map color, not a theme
/// color, and the grey the point picker draws its context in, for the reason
/// `map.md` gives: the tiles are pale in both themes, and quiet is a matter of
/// size and color, never of alpha over something this app does not control.
const Color kJourneyRunColor = Color(0xFF5F6368);

/// The journey screen's map: the legs as the trip's map draws them, their stops,
/// and the rest of each vehicle's run around them.
///
/// It draws and does not answer taps yet: everything a tap could say about a
/// leg is in the panel over the lower part of the screen.
class JourneyMap extends ConsumerStatefulWidget {
  const JourneyMap({
    super.key,
    required this.tripId,
    required this.legs,
    this.happeningItemId,
    this.accent,
    this.panelExtent,
    this.shownRuns = const {},
    this.runShapes = const {},
    this.fitTo,
  });

  final int tripId;

  /// The journey's transport legs, in the order it travels them.
  final List<ItineraryItem> legs;

  /// The leg under way, drawn in the red reserved for it.
  final int? happeningItemId;

  /// The trip's accent, or null while the trip is still loading.
  final Color? accent;

  /// The share of the map's height the panel over its lower part covers:
  /// the camera frames what it is asked to in what is left.
  final ValueListenable<double>? panelExtent;

  /// The legs whose run outside them is drawn, and each one's route; see
  /// [journeyMapFeatures].
  final Set<int> shownRuns;
  final Map<int, List<LatLng>> runShapes;

  /// Points to frame, once, whenever a new list arrives: the run that has
  /// just been put on the map.
  final ValueListenable<List<LatLng>?>? fitTo;

  @override
  ConsumerState<JourneyMap> createState() => _JourneyMapState();
}

class _JourneyMapState extends ConsumerState<JourneyMap> {
  final MapController _controller = MapController();

  @override
  void initState() {
    super.initState();
    widget.fitTo?.addListener(_frame);
  }

  @override
  void didUpdateWidget(JourneyMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fitTo != widget.fitTo) {
      oldWidget.fitTo?.removeListener(_frame);
      widget.fitTo?.addListener(_frame);
    }
  }

  @override
  void dispose() {
    widget.fitTo?.removeListener(_frame);
    super.dispose();
  }

  /// Frames what [JourneyMap.fitTo] now holds, above the panel as it stands.
  void _frame() {
    final points = widget.fitTo?.value;
    if (points == null || points.length < 2 || !mounted) return;
    _controller.fitCamera(_fit(points, context.size?.height ?? 0));
  }

  /// The view holding [points] with room around them, the part of the map's
  /// [height] the panel covers left out at the bottom.
  CameraFit _fit(List<LatLng> points, double height) => CameraFit.bounds(
    bounds: LatLngBounds.fromPoints(points),
    padding: EdgeInsets.fromLTRB(
      48,
      48,
      48,
      48 + height * (widget.panelExtent?.value ?? 0),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final basemap = ref.watch(basemapProvider);
    final overlays = ref.watch(mapOverlaysProvider);
    final modes = ref.watch(transportModesByIdProvider);
    final accent = widget.accent ?? theme.colorScheme.primary;
    // The legs' own lines and mode badges, by the trip map's rules.
    final lines = tripMapFeatures(
      widget.legs,
      happeningItemId: widget.happeningItemId,
      tracks: ref.watch(tripTracksProvider(widget.tripId)).value ?? const {},
    );
    final journey = journeyMapFeatures(
      widget.legs,
      shownRuns: widget.shownRuns,
      runShapes: widget.runShapes,
    );
    // The journey itself; the lines alone if no stop carries a position.
    final frame = journey.frame.isNotEmpty ? journey.frame : lines.allPoints;

    // As on the trip's map: put where the user is once, when a pressed
    // session first answers, and never moved by the mark after that.
    listenForFirstFix(ref, (fix) => centerOnFix(_controller, fix));

    // The same rule the trip's map draws a leg by: its own color, else the
    // trip's, and red while it is under way, which no choice may hide.
    Color colorOf(int? colorValue, {required bool happening}) => happening
        ? theme.colorScheme.error
        : (colorValue == null ? accent : Color(colorValue));
    final casing = theme.colorScheme.surface;

    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              minZoom: kMinMapZoom,
              // See finite_camera.dart: a pinch can hand over a NaN camera.
              cameraConstraint: const FiniteCamera(),
              initialCameraFit: frame.length > 1
                  ? _fit(frame, constraints.maxHeight)
                  : null,
              initialCenter: frame.isEmpty ? const LatLng(0, 0) : frame.first,
              initialZoom: 13,
              maxZoom: maxZoomOf(basemap),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              ...basemapTileLayers(
                basemap,
                overlays,
                ref.watch(appVersionProvider),
              ),
              // The run first, so the legs lie on top of it where they meet.
              PolylineLayer(
                polylines: [
                  for (final line in journey.runLines)
                    Polyline(
                      points: line,
                      strokeWidth: 2.5,
                      color: kJourneyRunColor,
                      borderStrokeWidth: 1.5,
                      borderColor: const Color(0xFFFFFFFF),
                    ),
                ],
              ),
              PolylineLayer(
                polylines: [
                  for (final path in lines.paths)
                    for (final segment in path.segments)
                      Polyline(
                        points: segment,
                        strokeWidth: path.happening ? 5 : 3.5,
                        // Broken for a line the router computed rather than one
                        // anybody followed, as on the trip's map.
                        pattern: path.dashed
                            ? StrokePattern.dashed(segments: const [7, 5])
                            : const StrokePattern.solid(),
                        color: colorOf(
                          path.colorValue,
                          happening: path.happening,
                        ),
                        borderStrokeWidth: 2,
                        borderColor: casing,
                      ),
                ],
              ),
              MarkerLayer(
                markers: [
                  for (final stop in journey.stops)
                    Marker(
                      point: stop.point,
                      width: stop.end ? 14 : 10,
                      height: stop.end ? 14 : 10,
                      child: Semantics(
                        label: stop.name,
                        child: _StopDot(
                          color: stop.outside ? kJourneyRunColor : accent,
                          end: stop.end,
                        ),
                      ),
                    ),
                  for (final path in lines.paths)
                    if (path.badged)
                      Marker(
                        point: path.anchor,
                        width: 28,
                        height: 28,
                        child: _ModeBadge(
                          color: colorOf(
                            path.colorValue,
                            happening: path.happening,
                          ),
                          icon:
                              modes[path.modeId]?.icon ??
                              kDefaultTransportModeIcon,
                        ),
                      ),
                ],
              ),
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
                MapLocationButton(
                  onCenter: (fix) => centerOnFix(_controller, fix),
                ),
                const SizedBox(height: 8),
                const MapStyleButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A stop: a dot ringed in white, larger where the traveler gets on or off.
class _StopDot extends StatelessWidget {
  const _StopDot({required this.color, required this.end});

  final Color color;
  final bool end;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      // An end is hollow, as a station on a line diagram is; a stop passed
      // through is filled.
      color: end ? const Color(0xFFFFFFFF) : color,
      shape: BoxShape.circle,
      border: Border.all(
        color: end ? color : const Color(0xFFFFFFFF),
        width: end ? 3 : 1.5,
      ),
    ),
  );
}

/// The transport mode on the middle of its leg, as the trip's map draws it.
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
