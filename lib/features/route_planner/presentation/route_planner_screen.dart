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
import '../../map/elevation.dart';
import '../../map/finite_camera.dart';
import '../../map/presentation/map_picker_screen.dart' show formatCoordinates;
import '../../map/widgets/elevation_profile_chart.dart';
import '../../map/widgets/map_overlays.dart';
import '../../map/widgets/map_style_button.dart';
import '../../transport_search/presentation/journey_formats.dart';
import '../application/route_engine.dart';
import '../application/tour_planner_controller.dart';
import '../data/saved_tour.dart';
import '../domain/route_profile.dart';
import '../domain/tour.dart';
import '../tour_entries.dart';
import '../tour_geometry.dart';

/// Opens the tour planner for [day] of the trip [tripId], and answers whether
/// a tour was added to it. With [editing] it opens on that saved tour, and
/// saving replaces the entries the tour was read from.
///
/// A full screen route for the reason the point picker is one: a sheet answers
/// a vertical drag by closing, which is the gesture that pans a map.
Future<bool> planRoute(
  BuildContext context, {
  required int tripId,
  required DateTime day,
  required Color color,
  List<LatLng> nearby = const [],
  SavedTour? editing,
}) async {
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => RoutePlannerScreen(
        tripId: tripId,
        day: day,
        color: color,
        nearby: nearby,
        editing: editing,
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
/// car to the trail there. A waypoint is named, marked as a place, moved or
/// removed from the sheet a tap on it opens; a tap on a line opens the section
/// it landed in, to travel it another way or to set a point into it. *Add to
/// day* stays disabled until every section has a line.
class RoutePlannerScreen extends ConsumerStatefulWidget {
  const RoutePlannerScreen({
    super.key,
    required this.tripId,
    required this.day,
    required this.color,
    this.nearby = const [],
    this.editing,
  });

  /// The saved tour being edited, or null for a new one.
  final SavedTour? editing;

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
  /// untimed. A saved tour opens on the time its first entry has.
  late int? _startMinutes = widget.editing?.startMinutes;

  /// The tour this screen plans: its own, so two planners never share one.
  late final _planner = tourPlannerProvider(widget.editing);

  /// What the map opens on: a saved tour's own points, else the trip's.
  late final List<LatLng> _opensOn = widget.editing == null
      ? widget.nearby
      : [
          for (final waypoint in widget.editing!.tour.waypoints)
            waypoint.position,
        ];

  bool _saving = false;

  /// The waypoint the next tap on the map moves, or null when a tap adds one.
  ///
  /// Moved by a tap and not by a drag: the router is asked when a point is
  /// set, and a point being dragged is not set. The state is said in the panel
  /// for as long as it lasts, with the way out beside it.
  int? _moving;

  /// Which line the last tap landed on, filled in by `PolylineLayer` before
  /// the gesture around it reads it, as on the trip map.
  final _lineHits = ValueNotifier<LayerHitResult<int>?>(null);

  @override
  void dispose() {
    _lineHits.dispose();
    super.dispose();
  }

  /// A tap on the map away from any line or waypoint.
  void _onMapTap(LatLng point) {
    final planner = ref.read(_planner.notifier);
    final moving = _moving;
    if (moving == null) {
      planner.addWaypoint(point);
      return;
    }
    planner.moveWaypoint(moving, point);
    setState(() => _moving = null);
  }

  /// A tap on a line: the section it landed in, unless a waypoint is waiting
  /// to be put down, which a line is as good a place for as any.
  Future<void> _onLineTap() async {
    final hit = _lineHits.value;
    if (hit == null || hit.hitValues.isEmpty) return;
    if (_moving != null) {
      _onMapTap(hit.coordinate);
      return;
    }
    final state = ref.read(_planner);
    final run = state.runs[hit.hitValues.first];
    final location = locateOnRun(
      state.tour,
      run,
      _linePoints(state, run),
      hit.coordinate,
    );
    if (location == null) return;
    final edit = await showAppSheet<_SectionEdit>(
      context,
      builder: (_) => _SectionSheet(mode: state.tour.modes[location.section]),
    );
    if (!mounted) return;
    final planner = ref.read(_planner.notifier);
    switch (edit) {
      case null:
        return;
      case _InsertPoint():
        planner.insertWaypoint(location.section, location.point);
      case _SetSectionMode(:final mode):
        planner.setSectionMode(location.section, mode);
    }
  }

  /// The line a run is drawn as: the router's, or straight through its
  /// waypoints while there is none.
  List<LatLng> _linePoints(TourPlannerState state, TourRun run) =>
      state.pathOf(run)?.points ??
      [for (final waypoint in run.waypointsOf(state.tour)) waypoint.position];

  Future<void> _save() async {
    setState(() => _saving = true);
    final ids = await ref
        .read(_planner.notifier)
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
    final planner = ref.read(_planner.notifier);
    final waypoint = ref.read(_planner).tour.waypoints[index];
    final edit = await showAppSheet<_WaypointEdit>(
      context,
      builder: (_) => _WaypointSheet(waypoint: waypoint),
    );
    switch (edit) {
      case null:
        return;
      case _RemoveWaypoint():
        planner.removeWaypoint(index);
      case _MoveWaypoint():
        setState(() => _moving = index);
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
    final state = ref.watch(_planner);
    final planner = ref.read(_planner.notifier);
    final tour = state.tour;
    final entries = state.entries;
    final profile = entries == null ? LaidProfile.empty : tourProfile(entries);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.routePlanTitle),
        actions: [
          TextButton(
            onPressed: entries == null || _saving ? null : _save,
            // Editing replaces what is there, which "add" would not say.
            child: Text(
              widget.editing == null ? l10n.connectionAddToDay : l10n.save,
            ),
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
                    initialCenter: _opensOn.isNotEmpty
                        ? _opensOn.first
                        : const LatLng(0, 0),
                    initialZoom: _opensOn.isNotEmpty ? 12 : 2,
                    initialCameraFit: _opensOn.length > 1
                        ? CameraFit.bounds(
                            bounds: LatLngBounds.fromPoints(_opensOn),
                            padding: const EdgeInsets.all(48),
                          )
                        : null,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onTap: (_, point) => _onMapTap(point),
                  ),
                  children: [
                    ...basemapTileLayers(
                      basemap,
                      overlays,
                      ref.watch(appVersionProvider),
                    ),
                    GestureDetector(
                      onTap: _onLineTap,
                      child: PolylineLayer<int>(
                        hitNotifier: _lineHits,
                        // A fingertip, not the stroke: the trip map's constant.
                        minimumHitbox: kLineHitbox,
                        polylines: [
                          for (final (index, run) in state.runs.indexed)
                            _lineOf(
                              state,
                              run,
                              index,
                              theme.colorScheme.surface,
                            ),
                        ],
                      ),
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
                                number: index + 1,
                                color: widget.color,
                                // The ends are what a tour is read from.
                                large:
                                    index == 0 ||
                                    index == tour.waypoints.length - 1 ||
                                    waypoint.splitsLeg,
                                filled: waypoint.isPlace,
                                moving: index == _moving,
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
            onRetry: planner.retry,
            onPickStartTime: _pickStartTime,
            moving: _moving != null,
            onCancelMove: () => setState(() => _moving = null),
            onShowProfile: profile.isEmpty
                ? null
                : () => showAppSheet<void>(
                    context,
                    builder: (_) => _ProfileSheet(
                      profile: profile,
                      totals: tourTotals(entries!),
                      color: widget.color,
                    ),
                  ),
            onShowPoints: tour.waypoints.isEmpty
                ? null
                : () => showAppSheet<void>(
                    context,
                    builder: (_) =>
                        _PointsSheet(planner: _planner, color: widget.color),
                  ),
          ),
        ],
      ),
    );
  }

  /// One run's line. Dashed like every line that is a proposal and not a
  /// record; a routed run still waiting for its answer is a thin dotted chord,
  /// so it reads as "not known yet" rather than as the way.
  Polyline<int> _lineOf(
    TourPlannerState state,
    TourRun run,
    int index,
    Color casing,
  ) {
    final known = state.pathOf(run) != null || run.mode is StraightMode;
    return Polyline<int>(
      points: _linePoints(state, run),
      hitValue: index,
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

/// A waypoint: its number in the tour on a ringed disc in map colors. The ring
/// is heavier where a leg ends, and the disc is filled where the point is a
/// place of its own.
///
/// Numbered so that a point in the list of waypoints can be found on the map,
/// most of them having no name to go by.
class _WaypointMark extends StatelessWidget {
  const _WaypointMark({
    required this.number,
    required this.color,
    required this.large,
    required this.filled,
    this.moving = false,
  });

  final int number;
  final Color color;
  final bool large;
  final bool filled;

  /// Whether this is the waypoint the next tap moves: drawn dark, so the one
  /// being moved is the one that stands out.
  final bool moving;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF202124);
    const paper = Color(0xFFFFFFFF);
    final fill = moving ? ink : (filled ? color : paper);
    // A trip's accent is the user's choice and may be pale: the number takes
    // whichever of the two reads on it.
    final onFill = ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
        ? paper
        : ink;
    return Center(
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(
            color: moving || filled ? paper : color,
            width: large || moving ? 3 : 2,
          ),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 2)],
        ),
        child: Text(
          '$number',
          style: TextStyle(
            color: onFill,
            fontSize: 11,
            height: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Below the map: the mode the next section takes, what the tour adds up to
/// (or what is in its way), the list of its points and its start time.
class _PlannerPanel extends StatelessWidget {
  const _PlannerPanel({
    required this.state,
    required this.startMinutes,
    required this.onSelectMode,
    required this.onRetry,
    required this.onPickStartTime,
    required this.moving,
    required this.onCancelMove,
    required this.onShowPoints,
    required this.onShowProfile,
  });

  /// Opens the tour's elevation profile. Null while the tour is not complete
  /// or none of its legs has heights.
  final VoidCallback? onShowProfile;

  /// Opens the list of waypoints, where one is removed and their order is
  /// changed. Null while there is none.
  final VoidCallback? onShowPoints;

  /// Whether a waypoint is waiting to be put down. The panel then says that
  /// and how to call it off, with the chips at rest, and keeps its height: a
  /// map that changed size now would shift under the finger about to tap it.
  final bool moving;
  final VoidCallback onCancelMove;

  final TourPlannerState state;
  final int? startMinutes;
  final ValueChanged<SectionMode> onSelectMode;
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
                          onSelected: moving ? null : (_) => onSelectMode(mode),
                        ),
                      ),
                  ],
                ),
              ),
              // Both lines keep their height whatever they say: the panel sits
              // under the map, and a panel that grew by a line would shift the
              // map under a finger on its way to it.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _status(context, l10n, theme),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  state.mode is StraightMode ? l10n.routePlanStraightHint : '',
                  style: muted,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    if (moving)
                      TextButton(
                        onPressed: onCancelMove,
                        child: Text(l10n.cancel),
                      )
                    else ...[
                      IconButton(
                        onPressed: onShowPoints,
                        icon: const Icon(Icons.format_list_numbered),
                        tooltip: l10n.routePlanPoints,
                      ),
                      IconButton(
                        onPressed: onShowProfile,
                        icon: const Icon(Icons.area_chart_outlined),
                        tooltip: l10n.elevationProfile,
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
    if (moving) return Text(l10n.routePlanMoveHint);
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
          Flexible(child: Text(l10n.routePlanRouting)),
        ],
      );
    }
    final entries = state.entries;
    if (entries != null) {
      final totals = tourTotals(entries);
      final style = theme.textTheme.titleMedium?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      );
      // The duration wears a clock and is written "1 h 35 min": beside two
      // figures in meters, the compact "1h 35m" read as a third distance.
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: formatTourTotals(totals)),
            if (totals.duration case final duration?) ...[
              const TextSpan(text: ' · '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(Icons.schedule, size: 18, color: style?.color),
              ),
              TextSpan(
                text:
                    ' ${formatStayDuration(l10n, (duration.inSeconds / 60).ceil())}',
              ),
            ],
          ],
        ),
        style: style,
      );
    }
    return Text(
      state.tour.waypoints.isEmpty
          ? l10n.routePlanHintStart
          : l10n.routePlanHintNext,
    );
  }
}

