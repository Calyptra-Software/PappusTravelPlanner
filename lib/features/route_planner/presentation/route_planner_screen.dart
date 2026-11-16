import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/date_format.dart';
import '../../../core/format/distance_format.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../../map/basemap_provider.dart';
import '../../map/finite_camera.dart';
import '../../map/widgets/map_overlays.dart';
import '../../map/widgets/map_style_button.dart';
import '../application/route_engine.dart';
import '../application/tour_planner_controller.dart';
import '../domain/route_profile.dart';
import '../domain/tour.dart';
import '../tour_entries.dart';

/// Opens the tour planner for [day] of the trip [tripId], and answers whether
/// a tour was added to it.
///
/// A full screen route for the reason the point picker is one: a sheet answers
/// a vertical drag by closing, which is the gesture that pans a map.
Future<bool> planRoute(
  BuildContext context, {
  required int tripId,
  required DateTime day,
  required Color color,
  List<LatLng> nearby = const [],
}) async {
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => RoutePlannerScreen(
        tripId: tripId,
        day: day,
        color: color,
        nearby: nearby,
      ),
    ),
  );
  return saved ?? false;
}

/// The modes a section can be given, in the order the chips offer them.
const List<SectionMode> kPlannerModes = [
  RoutedMode(RouteProfile.foot),
  RoutedMode(RouteProfile.bike),
  RoutedMode(RouteProfile.roadBike),
  RoutedMode(RouteProfile.gravelBike),
  RoutedMode(RouteProfile.mountainBike),
  RoutedMode(RouteProfile.car),
  // No router knows pistes and lifts, so a ski section is drawn by hand.
  StraightMode(TransportMode.ski),
  StraightMode(),
];

/// Planning a tour by tapping the map.
///
/// A tap sets the next waypoint, reached by the mode selected below the map;
/// selecting another mode before a tap is what makes the tour change from the
/// car to the trail there. A waypoint is named, marked as a place or removed
/// from the sheet a tap on it opens. *Add to day* stays disabled until every
/// section has a line.
class RoutePlannerScreen extends ConsumerStatefulWidget {
  const RoutePlannerScreen({
    super.key,
    required this.tripId,
    required this.day,
    required this.color,
    this.nearby = const [],
  });

  final int tripId;
  final DateTime day;

  /// The trip's accent, which its lines are drawn in on every other map.
  final Color color;

  /// The trip's positions, to open the map where the trip is.
  final List<LatLng> nearby;

