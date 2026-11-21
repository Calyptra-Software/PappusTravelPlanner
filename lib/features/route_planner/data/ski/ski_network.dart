import 'package:latlong2/latlong.dart';

import '../../../../data/database/tables.dart';
import '../../domain/piste_difficulty.dart';

/// What a way of a ski area is, for routing.
enum SkiWayKind {
  /// A piste skied down (`piste:type=downhill`), drawn downhill.
  downhill,

  /// A short link between pistes or to a lift (`piste:type=connection`),
  /// drawn the way it is skied.
  connection,

  /// A lift (`aerialway=*`), drawn from the bottom station to the top.
  lift,
}

/// One way of a ski area as the router needs it.
class SkiWay {
  const SkiWay({
    required this.id,
    required this.kind,
    required this.nodes,
    required this.points,
    this.aerialway,
    this.name,
    this.difficulty,
    this.oneway,
    this.duration,
  }) : assert(nodes.length == points.length);

  /// The OSM way id.
  final int id;
  final SkiWayKind kind;

  /// The OSM node ids along the way, in drawing order, and where each stands.
  /// Two ways that share a node id meet there.
  final List<int> nodes;
  final List<LatLng> points;

  /// The `aerialway` value of a lift (`gondola`, `t-bar`, ...); null on a
  /// piste.
  final String? aerialway;

  /// `piste:name`, else `name`.
  final String? name;

  /// `piste:difficulty`, where the way has a grade this app knows.
  final PisteDifficulty? difficulty;

  /// The way's `oneway` tag, or null when untagged. What an untagged way
  /// means depends on its kind (see `SkiGraph`).
  final SkiOneway? oneway;

  /// `aerialway:duration`: how long a ride takes, end to end.
  final Duration? duration;

  /// The transport mode a ride on this lift is filed under; null on a piste.
  TransportMode? get liftMode => switch (aerialway) {
    null => null,
    'chair_lift' => TransportMode.chairLift,
    'gondola' || 'cable_car' || 'mixed_lift' => TransportMode.gondola,
    _ => TransportMode.dragLift,
  };
}

/// A way's `oneway` tag, read.
enum SkiOneway { yes, no, reverse }

/// A lift station (`aerialway=station` node).
class SkiStation {
  const SkiStation({this.name, this.entry = true, this.exit = true});

  final String? name;

  /// Whether one can get on here, and get off: `aerialway:access=entry` lets
  /// riders on only, `exit` off only, `no` neither.
  final bool entry;
  final bool exit;
}

/// The pistes and lifts of an area, read from an Overpass answer.
class SkiNetwork {
  const SkiNetwork({required this.ways, this.stations = const {}});

  final List<SkiWay> ways;

  /// The lift stations of the area by node id. A station on a lift is where
  /// one can get on or off, even in the middle of it.
  final Map<int, SkiStation> stations;
}

/// The lift kinds a skier rides, as OSM tags them. Zip lines and goods lifts
/// are lifts too, but nobody takes them on a ski day.
const Set<String> kRiddenAerialways = {
  'gondola',
  'cable_car',
  'mixed_lift',
  'chair_lift',
  'drag_lift',
  't-bar',
  'j-bar',
  'platter',
  'rope_tow',
  'magic_carpet',
};

/// The Overpass QL query for the pistes, lifts and lift stations within the
/// box from ([south], [west]) to ([north], [east]).
///
/// `out body geom` gives each way its node ids, which say where ways meet, and
/// its coordinates in one answer, so no second query for the nodes is needed.
String skiNetworkQuery({
  required double south,
  required double west,
  required double north,
  required double east,
}) {
  String degrees(double value) => value.toStringAsFixed(5);
  final box =
      '${degrees(south)},${degrees(west)},${degrees(north)},${degrees(east)}';
  final lifts = kRiddenAerialways.join('|');
  return '[out:json][timeout:60][bbox:$box];'
      '('
      'way["piste:type"~"^(downhill|connection)\$"];'
      'way["aerialway"~"^($lifts)\$"];'
      'node["aerialway"="station"];'
      ');'
      'out body geom qt;';
}

