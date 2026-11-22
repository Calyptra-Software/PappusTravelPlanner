import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/route_planner/domain/pace.dart';
import 'package:travelplanner/features/route_planner/domain/route_profile.dart';
import 'package:travelplanner/features/route_planner/domain/routed_path.dart';
import 'package:travelplanner/features/route_planner/domain/tour.dart';

const _line = [LatLng(47, 11), LatLng(47.1, 11)];

RoutedPath _path({
  double length = 6000,
  double? ascent,
  double? descent,
  Duration? duration,
}) => RoutedPath(
  points: _line,
  lengthMeters: length,
  ascentMeters: ascent,
  descentMeters: descent,
  duration: duration,
);

PathSegment _segment(SegmentKind kind) => PathSegment(
  start: 0,
  end: 1,
  kind: kind,
  liftMode: kind == SegmentKind.lift ? TransportMode.gondola : null,
  lengthMeters: 1000,
  duration: const Duration(minutes: 10),
);

void main() {
  group('hikingDuration', () {
    test('on the flat is the walk at 4 km/h', () {
      expect(hikingDuration(lengthMeters: 6000), const Duration(minutes: 90));
    });

    test('takes the longer of flat and climb whole, the shorter half', () {
      // 4 km is an hour on the flat; 600 m up is two hours.
      expect(
        hikingDuration(lengthMeters: 4000, ascentMeters: 600),
        const Duration(hours: 2, minutes: 30),
      );
      // 8 km is two hours; 300 m up and 500 m down are two hours as well.
      expect(
        hikingDuration(
          lengthMeters: 8000,
          ascentMeters: 300,
          descentMeters: 500,
        ),
        const Duration(hours: 3),
      );
    });

    test('a faster pace divides the time', () {
      expect(
        hikingDuration(lengthMeters: 8000, factor: 1.6),
        const Duration(minutes: 75),
      );
    });
  });

  group('pacedDuration', () {
    test('on foot is the hiking time, not the router\'s estimate', () {
      final path = _path(
        length: 4000,
        ascent: 600,
        duration: const Duration(minutes: 70),
      );

      expect(
        pacedDuration(const RoutedMode(RouteProfile.foot), path, Pace.average),
        const Duration(hours: 2, minutes: 30),
      );
    });

    test('by bike is the router\'s estimate divided by the factor', () {
      final path = _path(duration: const Duration(minutes: 60));

      for (final profile in [
        RouteProfile.bike,
        RouteProfile.roadBike,
        RouteProfile.gravelBike,
        RouteProfile.mountainBike,
      ]) {
        expect(
          pacedDuration(RoutedMode(profile), path, Pace.brisk),
          const Duration(minutes: 50),
          reason: profile.name,
        );
      }
    });

    test('a drive and a line drawn by hand are as they are', () {
      final path = _path(duration: const Duration(minutes: 60));

      expect(
        pacedDuration(const RoutedMode(RouteProfile.car), path, Pace.fast),
        const Duration(minutes: 60),
      );
      expect(pacedDuration(const StraightMode(), _path(), Pace.fast), isNull);
    });

    test('on skis only a descent takes the pace', () {
      final path = _path(duration: const Duration(minutes: 10));
      const ski = SkiMode();

      expect(
        pacedDuration(
          ski,
          path,
          Pace.leisurely,
          segment: _segment(SegmentKind.descent),
        ),
        Duration(seconds: (600 / 0.7).round()),
      );
      for (final kind in [SegmentKind.lift, SegmentKind.walk]) {
        expect(
          pacedDuration(ski, path, Pace.leisurely, segment: _segment(kind)),
          const Duration(minutes: 10),
          reason: kind.name,
        );
      }
    });
  });

  test('a pace is set per way of travel the planner times itself', () {
    expect(paceKeyOf(const RoutedMode(RouteProfile.foot)), 'foot');
    expect(paceKeyOf(const RoutedMode(RouteProfile.roadBike)), 'roadBike');
    expect(paceKeyOf(const SkiMode()), 'ski');
    expect(paceKeyOf(const RoutedMode(RouteProfile.car)), isNull);
    expect(paceKeyOf(const StraightMode()), isNull);
  });

  test('a pace of one\'s own stays within its range, to hundredths', () {
    expect(Pace.of(1.5), const Pace(1.5));
    expect(Pace.of(1.2), Pace.brisk);
    expect(Pace.of(1.234), const Pace(1.23));
    expect(Pace.of(Pace.min), isNotNull);
    expect(Pace.of(Pace.max), isNotNull);
    expect(Pace.of(0.4), isNull);
    expect(Pace.of(2.5), isNull);
    expect(Pace.of(double.nan), isNull);
    expect(const Pace(1.5).isPreset, isFalse);
    expect(Pace.fast.isPreset, isTrue);
  });

  group('runningDuration', () {
    test('on the flat is the run at 10 km/h', () {
      expect(runningDuration(lengthMeters: 10000), const Duration(hours: 1));
    });

    test('counts a meter of climb as 7.92 on the flat, the descent not', () {
      // 100 m up are 792 m on the flat: 10.792 km at 10 km/h.
      expect(
        runningDuration(lengthMeters: 10000, ascentMeters: 100),
        Duration(seconds: (10.792 / 10 * 3600).round()),
      );
      expect(
        pacedDuration(
          const RoutedMode(RouteProfile.run),
          _path(length: 10000, ascent: 100, descent: 500),
          const Pace(1.2),
        ),
        Duration(seconds: (10.792 / 12 * 3600).round()),
      );
    });
  });
}
