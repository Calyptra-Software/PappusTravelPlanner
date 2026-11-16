import 'package:latlong2/latlong.dart';

import '../domain/routed_path.dart';

/// Reads BRouter's `format=geojson` answer: one `LineString` feature whose
/// coordinates are `[lon, lat, elevation]` and whose properties carry the
/// totals as **strings** (`"track-length": "6396"`).
///
/// Pure. Throws [FormatException] on anything that is not such an answer, or
/// that holds fewer than two usable points: a route of one point is no route.
RoutedPath parseBrouterResponse(dynamic json) {
  if (json is! Map) throw const FormatException('Not a BRouter answer');
  final features = json['features'];
  if (features is! List || features.isEmpty || features.first is! Map) {
    throw const FormatException('BRouter answer without a route');
  }
  final feature = features.first as Map;
  final geometry = feature['geometry'];
  final coordinates = geometry is Map ? geometry['coordinates'] : null;
  if (coordinates is! List) {
    throw const FormatException('BRouter answer without a line');
  }

  final points = <LatLng>[];
  final elevations = <double>[];
  for (final coordinate in coordinates) {
    if (coordinate is! List || coordinate.length < 2) continue;
    final lon = coordinate[0];
    final lat = coordinate[1];
    if (lon is! num || lat is! num) continue;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) continue;
    points.add(LatLng(lat.toDouble(), lon.toDouble()));
    final elevation = coordinate.length > 2 ? coordinate[2] : null;
    if (elevation is num) elevations.add(elevation.toDouble());
  }
  if (points.length < 2) {
    throw const FormatException('BRouter route with fewer than two points');
  }

  final properties = feature['properties'];
  final totals = properties is Map ? properties : const {};
  final length = _number(totals['track-length']);
  if (length == null) {
    throw const FormatException('BRouter route without a length');
  }
  final ascent = _number(totals['filtered ascend']);
  // "plain-ascend" is the height of the end above the start, so what was
  // climbed less that is what was descended.
  final net = _number(totals['plain-ascend']);
  final seconds = _number(totals['total-time']);

  return RoutedPath(
    points: points,
    elevations: elevations.length == points.length ? elevations : null,
    lengthMeters: length,
    ascentMeters: ascent,
    descentMeters: ascent != null && net != null ? ascent - net : null,
    duration: seconds == null ? null : Duration(seconds: seconds.round()),
  );
}

double? _number(Object? value) => switch (value) {
  num() => value.toDouble(),
  String() => double.tryParse(value),
  _ => null,
};
