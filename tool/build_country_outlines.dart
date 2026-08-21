// Builds `assets/geo/countries.json` from Natural Earth's admin-0 set.
//
//     dart run tool/build_country_outlines.dart \
//       ne_50m_admin_0_countries.geojson assets/geo/countries.json
//
// The source (public domain, https://www.naturalearthdata.com/) is 3.0 MB of
// GeoJSON with some eighty attributes per country; what ships is 240 KB. This
// exists as a committed tool rather than a one-off script because the asset is
// derived data: the day the set has to be rebuilt — a finer scale, another
// attribute, a country that changes its name — the alternative is guessing what
// was done to it the first time.
//
// It writes through `encodeTrackPoints`, the same codec the app reads it with,
// so the two halves cannot drift apart.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:travelplanner/data/database/track_points.dart';

/// Three decimals, about 110 m — finer than the outlines themselves are.
const int kOutlinePrecision = 1000;

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'usage: dart run tool/build_country_outlines.dart <geojson> <out.json>',
    );
    exitCode = 64;
    return;
  }
  final source = jsonDecode(File(args[0]).readAsStringSync()) as Map;
  final features = (source['features'] as List).cast<Map<String, dynamic>>();

  final stateCodes = <String, String>{};
  for (final feature in features) {
    final p = feature['properties'] as Map<String, dynamic>;
    if (_isState(p)) {
      stateCodes.putIfAbsent(p['SOV_A3'] as String, () => _stateCode(p));
    }
  }

  final countries = <Map<String, dynamic>>[];
  var rings = 0, points = 0;
  for (final feature in features) {
    final p = feature['properties'] as Map<String, dynamic>;
    final polygons = <List<String>>[];
    for (final polygon in _polygons(feature['geometry'] as Map)) {
      final encoded = <String>[];
      for (final ring in polygon) {
        final simplified = _simplify(ring, _toleranceFor(ring));
        // Two points are a line and one is a dot; neither encloses anything,
        // and a hole that has collapsed to either is better dropped than drawn.
        if (simplified.length < 4) continue;
        encoded.add(
          encodeTrackPoints(simplified, precision: kOutlinePrecision),
        );
        rings++;
        points += simplified.length;
      }
      // The outer ring is what makes the landmass; if it did not survive, the
      // holes in it have nothing to be holes in.
      if (encoded.isNotEmpty) polygons.add(encoded);
    }
    if (polygons.isEmpty) continue;

    countries.add({
      'c': p['ADM0_A3'],
      'sov': ?stateCodes[p['SOV_A3']],
      'en': p['NAME_EN'],
      'de': p['NAME_DE'] ?? p['NAME_EN'],
      'k': _region(p),
      's': _isState(p) ? 1 : 0,
      'p': polygons,
    });
  }

  File(args[1]).writeAsStringSync(
    jsonEncode({'precision': kOutlinePrecision, 'countries': countries}),
  );
  final states = countries.where((c) => c['s'] == 1).length;
  stdout.writeln(
    '${countries.length} areas ($states sovereign), '
    '$rings rings, $points points -> ${args[1]}',
  );
  final orphans = countries.where((c) => c['sov'] == null).map((c) => c['en']);
  if (orphans.isNotEmpty) {
    stdout.writeln('under no state: ${orphans.join(', ')}');
  }
}

/// Whether this area is a sovereign state — one row per state, and what the
/// tally counts.
///
/// The source's own test is that an area's administration is its own, which
/// takes no view on who *recognizes* it: Kosovo, Taiwan, Northern Cyprus and
/// Somaliland are each their own state here because each governs its own
/// ground, which is the only criterion a travel app can apply without taking
/// somebody's side. Antarctica is the one area that passes the test and is
/// plainly not a country: no state governs it, so it is drawn and counts for
/// nothing, exactly as Siachen Glacier does.
bool _isState(Map<String, dynamic> p) =>
    p['SOVEREIGNT'] == p['ADMIN'] && p['ADM0_A3'] != 'ATA';

/// ISO 3166-1 alpha-2 where the source has one, its three-letter
/// administrative code where it does not — Somaliland and Northern Cyprus have
/// no alpha-2 to give, and a state the tally counts has to be nameable.
String _stateCode(Map<String, dynamic> p) {
  final iso = p['ISO_A2_EH'] as String?;
  return (iso == null || iso == '-99' || iso == '-1')
      ? p['ADM0_A3'] as String
      : iso;
}

