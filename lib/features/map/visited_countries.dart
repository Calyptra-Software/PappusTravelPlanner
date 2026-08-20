import 'dart:convert';

import 'package:latlong2/latlong.dart';

import '../../data/database/app_database.dart';
import '../../data/database/tables.dart';
import '../../data/database/track_points.dart';

/// One country's outline, as the bundled set holds it.
///
/// [polygons] is one entry per landmass — a country is rarely one shape — and
/// each of those is its outer ring followed by any holes, which is how Lesotho
/// manages not to be in South Africa.
class CountryOutline {
  CountryOutline({
    required this.code,
    required this.nameEn,
    required this.nameDe,
    required this.polygons,
  }) : bounds = _boundsOf(polygons);

  /// ISO 3166-1 alpha-2 where the source has one, and its three-letter
  /// administrative code where it does not — Kosovo, Somaliland and the like
  /// have no alpha-2 to give. Only ever used as an identity, never shown.
  final String code;
  final String nameEn;
  final String nameDe;

  /// Rings in decoded coordinates: `polygons[i][0]` is an outer ring, anything
  /// after it a hole in that same landmass.
  final List<List<List<LatLng>>> polygons;

  /// The box every ring fits in, so a point far away is dismissed by four
  /// comparisons instead of walking a few thousand vertices.
  final ({double south, double north, double west, double east}) bounds;

  String name(String languageCode) => languageCode == 'de' ? nameDe : nameEn;

  static ({double south, double north, double west, double east}) _boundsOf(
    List<List<List<LatLng>>> polygons,
  ) {
    var south = 90.0, north = -90.0, west = 180.0, east = -180.0;
    for (final polygon in polygons) {
      for (final point in polygon.first) {
        if (point.latitude < south) south = point.latitude;
        if (point.latitude > north) north = point.latitude;
        if (point.longitude < west) west = point.longitude;
        if (point.longitude > east) east = point.longitude;
      }
    }
    return (south: south, north: north, west: west, east: east);
  }

  /// Whether [point] lies on this country.
  bool contains(LatLng point) {
    if (point.latitude < bounds.south ||
        point.latitude > bounds.north ||
        point.longitude < bounds.west ||
        point.longitude > bounds.east) {
      return false;
    }
    for (final polygon in polygons) {
      if (!_inRing(polygon.first, point)) continue;
      // Inside the landmass — unless it is inside a hole in it.
      final inHole = polygon.skip(1).any((hole) => _inRing(hole, point));
      if (!inHole) return true;
    }
    return false;
  }
}

/// Ray casting: count the ring's edges directly above the point.
///
/// Longitude is taken as it comes rather than normalised. The source splits a
/// country that crosses the antimeridian into separate landmasses at ±180, so
/// no ring here spans the seam and there is nothing to unwrap.
bool _inRing(List<LatLng> ring, LatLng point) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final a = ring[i];
    final b = ring[j];
    if ((a.longitude > point.longitude) != (b.longitude > point.longitude)) {
      final crossing =
          (b.latitude - a.latitude) *
              (point.longitude - a.longitude) /
              (b.longitude - a.longitude) +
          a.latitude;
      if (point.latitude < crossing) inside = !inside;
    }
  }
  return inside;
}

/// Reads the bundled outlines.
///
/// The rings are the same encoded polyline a track is stored in — the codec was
/// there, the format is compact, and every mapping tool reads it. That is what
/// turns 820 KB of source GeoJSON into 61 KB of asset, at a resolution finer
/// than the source's own generalisation.
List<CountryOutline> parseCountryOutlines(String source) {
  final json = jsonDecode(source);
  if (json is! Map<String, dynamic>) {
    throw const FormatException('Not a country outline set');
  }
  final precision = json['precision'] as int? ?? kTrackPrecision;
  return [
    for (final country in json['countries'] as List<dynamic>)
      if (country is Map<String, dynamic>)
        CountryOutline(
          code: country['c'] as String,
          nameEn: country['en'] as String,
          nameDe: country['de'] as String,
          polygons: [
            for (final polygon in country['p'] as List<dynamic>)
              [
                for (final ring in polygon as List<dynamic>)
                  decodeTrackPoints(ring as String, precision: precision),
              ],
          ],
        ),
  ];
}

/// The positions a set of entries stands on.
///
/// A place's own, and **both ends** of a transport leg. Deliberately not the
/// line between them: a flight from Hamburg to Rome passes over Austria without
/// anybody setting foot in it, and a chord drawn across the map is not a claim
/// that the ground under it was visited. What the entries say is where somebody
/// actually was.
Iterable<LatLng> visitedPoints(Iterable<ItineraryItem> items) sync* {
  for (final item in items) {
    if (item.kind == ItemKind.place) {
      if (item.lat case final lat?) {
        if (item.lon case final lon?) yield LatLng(lat, lon);
      }
      continue;
    }
    if (item.fromLat case final lat?) {
      if (item.fromLon case final lon?) yield LatLng(lat, lon);
    }
    if (item.toLat case final lat?) {
      if (item.toLon case final lon?) yield LatLng(lat, lon);
    }
  }
}

/// Which of [countries] the [points] fall in.
///
/// A point in no country is simply not counted: the outlines are generalised,
/// so a coastal position can fall a little offshore, and an ocean crossing's
/// ends are genuinely nowhere. Neither is worth inventing a nearest country for
/// — a wrong country is a claim, while a missing one is only a gap.
Set<String> visitedCountryCodes(
  List<CountryOutline> countries,
  Iterable<LatLng> points,
) {
  final visited = <String>{};
  for (final point in points) {
    for (final country in countries) {
      if (country.contains(point)) {
        visited.add(country.code);
        break;
      }
    }
  }
  return visited;
}
