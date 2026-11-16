import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/providers.dart';
import '../data/saved_tour.dart';
import '../data/tour_mapper.dart';
import '../domain/route_profile.dart';
import '../domain/routed_path.dart';
import '../domain/tour.dart';
import '../tour_entries.dart';
import 'route_engine.dart';
import 'route_planner_providers.dart';

/// A tour while it is being planned: the waypoints set so far, the mode the
/// next section will take, and what the router has answered.
class TourPlannerState {
  const TourPlannerState({
    this.tour = const Tour.empty(),
    this.mode = const RoutedMode(RouteProfile.foot),
    this.paths = const {},
    this.loading = const {},
    this.failures = const {},
  });

  final Tour tour;

  /// How the section to the **next** waypoint is traveled. Choosing another
  /// changes nothing already planned.
  final SectionMode mode;

  /// The router's answers, by [runKey]. An answer stays after its run is gone,
  /// so taking a waypoint back and setting it again asks nothing twice.
  final Map<String, RoutedPath> paths;

  /// The runs asked about and not answered yet, by [runKey].
  final Set<String> loading;

  /// The runs the router refused, by [runKey]. Kept until [TourPlannerController
  /// .retry], so a refusal is not asked again by itself.
  final Map<String, RouteEngineFailure> failures;

  List<TourRun> get runs => tourRuns(tour);

  /// The router's answer for [run], or null while there is none. Always null
  /// for a straight run, which has no answer to wait for.
  RoutedPath? pathOf(TourRun run) => paths[runKey(tour, run)];

  /// The tour as the entries it would be saved as, or null while it has fewer
  /// than two waypoints or a routed run is unanswered.
  List<TourEntry>? get entries {
    if (tour.waypoints.length < 2) return null;
    final answered = <int, RoutedPath>{};
    for (final (index, run) in runs.indexed) {
      final path = pathOf(run);
      if (path != null) answered[index] = path;
    }
    return tourEntries(tour, answered);
  }

  bool get routing => runs.any((run) => loading.contains(runKey(tour, run)));

  /// Why the first refused run of the tour was refused, or null when none was.
  RouteEngineFailure? get failure {
    for (final run in runs) {
      final failure = failures[runKey(tour, run)];
      if (failure != null) return failure;
    }
    return null;
  }

  TourPlannerState copyWith({
    Tour? tour,
    SectionMode? mode,
    Map<String, RoutedPath>? paths,
    Set<String>? loading,
    Map<String, RouteEngineFailure>? failures,
  }) => TourPlannerState(
    tour: tour ?? this.tour,
    mode: mode ?? this.mode,
    paths: paths ?? this.paths,
    loading: loading ?? this.loading,
    failures: failures ?? this.failures,
  );
}

/// Holds a tour being planned and asks the router for each run once.
///
/// The router is somebody else's server: a run is asked about when a waypoint
/// is set, never on a timer and never again after a refusal unless [retry] is
/// pressed, and one request covers a whole run.
class TourPlannerController extends Notifier<TourPlannerState> {
  TourPlannerController(this.saved);

  /// The saved tour the planner was opened on, or null for a new one.
  final SavedTour? saved;

  @override
  TourPlannerState build() {
    final saved = this.saved;
    if (saved == null) return const TourPlannerState();
    // A leg whose stored line was removed since has no answer among the saved
    // ones and is asked about once the state stands; the rest ask nothing.
    Future.microtask(() {
      if (ref.mounted) _route();
    });
    return TourPlannerState(
      tour: saved.tour,
      // The next section goes on as the tour ended.
      mode: saved.tour.modes.lastOrNull ?? const RoutedMode(RouteProfile.foot),
      paths: saved.paths,
    );
  }

  void selectMode(SectionMode mode) => state = state.copyWith(mode: mode);

  /// Adds a waypoint at the end, reached by the selected mode.
  void addWaypoint(LatLng position) =>
      _setTour(state.tour.extendedBy(TourWaypoint(position), state.mode));

  void updateWaypoint(int index, TourWaypoint waypoint) =>
      _setTour(state.tour.withWaypoint(index, waypoint));

  void removeWaypoint(int index) => _setTour(state.tour.without(index));

  /// Puts the waypoint at [index] somewhere else, keeping its name and whether
  /// it is a place.
  void moveWaypoint(int index, LatLng position) {
    final waypoint = state.tour.waypoints[index];
    updateWaypoint(
      index,
      TourWaypoint(position, name: waypoint.name, isPlace: waypoint.isPlace),
    );
  }

