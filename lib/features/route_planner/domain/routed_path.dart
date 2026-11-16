import 'package:latlong2/latlong.dart';

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

  /// The line, in travel order. At least two points.
  final List<LatLng> points;

  /// The height of each of [points] in meters, or null when the router had none
  /// for **any** of them: a profile with holes in it would draw a cliff at each
  /// hole, so heights are kept all or nothing, as a recording's times are.
  final List<double>? elevations;

  /// The length of the line as the router measured it.
  final double lengthMeters;

  /// Meters climbed and descended, as the router counts them (it filters the
  /// noise of its elevation model, which a plain sum over [elevations] would
  /// count as climbing). Null when it gave none.
  final double? ascentMeters;
  final double? descentMeters;

  /// How long the router expects the stretch to take. An estimate for a
  /// traveler it knows nothing about.
  final Duration? duration;
}
