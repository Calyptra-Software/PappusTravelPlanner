import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../../../data/database/tables.dart';
import '../../../map/map_features.dart';
import '../../application/route_engine.dart';
import '../../domain/piste_difficulty.dart';
import '../../domain/routed_path.dart';
import 'ski_network.dart';

/// How fast a skier comes down a piste, stops and all, in meters per second:
/// 18 km/h. A guess for somebody the app knows nothing about, as every
/// duration the planner gives is.
const double kDescentSpeed = 5;

/// A connection is mostly a flat track between two pistes: 11 km/h.
const double kConnectionSpeed = 3;

/// Walking in ski boots, skis on the shoulder: 3 km/h.
const double kSkiWalkSpeed = 0.8;

/// How much worse than its minutes a walk counts when the router weighs one
/// way against another, so that it walks only where skiing or a lift would
/// not do: a minute's walk weighs as three minutes on the snow.
const double kWalkPenalty = 3;

/// How much worse than its minutes a ride **down** a lift counts: a skier
/// came to ski down, so the router rides down only where no piste leads, or
/// one that does is a long way round.
const double kRideDownPenalty = 3;

/// The time a lift ride costs beyond the ride itself: queuing and getting on.
const Duration kBoardingTime = Duration(minutes: 2);

/// How far a skier walks between a piste and a lift (or another piste) whose
/// lines the map data leaves unjoined. Farther than that the router finds no
/// way rather than send somebody across a slope it knows nothing about.
const double kMaxWalkMeters = 150;

/// How far a waypoint may lie from every piste and lift and still be taken to
/// mean the nearest of them.
const double kMaxSnapMeters = 500;

/// Within this of a waypoint, every piste and lift node counts as a way to
/// start from or arrive at, weighed by the walk to it, not only the nearest.
const double kSnapRadiusMeters = 100;

/// A walk shorter than this is not a leg of its own but part of the descent
/// (or the ride) beside it: thirty meters from the end of a piste to the lift
/// is nothing anybody would write down.
const double kFoldWalkMeters = 200;

/// A descent shorter than this is folded the same way: the few meters of
/// piste from a lift station to the point somebody tapped.
const double kFoldDescentMeters = 50;

const Distance _distance = Distance(calculator: Haversine());

double _meters(LatLng a, LatLng b) => _distance.as(LengthUnit.Meter, a, b);

/// The speed a lift kind runs at, in meters per second, for a lift whose map
/// entry has no `aerialway:duration`. Typical figures, not anybody's
/// timetable.
double _liftSpeed(String? aerialway) => switch (aerialway) {
  'cable_car' => 8,
  'gondola' || 'mixed_lift' => 5,
  'chair_lift' => 2.5,
  'rope_tow' => 2,
  'magic_carpet' => 0.6,
  _ => 3,
};

/// One way to go from a node to another.
class _Edge {
  const _Edge({
    required this.to,
    required this.seconds,
    required this.meters,
    required this.points,
    required this.kind,
    this.way,
    this.down = false,
  });

  final int to;
  final double seconds;
  final double meters;

  /// The line from the edge's start to its end, both included.
  final List<LatLng> points;
  final SegmentKind kind;

  /// The way the edge runs along; null for a walk.
  final SkiWay? way;

  /// Whether the edge rides a lift downhill.
  final bool down;

  /// What the router weighs the edge by.
  double get cost => switch (kind) {
    SegmentKind.walk => seconds * kWalkPenalty,
    SegmentKind.lift when down => seconds * kRideDownPenalty,
    _ => seconds,
  };
}

/// A way [SkiGraph.find] found: the path, and for each of its points whether
/// it hangs on a lift's cable. A lift's line runs over its pylons, where the
/// ground is no height of the ride's (`levelAloft`).
class SkiRoute {
  SkiRoute(this.path, this.aloft) : assert(aloft.length == path.points.length);

  final RoutedPath path;
  final List<bool> aloft;
}

