import 'dart:convert';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../../../core/cache_files.dart';
import '../../../map/elevation.dart';
import '../../application/route_engine.dart';
import '../../application/ski_router.dart';
import '../../application/terrain_heights.dart';
import '../../domain/piste_difficulty.dart';
import '../../domain/routed_path.dart';
import '../../domain/terrain.dart';
import 'overpass_client.dart';
import 'ski_graph.dart';
import 'ski_network.dart';

/// How far around a ski run's waypoints the map data has to reach: a waypoint
/// is taken to mean pistes up to [kMaxSnapMeters] away, and a way may swing
/// out a little beyond its waypoints.
const double kSkiNeededMargin = 1000;

/// How far around the waypoints an area is loaded when it has to be: wider
/// than [kSkiNeededMargin], so the next waypoint, a few pistes on, is in the
/// area already rather than a reason to load another.
const double kSkiLoadMargin = 3000;

/// The longest side of an area loaded at once, in meters. A ski run reaching
/// farther is refused ([RouteEngineFailure.tooLarge]); naming a waypoint on the
/// way splits it into runs that are loaded each on its own.
const double kMaxSkiAreaMeters = 30000;

/// How long a loaded area is used before it is loaded again: pistes and lifts
/// change between seasons, not between weekends.
const Duration kSkiAreaMaxAge = Duration(days: 30);

const Distance _distance = Distance(calculator: Haversine());

/// A rectangle of the map, in degrees.
class SkiBox {
  const SkiBox(this.south, this.west, this.north, this.east);

  /// The box around [points], [margin] meters wider on every side.
  factory SkiBox.around(List<LatLng> points, double margin) {
    var south = 90.0, north = -90.0, west = 180.0, east = -180.0;
    for (final point in points) {
      south = math.min(south, point.latitude);
      north = math.max(north, point.latitude);
      west = math.min(west, point.longitude);
      east = math.max(east, point.longitude);
    }
    final dLat = margin / 111320;
    final middle = (south + north) / 2 * math.pi / 180;
    final dLon = margin / (111320 * math.max(math.cos(middle), 0.01));
    return SkiBox(
      math.max(south - dLat, -90),
      math.max(west - dLon, -180),
      math.min(north + dLat, 90),
      math.min(east + dLon, 180),
    );
  }

  final double south;
  final double west;
  final double north;
  final double east;

  /// The box grown outward to whole hundredths of a degree, so that boxes
  /// loaded for nearby runs come out the same and their file names stay short.
  SkiBox get rounded => SkiBox(
    (south * 100).floorToDouble() / 100,
    (west * 100).floorToDouble() / 100,
    (north * 100).ceilToDouble() / 100,
    (east * 100).ceilToDouble() / 100,
  );

  bool contains(SkiBox other) =>
      south <= other.south &&
      west <= other.west &&
      north >= other.north &&
      east >= other.east;

  /// The longer of the box's two sides, in meters.
  double get longestSideMeters {
    final middle = (south + north) / 2;
    final height = _distance.as(
      LengthUnit.Meter,
      LatLng(south, west),
      LatLng(north, west),
    );
    final width = _distance.as(
      LengthUnit.Meter,
      LatLng(middle, west),
      LatLng(middle, east),
    );
    return math.max(height, width);
  }

  /// What the box is filed under: its corners at the precision of [rounded].
  String get key => [
    south,
    west,
    north,
    east,
  ].map((value) => value.toStringAsFixed(2)).join('_');

  @override
  bool operator ==(Object other) =>
      other is SkiBox &&
      other.south == south &&
      other.west == west &&
      other.north == north &&
      other.east == east;

  @override
  int get hashCode => Object.hash(south, west, north, east);
}

/// Reads an Overpass answer into a graph. Throws [RouteEngineException] for an
/// answer that is not one, and for one the server cut short: Overpass answers
/// 200 and a `remark` when a query ran out of time or memory, with whatever it
/// had found until then, which would route over half a ski area.
SkiGraph buildSkiGraph(String answer) {
  final Object? json;
  try {
    json = jsonDecode(answer);
  } on FormatException catch (e) {
    throw RouteEngineException.local(
      'Unreadable Overpass answer: ${e.message}',
      RouteEngineFailure.failed,
    );
  }
  final remark = json is Map ? json['remark'] : null;
  if (remark is String && remark.contains('error')) {
    throw RouteEngineException.local(
      'Overpass cut the answer short: $remark',
      RouteEngineFailure.busy,
    );
  }
  try {
    return SkiGraph.build(parseSkiNetwork(json));
  } on FormatException catch (e) {
    throw RouteEngineException.local(
      'Unreadable Overpass answer: ${e.message}',
      RouteEngineFailure.failed,
    );
  }
}

/// A [SkiRouter] over map data loaded from an Overpass server.
///
/// An area is loaded the first time a ski run within it is routed, never
/// before, and kept: for the session in memory, and on a platform with a
/// cache directory ([CacheFiles]) for [kSkiAreaMaxAge] on disk, so a ski day
/// planned at home is routed again on the mountain without a connection.
/// Routing itself never leaves the device.
///
/// The map data has no heights; a path gets them from [TerrainHeights], each
/// ride straight from station to station ([levelAloft]). Without them, from a
/// server that cannot be reached, the path comes without heights: they are
/// worth less than the way.
class OverpassSkiRouter implements SkiRouter {
  OverpassSkiRouter(
    this._client, {
    this._heights,
    Future<CacheFiles?>? files,
    DateTime Function()? now,
    Future<SkiGraph> Function(String answer)? build,
  }) : _files = files ?? Future.value(),
       _now = now ?? DateTime.now,
       _build = build ?? ((answer) async => buildSkiGraph(answer));

