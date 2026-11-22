import 'route_profile.dart';
import 'routed_path.dart';
import 'tour.dart';

/// How fast somebody travels a way of travel the planner times itself, as a
/// factor on its standard speeds. Stored by name, in the preferences and in a
/// leg's plan, so the order is free.
enum Pace {
  leisurely(0.7),
  easy(0.85),
  average(1),
  brisk(1.2),
  fast(1.4);

  const Pace(this.factor);

  /// How many times the standard speed.
  final double factor;

  static Pace? byName(String? name) {
    for (final pace in values) {
      if (pace.name == name) return pace;
    }
    return null;
  }
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

/// How long [path] takes at [pace] when traveled by [mode], or null when
/// nothing is known about it.
///
/// - On foot, the hiking time ([hikingDuration]) from the path's length and
///   climb, in place of the router's estimate; without heights, the flat part
///   alone.
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
