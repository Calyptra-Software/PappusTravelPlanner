import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/route_planner/application/route_engine.dart';
import 'package:travelplanner/features/route_planner/data/ski/ski_graph.dart';
import 'package:travelplanner/features/route_planner/data/ski/ski_network.dart';
import 'package:travelplanner/features/route_planner/domain/piste_difficulty.dart';
import 'package:travelplanner/features/route_planner/domain/routed_path.dart';

/// A way of a hand-built ski area. Node ids are given; each node stands at
/// `(47 + lat / 1000, 11 + lon / 1000)`, so one unit of latitude is about
/// 111 m.
Map<String, Object?> _way(
  int id,
  List<(int node, double lat, double lon)> nodes,
  Map<String, String> tags,
) => {
  'type': 'way',
  'id': id,
  'nodes': [for (final n in nodes) n.$1],
  'geometry': [
    for (final n in nodes) {'lat': 47 + n.$2 / 1000, 'lon': 11 + n.$3 / 1000},
  ],
  'tags': tags,
};

Map<String, Object?> _station(
  int id,
  double lat,
  double lon, [
  String? name,
  String? access,
]) => {
  'type': 'node',
  'id': id,
  'lat': 47 + lat / 1000,
  'lon': 11 + lon / 1000,
  'tags': {'aerialway': 'station', 'name': ?name, 'aerialway:access': ?access},
};

LatLng _at(double lat, double lon) => LatLng(47 + lat / 1000, 11 + lon / 1000);

SkiGraph _graph(List<Map<String, Object?>> elements) =>
    SkiGraph.build(parseSkiNetwork({'elements': elements}));

List<SegmentKind> _kinds(RoutedPath path) => [
  for (final segment in path.segments!) segment.kind,
];

Matcher _refusedAs(RouteEngineFailure failure) => throwsA(
  isA<RouteEngineException>().having((e) => e.failure, 'failure', failure),
);