/// The pistes and lifts of an area as a graph a ski day is routed through.
///
/// A node is an OSM node on a piste, or a station of a lift: its two ends and
/// any `aerialway=station` node along it. Ways that share a node meet there.
/// The edges:
///
/// - A **piste** goes from each of its nodes to the next, in the direction it
///   is drawn, which for a downhill piste is downhill and for a connection the
///   way it is skied; `oneway=no` makes it both ways, `oneway=-1` turns it.
/// - A **lift** goes from each station to every station above it. A gondola
///   or cable car goes down as well, since one can ride it down, unless it is
///   tagged `oneway=yes`; a chairlift only with `oneway=no`; a drag lift never.
/// - A **walk** joins each end of a piste and each lift station to the nearest
///   node of every other way within [kMaxWalkMeters], both ways: the map data
///   often stops a piste a few meters short of the lift it leads to.
class SkiGraph {
  SkiGraph._(this._positions, this._edges, this._stationNames, this._grid);

  /// Builds the graph of [network].
  factory SkiGraph.build(SkiNetwork network) {
    final index = <int, int>{};
    final positions = <LatLng>[];
    final osmIds = <int>[];
    int nodeOf(int osmId, LatLng position) => index.putIfAbsent(osmId, () {
      positions.add(position);
      osmIds.add(osmId);
      return positions.length - 1;
    });

    final edges = <List<_Edge>>[];
    void grow() {
      while (edges.length < positions.length) {
        edges.add([]);
      }
    }

    // The graph nodes on each way, by way, for the walks.
    final nodesOfWay = <List<int>>[];
    // Ends of pistes and lift stations: where a walk starts.
    final walkStarts = <(int node, int way)>[];

    for (final (wayIndex, way) in network.ways.indexed) {
      final onWay = <int>[];
      if (way.kind == SkiWayKind.lift) {
        // Both ends, and every station between them one can use. An end
        // counts whatever it is tagged: a lift nobody could board at either
        // end is a tagging slip, not a lift.
        final last = way.nodes.length - 1;
        final stops = <({int index, bool entry, bool exit})>[];
        for (var i = 0; i <= last; i++) {
          final station = network.stations[way.nodes[i]];
          if (i == 0 || i == last) {
            stops.add((index: i, entry: true, exit: true));
          } else if (station != null && (station.entry || station.exit)) {
            stops.add((index: i, entry: station.entry, exit: station.exit));
          }
        }
        for (final stop in stops) {
          onWay.add(nodeOf(way.nodes[stop.index], way.points[stop.index]));
        }
        grow();
        _addLift(way, stops, onWay, edges);
        for (final node in onWay) {
          walkStarts.add((node, wayIndex));
        }
      } else {
        for (var i = 0; i < way.nodes.length; i++) {
          onWay.add(nodeOf(way.nodes[i], way.points[i]));
        }
        grow();
        _addPiste(way, onWay, edges);
        walkStarts
          ..add((onWay.first, wayIndex))
          ..add((onWay.last, wayIndex));
      }
      nodesOfWay.add(onWay);
    }

    final grid = _Grid(positions);
    final waysAtNode = List<Set<int>>.generate(positions.length, (_) => {});
    for (final (wayIndex, nodes) in nodesOfWay.indexed) {
      for (final node in nodes) {
        waysAtNode[node].add(wayIndex);
      }
    }
    final walked = <(int, int)>{};
    for (final (start, ownWay) in walkStarts) {
      final nearest = <int, (int node, double meters)>{};
      for (final node in grid.near(positions[start], kMaxWalkMeters)) {
        if (node == start) continue;
        final meters = _meters(positions[start], positions[node]);
        if (meters > kMaxWalkMeters) continue;
        for (final way in waysAtNode[node]) {
          if (way == ownWay || waysAtNode[start].contains(way)) continue;
          final best = nearest[way];
          if (best == null || meters < best.$2) nearest[way] = (node, meters);
        }
      }
      for (final (node, meters) in nearest.values) {
        final pair = start < node ? (start, node) : (node, start);
        if (!walked.add(pair)) continue;
        final seconds = meters / kSkiWalkSpeed;
        edges[start].add(
          _Edge(
            to: node,
            seconds: seconds,
            meters: meters,
            points: [positions[start], positions[node]],
            kind: SegmentKind.walk,
          ),
        );
        edges[node].add(
          _Edge(
            to: start,
            seconds: seconds,
            meters: meters,
            points: [positions[node], positions[start]],
            kind: SegmentKind.walk,
          ),
        );
      }
    }

    return SkiGraph._(positions, edges, {
      for (final (node, osmId) in osmIds.indexed)
        node: ?network.stations[osmId]?.name,
    }, grid);
  }

