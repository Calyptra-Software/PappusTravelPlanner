import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/features/route_planner/domain/route_profile.dart';
import 'package:travelplanner/features/route_planner/domain/tour.dart';
import 'package:travelplanner/features/route_planner/tour_geometry.dart';

const _foot = RoutedMode(RouteProfile.foot);
const _car = RoutedMode(RouteProfile.car);

TourWaypoint _at(double lat, [double lon = 11]) =>
    TourWaypoint(LatLng(lat, lon));

void main() {
  group('locateOnRun', () {
    test('a run of one section is that section, wherever the tap lands', () {
      final tour = Tour(waypoints: [_at(47), _at(47.2)], modes: const [_foot]);
      final run = tourRuns(tour).single;
      final line = [const LatLng(47, 11), const LatLng(47.2, 11)];

      final location = locateOnRun(
        tour,
        run,
        line,
        const LatLng(47.15, 11.01),
      )!;

      expect(location.section, 0);
      // Snapped onto the line, not left beside it.
      expect(location.point.latitude, closeTo(47.15, 1e-9));
      expect(location.point.longitude, closeTo(11, 1e-9));
    });

    test('a tap behind a shaping waypoint is in the next section', () {
      final tour = Tour(
        waypoints: [_at(47), _at(47.1), _at(47.2)],
        modes: const [_foot, _foot],
      );
      final run = tourRuns(tour).single;
      // A routed line: more points than waypoints, none exactly on the middle
      // waypoint.
      final line = [
        const LatLng(47, 11),
        const LatLng(47.05, 11.001),
        const LatLng(47.12, 11.001),
        const LatLng(47.2, 11),
      ];

      expect(locateOnRun(tour, run, line, const LatLng(47.04, 11))!.section, 0);
      expect(locateOnRun(tour, run, line, const LatLng(47.09, 11))!.section, 0);
      expect(locateOnRun(tour, run, line, const LatLng(47.11, 11))!.section, 1);
      expect(locateOnRun(tour, run, line, const LatLng(47.19, 11))!.section, 1);
    });

    test('a long straight section is not mistaken for its neighbor', () {
      // Nearer the middle waypoint than the first, but still before it: a
      // nearest-vertex reading would say the second section.
      final tour = Tour(
        waypoints: [_at(47), _at(47.2), _at(47.21)],
        modes: const [_foot, _foot],
      );
      final run = tourRuns(tour).single;
      final line = [for (final waypoint in tour.waypoints) waypoint.position];

      expect(locateOnRun(tour, run, line, const LatLng(47.18, 11))!.section, 0);
    });

    test('the section is counted in the tour, not in the run', () {
      final tour = Tour(
        waypoints: [_at(46.9), _at(47), _at(47.1), _at(47.2)],
        modes: const [_car, _foot, _foot],
      );
      final run = tourRuns(tour).last;
      final line = [
        const LatLng(47, 11),
        const LatLng(47.1, 11),
        const LatLng(47.2, 11),
      ];

      expect(locateOnRun(tour, run, line, const LatLng(47.05, 11))!.section, 1);
      expect(locateOnRun(tour, run, line, const LatLng(47.15, 11))!.section, 2);
    });

    test('a line passing one spot twice keeps its waypoints in order', () {
      // Out to 47.2 and back to the start, shaped by a waypoint on the way out
      // and one on the way back, at the same spot.
      final tour = Tour(
        waypoints: [_at(47), _at(47.1), _at(47.2), _at(47.1), _at(47)],
        modes: const [_foot, _foot, _foot, _foot],
      );
      final run = tourRuns(tour).single;
      final line = [
        const LatLng(47, 11),
        const LatLng(47.2, 11),
        const LatLng(47.2, 11.001),
        const LatLng(47, 11.001),
      ];

      // On the way back, just short of the start: the last section.
      expect(
        locateOnRun(tour, run, line, const LatLng(47.02, 11.001))!.section,
        3,
      );
      // On the way out, just past the start: the first.
      expect(locateOnRun(tour, run, line, const LatLng(47.02, 11))!.section, 0);
    });

    test('a line of one point has no place to tap', () {
      final tour = Tour(waypoints: [_at(47), _at(47.2)], modes: const [_foot]);

      expect(
        locateOnRun(tour, tourRuns(tour).single, const [
          LatLng(47, 11),
        ], const LatLng(47, 11)),
        isNull,
      );
    });
  });

  group('Tour.withInserted', () {
    test('sets a waypoint into a section and gives both halves its mode', () {
      final tour = Tour(
        waypoints: [_at(47), _at(47.1), _at(47.2)],
        modes: const [_car, _foot],
      ).withInserted(1, _at(47.15));

      expect(tour.waypoints.map((w) => w.position.latitude), [
        47,
        47.1,
        47.15,
        47.2,
      ]);
      expect(tour.modes, [_car, _foot, _foot]);
    });
  });

  group('Tour.withMode', () {
    test('changes one section and no other', () {
      final tour = Tour(
        waypoints: [_at(47), _at(47.1), _at(47.2)],
        modes: const [_foot, _foot],
      ).withMode(1, _car);

      expect(tour.modes, [_foot, _car]);
      // The run it was part of is two runs now.
      expect(tourRuns(tour), hasLength(2));
    });
  });
}