/// Reads an Overpass JSON answer to [skiNetworkQuery].
///
/// Throws [FormatException] for an answer that is not one. Ways that cannot
/// be routed are left out: a piste drawn as an area (`area=yes`), a way with
/// fewer than two points or without coordinates, a lift kind nobody rides.
SkiNetwork parseSkiNetwork(Object? json) {
  if (json is! Map) throw const FormatException('Not an Overpass answer');
  final elements = json['elements'];
  if (elements is! List) throw const FormatException('No elements');
  final ways = <SkiWay>[];
  final stations = <int, SkiStation>{};
  for (final element in elements) {
    if (element is! Map) continue;
    final id = element['id'];
    if (id is! int) continue;
    final tags = element['tags'];
    final tagMap = tags is Map ? tags : const {};
    String? tag(String key) {
      final value = tagMap[key];
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    switch (element['type']) {
      case 'node':
        if (tag('aerialway') == 'station') {
          final access = tag('aerialway:access');
          stations[id] = SkiStation(
            name: tag('name'),
            entry: access != 'no' && access != 'exit',
            exit: access != 'no' && access != 'entry',
          );
        }
      case 'way':
        final way = _way(id, element, tag);
        if (way != null) ways.add(way);
    }
  }
  return SkiNetwork(ways: ways, stations: stations);
}

SkiWay? _way(int id, Map element, String? Function(String key) tag) {
  final aerialway = tag('aerialway');
  final pisteType = tag('piste:type');
  final SkiWayKind kind;
  if (aerialway != null) {
    if (!kRiddenAerialways.contains(aerialway)) return null;
    kind = SkiWayKind.lift;
  } else if (pisteType == 'downhill') {
    kind = SkiWayKind.downhill;
  } else if (pisteType == 'connection') {
    kind = SkiWayKind.connection;
  } else {
    return null;
  }
  if (kind != SkiWayKind.lift && tag('area') == 'yes') return null;

  final nodeIds = element['nodes'];
  final geometry = element['geometry'];
  if (nodeIds is! List || geometry is! List) return null;
  if (nodeIds.length != geometry.length || nodeIds.length < 2) return null;
  final nodes = <int>[];
  final points = <LatLng>[];
  for (var i = 0; i < nodeIds.length; i++) {
    final node = nodeIds[i];
    final point = geometry[i];
    // A node outside the box can come back without coordinates; such a way
    // cannot be drawn whole and is left for an area that holds it.
    if (node is! int || point is! Map) return null;
    final lat = point['lat'];
    final lon = point['lon'];
    if (lat is! num || lon is! num) return null;
    nodes.add(node);
    points.add(LatLng(lat.toDouble(), lon.toDouble()));
  }

  return SkiWay(
    id: id,
    kind: kind,
    nodes: nodes,
    points: points,
    aerialway: aerialway,
    name: tag('piste:name') ?? tag('name'),
    difficulty: PisteDifficulty.byName(tag('piste:difficulty')),
    oneway: switch (tag('oneway')) {
      'yes' || 'true' || '1' => SkiOneway.yes,
      'no' || 'false' || '0' => SkiOneway.no,
      '-1' => SkiOneway.reverse,
      _ => null,
    },
    duration: parseAerialwayDuration(tag('aerialway:duration')),
  );
}

/// Reads `aerialway:duration`: minutes (`8`, `8.5`), or `mm:ss`, or
/// `hh:mm:ss`. Null for anything else, and for no time at all.
Duration? parseAerialwayDuration(String? value) {
  if (value == null) return null;
  final parts = value.split(':');
  if (parts.length == 1) {
    final minutes = double.tryParse(value);
    if (minutes == null || !minutes.isFinite || minutes <= 0) return null;
    return Duration(seconds: (minutes * 60).round());
  }
  if (parts.length > 3) return null;
  var seconds = 0;
  for (final part in parts) {
    final number = int.tryParse(part);
    if (number == null || number < 0) return null;
    seconds = seconds * 60 + number;
  }
  return seconds == 0 ? null : Duration(seconds: seconds);
}
