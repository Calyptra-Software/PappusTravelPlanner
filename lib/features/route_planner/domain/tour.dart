import 'package:latlong2/latlong.dart';

import '../../../data/database/tables.dart';
import 'route_profile.dart';

/// One point a tour is led through. Pointed at by the user, never derived:
/// where a tour changes from the car to the trail is a waypoint somebody set.
class TourWaypoint {
  const TourWaypoint(this.position, {this.name, this.isPlace = false});

  final LatLng position;

  /// What the point is called, when it was given a name. A named waypoint ends
  /// one leg and starts the next, since a leg can only carry names at its ends.
  final String? name;

  /// Whether the point becomes an entry of its own in the plan (a summit, a
  /// hut), beside ending the leg that reaches it.
  final bool isPlace;

  bool get isNamed => name != null && name!.trim().isNotEmpty;

  /// Whether a leg has to end here.
  bool get splitsLeg => isNamed || isPlace;
}

/// How one section of a tour, from a waypoint to the next, is traveled.
sealed class SectionMode {
  const SectionMode();

  /// The built-in mode the section is filed under in the itinerary; null for a
  /// hand-drawn line nobody gave one.
  TransportMode? get transportMode;
}

/// Over the street and path network, along the way a router finds.
class RoutedMode extends SectionMode {
  const RoutedMode(this.profile);

  final RouteProfile profile;

  @override
  TransportMode get transportMode => profile.transportMode;

  @override
  bool operator ==(Object other) =>
      other is RoutedMode && other.profile == profile;

  @override
  int get hashCode => profile.hashCode;
}

/// Straight from waypoint to waypoint, drawn by hand: a ski tour off the
/// paths, a glacier, a boat. No router is asked.
class StraightMode extends SectionMode {
  const StraightMode([this.transportMode]);

  @override
  final TransportMode? transportMode;

  @override
  bool operator ==(Object other) =>
      other is StraightMode && other.transportMode == transportMode;

  @override
  int get hashCode => Object.hash(StraightMode, transportMode);
}

/// A tour being planned: waypoints in order, and how each section between two
/// of them is traveled. A change of mode at a waypoint is what makes a tour
/// multimodal.
class Tour {
  Tour({required this.waypoints, required this.modes})
    : assert(
        modes.length == (waypoints.isEmpty ? 0 : waypoints.length - 1),
        'one mode per section',
      );

  const Tour.empty() : waypoints = const [], modes = const [];

  final List<TourWaypoint> waypoints;

  /// `modes[i]` is how the section from `waypoints[i]` to `waypoints[i + 1]` is
  /// traveled.
  final List<SectionMode> modes;

  /// The tour with [waypoint] added at its end, reached by [mode]. The first
  /// waypoint is reached by nothing, so its [mode] is ignored.
  Tour extendedBy(TourWaypoint waypoint, SectionMode mode) => Tour(
    waypoints: [...waypoints, waypoint],
    modes: [...modes, if (waypoints.isNotEmpty) mode],
  );

  /// The tour with the waypoint at [index] exchanged for [waypoint]: moved,
  /// named, or marked as a place.
  Tour withWaypoint(int index, TourWaypoint waypoint) =>
      Tour(waypoints: [...waypoints]..[index] = waypoint, modes: modes);

  /// The tour with [waypoint] set into the section at [section], between the
  /// two waypoints that section joins. Both halves keep the section's mode.
  Tour withInserted(int section, TourWaypoint waypoint) => Tour(
    waypoints: [...waypoints]..insert(section + 1, waypoint),
    modes: [...modes]..insert(section, modes[section]),
  );

  /// The tour with the section at [section] traveled by [mode] instead.
  Tour withMode(int section, SectionMode mode) =>
      Tour(waypoints: waypoints, modes: [...modes]..[section] = mode);

  /// The tour with the waypoint at [oldIndex] taken out and put back at
  /// [newIndex], counted in the list without it.
  ///
  /// A waypoint keeps the mode it is **reached by**: the summit walked up to is
  /// still walked up to wherever it comes in the tour. The first waypoint is
  /// reached by nothing, so it carries the mode it is left by, which is what it
  /// is reached by once something stands before it; whichever waypoint ends up
  /// first has its own set aside.
  Tour reordered(int oldIndex, int newIndex) {
    if (waypoints.length < 2 || oldIndex == newIndex) return this;
    final reachedBy = [modes.first, ...modes];
    final order = [for (var i = 0; i < waypoints.length; i++) i];
    order.insert(newIndex, order.removeAt(oldIndex));
    return Tour(
      waypoints: [for (final index in order) waypoints[index]],
      modes: [for (final index in order.skip(1)) reachedBy[index]],
    );
  }

  /// The tour without the waypoint at [index].
  ///
  /// The section that reached it goes with it, so the one that left it now
  /// starts a waypoint earlier and keeps its own mode. Removing the first
  /// waypoint drops the section that left it.
  Tour without(int index) => Tour(
    waypoints: [...waypoints]..removeAt(index),
    modes: modes.isEmpty
        ? const []
        : ([...modes]..removeAt(index == 0 ? 0 : index - 1)),
  );
}

/// A stretch of a tour that becomes one leg: consecutive sections traveled the
/// same way, with no waypoint between them at which a leg has to end.
class TourRun {
  const TourRun({required this.first, required this.last, required this.mode});

  /// Indices into [Tour.waypoints] of the run's two ends.
  final int first;
  final int last;

  final SectionMode mode;

  /// Every waypoint of the run, ends included: what a router is asked to lead
  /// the leg through.
  List<TourWaypoint> waypointsOf(Tour tour) =>
      tour.waypoints.sublist(first, last + 1);
}

/// Divides [tour] into the runs its legs are made of, in order.
///
/// A run ends where the mode changes or at a waypoint that [TourWaypoint
/// .splitsLeg]. One router request then covers a whole run rather than each
/// section, and moving a waypoint asks again for its own run only.
List<TourRun> tourRuns(Tour tour) {
  final runs = <TourRun>[];
  var first = 0;
  for (var section = 0; section < tour.modes.length; section++) {
    final end = section + 1;
    final isLast = end == tour.modes.length;
    if (isLast ||
        tour.modes[end] != tour.modes[section] ||
        tour.waypoints[end].splitsLeg) {
      runs.add(TourRun(first: first, last: end, mode: tour.modes[section]));
      first = end;
    }
  }
  return runs;
}
