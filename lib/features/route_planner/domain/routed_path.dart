import 'package:latlong2/latlong.dart';

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
}
