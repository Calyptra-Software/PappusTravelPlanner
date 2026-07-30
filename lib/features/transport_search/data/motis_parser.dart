/// Pure decoding of MOTIS API JSON into the connection-search domain.
///
/// Kept separate from `MotisTransportSearch` (the HTTP layer) so every parsing
/// rule is unit-testable against recorded response fixtures without a network.
/// Nothing here interprets time zones or maps onto the app's transport modes —
/// those are later, deliberately separate steps; this only turns the wire shape
/// into domain objects, carrying times through as the UTC instants the service
/// sends.
library;

import '../domain/journey.dart';
import '../domain/transit_mode.dart';
import '../domain/transport_place.dart';

/// Parses the body of `GET /api/v1/geocode` — a JSON array of matches.
List<TransportPlace> parseGeocodeResponse(dynamic json) {
  final list = json as List<dynamic>;
  return list
      .map((e) => _place(e as Map<String, dynamic>))
      .toList(growable: false);
}

/// Parses the body of `GET /api/v1/plan` — an object whose `itineraries` are
/// the routed options for one time window, alongside the cursors for the
/// windows before and after it.
JourneyResults parsePlanResponse(dynamic json) {
  final map = json as Map<String, dynamic>;
  return JourneyResults(
    options: _itineraries(map['itineraries']),
    // Same shape as an itinerary, different meaning: no transit, no departure
    // to speak of. Reading it is what keeps a short hop from looking like "no
    // connections" when the answer is simply to walk.
    direct: _itineraries(map['direct']),
    earlierCursor: _cursor(map['previousPageCursor']),
    laterCursor: _cursor(map['nextPageCursor']),
  );
}

List<JourneyOption> _itineraries(dynamic value) => [
  for (final e in (value as List<dynamic>?) ?? const [])
    _itinerary(e as Map<String, dynamic>),
];

/// A paging cursor, or null when the service offered none. An empty string is
/// treated as absent — a handle to nothing is nothing.
String? _cursor(dynamic value) =>
    value is String && value.isNotEmpty ? value : null;

/// Parses the body of `GET /api/v1/trip` — a single itinerary whose one leg's
/// `from`, `intermediateStops` and `to` are the vehicle's ordered stops, each
/// with planned and real-time times. Returns them in order.
///
/// The real-time [TripStop.arrival]/[TripStop.departure] are populated **only
/// when the trip actually carries real-time** (`realTime: true`). A trip that has
/// already run comes back with `realTime: false` and its live fields equal to the
/// plan; leaving them null there stops the refresh from writing a misleading
/// "confirmed on time" for a leg we have no live data for.
List<TripStop> parseTripResponse(dynamic json) {
  final legs = (json as Map<String, dynamic>)['legs'] as List<dynamic>?;
  if (legs == null || legs.isEmpty) return const [];
  final leg = legs.first as Map<String, dynamic>;
  final realTime = leg['realTime'] as bool? ?? false;
  return [
    _tripStop(leg['from'] as Map<String, dynamic>, realTime),
    for (final s in (leg['intermediateStops'] as List<dynamic>?) ?? const [])
      _tripStop(s as Map<String, dynamic>, realTime),
    _tripStop(leg['to'] as Map<String, dynamic>, realTime),
  ];
}

TripStop _tripStop(Map<String, dynamic> j, bool realTime) => TripStop(
  name: j['name'] as String? ?? '',
  cancelled: j['cancelled'] as bool? ?? false,
  timeZone: j['tz'] as String?,
  scheduledArrival: _parseUtcOrNull(j['scheduledArrival']),
  arrival: realTime ? _parseUtcOrNull(j['arrival']) : null,
  scheduledDeparture: _parseUtcOrNull(j['scheduledDeparture']),
  departure: realTime ? _parseUtcOrNull(j['departure']) : null,
);

DateTime? _parseUtcOrNull(dynamic v) => v == null ? null : DateTime.parse(v);

TransportPlace _place(Map<String, dynamic> j) => TransportPlace(
  id: j['id'] as String,
  name: j['name'] as String? ?? '',
  kind: _placeKind(j['type'] as String?),
  lat: _toDouble(j['lat']),
  lon: _toDouble(j['lon']),
  area: _area(j['areas']),
  timeZone: j['tz'] as String?,
);