/// A tour's length and climb on one line: `12 km · ↑ 850 m · ↓ 850 m`, with
/// the climb or the descent left out when the tour has none. The duration is
/// written beside it by the panel, behind a clock.
String formatTourTotals(TourTotals totals) => [
  formatDistance(totals.lengthMeters),
  if (totals.ascentMeters case final ascent?) '↑ ${ascent.round()} m',
  if (totals.descentMeters case final descent?) '↓ ${descent.round()} m',
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

class _MoveWaypoint extends _WaypointEdit {
  const _MoveWaypoint();
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
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).pop(const _MoveWaypoint()),
              icon: const Icon(Icons.open_with, size: 18),
              label: Text(l10n.routeWaypointMove),
            ),
          ),
          const SizedBox(height: 8),
          // A Wrap, so the two part onto two lines where one is too narrow
          // for both.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(const _RemoveWaypoint()),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                child: Text(l10n.routeWaypointRemove),
              ),
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

/// What the section sheet answers with.
sealed class _SectionEdit {
  const _SectionEdit();
}

class _InsertPoint extends _SectionEdit {
  const _InsertPoint();
}

class _SetSectionMode extends _SectionEdit {
  const _SetSectionMode(this.mode);

  final SectionMode mode;
}

/// One section of the tour: how it is traveled, and setting a point into it
/// where the line was tapped.
class _SectionSheet extends StatelessWidget {
  const _SectionSheet({required this.mode});