  @override
  ConsumerState<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends ConsumerState<RoutePlannerScreen> {
  final MapController _controller = MapController();

  /// When the tour starts, in minutes since midnight; null leaves its entries
  /// untimed.
  int? _startMinutes;

  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final ids = await ref
        .read(tourPlannerProvider.notifier)
        .save(
          tripId: widget.tripId,
          date: widget.day,
          startMinutes: _startMinutes,
        );
    if (!mounted) return;
    if (ids == null) {
      setState(() => _saving = false);
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _pickStartTime() async {
    final current = _startMinutes ?? 8 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null || !mounted) return;
    setState(() => _startMinutes = picked.hour * 60 + picked.minute);
  }

  Future<void> _editWaypoint(int index) async {
    final planner = ref.read(tourPlannerProvider.notifier);
    final waypoint = ref.read(tourPlannerProvider).tour.waypoints[index];
    final edit = await showAppSheet<_WaypointEdit>(
      context,
      builder: (_) => _WaypointSheet(waypoint: waypoint),
    );
    switch (edit) {
      case null:
        return;
      case _RemoveWaypoint():
        planner.removeWaypoint(index);
      case _ChangeWaypoint(:final waypoint):
        planner.updateWaypoint(index, waypoint);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final basemap = ref.watch(basemapProvider);
    final overlays = ref.watch(mapOverlaysProvider);
    final state = ref.watch(tourPlannerProvider);
    final planner = ref.read(tourPlannerProvider.notifier);
    final tour = state.tour;
    final entries = state.entries;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.routePlanTitle),
        actions: [
          TextButton(
            onPressed: entries == null || _saving ? null : _save,
            child: Text(l10n.connectionAddToDay),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    minZoom: kMinMapZoom,
                    // See finite_camera.dart: a pinch can hand over a NaN.
                    cameraConstraint: const FiniteCamera(),
                    maxZoom: maxZoomOf(basemap),
                    initialCenter: widget.nearby.isNotEmpty
                        ? widget.nearby.first
                        : const LatLng(0, 0),
                    initialZoom: widget.nearby.isNotEmpty ? 12 : 2,
                    initialCameraFit: widget.nearby.length > 1
                        ? CameraFit.bounds(
                            bounds: LatLngBounds.fromPoints(widget.nearby),
                            padding: const EdgeInsets.all(48),
                          )
                        : null,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onTap: (_, point) => planner.addWaypoint(point),
                  ),
                  children: [
                    ...basemapTileLayers(
                      basemap,
                      overlays,
                      ref.watch(appVersionProvider),
                    ),
                    PolylineLayer(
                      polylines: [
                        for (final run in state.runs)
                          _lineOf(state, run, theme.colorScheme.surface),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        for (final (index, waypoint) in tour.waypoints.indexed)
                          Marker(
                            point: waypoint.position,
                            width: 44,
                            height: 44,
                            child: GestureDetector(
                              key: ValueKey('waypoint-$index'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _editWaypoint(index),
                              child: _WaypointMark(
                                color: widget.color,
                                // The ends are what a tour is read from.
                                large:
                                    index == 0 ||
                                    index == tour.waypoints.length - 1 ||
                                    waypoint.splitsLeg,
                                filled: waypoint.isPlace,
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
                  child: Column(
                    children: [
                      MapZoomButtons(
                        controller: _controller,
                        basemap: basemap,
                        zoomInTooltip: l10n.mapZoomIn,
                        zoomOutTooltip: l10n.mapZoomOut,
                      ),
                      const SizedBox(height: 8),
                      const MapStyleButton(),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: MapAttributionBar(
                    basemap: basemap,
                    overlays: overlays,
                  ),
                ),
              ],
            ),
          ),
          _PlannerPanel(
            state: state,
            startMinutes: _startMinutes,
            onSelectMode: planner.selectMode,
            onUndo: tour.waypoints.isEmpty
                ? null
                : () => planner.removeWaypoint(tour.waypoints.length - 1),
            onRetry: planner.retry,
            onPickStartTime: _pickStartTime,
          ),
        ],
      ),
    );
  }

  /// One run's line. Dashed like every line that is a proposal and not a
  /// record; a routed run still waiting for its answer is a thin dotted chord,
  /// so it reads as "not known yet" rather than as the way.
  Polyline _lineOf(TourPlannerState state, TourRun run, Color casing) {
    final path = state.pathOf(run);
    final known = path != null || run.mode is StraightMode;
    return Polyline(
      points:
          path?.points ??
          [
            for (final waypoint in run.waypointsOf(state.tour))
              waypoint.position,
          ],
      strokeWidth: known ? 3.5 : 2,
      pattern: known
          ? StrokePattern.dashed(segments: const [7, 5])
          : const StrokePattern.dotted(),
      color: known ? widget.color : const Color(0xFF5F6368),
      borderStrokeWidth: known ? 2 : 0,
      borderColor: casing,
    );
  }
}

/// A waypoint on the map: a ringed dot in map colors, larger where a leg ends
/// and filled where the point is a place of its own.
class _WaypointMark extends StatelessWidget {
  const _WaypointMark({
    required this.color,
    required this.large,
    required this.filled,
  });

  final Color color;
  final bool large;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final size = large ? 18.0 : 12.0;
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: filled ? color : const Color(0xFFFFFFFF),
          shape: BoxShape.circle,
          border: Border.all(
            color: filled ? const Color(0xFFFFFFFF) : color,
            width: large ? 4 : 3,
          ),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 2)],
        ),
      ),
    );
  }
}

/// Below the map: the mode the next section takes, what the tour adds up to
/// (or what is in its way), and the two acts on the tour as a whole.
class _PlannerPanel extends StatelessWidget {
  const _PlannerPanel({
    required this.state,
    required this.startMinutes,
    required this.onSelectMode,
    required this.onUndo,
    required this.onRetry,
    required this.onPickStartTime,
  });

