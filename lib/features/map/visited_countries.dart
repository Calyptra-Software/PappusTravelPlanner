import 'dart:convert';

import 'package:latlong2/latlong.dart';

import '../../data/database/app_database.dart';
import '../../data/database/tables.dart';
import '../../data/database/track_points.dart';

/// One area's outline, as the bundled set holds it.
///
/// An *area* is not a country: the set carries dependencies and disputed
/// ground — Greenland, Bermuda, Western Sahara — as well as the states
/// themselves, because a world map with holes in it is a worse map. What is
/// counted is the **state** an area belongs to ([stateCode]); what is drawn is
/// the area.
///
/// [polygons] is one entry per landmass — a country is rarely one shape — and
/// each of those is its outer ring followed by any holes, which is how Lesotho
/// manages not to be in South Africa.
class CountryOutline {
  CountryOutline({
    required this.code,
    required this.stateCode,
    required this.nameEn,
    required this.nameDe,
    required this.region,
    required this.sovereign,
    required this.polygons,
  }) : bounds = _boundsOf(polygons);

  /// This area's own identity: the source's three-letter administrative code,
  /// which unlike the alpha-2 is unique — Australia, its Indian Ocean
  /// Territories and Ashmore and Cartier all answer `AU`. Never shown.
  final String code;

  /// The sovereign state this area counts toward, as ISO 3166-1 alpha-2 (or the
  /// three-letter code where the source has no alpha-2 to give — Somaliland,
  /// Northern Cyprus). A state's own area carries its own code here.
  ///
  /// Null for ground under no state at all: Siachen Glacier, which the source
  /// files under Kashmir and no further. A position there counts for nothing,
  /// which is the only honest answer a travel app has about a disputed glacier.
  final String? stateCode;

  final String nameEn;
  final String nameDe;

  /// The group this is counted under: the UN region, except that the Americas
  /// are split into north and south, which is how an atlas draws them and how
  /// anybody reading a list expects to find them.
  final String region;

  /// Whether this area *is* its state — the rows the tally counts and the list
  /// shows. The rest are drawn and attributed, never listed.
  final bool sovereign;

  /// What a mark on this area is stored under.
  ///
  /// A state answers with its own code, so a tick in the list and a tap on the
  /// map write the same row; a territory answers with its area code, since
  /// Greenland has to be tickable as itself — it is on the map, and a mark you
  /// cannot make is worse than no mark. The two cannot collide: a state's code
  /// is its alpha-2 (or, where the source has none, the very code its own area
  /// carries).
  String get markKey => sovereign ? (stateCode ?? code) : code;

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
/// Longitude is taken as it comes rather than normalized. The source splits a
/// country that crosses the antimeridian into separate landmasses at ±180, so
/// no ring here *steps* across the seam and there is nothing to unwrap. One ring
/// closes across it — Antarctica's, between its last point and its first, which
/// is what keeps the projection from drawing it inside out — and that edge is
/// harmless to this: it lies at a constant -85.05°, so the latitude it
/// contributes is -85.05 whatever the point's longitude, and nothing in the set
/// is further south than that.
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
/// there, the format is compact, and every mapping tool reads it. That, plus a
/// simplification scaled to each ring's own size, is what turns 3.0 MB of
/// source GeoJSON into 240 KB of asset. `tool/build_country_outlines.dart` is
/// the other half of this and writes through the same codec.
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
          stateCode: country['sov'] as String?,
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

/// Which of [countries] the [points] fall in, by area.
///
/// Areas rather than states, because the two answer different questions: this
/// is where somebody stood, and it is what the map fills. What it *counts
/// toward* is [statesVisited].
///
/// A point in no area is simply not counted: the outlines are generalized, so a
/// coastal position can fall a little offshore, and an ocean crossing's ends are
/// genuinely nowhere. Neither is worth inventing a nearest country for — a wrong
/// country is a claim, while a missing one is only a gap.
Set<String> visitedAreaCodes(
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

/// The states [areas] count toward.
///
/// A dependency counts for the state it belongs to — a week in Greenland is a
/// week in a country, and with only the states counted it has to be Denmark's
/// — while ground under no state at all counts for nothing.
Set<String> statesVisited(List<CountryOutline> countries, Set<String> areas) {
  return {
    for (final country in countries)
      if (areas.contains(country.code)) ?country.stateCode,
  };
}

/// Everywhere somebody has been, in the two shapes the screen needs it.
///
/// The distinction is not pedantry: the states are what "how much of the world"
/// means once only sovereign states are counted, while the areas are where the
/// person actually was. Filling a state's dependencies because its mainland was
/// visited would light up the whole Arctic for a weekend in Copenhagen, and in
/// Mercator that is a quarter of the picture.
class VisitedWorld {
  const VisitedWorld({
    required this.areas,
    required this.states,
    required this.derivedAreas,
    required this.derivedStates,
  });

  /// Area codes to draw as visited.
  final Set<String> areas;

  /// State codes to count and tick.
  final Set<String> states;

  /// The part of each that the trips put there, which is the part nobody may
  /// untick: taking a tick back is retracting a *statement*, and a trip is not
  /// one — the way to undo it is to change the trip.
  final Set<String> derivedAreas;
  final Set<String> derivedStates;
}

/// What the trips say plus what the user said themselves.
///
/// A mark names a *state*, so it fills that state's own ground and not the
/// dependencies scattered across the oceans under its flag — the tick says
/// "I have been to Denmark", which is not a claim about Greenland.
VisitedWorld visitedWorld(
  List<CountryOutline> countries,
  Set<String> visitedAreas,
  Set<String> marked,
) {
  final areas = {
    ...visitedAreas,
    for (final country in countries)
      if (marked.contains(country.markKey)) country.code,
  };
  // Through the areas rather than straight from the marks, so a mark on a
  // territory credits the state it belongs to — a fortnight in Greenland is a
  // fortnight in a country — and a mark on ground under no state credits
  // nothing.
  return VisitedWorld(
    areas: areas,
    states: statesVisited(countries, areas),
    derivedAreas: visitedAreas,
    derivedStates: statesVisited(countries, visitedAreas),
  );
}

/// Every mark that would make [stateCode] read as visited: its own, and its
/// territories'.
///
/// What the list's tick writes is the state's own key; what it *clears* is all
/// of these. The row means "I have been to Denmark", so turning it off has to
/// take back whatever was making it true — and a mark on Greenland was making
/// it true. Leaving that one standing would put the row back on the next
/// rebuild, which is a switch that does not switch.
Set<String> markKeysFor(List<CountryOutline> countries, String stateCode) => {
  for (final country in countries)
    if (country.stateCode == stateCode) country.markKey,
};

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

/// The states of one region, in the order the list shows them.
List<CountryOutline> statesIn(List<CountryOutline> countries, String region) =>
    [
      for (final country in countries)
        if (country.sovereign && country.region == region) country,
    ];

/// Every sovereign state, which is what the tally is out of.
List<CountryOutline> sovereignStates(List<CountryOutline> countries) => [
  for (final country in countries)
    if (country.sovereign) country,
];

/// The tally per region, and the world's, in a fixed order.
///
/// Over the **sovereign states** only: a dependency is drawn and attributed but
/// never counted as a country of its own, so "50 of 50 in Europe" is a claim
/// about states and not about how many shapes are shaded.
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
    if (!country.sovereign) continue;
    total[country.region] = (total[country.region] ?? 0) + 1;
    if (visited.contains(country.stateCode)) {
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
