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