  /// How the section is traveled now.
  final SectionMode mode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.routeSectionTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final option in kPlannerModes)
                ChoiceChip(
                  avatar: Icon(plannerModeIcon(option), size: 18),
                  label: Text(plannerModeLabel(option, l10n)),
                  selected: option == mode,
                  onSelected: (_) =>
                      Navigator.of(context).pop(_SetSectionMode(option)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(const _InsertPoint()),
            icon: const Icon(Icons.add_location_alt_outlined, size: 18),
            label: Text(l10n.routeSectionAddPoint),
          ),
        ],
      ),
    );
  }
}

/// The waypoints in order, to remove one or to change that order by dragging.
///
/// Watches the tour itself, so a drop or a removal is the change: the list
/// and the map behind it follow at once, and the router is asked about the
/// runs that made. Removing lives here, on each point, rather than as one
/// button taking the last: the unit an act applies to is where it is offered.
class _PointsSheet extends ConsumerWidget {
  const _PointsSheet({required this.planner, required this.color});

  /// The tour of the screen that opened this list.
  final NotifierProvider<TourPlannerController, TourPlannerState> planner;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tour = ref.watch(planner).tour;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(l10n.routePlanPoints, style: theme.textTheme.titleLarge),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            l10n.routePlanPointsHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Flexible(
          child: ReorderableListView(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: 16),
            // newIndex is already adjusted for the removal at oldIndex.
            onReorderItem: ref.read(planner.notifier).reorderWaypoint,
            children: [
              for (final (index, waypoint) in tour.waypoints.indexed)
                ListTile(
                  key: ValueKey('point-$index'),
                  leading: SizedBox.square(
                    dimension: 28,
                    child: _WaypointMark(
                      number: index + 1,
                      color: color,
                      large: true,
                      filled: waypoint.isPlace,
                    ),
                  ),
                  title: Text(
                    waypoint.isNamed
                        ? waypoint.name!.trim()
                        : formatCoordinates(waypoint.position),
                  ),
                  // What a point keeps when it is moved: how it is reached.
                  subtitle: Text(
                    index == 0
                        ? l10n.routePointStart
                        : plannerModeLabel(tour.modes[index - 1], l10n),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: ValueKey('point-remove-$index'),
                        icon: const Icon(Icons.delete_outline),
                        color: theme.colorScheme.error,
                        tooltip: l10n.routeWaypointRemove,
                        onPressed: () {
                          ref.read(planner.notifier).removeWaypoint(index);
                          // An empty list has nothing left to offer.
                          if (tour.waypoints.length == 1) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                      ReorderableDragStartListener(
                        key: ValueKey('point-handle-$index'),
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The tour's heights along its length, with what they add up to above.
class _ProfileSheet extends StatelessWidget {
  const _ProfileSheet({
    required this.profile,
    required this.totals,
    required this.color,
  });

  final LaidProfile profile;
  final TourTotals totals;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.elevationProfile, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            formatTourTotals(totals),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ElevationProfileChart(profile: profile, color: color, height: 160),
        ],
      ),
    );
  }
}
