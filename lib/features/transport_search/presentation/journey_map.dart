import 'dart:math' as math;

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
import '../../../data/database/tables.dart' show TrackSource;
import '../journey_map_features.dart';
import '../vehicle_progress.dart';
import 'journey_timeline.dart';

/// The quiet color of what lies outside the traveler's legs: the run before
/// boarding and after getting off, and its stops. A map color, not a theme
/// color, and the grey the point picker draws its context in, for the reason
/// `map.md` gives: the tiles are pale in both themes, and quiet is a matter of
/// size and color, never of alpha over something this app does not control.
const Color kJourneyRunColor = Color(0xFF5F6368);

/// The journey screen's map: the legs as the trip's map draws them, their stops,
/// and the rest of each vehicle's run around them.
///
/// On it, every vehicle of the journey that is on its way, where its timetable
/// puts it ([progressAt]): on the leg it runs, and on the run around a leg
/// only while that run is shown. A vehicle is placed only on a route the map
/// draws, never between two stops' points, which would put a train in a
/// field. A tap on one, or the follow button, keeps it in view as it moves,
/// until the map is moved by hand.
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
    this.clock,
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

  /// The time the vehicles are placed at, ticking while the screen is open;
  /// null where none is placed (a routine, which has no today).
  final ValueListenable<DateTime?>? clock;

  @override
  ConsumerState<JourneyMap> createState() => _JourneyMapState();
}

class _JourneyMapState extends ConsumerState<JourneyMap> {
  final MapController _controller = MapController();

  /// The vehicles to place, as the last build read them off the legs.
  List<_Vehicle> _vehicles = const [];

  /// The leg whose vehicle the camera follows, if any.
  int? _following;

  @override
  void initState() {
    super.initState();
    widget.fitTo?.addListener(_frame);
    widget.clock?.addListener(_follow);
  }