void main() {
  group('parseSkiNetwork', () {
    test('reads pistes, lifts and stations, and leaves out the rest', () {
      final network = parseSkiNetwork({
        'elements': [
          _way(
            1,
            [(1, 0, 0), (2, 10, 0)],
            {
              'aerialway': 'chair_lift',
              'name': 'Sonnenbahn',
              'aerialway:duration': '3:10',
            },
          ),
          _way(
            2,
            [(2, 10, 0), (3, 5, 1), (1, 0, 0)],
            {
              'piste:type': 'downhill',
              'piste:name': 'Sonnenhang',
              'name': 'Way name',
              'piste:difficulty': 'intermediate',
            },
          ),
          _way(
            3,
            [(4, 0, 0), (5, 1, 0), (6, 1, 1), (4, 0, 0)],
            {'piste:type': 'downhill', 'area': 'yes'},
          ),
          _way(4, [(7, 0, 0), (8, 3, 0)], {'aerialway': 'zip_line'}),
          _way(5, [(9, 0, 0)], {'piste:type': 'downhill'}),
          _way(6, [(10, 0, 0), (11, 1, 0)], {'piste:type': 'nordic'}),
          _station(2, 10, 0, 'Bergstation'),
          _station(1, 0, 0),
        ],
      });

      expect(network.ways.map((w) => w.id), [1, 2]);
      final [lift, piste] = network.ways;
      expect(lift.kind, SkiWayKind.lift);
      expect(lift.liftMode, TransportMode.chairLift);
      expect(lift.name, 'Sonnenbahn');
      expect(lift.duration, const Duration(minutes: 3, seconds: 10));
      expect(piste.kind, SkiWayKind.downhill);
      expect(piste.name, 'Sonnenhang', reason: 'piste:name comes first');
      expect(piste.difficulty, PisteDifficulty.intermediate);
      expect(piste.liftMode, isNull);
      expect(network.stations.keys, [2, 1]);
      expect(network.stations[2]!.name, 'Bergstation');
      expect(network.stations[1]!.name, isNull);
    });

    test('a way with a node lacking coordinates is left out', () {
      final network = parseSkiNetwork({
        'elements': [
          {
            'type': 'way',
            'id': 1,
            'nodes': [1, 2],
            'geometry': [
              {'lat': 47, 'lon': 11},
              null,
            ],
            'tags': {'piste:type': 'downhill'},
          },
        ],
      });

      expect(network.ways, isEmpty);
    });

    test('an answer that is not one is a FormatException', () {
      expect(() => parseSkiNetwork('nope'), throwsFormatException);
      expect(() => parseSkiNetwork({'remark': 'x'}), throwsFormatException);
    });

    test('files each lift kind under its mode', () {
      TransportMode? modeOf(String aerialway) => SkiWay(
        id: 1,
        kind: SkiWayKind.lift,
        nodes: const [],
        points: const [],
        aerialway: aerialway,
      ).liftMode;

      expect(modeOf('gondola'), TransportMode.gondola);
      expect(modeOf('cable_car'), TransportMode.gondola);
      expect(modeOf('mixed_lift'), TransportMode.gondola);
      expect(modeOf('chair_lift'), TransportMode.chairLift);
      for (final drag in [
        'drag_lift',
        't-bar',
        'j-bar',
        'platter',
        'rope_tow',
        'magic_carpet',
      ]) {
        expect(modeOf(drag), TransportMode.dragLift, reason: drag);
      }
    });
  });

  test('parseAerialwayDuration reads minutes and clock times', () {
    expect(parseAerialwayDuration('8'), const Duration(minutes: 8));
    expect(parseAerialwayDuration('8.5'), const Duration(seconds: 510));
    expect(parseAerialwayDuration('3:10'), const Duration(seconds: 190));
    expect(
      parseAerialwayDuration('1:02:03'),
      const Duration(hours: 1, minutes: 2, seconds: 3),
    );
    for (final odd in [null, '', 'fast', '0', '-3', '1:x', '1:2:3:4', '0:00']) {
      expect(parseAerialwayDuration(odd), isNull, reason: '$odd');
    }
  });

  test('the query asks for the box, pistes, ridden lifts and stations', () {
    final query = skiNetworkQuery(
      south: 47.43,
      west: 11.03,
      north: 47.48,
      east: 11.12,
    );

    expect(query, contains('[bbox:47.43000,11.03000,47.48000,11.12000]'));
    expect(query, contains('piste:type"~"^(downhill|connection)\$"'));
    expect(query, contains('chair_lift'));
    expect(query, isNot(contains('zip_line')));
    expect(query, contains('node["aerialway"="station"]'));
    expect(query, endsWith('out body geom qt;'));
  });

  group('SkiGraph', () {
    // A lift from the valley (node 1) to the top (node 2), and a piste back.
    List<Map<String, Object?>> valleyAndTop({
      String aerialway = 'chair_lift',
      Map<String, String> liftTags = const {},
      bool piste = true,
    }) => [
      _way(
        1,
        [(1, 0, 0), (2, 10, 0)],
        {'aerialway': aerialway, 'name': 'Bahn', ...liftTags},
      ),
      if (piste)
        _way(
          2,
          [(2, 10, 0), (3, 5, 2), (1, 0, 0)],
          {'piste:type': 'downhill', 'name': 'Talabfahrt'},
        ),
      _station(1, 0, 0, 'Tal'),
      _station(2, 10, 0, 'Berg'),
    ];

    test('rides up and skis down, each a segment of its own', () {
      final graph = _graph(valleyAndTop());

      final path = graph.route([_at(0, 0), _at(10, 0), _at(0, 0)]);

      expect(_kinds(path), [SegmentKind.lift, SegmentKind.descent]);
      final [ride, descent] = path.segments!;
      expect(ride.liftMode, TransportMode.chairLift);
      expect(ride.name, 'Bahn');
      expect((ride.fromName, ride.toName), ('Tal', 'Berg'));
      expect(descent.name, 'Talabfahrt');
      expect((descent.fromName, descent.toName), ('Berg', 'Tal'));
      expect(path.waypointIndices, [0, ride.end, path.points.length - 1]);
      expect(path.points.first, _at(0, 0));
      expect(path.points.last, _at(0, 0));
      expect(
        path.duration,
        Duration(
          seconds: path.segments!.fold(0, (s, e) => s + e.duration.inSeconds),
        ),
      );
    });

    test('a descent keeps the grade of each piste it runs down', () {
      final graph = _graph([
        _way(1, [(1, 0, 0), (2, 10, 0)], {'aerialway': 'chair_lift'}),
        // One piste in two ways, as the map data often has it.
        _way(
          2,
          [(2, 10, 0), (3, 6, 1)],
          {
            'piste:type': 'downhill',
            'name': 'Oben',
            'piste:difficulty': 'intermediate',
          },
        ),
        _way(
          3,
          [(3, 6, 1), (4, 3, 1)],
          {
            'piste:type': 'downhill',
            'name': 'Oben',
            'piste:difficulty': 'intermediate',
          },
        ),
        _way(
          4,
          [(4, 3, 1), (1, 0, 0)],
          {'piste:type': 'downhill', 'piste:difficulty': 'advanced'},
        ),
      ]);

      final path = graph.route([_at(0, 0), _at(10, 0), _at(0, 0)]);

      final [ride, descent] = path.segments!;
      expect(ride.pistes, isEmpty);
      expect(descent.pistes, const [
        PisteStretch(name: 'Oben', difficulty: PisteDifficulty.intermediate),
        PisteStretch(difficulty: PisteDifficulty.advanced),
      ]);
    });

    test('the way from one lift to the next is part of the next ride', () {
      final graph = _graph([
        _way(1, [(1, 0, 0), (2, 10, 0)], {'aerialway': 'chair_lift'}),
        // About 100 m of piste from the top station to the next lift.
        _way(2, [(2, 10, 0), (3, 9.5, 1)], {'piste:type': 'downhill'}),
        _way(
          3,
          [(3, 9.5, 1), (4, 20, 1)],
          {'aerialway': 'gondola', 'name': 'Bahn'},
        ),
        _station(3, 9.5, 1, 'Fürggli'),
      ]);

      final path = graph.route([_at(0, 0), _at(20, 1)]);

      expect(_kinds(path), [SegmentKind.lift, SegmentKind.lift]);
      final [chair, gondola] = path.segments!;
      expect(gondola.start, chair.end);
      expect(path.points[gondola.start], _at(10, 0));
      expect((gondola.name, gondola.fromName), ('Bahn', 'Fürggli'));
      expect(
        path.duration,
        Duration(
          seconds: chair.duration.inSeconds + gondola.duration.inSeconds,
        ),
      );
    });

    test('a ride takes its tagged time and the time to get on', () {
      final graph = _graph(valleyAndTop(liftTags: {'aerialway:duration': '6'}));

      final ride = graph.route([_at(0, 0), _at(10, 0)]).segments!.single;

      expect(ride.duration, const Duration(minutes: 6) + kBoardingTime);
    });

    test('a drag lift is never ridden down', () {
      final graph = _graph(valleyAndTop(aerialway: 't-bar', piste: false));

      expect(
        () => graph.route([_at(10, 0), _at(0, 0)]),
        _refusedAs(RouteEngineFailure.noRoute),
      );
    });

    test('a chairlift goes down only when tagged so', () {
      expect(
        () => _graph(valleyAndTop(piste: false)).route([_at(10, 0), _at(0, 0)]),
        _refusedAs(RouteEngineFailure.noRoute),
      );

      final down = _graph(
        valleyAndTop(piste: false, liftTags: {'oneway': 'no'}),
      ).route([_at(10, 0), _at(0, 0)]);
      expect(down.segments!.single.kind, SegmentKind.lift);
      expect(down.points.first, _at(10, 0));
    });

    test('a gondola is ridden down where no piste leads', () {
      final graph = _graph(valleyAndTop(aerialway: 'gondola', piste: false));

      final down = graph.route([_at(10, 0), _at(0, 0)]);

      expect(down.segments!.single.liftMode, TransportMode.gondola);
      expect(
        () => _graph(
          valleyAndTop(
            aerialway: 'gondola',
            piste: false,
            liftTags: {'oneway': 'yes'},
          ),
        ).route([_at(10, 0), _at(0, 0)]),
        _refusedAs(RouteEngineFailure.noRoute),
      );
    });

    test('a gondola is not ridden down where a piste leads', () {
      // The piste is longer than the ride, and skied anyway.
      final graph = _graph(valleyAndTop(aerialway: 'gondola'));

      final down = graph.route([_at(10, 0), _at(0, 0)]);

      expect(_kinds(down), [SegmentKind.descent]);
    });

    test('a piste drawn the other way is not skied uphill', () {
      final graph = _graph([
        _way(1, [(1, 0, 0), (2, 10, 0)], {'piste:type': 'downhill'}),
      ]);

      expect(
        () => graph.route([_at(10, 0), _at(0, 0)]),
        _refusedAs(RouteEngineFailure.noRoute),
      );
      expect(
        _kinds(
          _graph([
            _way(
              1,
              [(1, 0, 0), (2, 10, 0)],
              {'piste:type': 'downhill', 'oneway': '-1'},
            ),
          ]).route([_at(10, 0), _at(0, 0)]),
        ),
        [SegmentKind.descent],
      );
    });

    test('a short walk from the piste to the lift is part of the descent', () {
      final graph = _graph([
        _way(1, [(1, 0, 0), (2, 10, 0)], {'aerialway': 'drag_lift'}),
        // Ends about 40 m beside the valley station, not at it.
        _way(2, [(2, 10, 0), (3, 0, 0.5)], {'piste:type': 'downhill'}),
      ]);

      final path = graph.route([_at(10, 0), _at(0, 0), _at(10, 0)]);

      expect(_kinds(path), [SegmentKind.descent, SegmentKind.lift]);
      expect(path.segments!.first.lengthMeters, greaterThan(1110));
    });

    test('a walk between two pistes is part of the descent', () {
      List<Map<String, Object?>> apart(double lon) => [
        _way(1, [(1, 10, 0), (2, 0, 0)], {'piste:type': 'downhill'}),
        _way(2, [(3, 0, lon), (4, -10, lon)], {'piste:type': 'downhill'}),
      ];

      // About 113 m of longitude between the two at this latitude.
      final walked = _graph(apart(1.5)).route([_at(10, 0), _at(-10, 1.5)]);
      expect(_kinds(walked), [SegmentKind.descent]);
      expect(walked.lengthMeters, closeTo(2 * 1112 + 113, 5));

      // Too far to walk in ski boots across a slope the map knows nothing of.
      expect(
        () => _graph(apart(3)).route([_at(10, 0), _at(-10, 3)]),
        _refusedAs(RouteEngineFailure.noRoute),
      );
    });

    test('a walk from a waypoint far off the piste is a leg of its own', () {
      final graph = _graph(valleyAndTop());

      // About 300 m east of the valley station.
      final path = graph.route([_at(0, 4), _at(10, 0)]);

      expect(_kinds(path), [SegmentKind.walk, SegmentKind.lift]);
      expect(path.points.first, _at(0, 4));
      expect(path.segments!.first.duration.inSeconds, closeTo(300 / 0.8, 10));
    });

    test('takes two waypoints or more', () {
      expect(
        () => _graph(valleyAndTop()).route([_at(0, 0)]),
        throwsArgumentError,
      );
    });

    test('two waypoints on one spot are a way of no length', () {
      final path = _graph(valleyAndTop()).route([_at(0, 0), _at(0, 0)]);

      expect(_kinds(path), [SegmentKind.walk]);
      expect(path.lengthMeters, 0);
    });

    test('a waypoint off every piste is refused', () {
      final graph = _graph(valleyAndTop());

      expect(
        () => graph.route([_at(0, 0), _at(100, 0)]),
        _refusedAs(RouteEngineFailure.noRoute),
      );
    });

    test('a piste harder than allowed is skied around', () {
      final graph = _graph([
        _way(1, [(1, 0, 0), (2, 10, 0)], {'aerialway': 'chair_lift'}),
        // Straight down, black.
        _way(
          2,
          [(2, 10, 0), (1, 0, 0)],
          {
            'piste:type': 'downhill',
            'piste:difficulty': 'advanced',
            'name': 'Steil',
          },
        ),
        // A long way round, blue.
        _way(
          3,
          [(2, 10, 0), (3, 5, 8), (1, 0, 0)],
          {
            'piste:type': 'downhill',
            'piste:difficulty': 'easy',
            'name': 'Familie',
          },
        ),
      ]);

      expect(
        graph.route([_at(10, 0), _at(0, 0)]).segments!.single.name,
        'Steil',
      );
      expect(
        graph
            .route([
              _at(10, 0),
              _at(0, 0),
            ], maxDifficulty: PisteDifficulty.intermediate)
            .segments!
            .single
            .name,
        'Familie',
      );
    });

    test('a station in the middle of a lift is a place to get off', () {
      final graph = _graph([
        _way(
          1,
          [(1, 0, 0), (2, 5, 0), (3, 10, 0)],
          {'aerialway': 'gondola', 'name': 'Bahn'},
        ),
        _station(2, 5, 0, 'Mittelstation'),
        // From the middle station across.
        _way(2, [(2, 5, 0), (4, 4, 5)], {'piste:type': 'downhill'}),
      ]);

      final path = graph.route([_at(0, 0), _at(4, 5)]);

      expect(_kinds(path), [SegmentKind.lift, SegmentKind.descent]);
      expect(path.segments!.first.toName, 'Mittelstation');
    });
  });

  group('a station in the middle tagged', () {
    SkiGraph lift(String access) => _graph([
      _way(1, [(1, 0, 0), (2, 5, 0), (3, 10, 0)], {'aerialway': 'chair_lift'}),
      _station(2, 5, 0, 'Mitte', access),
      _way(2, [(2, 5, 0), (4, 4, 5)], {'piste:type': 'downhill'}),
      _way(3, [(5, 6, 5), (2, 5, 0)], {'piste:type': 'downhill'}),
    ]);

    test('exit lets riders off but not on', () {
      final graph = lift('exit');

      expect(_kinds(graph.route([_at(0, 0), _at(4, 5)])), [
        SegmentKind.lift,
        SegmentKind.descent,
      ]);
      expect(
        () => graph.route([_at(6, 5), _at(10, 0)]),
        _refusedAs(RouteEngineFailure.noRoute),
      );
    });

    test('entry lets riders on but not off', () {
      final graph = lift('entry');

      expect(_kinds(graph.route([_at(6, 5), _at(10, 0)])), [
        SegmentKind.descent,
        SegmentKind.lift,
      ]);
      expect(
        () => graph.route([_at(0, 0), _at(4, 5)]),
        _refusedAs(RouteEngineFailure.noRoute),
      );
    });

    test('no is no station at all', () {
      expect(
        () => lift('no').route([_at(0, 0), _at(4, 5)]),
        _refusedAs(RouteEngineFailure.noRoute),
      );
    });
  });

  group('a real ski area', () {
    // An Overpass answer for the Garmisch-Classic area, recorded once on
    // 2026-11-21. Map data © OpenStreetMap contributors, ODbL.
    late SkiGraph graph;
    setUpAll(() {
      final json = jsonDecode(
        File('test/fixtures/overpass_garmisch_classic.json').readAsStringSync(),
      );
      graph = SkiGraph.build(parseSkiNetwork(json));
    });

    const kreuzeckValley = LatLng(47.4715, 11.0637);
    const kreuzeckTop = LatLng(47.4523, 11.0671);
    const hausbergValley = LatLng(47.4818, 11.0947);
    const osterfelderkopf = LatLng(47.4393, 11.0510);

    test('up the Kreuzeckbahn and down to the Hausberg', () {
      final path = graph.route([kreuzeckValley, kreuzeckTop, hausbergValley]);

      expect(_kinds(path), [SegmentKind.lift, SegmentKind.descent]);
      final [ride, descent] = path.segments!;
      expect(ride.name, 'Kreuzeckbahn');
      expect(ride.liftMode, TransportMode.gondola);
      expect(descent.name, contains('Horn-Abfahrt'));
      expect(path.waypointIndices, [0, ride.end, path.points.length - 1]);
      expect(path.lengthMeters, closeTo(7342, 50));
    });

    test('from the top to the valley it skis rather than rides down', () {
      final path = graph.route([osterfelderkopf, kreuzeckValley]);

      expect(
        path.segments!
            .where((s) => s.kind == SegmentKind.lift)
            .map((s) => s.name),
        isNot(contains('Alpspitzbahn')),
      );
      expect(path.segments!.first.name, startsWith('Osterfelder-Abfahrt'));
    });

    test('from the valley up to the Osterfelderkopf, through the area', () {
      final path = graph.route([hausbergValley, osterfelderkopf]);

      final rides = [
        for (final s in path.segments!)
          if (s.kind == SegmentKind.lift) s.name,
      ];
      expect(rides.first, 'Hausbergbahn');
      expect(rides.last, 'Alpspitzbahn');
      expect(path.segments!.last.toName, 'Bergstation Alpspitzbahn');
    });
  });
}
