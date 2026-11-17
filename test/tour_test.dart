import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/route_planner/domain/route_profile.dart';
import 'package:travelplanner/features/route_planner/domain/routed_path.dart';
import 'package:travelplanner/features/route_planner/domain/tour.dart';
import 'package:travelplanner/features/route_planner/tour_entries.dart';

const _car = RoutedMode(RouteProfile.car);
const _foot = RoutedMode(RouteProfile.foot);
const _ski = StraightMode(TransportMode.ski);

TourWaypoint _at(double lat, {String? name, bool isPlace = false}) =>
    TourWaypoint(LatLng(lat, 11), name: name, isPlace: isPlace);

RoutedPath _path(
  double from,
  double to, {
  double length = 1000,
  double? ascent,
  double? descent,
  Duration? duration,
}) => RoutedPath(
  points: [LatLng(from, 11), LatLng(to, 11)],
  lengthMeters: length,
  ascentMeters: ascent,
  descentMeters: descent,
  duration: duration,
);

List<(int, int)> _ends(Tour tour) => [
  for (final run in tourRuns(tour)) (run.first, run.last),
];

void main() {
  group('tourRuns', () {
    test('an empty tour and a single waypoint have none', () {
      expect(tourRuns(const Tour.empty()), isEmpty);
      expect(tourRuns(Tour(waypoints: [_at(47)], modes: const [])), isEmpty);
    });

    test('sections traveled the same way are one run', () {
      final tour = Tour(
        waypoints: [_at(47), _at(47.1), _at(47.2)],
        modes: const [_foot, _foot],
      );

      expect(_ends(tour), [(0, 2)]);
      expect(tourRuns(tour).single.waypointsOf(tour), hasLength(3));
    });

    test('a change of mode ends a run at the waypoint it happens at', () {
      final tour = Tour(
        waypoints: [_at(47), _at(47.1), _at(47.2), _at(47.3)],
        modes: const [_car, _foot, _foot],
      );

      expect(_ends(tour), [(0, 1), (1, 3)]);
      expect(tourRuns(tour).map((run) => run.mode), [_car, _foot]);
    });

    test('a named waypoint ends a run though the mode goes on', () {
      final tour = Tour(
        waypoints: [
          _at(47),
          _at(47.1, name: 'Hut'),
          _at(47.2),
        ],
        modes: const [_foot, _foot],
      );

      expect(_ends(tour), [(0, 1), (1, 2)]);
    });

    test('a blank name is no name', () {
      final tour = Tour(
        waypoints: [
          _at(47),
          _at(47.1, name: '  '),
          _at(47.2),
        ],
        modes: const [_foot, _foot],
      );

      expect(_ends(tour), [(0, 2)]);
    });

    test('two profiles of one transport mode are two runs', () {
      final tour = Tour(
        waypoints: [_at(47), _at(47.1), _at(47.2)],
        modes: const [
          RoutedMode(RouteProfile.bike),
          RoutedMode(RouteProfile.mountainBike),
        ],
      );

      expect(_ends(tour), [(0, 1), (1, 2)]);
    });
  });

  group('Tour.extendedBy', () {
    test('the first waypoint is reached by nothing', () {
      final tour = const Tour.empty()
          .extendedBy(_at(47), _car)
          .extendedBy(_at(47.1), _foot);

      expect(tour.waypoints, hasLength(2));
      expect(tour.modes, [_foot]);
    });
  });

  group('Tour.without', () {
    final tour = Tour(
      waypoints: [_at(47), _at(47.1), _at(47.2)],
      modes: const [_car, _foot],
    );

    test('the last waypoint takes the section that reached it', () {
      final shorter = tour.without(2);

      expect(shorter.waypoints, hasLength(2));
      expect(shorter.modes, [_car]);
    });

    test('a waypoint in the middle leaves the next section its mode', () {
      final shorter = tour.without(1);

      expect(shorter.waypoints.map((w) => w.position.latitude), [47, 47.2]);
      expect(shorter.modes, [_foot]);
    });

    test('the first waypoint takes the section that left it', () {
      final shorter = tour.without(0);

      expect(shorter.waypoints.map((w) => w.position.latitude), [47.1, 47.2]);
      expect(shorter.modes, [_foot]);
    });

    test('the only waypoint leaves an empty tour', () {
      final empty = Tour(waypoints: [_at(47)], modes: const []).without(0);

      expect(empty.waypoints, isEmpty);
      expect(empty.modes, isEmpty);
    });
  });

  group('Tour.reordered', () {
    final tour = Tour(
      waypoints: [
        _at(47, name: 'Home'),
        _at(47.1, name: 'Car park'),
        _at(47.2, name: 'Summit'),
      ],
      modes: const [_car, _foot],
    );

    List<String?> names(Tour tour) => [for (final w in tour.waypoints) w.name];

    test('a waypoint keeps the mode it is reached by', () {
      final moved = tour.reordered(2, 1);

      expect(names(moved), ['Home', 'Summit', 'Car park']);
      // Still walked up to, and the car park still driven to.
      expect(moved.modes, [_foot, _car]);
    });

    test('the first waypoint, moved back, is reached as it was left', () {
      final moved = tour.reordered(0, 2);

      expect(names(moved), ['Car park', 'Summit', 'Home']);
      expect(moved.modes, [_foot, _car]);
    });

    test('a waypoint moved to the front sets its own mode aside', () {
      final moved = tour.reordered(2, 0);

      expect(names(moved), ['Summit', 'Home', 'Car park']);
      expect(moved.modes, [_car, _car]);
    });

    test('moving a waypoint onto its own place changes nothing', () {
      expect(identical(tour.reordered(1, 1), tour), isTrue);
    });

    test('a single waypoint has no order to change', () {
      final one = Tour(waypoints: [_at(47)], modes: const []);

      expect(identical(one.reordered(0, 0), one), isTrue);
    });
  });

  group('Tour.withWaypoint', () {
    test('exchanges one waypoint and keeps the modes', () {
      final tour = Tour(
        waypoints: [_at(47), _at(47.1)],
        modes: const [_ski],
      ).withWaypoint(1, _at(47.1, name: 'Hut'));

      expect(tour.waypoints.last.name, 'Hut');
      expect(tour.modes, [_ski]);
    });
  });

  group('tourEntries', () {
    test('drive, walk up to a summit that is a place, ski down', () {
      final tour = Tour(
        waypoints: [
          _at(47, name: 'Home'),
          _at(47.1, name: 'Car park'),
          _at(47.15),
          _at(47.2, name: 'Summit', isPlace: true),
          _at(47.1, name: 'Car park'),
        ],
        modes: const [_car, _foot, _foot, _ski],
      );

      final entries = tourEntries(tour, {
        0: _path(47, 47.1),
        1: _path(47.1, 47.2),
      })!;

      expect(entries, hasLength(4));
      final [
        drive as TourLeg,
        walk as TourLeg,
        summit as TourPlace,
        ski as TourLeg,
      ] = entries;
      expect(drive.from.name, 'Home');
      expect(drive.to.name, 'Car park');
      expect(walk.mode, _foot);
      expect(walk.to.name, 'Summit');
      expect(summit.waypoint.name, 'Summit');
      expect(ski.mode, _ski);
      expect(ski.path.points, [const LatLng(47.2, 11), const LatLng(47.1, 11)]);
    });

    test('a straight run is as long as its line and knows nothing else', () {
      final tour = Tour(
        waypoints: [_at(47), _at(47.1), _at(47.2)],
        modes: const [_ski, _ski],
      );

      final leg = tourEntries(tour, const {})!.single as TourLeg;

      expect(leg.path.points, hasLength(3));
      // Two tenths of a degree of latitude.
      expect(leg.path.lengthMeters, closeTo(22240, 50));
      expect(leg.path.elevations, isNull);
      expect(leg.path.duration, isNull);
    });

    test('is null while a routed run has no answer', () {
      final tour = Tour(
        waypoints: [_at(47), _at(47.1), _at(47.2)],
        modes: const [_car, _foot],
      );

      expect(tourEntries(tour, {0: _path(47, 47.1)}), isNull);
    });

    test('the first waypoint is a place when marked', () {
      final tour = Tour(
        waypoints: [
          _at(47, name: 'Hut', isPlace: true),
          _at(47.1),
        ],
        modes: const [_ski],
      );

      final entries = tourEntries(tour, const {})!;

      expect(entries.first, isA<TourPlace>());
      expect(entries.last, isA<TourLeg>());
    });
  });

  group('tourTotals', () {
    TourLeg leg(RoutedPath path) =>
        TourLeg(from: _at(47), to: _at(47.1), mode: _foot, path: path);

    test('adds the legs up', () {
      final totals = tourTotals([
        leg(
          _path(
            47,
            47.1,
            length: 1000,
            ascent: 100,
            descent: 20,
            duration: const Duration(minutes: 30),
          ),
        ),
        TourPlace(_at(47.1)),
        leg(
          _path(
            47.1,
            47.2,
            length: 500,
            ascent: 50,
            descent: 5,
            duration: const Duration(minutes: 10),
          ),
        ),
      ]);

      expect(totals.lengthMeters, 1500);
      expect(totals.ascentMeters, 150);
      expect(totals.descentMeters, 25);
      expect(totals.duration, const Duration(minutes: 40));
    });

    test('gives no climb or duration when one leg has none', () {
      final totals = tourTotals([
        leg(
          _path(47, 47.1, ascent: 100, duration: const Duration(minutes: 30)),
        ),
        leg(_path(47.1, 47.2, length: 500)),
      ]);

      expect(totals.lengthMeters, 1500);
      expect(totals.ascentMeters, isNull);
      expect(totals.duration, isNull);
    });

    test('an empty tour has no length', () {
      expect(tourTotals(const []).lengthMeters, 0);
      expect(tourTotals(const []).duration, isNull);
    });
  });

  test('two sections traveled the same way are equal, and hash alike', () {
    const a = RoutedMode(RouteProfile.foot);
    const b = RoutedMode(RouteProfile.foot);
    final c = StraightMode(TransportMode.ski);
    final d = StraightMode(TransportMode.ski);

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(c, d);
    expect(c.hashCode, d.hashCode);
    expect(c, isNot(const StraightMode()));
    expect({
      ...<SectionMode>[a, b, c, d],
    }, hasLength(2));
  });

  test('an empty tour has no waypoints and no sections', () {
    // Not a const: the constructor as code that runs.
    // ignore: prefer_const_constructors
    final empty = Tour.empty();

    expect(empty.waypoints, isEmpty);
    expect(empty.modes, isEmpty);
  });
}