  final TourPlannerState state;
  final int? startMinutes;
  final ValueChanged<SectionMode> onSelectMode;
  final VoidCallback? onUndo;
  final VoidCallback onRetry;
  final VoidCallback onPickStartTime;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    for (final mode in kPlannerModes)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Icon(plannerModeIcon(mode), size: 18),
                          label: Text(plannerModeLabel(mode, l10n)),
                          selected: mode == state.mode,
                          onSelected: (_) => onSelectMode(mode),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _status(context, l10n, theme),
              ),
              if (state.mode is StraightMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                  child: Text(l10n.routePlanStraightHint, style: muted),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: onUndo,
                      icon: const Icon(Icons.undo, size: 18),
                      label: Text(l10n.routePlanUndo),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: onPickStartTime,
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text(
                        startMinutes == null
                            ? l10n.routePlanStartTime
                            : l10n.routePlanStartsAt(
                                formatMinutes(startMinutes),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One line saying where the tour stands: refused, being routed, complete
  /// with its totals, or what to do next.
  Widget _status(BuildContext context, AppLocalizations l10n, ThemeData theme) {
    final failure = state.failure;
    if (failure != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              routeFailureText(failure, l10n),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(l10n.connectionRetry)),
        ],
      );
    }
    if (state.routing) {
      return Row(
        children: [
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(l10n.routePlanRouting),
        ],
      );
    }
    final entries = state.entries;
    if (entries != null) {
      return Text(
        formatTourTotals(tourTotals(entries)),
        style: theme.textTheme.titleMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }
    return Text(
      state.tour.waypoints.isEmpty
          ? l10n.routePlanHintStart
          : l10n.routePlanHintNext,
    );
  }
}

/// A tour's totals on one line: `12 km · ↑ 850 m · ↓ 850 m · 4h 10m`, with
/// each figure left out when the tour has none.
String formatTourTotals(TourTotals totals) => [
  formatDistance(totals.lengthMeters),
  if (totals.ascentMeters case final ascent?) '↑ ${ascent.round()} m',
  if (totals.descentMeters case final descent?) '↓ ${descent.round()} m',
  if (totals.duration case final duration?)
    formatDurationHm((duration.inSeconds / 60).ceil()),
].join(' · ');

String plannerModeLabel(SectionMode mode, AppLocalizations l10n) =>
    switch (mode) {
      RoutedMode(:final profile) => switch (profile) {
        RouteProfile.foot => l10n.routeProfileFoot,
        RouteProfile.bike => l10n.routeProfileBike,
        RouteProfile.roadBike => l10n.routeProfileRoadBike,
        RouteProfile.gravelBike => l10n.routeProfileGravelBike,
        RouteProfile.mountainBike => l10n.routeProfileMountainBike,
        RouteProfile.car => l10n.routeProfileCar,
      },
      StraightMode(transportMode: TransportMode.ski) => l10n.routeModeSki,
      StraightMode() => l10n.routeModeStraight,
    };

IconData plannerModeIcon(SectionMode mode) => switch (mode) {
  RoutedMode(:final profile) => switch (profile) {
    RouteProfile.foot => Icons.directions_walk,
    RouteProfile.bike => Icons.directions_bike,
    RouteProfile.roadBike => Icons.pedal_bike,
    RouteProfile.gravelBike => Icons.pedal_bike,
    RouteProfile.mountainBike => Icons.terrain,
    RouteProfile.car => Icons.directions_car,
  },
  StraightMode(transportMode: TransportMode.ski) => Icons.downhill_skiing,
  StraightMode() => Icons.show_chart,
};

String routeFailureText(RouteEngineFailure failure, AppLocalizations l10n) =>
    switch (failure) {
      RouteEngineFailure.unreachable => l10n.routeFailureUnreachable,
      RouteEngineFailure.noRoute => l10n.routeFailureNoRoute,
      RouteEngineFailure.failed => l10n.routeFailureFailed,
    };

/// What the waypoint sheet answers with.
sealed class _WaypointEdit {
  const _WaypointEdit();
}

class _RemoveWaypoint extends _WaypointEdit {
  const _RemoveWaypoint();
}

class _ChangeWaypoint extends _WaypointEdit {
  const _ChangeWaypoint(this.waypoint);

  final TourWaypoint waypoint;
}

/// One waypoint's name, whether it is a place of its own, and its removal.
class _WaypointSheet extends StatefulWidget {
  const _WaypointSheet({required this.waypoint});

  final TourWaypoint waypoint;

  @override
  State<_WaypointSheet> createState() => _WaypointSheetState();
}

class _WaypointSheetState extends State<_WaypointSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.waypoint.name,
  );
  late bool _isPlace = widget.waypoint.isPlace;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.routeWaypointTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.routeWaypointName),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.routeWaypointAsPlace),
            value: _isPlace,
            onChanged: (value) => setState(() => _isPlace = value),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(const _RemoveWaypoint()),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                child: Text(l10n.routeWaypointRemove),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  final name = _name.text.trim();
                  Navigator.of(context).pop(
                    _ChangeWaypoint(
                      TourWaypoint(
                        widget.waypoint.position,
                        name: name.isEmpty ? null : name,
                        isPlace: _isPlace,
                      ),
                    ),
                  );
                },
                child: Text(l10n.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