  static void _addPiste(SkiWay way, List<int> nodes, List<List<_Edge>> edges) {
    final speed = way.kind == SkiWayKind.connection
        ? kConnectionSpeed
        : kDescentSpeed;
    final forward = way.oneway != SkiOneway.reverse;
    final backward =
        way.oneway == SkiOneway.no || way.oneway == SkiOneway.reverse;
    for (var i = 1; i < nodes.length; i++) {
      final a = way.points[i - 1];
      final b = way.points[i];
      final meters = _meters(a, b);
      if (forward) {
        edges[nodes[i - 1]].add(
          _Edge(
            to: nodes[i],
            seconds: meters / speed,
            meters: meters,
            points: [a, b],
            kind: SegmentKind.descent,
            way: way,
          ),
        );
      }
      if (backward) {
        edges[nodes[i]].add(
          _Edge(
            to: nodes[i - 1],
            seconds: meters / speed,
            meters: meters,
            points: [b, a],
            kind: SegmentKind.descent,
            way: way,
          ),
        );
      }
    }
  }

  static void _addLift(
    SkiWay way,
    List<({int index, bool entry, bool exit})> stops,
    List<int> nodes,
    List<List<_Edge>> edges,
  ) {
    final total = lineLength(way.points);
    final rideSeconds =
        way.duration?.inSeconds.toDouble() ?? total / _liftSpeed(way.aerialway);
    final bothWays = switch (way.liftMode) {
      TransportMode.gondola => way.oneway != SkiOneway.yes,
      TransportMode.chairLift => way.oneway == SkiOneway.no,
      _ => false,
    };
    final up = way.oneway != SkiOneway.reverse;
    final down = bothWays || way.oneway == SkiOneway.reverse;
    for (var a = 0; a < stops.length; a++) {
      for (var b = a + 1; b < stops.length; b++) {
        final line = way.points.sublist(stops[a].index, stops[b].index + 1);
        final meters = lineLength(line);
        final share = total == 0 ? 1.0 : meters / total;
        final seconds = rideSeconds * share + kBoardingTime.inSeconds;
        if (up && stops[a].entry && stops[b].exit) {
          edges[nodes[a]].add(
            _Edge(
              to: nodes[b],
              seconds: seconds,
              meters: meters,
              points: line,
              kind: SegmentKind.lift,
              way: way,
            ),
          );
        }
        if (down && stops[b].entry && stops[a].exit) {
          edges[nodes[b]].add(
            _Edge(
              to: nodes[a],
              seconds: seconds,
              meters: meters,
              points: line.reversed.toList(),
              kind: SegmentKind.lift,
              way: way,
              down: true,
            ),
          );
        }
      }
    }
  }

  final List<LatLng> _positions;
  final List<List<_Edge>> _edges;
  final Map<int, String> _stationNames;
  final _Grid _grid;

