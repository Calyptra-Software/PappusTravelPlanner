import 'package:latlong2/latlong.dart';

import '../../data/database/tables.dart';
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
    this.part,
  }) : waypoints = waypoints ?? const [];

  /// Where the run is laid out as several legs (a ski day), which of them
  /// this is; null for a leg that is its run.
  final TourLegPart? part;

  /// The built-in mode the leg is filed under: a lift's own for a ride, ski
  /// for a descent, walking for a walk; the run's mode where the leg is its
  /// run.
  TransportMode? get transportMode => switch (part?.segment) {
    null => mode.transportMode,
    PathSegment(kind: SegmentKind.lift, :final liftMode) => liftMode,
    PathSegment(kind: SegmentKind.descent) => TransportMode.ski,
    PathSegment(kind: SegmentKind.walk) => TransportMode.walk,
  };

  /// What the leg is called: a lift's name, or the pistes of a descent.
  String? get title => part?.segment.name;

  /// Every waypoint the leg is led through, ends included: what the router was
  /// asked with, kept so the tour can be opened again. Empty where a leg was
  /// built without them.
  final List<TourWaypoint> waypoints;

  final TourWaypoint from;
  final TourWaypoint to;
  final SectionMode mode;
  final RoutedPath path;
}

/// One of the legs a run is laid out as.
class TourLegPart {
  const TourLegPart({
    required this.index,
    required this.segment,
    required this.runFrom,
    required this.runTo,
  });

  /// Which leg of its run this is, counted from 0.
  final int index;

  /// The part of the run's path the leg is.
  final PathSegment segment;

  /// The ends of the run the leg belongs to: what tells the legs of one run
  /// from another's when the tour is saved again.
  final TourWaypoint runFrom;
  final TourWaypoint runTo;
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
      RoutedMode() || SkiMode() => paths[index],
    };
    if (path == null) return null;
    final segments = path.segments;
    if (segments != null && segments.isNotEmpty) {
      entries.addAll(_partsOf(run.mode, waypoints, path, segments));
    } else {
      entries.add(
        TourLeg(
          from: waypoints.first,
          to: waypoints.last,
          mode: run.mode,
          path: path,
          waypoints: waypoints,
        ),
      );
    }
    if (waypoints.last.isPlace) entries.add(TourPlace(waypoints.last));
  }
  return entries;
}

/// The legs a run of [waypoints] is laid out as, one per segment of its
/// [path].
///
/// Where two legs meet, the point is the user's waypoint when the router
/// passed one there, and otherwise one the router chose
/// ([TourWaypoint.byRouter]), named after the lift station it is, if the map
/// data names it. Every other waypoint of the run rides along in the leg it
/// lies in, so that each is in exactly one leg and the run can be read back
/// from them.
List<TourLeg> _partsOf(
  SectionMode mode,
  List<TourWaypoint> waypoints,
  RoutedPath path,
  List<PathSegment> segments,
) {
  final last = path.points.length - 1;
  // Where along the path each waypoint was reached; without the router's
  // word, the ends only.
  final reached =
      path.waypointIndices != null &&
          path.waypointIndices!.length == waypoints.length
      ? path.waypointIndices!
      : [for (var i = 0; i < waypoints.length; i++) i == 0 ? 0 : last];

  // The point each leg starts at, after the first.
  final starts = <int, TourWaypoint>{};
  // The waypoints inside each leg, by leg.
  final inside = [for (final _ in segments) <TourWaypoint>[]];
  for (var w = 1; w < waypoints.length - 1; w++) {
    final at = reached[w];
    var leg = segments.indexWhere((s) => s.start <= at && at < s.end);
    if (leg < 0) leg = segments.length - 1;
    if (leg > 0 && segments[leg].start == at && !starts.containsKey(leg)) {
      starts[leg] = waypoints[w];
    } else {
      inside[leg].add(waypoints[w]);
    }
  }
  for (var leg = 1; leg < segments.length; leg++) {
    final segment = segments[leg];
    starts[leg] ??= TourWaypoint(
      path.points[segment.start],
      name: segments[leg - 1].toName ?? segment.fromName,
      byRouter: true,
    );
  }

  final legs = <TourLeg>[];
  for (final (index, segment) in segments.indexed) {
    final from = index == 0 ? waypoints.first : starts[index]!;
    final to = index == segments.length - 1
        ? waypoints.last
        : starts[index + 1]!;
    legs.add(
      TourLeg(
        from: from,
        to: to,
        mode: mode,
        path: RoutedPath.measured(
          points: path.points.sublist(segment.start, segment.end + 1),
          elevations: path.elevations?.sublist(segment.start, segment.end + 1),
          lengthMeters: segment.lengthMeters,
          duration: segment.duration,
        ),
        waypoints: [from, ...inside[index], to],
        part: TourLegPart(
          index: index,
          segment: segment,
          runFrom: waypoints.first,
          runTo: waypoints.last,
        ),
      ),
    );
  }
  return legs;
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