  /// Changes the order of the waypoints; see [Tour.reordered] for what becomes
  /// of the modes.
  void reorderWaypoint(int oldIndex, int newIndex) =>
      _setTour(state.tour.reordered(oldIndex, newIndex));

  /// Travels the section at [section] by [mode] instead.
  void setSectionMode(int section, SectionMode mode) =>
      _setTour(state.tour.withMode(section, mode));

  /// Sets a waypoint into the section at [section], at [position] on its line.
  ///
  /// A point on the way the router found does not change that way, so the run's
  /// answer is kept for the run it becomes and the router is not asked about a
  /// line it has just given. Moving or naming the new point asks as usual.
  void insertWaypoint(int section, LatLng position) {
    final before = state.tour;
    final after = before.withInserted(section, TourWaypoint(position));
    final run = state.runs.firstWhere(
      (run) => run.first <= section && section < run.last,
    );
    final path = state.pathOf(run);
    final grown = tourRuns(after).firstWhere((r) => r.first == run.first);
    final key = runKey(after, grown);
    if (path != null && key != null) {
      state = state.copyWith(paths: {...state.paths, key: path});
    }
    _setTour(after);
  }

  /// Asks again about every run the router refused.
  void retry() {
    state = state.copyWith(failures: const {});
    _route();
  }

  void _setTour(Tour tour) {
    state = state.copyWith(tour: tour);
    _route();
  }

  void _route() {
    final tour = state.tour;
    for (final run in state.runs) {
      final mode = run.mode;
      final key = runKey(tour, run);
      if (mode is! RoutedMode || key == null) continue;
      if (state.paths.containsKey(key) ||
          state.loading.contains(key) ||
          state.failures.containsKey(key)) {
        continue;
      }
      state = state.copyWith(loading: {...state.loading, key});
      unawaited(
        _ask(key, [
          for (final waypoint in run.waypointsOf(tour)) waypoint.position,
        ], mode.profile),
      );
    }
  }

  Future<void> _ask(
    String key,
    List<LatLng> waypoints,
    RouteProfile profile,
  ) async {
    RoutedPath? path;
    RouteEngineFailure? failure;
    try {
      path = await ref
          .read(routeEngineProvider)
          .route(waypoints: waypoints, profile: profile);
    } on RouteEngineException catch (e) {
      failure = e.failure;
    }
    if (!ref.mounted) return;
    state = state.copyWith(
      loading: {...state.loading}..remove(key),
      paths: path == null ? null : {...state.paths, key: path},
      failures: failure == null ? null : {...state.failures, key: failure},
    );
  }

  /// Writes the tour into [tripId] on [date] and returns the new rows' ids, or
  /// null when the tour is not complete (see [TourPlannerState.entries]).
  ///
  /// A tour opened from its entries **replaces** them, the way a connection
  /// searched again replaces its legs (`replaceJourneyLegs`): the new entries
  /// take the slot and the group of the old ones, and a cost or a file hung on
  /// an old entry is kept. What an old entry held of its own (a note, actual
  /// times, a recording) goes with it.
  ///
  /// The modes are read once from the repository, not from the autoDispose
  /// provider, for the reason `TransportSearchController._modes` gives.
  Future<List<int>?> save({
    required int tripId,
    required DateTime date,
    int? startMinutes,
  }) async {
    final entries = state.entries;
    if (entries == null) return null;
    final repository = ref.read(repositoryProvider);
    final saved = this.saved;
    final mapped = tourToItems(
      entries,
      tripId: tripId,
      date: date,
      resolveMode: builtinModeResolver(await repository.transportModes()),
      tourId: saved?.tourId ?? _newTourId(),
      startMinutes: startMinutes,
    );
    if (saved != null) {
      return repository.replaceJourneyLegs(
        tripId,
        oldLegIds: saved.itemIds,
        legs: mapped.items,
        groupId: saved.groupId,
        shapes: mapped.shapes,
        elevations: mapped.elevations,
      );
    }
    return repository.insertJourney(
      tripId,
      mapped.items,
      shapes: mapped.shapes,
      elevations: mapped.elevations,
    );
  }

  /// A mark no other tour of the trip carries: the moment it was saved, which
  /// is all it has to be told apart by.
  static String _newTourId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);
}

/// The tour being planned on the planner screen, opened on a saved tour or,
/// with null, on an empty one. Disposed with the screen: a tour not saved is
/// not kept.
final tourPlannerProvider = NotifierProvider.autoDispose
    .family<TourPlannerController, TourPlannerState, SavedTour?>(
      TourPlannerController.new,
    );
