import 'dart:convert';

/// One waypoint of a planned route, as an entry keeps it.
class RoutePlanPoint {
  const RoutePlanPoint({
    required this.lat,
    required this.lon,
    this.name,
    this.isPlace = false,
  });

  final double lat;
  final double lon;

  /// What the point was called, when it was given a name.
  final String? name;

  /// Whether the point is an entry of its own in the plan.
  final bool isPlace;
}

/// What the route planner made an entry from, kept in
/// `ItineraryItems.routePlan`.
///
/// A column of JSON and not a table, for the reason the stopovers are one: it
/// belongs to exactly one entry, is written once when a tour is saved and read
/// only when that tour is opened again.
///
/// Every entry of one saved tour carries the same [tour], which is how they
/// are found again as a tour: the legs, and the places between them. A leg
/// also keeps the [waypoints] it was led through, ends included, and how it
/// was traveled, which is what the router was asked with; a place keeps only
/// [tour], its position being the entry's own.
///
/// The way of travel is kept as plain names ([profile], [straightMode]), read
/// back by the planner, so this file knows nothing about the planner's types
/// and the copies that carry the column need not either.
class RoutePlan {
  const RoutePlan({
    required this.tour,
    this.profile,
    this.straight = false,
    this.straightMode,
    this.waypoints = const [],
    this.seconds,
    this.meters,
  });

  /// Shared by the entries one tour was saved as.
  final String tour;

  /// The routing profile's name, for a leg the router found.
  final String? profile;

  /// Whether the leg is a line drawn by hand, with [straightMode] the built-in
  /// transport mode it was given, if any.
  final bool straight;
  final String? straightMode;

  /// The leg's waypoints in travel order, ends included. Empty on a place.
  final List<RoutePlanPoint> waypoints;

  /// What the router said the leg takes and how long it is, kept so that
  /// opening the tour again shows what it showed without asking again.
  final int? seconds;
  final double? meters;

  bool get isLeg => waypoints.length >= 2;

  /// The plan of the same leg traveled the other way.
  RoutePlan get reversed => RoutePlan(
    tour: tour,
    profile: profile,
    straight: straight,
    straightMode: straightMode,
    waypoints: waypoints.reversed.toList(),
    seconds: seconds,
    meters: meters,
  );
}

String encodeRoutePlan(RoutePlan plan) => jsonEncode({
  'tour': plan.tour,
  'profile': ?plan.profile,
  if (plan.straight) 'straight': true,
  'mode': ?plan.straightMode,
  if (plan.waypoints.isNotEmpty)
    'points': [
      for (final point in plan.waypoints)
        {
          'lat': point.lat,
          'lon': point.lon,
          'name': ?point.name,
          if (point.isPlace) 'place': true,
        },
    ],
  'seconds': ?plan.seconds,
  'meters': ?plan.meters,
});

/// Reads back what [encodeRoutePlan] wrote, or null for anything else: an
/// entry the planner did not make, or a string from a shared bundle that is
/// not one of ours. A waypoint without both coordinates makes the whole plan
/// unreadable, since a tour reopened with a point missing is another tour.
RoutePlan? decodeRoutePlan(String? encoded) {
  if (encoded == null || encoded.isEmpty) return null;
  final Object? json;
  try {
    json = jsonDecode(encoded);
  } on FormatException {
    return null;
  }
  if (json is! Map) return null;
  final tour = json['tour'];
  if (tour is! String || tour.isEmpty) return null;
  final waypoints = <RoutePlanPoint>[];
  final points = json['points'];
  if (points is List) {
    for (final point in points) {
      if (point is! Map) return null;
      final lat = point['lat'];
      final lon = point['lon'];
      if (lat is! num || lon is! num) return null;
      if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
      final name = point['name'];
      waypoints.add(
        RoutePlanPoint(
          lat: lat.toDouble(),
          lon: lon.toDouble(),
          name: name is String ? name : null,
          isPlace: point['place'] == true,
        ),
      );
    }
  }
  final profile = json['profile'];
  final mode = json['mode'];
  final seconds = json['seconds'];
  final meters = json['meters'];
  return RoutePlan(
    tour: tour,
    profile: profile is String ? profile : null,
    straight: json['straight'] == true,
    straightMode: mode is String ? mode : null,
    waypoints: waypoints,
    seconds: seconds is num ? seconds.round() : null,
    meters: meters is num ? meters.toDouble() : null,
  );
}

/// [encoded] with its leg traveled the other way, for a copy that runs back
/// along the same way. Unreadable or absent stays as it is.
String? reversedRoutePlan(String? encoded) {
  final plan = decodeRoutePlan(encoded);
  return plan == null ? encoded : encodeRoutePlan(plan.reversed);
}