  final OverpassClient _client;
  final TerrainHeights? _heights;
  final Future<CacheFiles?> _files;
  final DateTime Function() _now;
  final Future<SkiGraph> Function(String answer) _build;

  final _areas = <SkiBox, SkiGraph>{};
  final _loading = <SkiBox, Future<SkiGraph>>{};
  Future<void>? _pruned;

  @override
  Future<RoutedPath> route({
    required List<LatLng> waypoints,
    required PisteDifficulty maxDifficulty,
  }) async {
    final graph = await _graphFor(waypoints);
    final found = graph.find(waypoints, maxDifficulty: maxDifficulty);
    final path = found.path;
    final heights = await _heights?.at(path.points);
    if (heights == null) return path;
    final elevations = levelAloft(path.points, heights, found.aloft);
    final climb = climbOf(elevations);
    return RoutedPath(
      points: path.points,
      lengthMeters: path.lengthMeters,
      elevations: elevations,
      ascentMeters: climb.ascent,
      descentMeters: climb.descent,
      duration: path.duration,
      segments: path.segments,
      waypointIndices: path.waypointIndices,
    );
  }

  @override
  Future<void> forget() async {
    _areas.clear();
    final files = await _files;
    if (files == null) return;
    for (final key in await files.keys()) {
      await files.delete(key);
    }
  }

  Future<SkiGraph> _graphFor(List<LatLng> waypoints) async {
    final needed = SkiBox.around(waypoints, kSkiNeededMargin);
    // Rounded, as it would be loaded: rounding adds up to a kilometer.
    if (needed.rounded.longestSideMeters > kMaxSkiAreaMeters) {
      throw const RouteEngineException.local(
        'Ski run spans too large an area',
        RouteEngineFailure.tooLarge,
      );
    }
    for (final MapEntry(key: box, value: graph) in _areas.entries) {
      if (box.contains(needed)) return graph;
    }
    for (final MapEntry(key: box, value: loading) in _loading.entries) {
      if (box.contains(needed)) return loading;
    }
    final box = _loadBox(waypoints);
    final loading = _load(box, needed);
    _loading[box] = loading;
    try {
      return await loading;
    } finally {
      _loading.remove(box);
    }
  }

  /// The area loaded for a run through [waypoints]: [kSkiLoadMargin] around
  /// them, less where that would pass [kMaxSkiAreaMeters].
  SkiBox _loadBox(List<LatLng> waypoints) {
    var margin = kSkiLoadMargin;
    var box = SkiBox.around(waypoints, margin).rounded;
    while (box.longestSideMeters > kMaxSkiAreaMeters &&
        margin > kSkiNeededMargin) {
      margin = math.max(margin - 500, kSkiNeededMargin);
      box = SkiBox.around(waypoints, margin).rounded;
    }
    return box;
  }

  Future<SkiGraph> _load(SkiBox box, SkiBox needed) async {
    final files = await _files;
    if (files != null) await (_pruned ??= _prune(files));
    final cached = files == null ? null : await _cached(files, needed);
    if (cached != null) {
      try {
        final graph = await _build(cached.answer);
        return _areas[cached.box] = graph;
      } on RouteEngineException {
        // A file that does not read is no cache; load the area again.
        await files!.delete(cached.key);
      }
    }
    final answer = await _client.run(
      skiNetworkQuery(
        south: box.south,
        west: box.west,
        north: box.north,
        east: box.east,
      ),
    );
    final graph = await _build(answer);
    _areas[box] = graph;
    await files?.write('${box.key}_${_dayKey(_now())}', answer);
    return graph;
  }

  /// The freshest area on disk that holds [needed], if one is young enough.
  Future<({SkiBox box, String key, String answer})?> _cached(
    CacheFiles files,
    SkiBox needed,
  ) async {
    ({SkiBox box, String key, DateTime day})? best;
    for (final key in await files.keys()) {
      final entry = _parseKey(key);
      if (entry == null || !entry.box.contains(needed)) continue;
      if (best == null || entry.day.isAfter(best.day)) {
        best = (box: entry.box, key: key, day: entry.day);
      }
    }
    if (best == null) return null;
    final answer = await files.read(best.key);
    if (answer == null) return null;
    return (box: best.box, key: best.key, answer: answer);
  }

  /// Drops every area older than [kSkiAreaMaxAge], and every file that is not
  /// one, once, the first time the router loads anything.
  Future<void> _prune(CacheFiles files) async {
    final oldest = _now().subtract(kSkiAreaMaxAge);
    for (final key in await files.keys()) {
      final entry = _parseKey(key);
      if (entry == null || entry.day.isBefore(oldest)) await files.delete(key);
    }
  }

  static String _dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}'
      '${day.month.toString().padLeft(2, '0')}'
      '${day.day.toString().padLeft(2, '0')}';

  /// Reads `south_west_north_east_yyyymmdd` back.
  static ({SkiBox box, DateTime day})? _parseKey(String key) {
    final parts = key.split('_');
    if (parts.length != 5) return null;
    final corners = [for (final part in parts.take(4)) double.tryParse(part)];
    final day = parts[4];
    if (corners.contains(null) || day.length != 8) return null;
    final year = int.tryParse(day.substring(0, 4));
    final month = int.tryParse(day.substring(4, 6));
    final date = int.tryParse(day.substring(6));
    if (year == null || month == null || date == null) return null;
    return (
      box: SkiBox(corners[0]!, corners[1]!, corners[2]!, corners[3]!),
      day: DateTime(year, month, date),
    );
  }
}
