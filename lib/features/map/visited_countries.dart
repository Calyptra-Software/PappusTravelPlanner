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
    required this.region,
    required this.sovereign,
    required this.polygons,
  }) : bounds = _boundsOf(polygons);

  /// ISO 3166-1 alpha-2 where the source has one, and its three-letter
  /// administrative code where it does not — Kosovo, Somaliland and the like
  /// have no alpha-2 to give. Only ever used as an identity, never shown.
  final String code;
  final String nameEn;
  final String nameDe;

  /// The group this is counted under: the UN region, except that the Americas
  /// are split into north and south, which is how an atlas draws them and how
  /// anybody reading a list expects to find them.
  final String region;

  /// Whether it governs itself. The set carries dependencies and disputed
  /// areas as well — Greenland, Bermuda, Western Sahara — because a map with
  /// holes in it is a worse map, and somebody who has been to Greenland should
  /// be able to say so. Kept as a flag rather than acted on, so counting only
  /// sovereign states later is a filter and not a re-conversion.
  final bool sovereign;

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
          region: country['k'] as String? ?? 'Other',
          sovereign: (country['s'] as int? ?? 1) == 1,
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

/// How much of one region has been seen.
class RegionTally {
  const RegionTally({
    required this.region,
    required this.visited,
    required this.total,
  });

  final String region;
  final int visited;
  final int total;

  /// Rounded for reading, not for arithmetic — the ratio beside it is the
  /// figure that means anything.
  int get percent => total == 0 ? 0 : (visited * 100 / total).round();
}

/// The tally per region, and the world's, in a fixed order.
///
/// Ordered by how many countries a region holds rather than alphabetically or
/// by how much of it has been seen: a list that reorders itself as you travel
/// is one you have to re-read every time, and this way each region keeps the
/// place you learned it in.
List<RegionTally> regionTallies(
  List<CountryOutline> countries,
  Set<String> visited,
) {
  final total = <String, int>{};
  final seen = <String, int>{};
  for (final country in countries) {
    total[country.region] = (total[country.region] ?? 0) + 1;
    if (visited.contains(country.code)) {
      seen[country.region] = (seen[country.region] ?? 0) + 1;
    }
  }
  final regions = total.keys.toList()
    ..sort((a, b) {
      final byCount = total[b]!.compareTo(total[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  return [
    for (final region in regions)
      RegionTally(
        region: region,
        visited: seen[region] ?? 0,
        total: total[region]!,
      ),
  ];
}