  /// The way through [waypoints] in order, skiing no piste harder than
  /// [maxDifficulty]. A piste without a grade is taken.
  ///
  /// Each waypoint is taken to mean the pistes and lifts around it (see
  /// [kSnapRadiusMeters]); the path starts at the first waypoint and ends at
  /// the last, and passes the others where it came nearest them.
  ///
  /// Throws [RouteEngineException] with [RouteEngineFailure.noRoute] when a
  /// waypoint lies off every piste and lift, or no way leads on to the next.
  RoutedPath route(
    List<LatLng> waypoints, {
    PisteDifficulty maxDifficulty = PisteDifficulty.standard,
  }) => find(waypoints, maxDifficulty: maxDifficulty).path;

  /// [route], with which points of the path hang on a lift's cable.
  SkiRoute find(
    List<LatLng> waypoints, {
    PisteDifficulty maxDifficulty = PisteDifficulty.standard,
  }) {
    if (waypoints.length < 2) {
      throw ArgumentError.value(waypoints, 'waypoints', 'needs two or more');
    }
    final steps = <_Edge>[];
    final reached = <int>[];
    int? from;
    for (var i = 1; i < waypoints.length; i++) {
      final sources = from == null ? _snap(waypoints[i - 1]) : {from: 0.0};
      final targets = _snap(waypoints[i]);
      final found = _search(sources, targets, maxDifficulty);
      if (found == null) {
        throw const RouteEngineException.local(
          'No way over the pistes',
          RouteEngineFailure.noRoute,
        );
      }
      if (from == null) reached.add(found.start);
      steps.addAll(found.edges);
      reached.add(found.end);
      from = found.end;
    }
    return _assemble(waypoints, steps, reached);
  }

  /// The nodes a skier at [point] can start from or arrive at, with what the
  /// walk there costs. Throws when there are none within [kMaxSnapMeters].
  Map<int, double> _snap(LatLng point) {
    final near = <int, double>{};
    int? nearest;
    var nearestMeters = double.infinity;
    for (final node in _grid.near(point, kMaxSnapMeters)) {
      final meters = _meters(point, _positions[node]);
      if (meters < nearestMeters) {
        nearest = node;
        nearestMeters = meters;
      }
      if (meters <= kSnapRadiusMeters) near[node] = meters;
    }
    if (nearest == null || nearestMeters > kMaxSnapMeters) {
      throw const RouteEngineException.local(
        'No piste or lift near a waypoint',
        RouteEngineFailure.noRoute,
      );
    }
    if (near.isEmpty) near[nearest] = nearestMeters;
    return {
      for (final MapEntry(key: node, value: meters) in near.entries)
        node: meters / kSkiWalkSpeed * kWalkPenalty,
    };
  }

  /// Dijkstra from [sources] to the cheapest of [targets], each with what
  /// reaching it from its waypoint costs.
  ({int start, int end, List<_Edge> edges})? _search(
    Map<int, double> sources,
    Map<int, double> targets,
    PisteDifficulty maxDifficulty,
  ) {
    final cost = <int, double>{};
    final via = <int, (int from, _Edge edge)>{};
    final heap = _Heap();
    for (final MapEntry(key: node, value: start) in sources.entries) {
      cost[node] = start;
      heap.push(start, node);
    }
    var best = double.infinity;
    int? end;
    final done = <int>{};
    while (heap.isNotEmpty) {
      final (spent, node) = heap.pop();
      if (spent >= best) break;
      if (!done.add(node)) continue;
      if (targets[node] case final arrival?) {
        if (spent + arrival < best) {
          best = spent + arrival;
          end = node;
        }
      }
      for (final edge in _edges[node]) {
        if (!_allowed(edge, maxDifficulty)) continue;
        final next = spent + edge.cost;
        if (next < (cost[edge.to] ?? double.infinity)) {
          cost[edge.to] = next;
          via[edge.to] = (node, edge);
          heap.push(next, edge.to);
        }
      }
    }
    if (end == null) return null;
    final edges = <_Edge>[];
    var node = end;
    for (var step = via[node]; step != null; step = via[node]) {
      edges.add(step.$2);
      node = step.$1;
    }
    return (start: node, end: end, edges: edges.reversed.toList());
  }

