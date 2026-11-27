import 'package:latlong2/latlong.dart';

import 'route_profile.dart';
import 'routed_path.dart';
import 'tour.dart';

/// How fast somebody travels a way of travel the planner times itself, as a
/// factor on its standard speeds: one of the [presets], or one of the user's
/// own between [min] and [max]. Stored as the factor, in the preferences and in
/// a leg's plan.
final class Pace {
  const Pace(this.factor);

  static const leisurely = Pace(0.7);
  static const easy = Pace(0.85);
  static const average = Pace(1);
  static const brisk = Pace(1.2);
  static const fast = Pace(1.4);

  /// The steps offered first, slowest first.
  static const presets = [leisurely, easy, average, brisk, fast];

  /// The range a pace of one's own may take: wider than the presets, for a
  /// fast walker, and narrow enough that a slip of the finger does not time a
  /// walk at a car's speed.
  static const double min = 0.5;
  static const double max = 2;

  /// How many times the standard speed.
  final double factor;

  /// A pace of one's own at [factor], or null outside [min] to [max]. Rounded
  /// to hundredths, so a speed typed in comes back the same.
  static Pace? of(double factor) =>
      factor.isFinite && factor >= min - 1e-9 && factor <= max + 1e-9
      ? Pace((factor * 100).round() / 100)
      : null;

  /// Whether this is one of the [presets].
  bool get isPreset => presets.contains(this);

  @override
  bool operator ==(Object other) => other is Pace && other.factor == factor;

  @override
  int get hashCode => factor.hashCode;

  @override
  String toString() => 'Pace($factor)';
}

/// What a pace is set for: a profile's name, or `ski`. Null for a way of
/// travel no pace applies to: a drive, which the router times by the speed
/// limits, and a line drawn by hand, which has no duration at all.
///
/// One pace per way of travel and tour, not per section: it is how fast one
/// person walks or rides, as the piste grade is one skier's.
String? paceKeyOf(SectionMode mode) => switch (mode) {
  RoutedMode(profile: RouteProfile.car) => null,
  RoutedMode(:final profile) => profile.name,
  SkiMode() => 'ski',
  StraightMode() => null,
};

/// Walking speed on the flat at [Pace.average], in km/h.
const double kHikingSpeed = 4;

/// Meters climbed and descended an hour at [Pace.average].
const double kHikingAscentPerHour = 300;
const double kHikingDescentPerHour = 500;

/// Running speed on the flat at [Pace.average], in km/h: six minutes a
/// kilometer.
const double kRunningSpeed = 10;

/// How many meters on the flat a meter of climb costs a runner: Scarf's
/// equivalence of distance and climb, 7.92, from Naismith's rule and checked
/// against fell running times (Scarf 2007, *Journal of Sports Sciences* 25(6),
/// 719-726, doi:10.1080/02640410600874906).
const double kClimbEquivalence = 7.92;

/// How long a walk takes by the hiking time of DIN 33466: the time on the flat
/// and the time for the climb and the descent, each at the standard speeds
/// times [factor], of which the longer counts whole and the shorter half.
///
/// The formula on hiking signposts and in guidebooks. The router's own
/// estimate leaves the descent out almost entirely: 103 min for 6.4 km with
/// 800 m down, where this gives about 170.
Duration hikingDuration({
  required double lengthMeters,
  double ascentMeters = 0,
  double descentMeters = 0,
  double factor = 1,
}) {
  final flat = lengthMeters / 1000 / (kHikingSpeed * factor);
  final vertical =
      ascentMeters / (kHikingAscentPerHour * factor) +
      descentMeters / (kHikingDescentPerHour * factor);
  final hours = flat > vertical ? flat + vertical / 2 : vertical + flat / 2;
  return Duration(seconds: (hours * 3600).round());
}

/// How long a run takes: its length with each meter of climb counted as
/// [kClimbEquivalence] meters on the flat, at [kRunningSpeed] times [factor].
/// The descent is counted neither way: a runner gains little on a gentle one
/// and loses on a steep one, and the rule gives no figure for either.
Duration runningDuration({
  required double lengthMeters,
  double ascentMeters = 0,
  double factor = 1,
}) {
  final flatMeters = lengthMeters + kClimbEquivalence * ascentMeters;
  final hours = flatMeters / 1000 / (kRunningSpeed * factor);
  return Duration(seconds: (hours * 3600).round());
}

/// How long [path] takes at [pace] when traveled by [mode], or null when
/// nothing is known about it.
///
/// - On foot, the hiking time ([hikingDuration]) from the path's length and
///   climb, in place of the router's estimate; without heights, the flat part
///   alone. Running, the running time ([runningDuration]) likewise.
/// - By bike, the router's estimate divided by the factor.
/// - On a ski run, each descent divided by the factor; a ride, its boarding
///   and a walk in ski boots are the lift's and the ground's, not the skier's.
/// - A drive and a line drawn by hand as they are.
///
/// [segment] is the part of a ski run the path is, where it is one.
Duration? pacedDuration(
  SectionMode mode,
  RoutedPath path,
  Pace pace, {
  PathSegment? segment,
}) {
  final factor = pace.factor;
  final duration = path.duration;
  return switch (mode) {
    RoutedMode(profile: RouteProfile.foot) => hikingDuration(
      lengthMeters: path.lengthMeters,
      ascentMeters: path.ascentMeters ?? 0,
      descentMeters: path.descentMeters ?? 0,
      factor: factor,
    ),
    RoutedMode(profile: RouteProfile.run) => runningDuration(
      lengthMeters: path.lengthMeters,
      ascentMeters: path.ascentMeters ?? 0,
      factor: factor,
    ),
    RoutedMode(profile: RouteProfile.car) => duration,
    RoutedMode() => duration == null ? null : _divided(duration, factor),
    SkiMode() when segment != null && segment.kind != SegmentKind.descent =>
      duration,
    SkiMode() => duration == null ? null : _divided(duration, factor),
    StraightMode() => duration,
  };
}

Duration _divided(Duration duration, double factor) =>
    Duration(seconds: (duration.inSeconds / factor).round());

/// How a leg's time spreads along its line, for placing where the plan has
/// its traveler: for each of [points], the effort of the way up to it, in
/// hours at the average pace. Only the shares matter, so the pace does not.
///
/// On foot each stretch counts its flat time and its climb and descent as
/// [hikingDuration] does, added rather than combined, since a share of the
/// formula's maximum is no share of the way; running counts as
/// [runningDuration] does. Without [elevations], and for every other way of
/// travel, the effort is the distance: an even pace along the line.
List<double> effortAlong(
  RouteProfile? profile,
  List<LatLng> points,
  List<double>? elevations,
) {
  const distance = Distance(calculator: Haversine());
  final heights = elevations != null && elevations.length == points.length
      ? elevations
      : null;
  final effort = <double>[if (points.isNotEmpty) 0];
  for (var i = 1; i < points.length; i++) {
    final meters = distance.distance(points[i - 1], points[i]);
    final rise = heights == null ? 0.0 : heights[i] - heights[i - 1];
    final up = rise > 0 ? rise : 0.0;
    final down = rise < 0 ? -rise : 0.0;
    final step = switch (profile) {
      _ when heights == null => meters / 1000 / kHikingSpeed,
      RouteProfile.foot =>
        meters / 1000 / kHikingSpeed +
            up / kHikingAscentPerHour +
            down / kHikingDescentPerHour,
      RouteProfile.run =>
        (meters + kClimbEquivalence * up) / 1000 / kRunningSpeed,
      _ => meters / 1000 / kHikingSpeed,
    };
    effort.add(effort.last + step);
  }
  return effort;
}