  @override
  void didUpdateWidget(JourneyMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fitTo != widget.fitTo) {
      oldWidget.fitTo?.removeListener(_frame);
      widget.fitTo?.addListener(_frame);
    }
    if (oldWidget.clock != widget.clock) {
      oldWidget.clock?.removeListener(_follow);
      widget.clock?.addListener(_follow);
    }
  }

  @override
  void dispose() {
    widget.fitTo?.removeListener(_frame);
    widget.clock?.removeListener(_follow);
    super.dispose();
  }

  /// Frames what [JourneyMap.fitTo] now holds, above the panel as it stands.
  void _frame() {
    final points = widget.fitTo?.value;
    if (points == null || points.length < 2 || !mounted) return;
    _stopFollowing();
    _controller.fitCamera(_fit(points, context.size?.height ?? 0));
  }

  /// Where each vehicle is at the clock's time, by leg id.
  Map<int, _Placed> _placed(ThemeData theme) {
    final now = widget.clock?.value;
    if (now == null) return const {};
    return {
      for (final vehicle in _vehicles) vehicle.legId: ?vehicle.at(now, theme),
    };
  }

  /// Starts following [legId]'s vehicle, bringing it into view at once.
  void _startFollowing(int legId) {
    setState(() => _following = legId);
    _follow(zoomIn: true);
  }

  void _stopFollowing() {
    if (_following != null && mounted) setState(() => _following = null);
  }

  /// Moves the camera onto the followed vehicle, in the middle of the map
  /// above the panel, at the zoom it has (at least a town's, when it starts).
  /// A vehicle that has gone off what the map shows ends the following.
  void _follow({bool zoomIn = false}) {
    final legId = _following;
    if (legId == null || !mounted) return;
    final placed = _placed(Theme.of(context))[legId];
    if (placed == null) {
      _stopFollowing();
      return;
    }
    final height = context.size?.height ?? 0;
    final covered = height * (widget.panelExtent?.value ?? 0);
    final zoom = _controller.camera.zoom;
    _controller.move(
      placed.point,
      zoomIn ? math.max(zoom, 13) : zoom,
      offset: Offset(0, -covered / 2),
    );
  }

  /// Whether [event] is the map being moved by hand, which ends following.
  static bool _byHand(MapEvent event) => switch (event.source) {
    MapEventSource.dragStart ||
    MapEventSource.onDrag ||
    MapEventSource.multiFingerGestureStart ||
    MapEventSource.onMultiFinger ||
    MapEventSource.doubleTap ||
    MapEventSource.doubleTapHold ||
    MapEventSource.doubleTapZoomAnimationController ||
    MapEventSource.flingAnimationController ||
    MapEventSource.scrollWheel ||
    MapEventSource.keyboard ||
    MapEventSource.cursorKeyboardRotation => true,
    _ => false,
  };

  /// The view holding [points] with room around them, the part of the map's
  /// [height] the panel covers left out at the bottom.
  ///
  /// The room above and below shrinks with the strip the panel leaves: a
  /// panel pulled up to the top leaves less than two fixed margins, and a view
  /// asked to fit into less than nothing is zoomed out to the whole world.
  CameraFit _fit(List<LatLng> points, double height) {
    final covered = height * (widget.panelExtent?.value ?? 0);
    final margin = math.min(48.0, math.max(0.0, height - covered) / 4);
    return CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: EdgeInsets.fromLTRB(48, margin, 48, covered + margin),
    );
  }

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
    final tracks = ref.watch(tripTracksProvider(widget.tripId)).value;
    _vehicles = widget.clock == null
        ? const []
        : [
            for (final leg in widget.legs)
              ?_Vehicle.of(
                leg,
                legShape: _drawnRoute(tracks?[leg.id] ?? const []),
                runShape: widget.shownRuns.contains(leg.id)
                    ? widget.runShapes[leg.id]
                    : null,
                runShown: widget.shownRuns.contains(leg.id),
                happening: leg.id == widget.happeningItemId,
                legColor: leg.colorValue == null
                    ? accent
                    : Color(leg.colorValue!),
                icon: modes[leg.mode]?.icon ?? kDefaultTransportModeIcon,
              ),
          ];

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
              onMapEvent: (event) {
                if (_byHand(event)) _stopFollowing();
              },
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
              // Over the stops and badges, under where the user is.
              if (widget.clock case final clock?)
                ValueListenableBuilder<DateTime?>(
                  valueListenable: clock,
                  builder: (context, _, _) => MarkerLayer(
                    markers: [
                      for (final MapEntry(key: legId, value: placed) in _placed(
                        theme,
                      ).entries)
                        Marker(
                          point: placed.point,
                          width: 30,
                          height: 30,
                          child: GestureDetector(
                            onTap: () => _startFollowing(legId),
                            child: Semantics(
                              label: l10n.journeyVehicleEstimated,
                              button: true,
                              child: VehicleBadge(
                                icon: placed.icon,
                                color: placed.color,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
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
                  onCenter: (fix) {
                    _stopFollowing();
                    centerOnFix(_controller, fix);
                  },
                ),
                const SizedBox(height: 8),
                const MapStyleButton(),
                // Only while there is a vehicle on the map to follow.
                if (widget.clock case final clock?)
                  ValueListenableBuilder<DateTime?>(
                    valueListenable: clock,
                    builder: (context, _, _) {
                      final placed = _placed(theme);
                      if (placed.isEmpty) return const SizedBox.shrink();
                      // The traveler's own vehicle first, else the first.
                      final target = placed.containsKey(widget.happeningItemId)
                          ? widget.happeningItemId!
                          : placed.keys.first;
                      final on = _following != null;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: MapRoundButton(
                          icon: on
                              ? Icons.navigation
                              : Icons.navigation_outlined,
                          foreground: on ? theme.colorScheme.primary : null,
                          tooltip: l10n.journeyFollowVehicle,
                          onPressed: on
                              ? _stopFollowing
                              : () => _startFollowing(target),
                        ),
                      );
                    },
                  ),
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

/// The route a leg's vehicle is placed on when its run is not shown: the
/// line the map draws for it, the router's where that is drawn (the route the
/// vehicle runs), else a recording. Null when the map draws no line but the
/// chord, on which nothing is placed.
List<LatLng>? _drawnRoute(List<TrackLine> lines) {
  final drawn = drawnTrackIds([
    for (final line in lines)
      (id: line.id, source: line.source, display: line.display),
  ]);
  final shown = [
    for (final line in lines)
      if (drawn.contains(line.id) && line.points.length > 1) line,
  ];
  if (shown.isEmpty) return null;
  return shown
      .firstWhere(
        (line) => line.source == TrackSource.routed,
        orElse: () => shown.first,
      )
      .points;
}

/// A vehicle placed on the map: where, in what color, with which icon.
typedef _Placed = ({LatLng point, Color color, IconData icon});

/// One leg's vehicle, with what placing it needs read off the leg once per
/// build rather than on every tick.
class _Vehicle {
  _Vehicle._({
    required this.legId,
    required this.calls,
    required this.legRoute,
    required this.runRoute,
    required this.runShown,
    required this.happening,
    required this.legColor,
    required this.icon,
  });

  /// The vehicle of [leg], or null when it has nothing to be placed by: a leg
  /// without times, or one the map draws no route for at all.
  static _Vehicle? of(
    ItineraryItem leg, {
    required List<LatLng>? legShape,
    required List<LatLng>? runShape,
    required bool runShown,
    required bool happening,
    required Color legColor,
    required IconData icon,
  }) {
    final calls = legCalls(leg);
    if (calls.isEmpty || (legShape == null && runShape == null)) return null;
    return _Vehicle._(
      legId: leg.id,
      calls: calls,
      // The leg's own line reaches its own stops only.
      legRoute: legShape == null
          ? null
          : VehicleRoute(calls, legShape, covers: (call) => call.part.onLeg),
      runRoute: runShape == null ? null : VehicleRoute(calls, runShape),
      runShown: runShown,
      happening: happening,
      legColor: legColor,
      icon: icon,
    );
  }

  final int legId;
  final List<RunCall> calls;
  final VehicleRoute? legRoute;
  final VehicleRoute? runRoute;
  final bool runShown;
  final bool happening;
  final Color legColor;
  final IconData icon;

  /// Where the vehicle is at [now], or null when it is not on its way or not
  /// on a stretch the map shows a route for. On the leg it is the leg's color,
  /// red while the leg is under way (the traveler is in it); outside, the
  /// quiet grey of the run.
  _Placed? at(DateTime now, ThemeData theme) {
    final progress = progressAt(calls, now);
    if (progress == null) return null;
    final onLeg = progressOnLeg(calls, progress);
    if (!onLeg && !runShown) return null;
    final route = runRoute ?? (onLeg ? legRoute : null);
    if (route == null) return null;
    // Between the stops the route has a place for: a stop stored without its
    // position is passed along the line rather than losing the vehicle.
    final along = progressAt(calls, now, include: route.places);
    final point = along == null ? null : route.pointOf(along);
    if (point == null) return null;
    return (
      point: point,
      color: !onLeg
          ? kJourneyRunColor
          : happening
          ? theme.colorScheme.error
          : legColor,
      icon: icon,
    );
  }
}