  static bool _allowed(_Edge edge, PisteDifficulty maxDifficulty) {
    if (edge.kind != SegmentKind.descent) return true;
    final difficulty = edge.way?.difficulty;
    return difficulty == null || difficulty.index <= maxDifficulty.index;
  }

  /// Lays [steps] out as one line with its segments: consecutive descents are
  /// one descent, each lift ride is one, a short walk is folded into the
  /// descent or ride beside it ([kFoldWalkMeters]), and the way from one lift
  /// to the next into the next ([foldTransfers]).
  SkiRoute _assemble(
    List<LatLng> waypoints,
    List<_Edge> steps,
    List<int> reached,
  ) {
    // The walk from a waypoint to the node it was taken to mean, and from the
    // last node to the last waypoint: part of the way, if a short one.
    final first = _positions[reached.first];
    final last = _positions[reached.last];
    final parts = <_Part>[
      if (_meters(waypoints.first, first) > 1)
        _Part.walk(waypoints.first, first, fromName: null, toName: null),
    ];
    var node = reached.first;
    for (final edge in steps) {
      final kind = edge.kind;
      final previous = parts.lastOrNull;
      final joins =
          previous != null && previous.kind == kind && kind != SegmentKind.lift;
      if (joins) {
        previous.add(edge);
      } else {
        parts.add(_Part(edge, fromName: _stationNames[node]));
      }
      parts.last.toName = _stationNames[edge.to];
      node = edge.to;
    }
    if (_meters(last, waypoints.last) > 1) {
      parts.add(_Part.walk(last, waypoints.last, fromName: null, toName: null));
    }
    if (parts.isEmpty) {
      // Both waypoints at one node: a way of no length.
      parts.add(_Part.walk(waypoints.first, waypoints.last));
    }
    _foldWalks(parts);

    final points = <LatLng>[];
    final aloft = <bool>[];
    final segments = <PathSegment>[];
    // Where each step's end lies along [points], to find the waypoints again.
    for (final part in parts) {
      final start = points.isEmpty ? 0 : points.length - 1;
      points.addAll(points.isEmpty ? part.points : part.points.skip(1));
      aloft.addAll(aloft.isEmpty ? part.aloft : part.aloft.skip(1));
      segments.add(
        PathSegment(
          start: start,
          end: points.length - 1,
          kind: part.kind,
          lengthMeters: part.meters,
          duration: Duration(seconds: part.seconds.round()),
          liftMode: part.kind == SegmentKind.lift ? part.way!.liftMode : null,
          name: part.name,
          fromName: part.fromName,
          toName: part.toName,
          pistes: part.kind == SegmentKind.descent ? part.pistes : const [],
        ),
      );
    }
    final path = RoutedPath(
      points: points,
      lengthMeters: segments.fold(0, (sum, s) => sum + s.lengthMeters),
      duration: Duration(
        seconds: segments.fold(0, (sum, s) => sum + s.duration.inSeconds),
      ),
      segments: foldTransfers(segments),
      waypointIndices: _waypointIndices(points, reached),
    );
    return SkiRoute(path, aloft);
  }

  /// Where along [points] each node of [reached] is passed, in order.
  List<int> _waypointIndices(List<LatLng> points, List<int> reached) {
    final indices = <int>[];
    var from = 0;
    for (final (k, node) in reached.indexed) {
      final position = _positions[node];
      var found = -1;
      for (var i = from; i < points.length; i++) {
        if (points[i] == position) {
          found = i;
          break;
        }
      }
      // The first and last waypoints are the line's ends, whatever node they
      // were taken to mean.
      if (k == 0) found = 0;
      if (k == reached.length - 1) found = points.length - 1;
      if (found < 0) found = from;
      indices.add(found);
      from = found;
    }
    return indices;
  }

