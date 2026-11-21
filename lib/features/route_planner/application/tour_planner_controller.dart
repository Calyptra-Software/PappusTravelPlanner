import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/providers.dart';
import '../data/saved_tour.dart';
import '../data/tour_mapper.dart';
import '../domain/piste_difficulty.dart';
import '../domain/piste_note.dart';
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

  /// The router's answers, by [sectionKey], and by [runKey] where a whole run
  /// was answered at once (a saved tour's stored line). An answer stays after
  /// its section is gone, so taking a waypoint back and setting it again asks
  /// nothing twice.
  final Map<String, RoutedPath> paths;

  /// The sections asked about and not answered yet, by [sectionKey].
  final Set<String> loading;

  /// The sections the router refused, by [sectionKey]. Kept until
  /// [TourPlannerController.retry], so a refusal is not asked again by itself.
  final Map<String, RouteEngineFailure> failures;

  List<TourRun> get runs => tourRuns(tour);

  /// The keys of [run]'s sections, in order; empty for a straight run.
  List<String> sectionKeysOf(TourRun run) => [
    for (var section = run.first; section < run.last; section++)
      ?sectionKey(tour, section),
  ];

  /// The router's answer for [run]: the run's own, or its sections' joined
  /// (`joinPaths`), or null while one of them has none. Always null for a
  /// straight run, which has no answer to wait for.
  RoutedPath? pathOf(TourRun run) {
    final key = runKey(tour, run);
    if (key == null) return null;
    final joined = _joined[this] ??= {};
    if (joined.containsKey(key)) return joined[key];
    final whole = paths[key];
    if (whole != null) return joined[key] = whole;
    final parts = <RoutedPath>[];
    for (final section in sectionKeysOf(run)) {
      final path = paths[section];
      if (path == null) return joined[key] = null;
      parts.add(path);
    }
    return joined[key] = joinPaths(parts);
  }

  /// The answers already joined, per state: the map, the panel and the
  /// entries all ask for the same run within one frame.
  static final _joined = Expando<Map<String, RoutedPath?>>();

  /// [run]'s line as far as it is known: its answer, or for each section the
  /// answer it has, or the straight line between its two waypoints while it
  /// has none. With whether each piece is an answer, for drawing them apart.
  List<({List<LatLng> points, bool known})> linesOf(TourRun run) {
    final whole = pathOf(run);
    if (whole != null || run.mode is StraightMode) {
      return [
        (
          points:
              whole?.points ??
              [for (final waypoint in run.waypointsOf(tour)) waypoint.position],
          known: true,
        ),
      ];
    }
    return [
      for (var section = run.first; section < run.last; section++)
        switch (paths[sectionKey(tour, section)]) {
          final path? => (points: path.points, known: true),
          null => (
            points: [
              tour.waypoints[section].position,
              tour.waypoints[section + 1].position,
            ],
            known: false,
          ),
        },
    ];
  }

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

  bool get routing => runs.any(_waiting);

  /// Whether a ski run is among those being routed: the wait may then be for
  /// a ski area's map data, which takes longer than a route.
  bool get routingSki =>
      runs.any((run) => run.mode is SkiMode && _waiting(run));

  /// Whether [run] has no answer yet and one of its sections is asked about.
  bool _waiting(TourRun run) =>
      pathOf(run) == null && sectionKeysOf(run).any(loading.contains);

  /// The hardest piste the tour's ski runs take: the selected mode's, else
  /// the tour's first ski section's, else [PisteDifficulty.standard].
  PisteDifficulty get skiDifficulty {
    if (mode case SkiMode(:final maxDifficulty)) return maxDifficulty;
    for (final mode in tour.modes) {
      if (mode case SkiMode(:final maxDifficulty)) return maxDifficulty;
    }
    return PisteDifficulty.standard;
  }

  /// Why the first refused section of the tour was refused, or null when none
  /// was.
  RouteEngineFailure? get failure {
    for (final run in runs) {
      if (pathOf(run) != null) continue;
      for (final key in sectionKeysOf(run)) {
        final failure = failures[key];
        if (failure != null) return failure;
      }
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

/// Holds a tour being planned and asks the router for each section once.
///
/// The router is somebody else's server: a section is asked about when a
/// waypoint is set, never on a timer and never again after a refusal unless
/// [retry] is pressed.
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
      TourWaypoint(
        position,
        name: waypoint.name,
        isPlace: waypoint.isPlace,
        key: waypoint.key,
      ),
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

  /// Routes every ski run of the tour, and the next one, with no piste harder
  /// than [difficulty]. For the whole tour, not one section: it is one
  /// skier's ability, and a grade that changed only the next section would
  /// look as if it changed nothing.
  void setSkiDifficulty(PisteDifficulty difficulty) {
    final ski = SkiMode(difficulty);
    final tour = state.tour;
    state = state.copyWith(mode: state.mode is SkiMode ? ski : null);
    _setTour(
      Tour(
        waypoints: tour.waypoints,
        modes: [for (final mode in tour.modes) mode is SkiMode ? ski : mode],
      ),
    );
  }

  /// Loads the map data of the tour's ski runs afresh and routes them again:
  /// for pistes that changed since the area was loaded.
  Future<void> reloadSki() async {
    await ref.read(skiRouterProvider).forget();
    if (!ref.mounted) return;
    bool isSki(String key) => key.startsWith('ski:');
    state = state.copyWith(
      paths: {...state.paths}..removeWhere((key, _) => isSki(key)),
      failures: {...state.failures}..removeWhere((key, _) => isSki(key)),
    );
    _route();
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

  /// Asks about each section of a run without an answer that is neither
  /// answered, asked nor refused. A section at a time, not the run: a point
  /// set at the end asks only about the section it adds, and the run's line
  /// up to it stays as it was.
  void _route() {
    final tour = state.tour;
    for (final run in state.runs) {
      if (state.pathOf(run) != null) continue;
      for (var section = run.first; section < run.last; section++) {
        final key = sectionKey(tour, section);
        if (key == null ||
            state.paths.containsKey(key) ||
            state.loading.contains(key) ||
            state.failures.containsKey(key)) {
          continue;
        }
        final waypoints = [
          tour.waypoints[section].position,
          tour.waypoints[section + 1].position,
        ];
        final Future<RoutedPath> Function()? ask = switch (run.mode) {
          RoutedMode(:final profile) =>
            () => ref
                .read(routeEngineProvider)
                .route(waypoints: waypoints, profile: profile),
          SkiMode(:final maxDifficulty) =>
            () => ref
                .read(skiRouterProvider)
                .route(waypoints: waypoints, maxDifficulty: maxDifficulty),
          // Drawn by hand: nothing to ask, and no key either.
          StraightMode() => null,
        };
        if (ask == null) continue;
        state = state.copyWith(loading: {...state.loading, key});
        unawaited(_ask(key, ask));
      }
    }
  }

  Future<void> _ask(String key, Future<RoutedPath> Function() ask) async {
    RoutedPath? path;
    RouteEngineFailure? failure;
    try {
      path = await ask();
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
  /// A tour opened from its entries is written back over them
  /// (`TripRepository.rewriteRoute`): an entry that stayed the same entry
  /// (`keptEntryIds`) keeps its row and with it its notes, actual times,
  /// files, costs and recordings; only its plan is rewritten, and its planned
  /// times only when the tour is given a start time. A new entry is added, and
  /// one the tour no longer has is removed, its costs and files moved to the
  /// tour's group.
  ///
  /// [pisteColor] names the colors a new descent's notes give its pistes; an
  /// entry kept keeps the notes it has, whatever they say.
  ///
  /// The modes are read once from the repository, not from the autoDispose
  /// provider, for the reason `TransportSearchController._modes` gives.
  Future<List<int>?> save({
    required int tripId,
    required DateTime date,
    int? startMinutes,
    int? alternativeId,
    PisteColorName? pisteColor,
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
      pisteColor: pisteColor,
    );
    if (saved != null) {
      final kept = keptEntryIds(entries, saved);
      return repository.rewriteRoute(
        tripId,
        oldIds: saved.itemIds,
        entries: [
          for (final (index, row) in mapped.items.indexed)
            (
              keepId: kept[index],
              // An entry kept keeps its notes, which are the user's once
              // written; and without a start time the tour says nothing
              // about when, so it keeps the times it has too.
              row: switch (kept[index]) {
                null => row,
                _ when startMinutes == null => row.copyWith(
                  notes: const Value.absent(),
                  startMinutes: const Value.absent(),
                  endMinutes: const Value.absent(),
                  endDayOffset: const Value.absent(),
                ),
                _ => row.copyWith(notes: const Value.absent()),
              },
            ),
        ],
        groupId: saved.groupId,
        shapes: mapped.shapes,
        elevations: mapped.elevations,
        sources: mapped.sources,
      );
    }
    return repository.insertJourney(
      tripId,
      mapped.items,
      // A new tour planned from an option's add row goes into that option.
      alternativeId: alternativeId,
      shapes: mapped.shapes,
      elevations: mapped.elevations,
      sources: mapped.sources,
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