PlaceKind _placeKind(String? type) {
  switch (type?.toUpperCase()) {
    case 'STOP':
      return PlaceKind.stop;
    case 'ADDRESS':
      return PlaceKind.address;
    case 'PLACE':
      return PlaceKind.place;
    default:
      return PlaceKind.other;
  }
}

/// Picks the most useful containing area to show beside a stop name: the one the
/// geocoder flagged as its `default`, else the one it `matched` the query on,
/// else the first. Null when there are none.
String? _area(dynamic areas) {
  if (areas is! List || areas.isEmpty) return null;
  final list = areas.cast<Map<String, dynamic>>();
  Map<String, dynamic>? pick;
  pick = list.where((a) => a['default'] == true).firstOrNull;
  pick ??= list.where((a) => a['matched'] == true).firstOrNull;
  pick ??= list.first;
  return pick['name'] as String?;
}

JourneyOption _itinerary(Map<String, dynamic> j) => JourneyOption(
  departure: _parseUtc(j['startTime']),
  arrival: _parseUtc(j['endTime']),
  duration: Duration(seconds: (j['duration'] as num?)?.toInt() ?? 0),
  transfers: (j['transfers'] as num?)?.toInt() ?? 0,
  legs: (j['legs'] as List<dynamic>)
      .map((e) => _leg(e as Map<String, dynamic>))
      .toList(growable: false),
);

JourneyLeg _leg(Map<String, dynamic> j) {
  final realTime = j['realTime'] as bool? ?? false;
  return JourneyLeg(
    mode: transitModeFromMotis(j['mode'] as String? ?? 'OTHER'),
    from: _legEnd(
      j['from'] as Map<String, dynamic>,
      scheduledKey: 'scheduledDeparture',
      liveKey: 'departure',
      realTime: realTime,
    ),
    to: _legEnd(
      j['to'] as Map<String, dynamic>,
      scheduledKey: 'scheduledArrival',
      liveKey: 'arrival',
      realTime: realTime,
    ),
    realTime: realTime,
    line: (j['routeShortName'] ?? j['displayName']) as String?,
    headsign: j['headsign'] as String?,
    tripId: j['tripId'] as String?,
    cancelled: j['cancelled'] as bool? ?? false,
    stops: _legStops(j['intermediateStops'], realTime),
  );
}

/// The stops between a leg's two ends. The plan response carries them on the
/// leg itself, so nothing extra is fetched to read them.
///
/// Only the **departure** is taken (see [LegStop]); a terminus-shaped entry
/// without one — nothing in a well-formed response, but feeds vary — falls back
/// to its arrival, and one with neither is dropped rather than dated from thin
/// air. The live departure is read on the leg's own [realTime] terms, exactly as
/// its ends are: a trip that has already run reports its plan as if it were
/// live, and taking that would invent an on-time record.
List<LegStop> _legStops(dynamic value, bool realTime) => [
  for (final e in (value as List<dynamic>?) ?? const [])
    if (e is Map<String, dynamic>)
      if (_parseUtcOrNull(e['scheduledDeparture'] ?? e['scheduledArrival'])
          case final departure?)
        LegStop(
          name: e['name'] as String? ?? '',
          scheduledDeparture: departure,
          actualDeparture: realTime
              ? _parseUtcOrNull(e['departure'] ?? e['arrival'])
              : null,
          timeZone: e['tz'] as String?,
          cancelled: e['cancelled'] as bool? ?? false,
        ),
];

LegPoint _legEnd(
  Map<String, dynamic> j, {
  required String scheduledKey,
  required String liveKey,
  required bool realTime,
}) {
  final live = j[liveKey];
  return LegPoint(
    name: j['name'] as String? ?? '',
    scheduled: _parseUtc(j[scheduledKey] ?? live),
    actual: realTime && live != null ? _parseUtc(live) : null,
    lat: _toDouble(j['lat']),
    lon: _toDouble(j['lon']),
    track: (j['track'] ?? j['scheduledTrack']) as String?,
    timeZone: j['tz'] as String?,
  );
}

double? _toDouble(dynamic v) => v == null ? null : (v as num).toDouble();

/// MOTIS emits timestamps as UTC (a trailing `Z`); the resulting [DateTime] is
/// UTC and left that way — see [LegPoint] on why wall-clock is a later step.
DateTime _parseUtc(dynamic v) => DateTime.parse(v as String);
