import 'package:latlong2/latlong.dart';

import '../map/elevation.dart';
import '../map/map_features.dart';
import 'domain/routed_path.dart';
import 'domain/tour.dart';

/// What a planned tour becomes in a plan, in order: a leg per run and a place
/// per waypoint marked as one.
sealed class TourEntry {
  const TourEntry();
}

/// One leg: a run of the tour and the line it follows.
class TourLeg extends TourEntry {
  const TourLeg({
    required this.from,
    required this.to,
    required this.mode,
    required this.path,
    List<TourWaypoint>? waypoints,
  }) : waypoints = waypoints ?? const [];

  /// Every waypoint the leg is led through, ends included: what the router was
  /// asked with, kept so the tour can be opened again. Empty where a leg was
  /// built without them.
  final List<TourWaypoint> waypoints;

  final TourWaypoint from;
  final TourWaypoint to;
  final SectionMode mode;
  final RoutedPath path;
}

/// A waypoint that is an entry of its own.
class TourPlace extends TourEntry {
  const TourPlace(this.waypoint);

  final TourWaypoint waypoint;
}

/// The line of a run nobody routes: straight from waypoint to waypoint, with
/// its length and nothing else, since nothing else is known about it.
RoutedPath straightPath(List<LatLng> points) =>
    RoutedPath(points: points, lengthMeters: lineLength(points));

/// Lays [tour] out as the entries it is saved as.
///
/// [paths] holds the router's answer per run, by index into `tourRuns(tour)`;
/// a [StraightMode] run needs none. Returns null while a routed run has no
/// answer yet: a tour with a leg missing is not one to save.
///
/// A place stands between the leg that reaches it and the one that leaves it;
/// the tour's first and last waypoints are places too when marked.
List<TourEntry>? tourEntries(Tour tour, Map<int, RoutedPath> paths) {
  final runs = tourRuns(tour);
  final entries = <TourEntry>[];
  if (tour.waypoints.isNotEmpty && tour.waypoints.first.isPlace) {
    entries.add(TourPlace(tour.waypoints.first));
  }
  for (final (index, run) in runs.indexed) {
    final waypoints = run.waypointsOf(tour);
    final path = switch (run.mode) {
      StraightMode() => straightPath([for (final w in waypoints) w.position]),
      RoutedMode() => paths[index],
    };
    if (path == null) return null;
    entries.add(
      TourLeg(
        from: waypoints.first,
        to: waypoints.last,
        mode: run.mode,
        path: path,
        waypoints: waypoints,
      ),
    );
    if (waypoints.last.isPlace) entries.add(TourPlace(waypoints.last));
  }
  return entries;
}

/// The heights along a tour: each leg's profile at its distance from the
/// start, with a gap where a leg has no heights (a line drawn by hand).
LaidProfile tourProfile(List<TourEntry> entries) => layProfiles([
  for (final leg in entries.whereType<TourLeg>())
    (
      profile: elevationProfile(leg.path.points, leg.path.elevations),
      meters: leg.path.lengthMeters,
    ),
]);

/// What a tour adds up to.
class TourTotals {
  const TourTotals({
    required this.lengthMeters,
    this.ascentMeters,
    this.descentMeters,
    this.duration,
  });

  final double lengthMeters;

  /// Null unless **every** leg has a figure: a climb or a duration that left a
  /// leg out would read as the whole tour's and be short by that leg.
  final double? ascentMeters;
  final double? descentMeters;
  final Duration? duration;
}

/// Sums the legs of [entries].
TourTotals tourTotals(List<TourEntry> entries) {
  final legs = entries.whereType<TourLeg>().toList();
  double? sum(double? Function(RoutedPath path) of) {
    var total = 0.0;
    for (final leg in legs) {
      final value = of(leg.path);
      if (value == null) return null;
      total += value;
    }
    return legs.isEmpty ? null : total;
  }

  final seconds = sum((path) => path.duration?.inSeconds.toDouble());
  return TourTotals(
    lengthMeters: sum((path) => path.lengthMeters) ?? 0,
    ascentMeters: sum((path) => path.ascentMeters),
    descentMeters: sum((path) => path.descentMeters),
    duration: seconds == null ? null : Duration(seconds: seconds.round()),
  );
}