  /// Folds each walk shorter than [kFoldWalkMeters], and each descent shorter
  /// than [kFoldDescentMeters], into a neighbor: the descent before it, else
  /// the descent after it, else whatever is before it, else whatever is after
  /// it. A part that is all there is stays.
  static void _foldWalks(List<_Part> parts) {
    bool short(_Part part) => switch (part.kind) {
      SegmentKind.walk => part.meters < kFoldWalkMeters,
      SegmentKind.descent => part.meters < kFoldDescentMeters,
      SegmentKind.lift => false,
    };
    var i = 0;
    while (i < parts.length) {
      final part = parts[i];
      if (!short(part) || parts.length == 1) {
        i++;
        continue;
      }
      final before = i > 0 ? parts[i - 1] : null;
      final after = i + 1 < parts.length ? parts[i + 1] : null;
      if (before?.kind == SegmentKind.descent ||
          (after?.kind != SegmentKind.descent && before != null)) {
        before!.append(part);
        parts.removeAt(i);
      } else {
        after!.prepend(part);
        parts.removeAt(i);
      }
      // A descent may now meet another descent across the folded walk.
      if (i > 0 &&
          i < parts.length &&
          parts[i - 1].kind == SegmentKind.descent &&
          parts[i].kind == SegmentKind.descent) {
        parts[i - 1].append(parts.removeAt(i));
      }
    }
  }
}

/// A segment while it is being put together.
class _Part {
  _Part(_Edge edge, {this.fromName})
    : kind = edge.kind,
      way = edge.way,
      points = [...edge.points],
      aloft = _aloftOf(edge),
      meters = edge.meters,
      seconds = edge.seconds,
      _names = [?edge.way?.name],
      pistes = [?_stretchOf(edge)];

  _Part.walk(LatLng from, LatLng to, {this.fromName, this.toName})
    : kind = SegmentKind.walk,
      way = null,
      points = [from, to],
      aloft = [false, false],
      meters = _meters(from, to),
      seconds = _meters(from, to) / kSkiWalkSpeed,
      _names = [],
      pistes = [];

  final SegmentKind kind;
  final SkiWay? way;
  final List<LatLng> points;

  /// Whether each of [points] hangs on a lift's cable ([SkiRoute.aloft]).
  final List<bool> aloft;
  double meters;
  double seconds;
  String? fromName;
  String? toName;
  final List<String> _names;

  /// The pistes skied down, in order ([PathSegment.pistes]).
  final List<PisteStretch> pistes;

  /// The stretch of piste [edge] is, if it is one.
  static PisteStretch? _stretchOf(_Edge edge) =>
      edge.kind == SegmentKind.descent
      ? PisteStretch(name: edge.way?.name, difficulty: edge.way?.difficulty)
      : null;

  /// What [SkiRoute.aloft] says about the points of [edge]: on a ride, every
  /// point between its two stops, which are on the ground.
  static List<bool> _aloftOf(_Edge edge) => [
    for (var i = 0; i < edge.points.length; i++)
      edge.kind == SegmentKind.lift && i > 0 && i < edge.points.length - 1,
  ];

  void add(_Edge edge) {
    points.addAll(edge.points.skip(1));
    aloft.addAll(_aloftOf(edge).skip(1));
    meters += edge.meters;
    seconds += edge.seconds;
    if (edge.way?.name case final name? when _names.lastOrNull != name) {
      _names.add(name);
    }
    if (_stretchOf(edge) case final stretch?
        when pistes.lastOrNull != stretch) {
      pistes.add(stretch);
    }
  }

  /// Takes [other], which follows this part, into it. A lift ride that takes
  /// in a few meters of piste or a walk is still that lift, under its name and
  /// between its stations; a descent takes the names of what it took in.
  void append(_Part other) {
    points.addAll(other.points.skip(1));
    aloft.addAll(other.aloft.skip(1));
    meters += other.meters;
    seconds += other.seconds;
    if (kind == SegmentKind.lift) return;
    for (final name in other._names) {
      if (_names.lastOrNull != name) _names.add(name);
    }
    final joined = joinStretches(pistes, other.pistes);
    pistes
      ..clear()
      ..addAll(joined);
    toName = other.toName;
  }

