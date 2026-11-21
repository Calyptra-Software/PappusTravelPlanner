import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/route_planner/domain/piste_difficulty.dart';
import 'package:travelplanner/features/route_planner/domain/routed_path.dart';

LatLng _p(double i) => LatLng(47 + i / 100, 11);

PathSegment _segment(
  int start,
  int end,
  SegmentKind kind, {
  String? name,
  String? from,
  String? to,
  int minutes = 5,
  List<PisteStretch> pistes = const [],
}) => PathSegment(
  start: start,
  end: end,
  kind: kind,
  liftMode: kind == SegmentKind.lift ? TransportMode.chairLift : null,
  name: name,
  fromName: from,
  toName: to,
  lengthMeters: 1000,
  duration: Duration(minutes: minutes),
  pistes: pistes,
);

void main() {
  test('one path is itself', () {
    final path = RoutedPath(points: [_p(0), _p(1)], lengthMeters: 1000);

    expect(identical(joinPaths([path]), path), isTrue);
  });

  test('adds up, keeps the shared point once, and counts the climb', () {
    final joined = joinPaths([
      RoutedPath(
        points: [_p(0), _p(1)],
        elevations: const [500, 600],
        lengthMeters: 1000,
        duration: const Duration(minutes: 10),
      ),
      RoutedPath(
        points: [_p(1), _p(2)],
        elevations: const [600, 550],
        lengthMeters: 1200,
        duration: const Duration(minutes: 15),
      ),
    ]);

    expect(joined.points, [_p(0), _p(1), _p(2)]);
    expect(joined.elevations, [500, 600, 550]);
    expect(joined.lengthMeters, 2200);
    expect(joined.duration, const Duration(minutes: 25));
    expect((joined.ascentMeters, joined.descentMeters), (100, 50));
    expect(joined.segments, isNull);
  });

  test('ends that do not meet are both kept', () {
    final joined = joinPaths([
      RoutedPath(points: [_p(0), _p(1)], lengthMeters: 1000),
      RoutedPath(points: [_p(1.01), _p(2)], lengthMeters: 1000),
    ]);

    expect(joined.points, [_p(0), _p(1), _p(1.01), _p(2)]);
  });

  test('no heights or duration where one path has none', () {
    final joined = joinPaths([
      RoutedPath(
        points: [_p(0), _p(1)],
        elevations: const [500, 600],
        lengthMeters: 1000,
        duration: const Duration(minutes: 10),
      ),
      RoutedPath(points: [_p(1), _p(2)], lengthMeters: 1000),
    ]);

    expect(joined.elevations, isNull);
    expect(joined.ascentMeters, isNull);
    expect(joined.duration, isNull);
  });

  test('a descent across the joint is one, a lift ride never', () {
    final joined = joinPaths([
      RoutedPath(
        points: [_p(0), _p(1), _p(2)],
        lengthMeters: 2000,
        segments: [
          _segment(0, 1, SegmentKind.lift, name: 'Bahn', to: 'Berg'),
          _segment(1, 2, SegmentKind.descent, name: 'Blau', from: 'Berg'),
        ],
        waypointIndices: const [0, 2],
      ),
      RoutedPath(
        points: [_p(2), _p(3), _p(4), _p(5)],
        lengthMeters: 3000,
        segments: [
          _segment(0, 1, SegmentKind.descent, name: 'Blau, Rot', to: 'Tal'),
          _segment(1, 2, SegmentKind.lift, name: 'Bahn'),
          _segment(2, 3, SegmentKind.lift, name: 'Bahn'),
        ],
        waypointIndices: const [0, 3],
      ),
    ]);

    final segments = joined.segments!;
    expect(segments.map((s) => (s.start, s.end)), [
      (0, 1),
      (1, 3),
      (3, 4),
      (4, 5),
    ]);
    final descent = segments[1];
    expect(descent.name, 'Blau, Rot');
    expect((descent.fromName, descent.toName), ('Berg', 'Tal'));
    expect(descent.duration, const Duration(minutes: 10));
    expect(descent.lengthMeters, 2000);
    expect(joined.waypointIndices, [0, 2, 5]);
  });

  test('a descent across the joint runs down the pistes of both', () {
    const red = PisteStretch(
      name: 'Rot',
      difficulty: PisteDifficulty.intermediate,
    );
    const black = PisteStretch(
      name: 'Schwarz',
      difficulty: PisteDifficulty.advanced,
    );
    final joined = joinPaths([
      RoutedPath(
        points: [_p(0), _p(1)],
        lengthMeters: 1000,
        segments: [
          _segment(0, 1, SegmentKind.descent, pistes: [red]),
        ],
      ),
      RoutedPath(
        points: [_p(1), _p(2)],
        lengthMeters: 1000,
        segments: [
          _segment(0, 1, SegmentKind.descent, pistes: [red, black]),
        ],
      ),
    ]);

    expect(joined.segments!.single.pistes, [red, black]);
  });

  test('where the ends do not meet, the first segment takes in the gap', () {
    final joined = joinPaths([
      RoutedPath(
        points: [_p(0), _p(1)],
        lengthMeters: 1000,
        segments: [_segment(0, 1, SegmentKind.lift)],
      ),
      RoutedPath(
        points: [_p(1.01), _p(2)],
        lengthMeters: 1000,
        segments: [_segment(0, 1, SegmentKind.lift)],
      ),
    ]);

    expect(joined.segments!.map((s) => (s.start, s.end)), [(0, 1), (1, 3)]);
  });
}