/// The group a state is counted under.
///
/// `REGION_UN`, except that its single "Americas" is not how anybody reads a
/// list of continents, so the Americas are split by `CONTINENT`. South Georgia
/// is the one area the source files under Antarctica while its continent says
/// otherwise; it reads better beside the Falklands.
String _region(Map<String, dynamic> p) {
  final region = p['REGION_UN'] as String;
  if (region == 'Americas') return p['CONTINENT'] as String;
  if (p['ADM0_A3'] == 'SGS') return 'South America';
  return region;
}

/// Every ring of a feature, as `[outer, hole, hole, …]` per landmass.
Iterable<List<List<LatLng>>> _polygons(Map geometry) sync* {
  List<List<LatLng>> rings(List polygon) => [
    for (final ring in polygon)
      [
        for (final point in ring as List)
          LatLng(
            ((point as List)[1] as num).toDouble(),
            (point[0] as num).toDouble(),
          ),
      ],
  ];

  final coordinates = geometry['coordinates'] as List;
  switch (geometry['type']) {
    case 'Polygon':
      yield rings(coordinates);
    case 'MultiPolygon':
      for (final polygon in coordinates) {
        yield rings(polygon as List);
      }
  }
}

/// How far a vertex may move, in degrees — scaled to the ring's own extent.
///
/// This is the whole reason the micro-states survive. One fixed tolerance
/// generous enough to be worth applying to Russia's coastline collapses San
/// Marino to a triangle and Monaco to nothing at all, so each ring is allowed
/// an error proportional to its own size, capped so that a continent-sized one
/// does not become a lozenge.
double _toleranceFor(List<LatLng> ring) {
  var south = 90.0, north = -90.0, west = 180.0, east = -180.0;
  for (final point in ring) {
    south = math.min(south, point.latitude);
    north = math.max(north, point.latitude);
    west = math.min(west, point.longitude);
    east = math.max(east, point.longitude);
  }
  final extent = math.max(north - south, east - west);
  return math.min(0.02, extent / 60);
}

/// Douglas-Peucker, iterative so a coastline of ten thousand points cannot
/// overflow the stack.
List<LatLng> _simplify(List<LatLng> ring, double tolerance) {
  if (ring.length < 5) return ring;
  final keep = List<bool>.filled(ring.length, false);
  keep[0] = true;
  keep[ring.length - 1] = true;
  final stack = <List<int>>[
    [0, ring.length - 1],
  ];
  while (stack.isNotEmpty) {
    final [first, last] = stack.removeLast();
    var farthest = -1;
    var worst = tolerance;
    for (var i = first + 1; i < last; i++) {
      final distance = _distanceToSegment(ring[i], ring[first], ring[last]);
      if (distance > worst) {
        worst = distance;
        farthest = i;
      }
    }
    if (farthest < 0) continue;
    keep[farthest] = true;
    stack.add([first, farthest]);
    stack.add([farthest, last]);
  }
  return [
    for (var i = 0; i < ring.length; i++)
      if (keep[i]) ring[i],
  ];
}

/// Perpendicular distance in degrees, treating the two as plane coordinates.
///
/// A degree of longitude is shorter than one of latitude everywhere but the
/// equator, so this is generous towards the poles — which is the right way
/// round: it keeps *more* of a ring than a metric measure would, and the
/// tolerance is a drawing decision rather than a measurement.
double _distanceToSegment(LatLng point, LatLng start, LatLng end) {
  var x = start.longitude, y = start.latitude;
  var dx = end.longitude - x, dy = end.latitude - y;
  if (dx != 0 || dy != 0) {
    final t =
        ((point.longitude - x) * dx + (point.latitude - y) * dy) /
        (dx * dx + dy * dy);
    if (t > 1) {
      x = end.longitude;
      y = end.latitude;
    } else if (t > 0) {
      x += dx * t;
      y += dy * t;
    }
  }
  dx = point.longitude - x;
  dy = point.latitude - y;
  return math.sqrt(dx * dx + dy * dy);
}