  /// Takes [other], which comes before this part, into it; see [append].
  void prepend(_Part other) {
    points.insertAll(0, other.points.take(other.points.length - 1));
    aloft.insertAll(0, other.aloft.take(other.aloft.length - 1));
    meters += other.meters;
    seconds += other.seconds;
    if (kind == SegmentKind.lift) return;
    _names.insertAll(0, other._names);
    final joined = joinStretches(other.pistes, pistes);
    pistes
      ..clear()
      ..addAll(joined);
    fromName = other.fromName;
  }

  /// A lift's name, or the pistes a descent runs down, each once in a row.
  String? get name {
    if (kind == SegmentKind.walk) return null;
    final unique = <String>[];
    for (final name in _names) {
      if (!unique.contains(name)) unique.add(name);
    }
    return unique.isEmpty ? null : unique.join(', ');
  }
}

/// A min-heap of (cost, node).
class _Heap {
  final _costs = <double>[];
  final _nodes = <int>[];

  bool get isNotEmpty => _costs.isNotEmpty;

  void push(double cost, int node) {
    _costs.add(cost);
    _nodes.add(node);
    var i = _costs.length - 1;
    while (i > 0) {
      final parent = (i - 1) ~/ 2;
      if (_costs[parent] <= _costs[i]) break;
      _swap(i, parent);
      i = parent;
    }
  }

  (double, int) pop() {
    final top = (_costs.first, _nodes.first);
    final lastCost = _costs.removeLast();
    final lastNode = _nodes.removeLast();
    if (_costs.isNotEmpty) {
      _costs[0] = lastCost;
      _nodes[0] = lastNode;
      var i = 0;
      while (true) {
        final left = 2 * i + 1;
        final right = left + 1;
        var smallest = i;
        if (left < _costs.length && _costs[left] < _costs[smallest]) {
          smallest = left;
        }
        if (right < _costs.length && _costs[right] < _costs[smallest]) {
          smallest = right;
        }
        if (smallest == i) break;
        _swap(i, smallest);
        i = smallest;
      }
    }
    return top;
  }

  void _swap(int a, int b) {
    final cost = _costs[a];
    _costs[a] = _costs[b];
    _costs[b] = cost;
    final node = _nodes[a];
    _nodes[a] = _nodes[b];
    _nodes[b] = node;
  }
}

/// The nodes of the graph by grid cell, to find the ones near a point without
/// measuring to all of them.
class _Grid {
  _Grid(this._positions) {
    for (final (node, position) in _positions.indexed) {
      _cells.putIfAbsent(_cellOf(position), () => []).add(node);
    }
  }

  /// About 110 m of latitude per cell; fewer meters of longitude toward the
  /// poles, which only makes the cells narrower than they need to be.
  static const double _cellDegrees = 0.001;

  final List<LatLng> _positions;
  final _cells = <(int, int), List<int>>{};

  static (int, int) _cellOf(LatLng p) => (
    (p.latitude / _cellDegrees).floor(),
    (p.longitude / _cellDegrees).floor(),
  );

  /// The nodes within about [meters] of [point], and some a little farther.
  Iterable<int> near(LatLng point, double meters) sync* {
    final latCells = (meters / 111000 / _cellDegrees).ceil();
    final cosLat = math.cos(point.latitude * math.pi / 180).abs();
    final lonCells = (meters / (111000 * math.max(cosLat, 0.01)) / _cellDegrees)
        .ceil();
    final (row, column) = _cellOf(point);
    for (var r = row - latCells; r <= row + latCells; r++) {
      for (var c = column - lonCells; c <= column + lonCells; c++) {
        final nodes = _cells[(r, c)];
        if (nodes != null) yield* nodes;
      }
    }
  }
}
