import 'package:latlong2/latlong.dart';

import '../../../data/database/tables.dart';
import '../../map/elevation.dart';

/// What a router answered for one stretch: the line, and what it measured
/// along it.
///
/// A proposal, never a record: written into a plan it becomes a
/// `TrackSource.routed` track, which the map draws dashed.
class RoutedPath {
  const RoutedPath({
    required this.points,
    required this.lengthMeters,
    this.elevations,
    this.ascentMeters,
    this.descentMeters,
    this.duration,
    this.segments,
    this.waypointIndices,
  }) : assert(elevations == null || elevations.length == points.length);

  /// A path whose climb is counted from its [elevations] (`climbOf`), the way
  /// every line with heights is counted: null without heights.
  factory RoutedPath.measured({
    required List<LatLng> points,
    required double lengthMeters,
    List<double>? elevations,
    Duration? duration,
  }) {
    final climb = elevations == null ? null : climbOf(elevations);
    return RoutedPath(
      points: points,
      lengthMeters: lengthMeters,
      elevations: elevations,
      ascentMeters: climb?.ascent,
      descentMeters: climb?.descent,
      duration: duration,
    );
  }

  /// The line, in travel order. At least two points.
  final List<LatLng> points;

  /// The height of each of [points] in meters, or null when the router had none
  /// for **any** of them: a profile with holes in it would draw a cliff at each
  /// hole, so heights are kept all or nothing, as a recording's times are.
  final List<double>? elevations;

  /// The length of the line as the router measured it.
  final double lengthMeters;

  /// Meters climbed and descended, counted from [elevations] past a threshold
  /// (see `climbOf`), since a plain sum would count the noise of the elevation
  /// model as climbing. Null without heights.
  final double? ascentMeters;
  final double? descentMeters;

  /// How long the router expects the stretch to take. An estimate for a
  /// traveler it knows nothing about.
  final Duration? duration;

  /// The parts of the line that are traveled differently, in order, where the
  /// router told them apart: a ski day's lift rides, descents and walks. Each
  /// becomes a leg of its own. Null for a line that is one leg.
  final List<PathSegment>? segments;

  /// Where along [points] each waypoint the router was asked with was reached,
  /// as an index into [points], in order. Known only where the line has
  /// [segments], since only then does a waypoint have to be placed in one of
  /// them.
  final List<int>? waypointIndices;
}

/// [paths], one after the other, as one path: the sections of a run, each
/// asked about on its own, joined into the run's line.
///
/// A point shared by two of them is kept once. Lengths and durations add up
/// (no duration where one has none), heights are kept only when every path
/// has them, and the climb is counted again over the whole, as for every line
/// with heights. Where every path has [RoutedPath.segments], so does the
/// result, and a descent or a walk running across the joint is one.
RoutedPath joinPaths(List<RoutedPath> paths) {
  if (paths.length == 1) return paths.single;
  final points = <LatLng>[];
  final elevations = <double>[];
  final withHeights = paths.every((path) => path.elevations != null);
  final withSegments = paths.every((path) => path.segments != null);
  final segments = <PathSegment>[];
  final reached = <int>[0];
  var seconds = 0;
  var timed = true;
  var meters = 0.0;
  for (final path in paths) {
    // Where the path's first point lands, and the first point its first
    // segment takes in: the joint itself, even where the two ends differ.
    final int base;
    final int from;
    if (points.isEmpty) {
      base = 0;
      from = 0;
      points.addAll(path.points);
      if (withHeights) elevations.addAll(path.elevations!);
    } else {
      final joint = points.length - 1;
      final same = _closeTo(points.last, path.points.first);
      base = same ? joint : joint + 1;
      from = joint;
      points.addAll(same ? path.points.skip(1) : path.points);
      if (withHeights) {
        elevations.addAll(same ? path.elevations!.skip(1) : path.elevations!);
      }
    }
    if (withSegments) {
      for (final (index, segment) in path.segments!.indexed) {
        final shifted = PathSegment(
          start: index == 0 ? from : segment.start + base,
          end: segment.end + base,
          kind: segment.kind,
          lengthMeters: segment.lengthMeters,
          duration: segment.duration,
          liftMode: segment.liftMode,
          name: segment.name,
          fromName: segment.fromName,
          toName: segment.toName,
        );
        final last = segments.lastOrNull;
        if (index == 0 &&
            last != null &&
            last.kind == shifted.kind &&
            last.kind != SegmentKind.lift) {
          segments.last = _merged(last, shifted);
        } else {
          segments.add(shifted);
        }
      }
    }
    reached.add(points.length - 1);
    meters += path.lengthMeters;
    if (path.duration == null) timed = false;
    seconds += path.duration?.inSeconds ?? 0;
  }
  final measured = RoutedPath.measured(
    points: points,
    lengthMeters: meters,
    elevations: withHeights ? elevations : null,
    duration: timed ? Duration(seconds: seconds) : null,
  );
  return RoutedPath(
    points: measured.points,
    lengthMeters: measured.lengthMeters,
    elevations: measured.elevations,
    ascentMeters: measured.ascentMeters,
    descentMeters: measured.descentMeters,
    duration: measured.duration,
    segments: withSegments ? segments : null,
    waypointIndices: withSegments ? reached : null,
  );
}

/// Within about a meter.
bool _closeTo(LatLng a, LatLng b) =>
    (a.latitude - b.latitude).abs() < 1e-5 &&
    (a.longitude - b.longitude).abs() < 1e-5;

/// Two segments of one kind that meet, as one: a descent down the pistes of
/// both, each named once.
PathSegment _merged(PathSegment a, PathSegment b) {
  final names = <String>[];
  for (final name in [a.name, b.name]) {
    for (final part in name?.split(', ') ?? const <String>[]) {
      if (!names.contains(part)) names.add(part);
    }
  }
  return PathSegment(
    start: a.start,
    end: b.end,
    kind: a.kind,
    lengthMeters: a.lengthMeters + b.lengthMeters,
    duration: a.duration + b.duration,
    name: names.isEmpty ? null : names.join(', '),
    fromName: a.fromName,
    toName: b.toName,
  );
}

/// How a [PathSegment] is traveled.
enum SegmentKind {
  /// Skied down one or more pistes.
  descent,

  /// Ridden up (or down) one lift.
  lift,

  /// Walked, between a piste and a lift.
  walk,
}

/// One part of a [RoutedPath] that is traveled one way: points [start] to
/// [end] of the path, both included, so a segment shares its first point with
/// the one before it.
class PathSegment {
  const PathSegment({
    required this.start,
    required this.end,
    required this.kind,
    required this.lengthMeters,
    required this.duration,
    this.liftMode,
    this.name,
    this.fromName,
    this.toName,
  }) : assert(end > start),
       assert((kind == SegmentKind.lift) == (liftMode != null));

  final int start;
  final int end;
  final SegmentKind kind;
  final double lengthMeters;
  final Duration duration;

  /// The kind of lift, for a [SegmentKind.lift] segment only: one of
  /// [TransportMode.gondola], [TransportMode.chairLift] and
  /// [TransportMode.dragLift], the lift modes the itinerary tells apart.
  final TransportMode? liftMode;

  /// What the segment is called in the map data: a lift's name, or the names
  /// of the pistes a descent runs down. Null when they have none.
  final String? name;

  /// The stations the segment starts and ends at, when the map data names
  /// them.
  final String? fromName;
  final String? toName;
}
