import 'package:latlong2/latlong.dart';

import 'map_features.dart';

/// How far a line has to rise or fall before it counts as climbing.
///
/// An elevation model is noisy by a few meters from point to point, and a plain
/// sum of every rise counts that noise as climbing: on a recorded mountain
/// route the plain sum was 171 m where the router, which filters, says 123.
/// With this threshold the same route comes to 122 m up and 796 m down against
/// the router's 123 and 799. One route is all it was checked on.
const double kClimbThresholdMeters = 8;

/// Meters climbed and descended along a line.
typedef Climb = ({double ascent, double descent});

/// What [elevations] add up to, counting a rise or a fall only once it has
/// passed [kClimbThresholdMeters] from the last height counted.
///
/// The one definition of climb in the app: the planner's totals and a stored
/// line's row both read it, so the same line cannot be given two figures.
Climb climbOf(List<double> elevations) {
  if (elevations.isEmpty) return (ascent: 0, descent: 0);
  var ascent = 0.0;
  var descent = 0.0;
  var reference = elevations.first;
  for (final height in elevations.skip(1)) {
    final change = height - reference;
    if (change >= kClimbThresholdMeters) {
      ascent += change;
      reference = height;
    } else if (change <= -kClimbThresholdMeters) {
      descent -= change;
      reference = height;
    }
  }
  return (ascent: ascent, descent: descent);
}

/// One point of an elevation profile: how far along the line, how high, and
/// where it is, so a point of the profile can be found on the map.
typedef ProfilePoint = ({double meters, double elevation, LatLng position});

/// The profile of a line: each of [points] by its distance from the start.
///
/// Empty unless there is a height for every point and at least two of them.
List<ProfilePoint> elevationProfile(
  List<LatLng> points,
  List<double>? elevations,
) {
  if (elevations == null ||
      points.length < 2 ||
      elevations.length != points.length) {
    return const [];
  }
  final profile = <ProfilePoint>[
    (meters: 0, elevation: elevations.first, position: points.first),
  ];
  var along = 0.0;
  for (var i = 1; i < points.length; i++) {
    along += lineLength([points[i - 1], points[i]]);
    profile.add((meters: along, elevation: elevations[i], position: points[i]));
  }
  return profile;
}

/// The profile of something made of several lines: each line's own profile
/// at its distance from the start, with a gap where a line has no heights.
class LaidProfile {
  const LaidProfile({required this.stretches, required this.meters});

  static const empty = LaidProfile(stretches: [], meters: 0);

  /// One run of points per line that has heights, in order, each measured
  /// from the start of the whole.
  final List<List<ProfilePoint>> stretches;

  /// How long the whole is, lines without heights included.
  final double meters;

  bool get isEmpty => stretches.isEmpty;

  /// The lowest and highest point drawn; null when nothing is.
  ({double low, double high})? get range {
    double? low;
    double? high;
    for (final stretch in stretches) {
      for (final point in stretch) {
        if (low == null || point.elevation < low) low = point.elevation;
        if (high == null || point.elevation > high) high = point.elevation;
      }
    }
    return low == null || high == null ? null : (low: low, high: high);
  }

  /// The point [meters] from the start, between the two profile points it
  /// falls between, or null where the profile has a gap or the whole ends.
  ///
  /// Interpolated in a straight line, height and position alike: the points
  /// of a routed line lie a few meters apart, and between two of them the
  /// line is straight.
  ProfilePoint? at(double meters) {
    for (final stretch in stretches) {
      if (meters < stretch.first.meters || meters > stretch.last.meters) {
        continue;
      }
      for (var i = 1; i < stretch.length; i++) {
        final a = stretch[i - 1];
        final b = stretch[i];
        if (meters > b.meters) continue;
        final span = b.meters - a.meters;
        final t = span <= 0 ? 0.0 : (meters - a.meters) / span;
        return (
          meters: meters,
          elevation: a.elevation + t * (b.elevation - a.elevation),
          position: LatLng(
            a.position.latitude +
                t * (b.position.latitude - a.position.latitude),
            a.position.longitude +
                t * (b.position.longitude - a.position.longitude),
          ),
        );
      }
      return stretch.last;
    }
    return null;
  }
}

/// Lays [lines] end to end. Each is a profile and how long the line is; a
/// line with no profile still takes up its length, as a gap, since a profile
/// that closed up over it would show a tour shorter than it is.
LaidProfile layProfiles(
  List<({List<ProfilePoint> profile, double meters})> lines,
) {
  final stretches = <List<ProfilePoint>>[];
  var offset = 0.0;
  for (final line in lines) {
    if (line.profile.isEmpty) {
      offset += line.meters;
      continue;
    }
    stretches.add([
      for (final point in line.profile)
        (
          meters: offset + point.meters,
          elevation: point.elevation,
          position: point.position,
        ),
    ]);
    offset += line.profile.last.meters;
  }
  return LaidProfile(stretches: stretches, meters: offset);
}
