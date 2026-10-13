/// Filling in the two things the router cannot say about an end it was handed
/// as a **coordinate** rather than as a stop id.
///
/// A stop comes back named and zoned — `Hamburg-Rahlstedt`, `Europe/Berlin`.
/// A coordinate comes back as `{"name": "START", "vertexType": "NORMAL"}` with
/// no `stopId` and **no `tz` at all**, because the router knows a point on the
/// street network and nothing else about it. Both ends of a query are addressed
/// that way whenever the search was issued from a picked address, a point tapped
/// on the map, or the coordinates an imported leg carries — so this is not an
/// edge case but the whole of what a door-to-door search returns.
///
/// Left alone, each silence turns into a false statement rather than a missing
/// one:
///
///  * `START` / `END` are placed in the timeline as the stations' names, which
///    is the one thing they are not.
///  * a missing zone was read as UTC, so the leg was shown — and, once
///    imported, *stored* — two hours early in Berlin's summer. A wrong time
///    that looks like a time is worse than no time: nothing about it says it
///    was guessed.
///
/// So both are supplied here, from what the app knows and the router does not,
/// and only ever for an end with no `stopId`. What the service itself said
/// always stands.
///
/// A third thing a coordinate end brings is a walk to nowhere. The router always
/// walks from the point to the nearest stop and from the last stop to the point,
/// and when the point *is* the stop — which it is whenever one leg of an
/// imported run is searched again from the coordinates that leg carries — that
/// walk is `distance: 0.0` and still rounded up to a minute: a "walk" from
/// Farmsen to Farmsen, written into the timeline and a minute added to the
/// journey. Such a leg is dropped here ([kStandingWalkMeters]), and the
/// option's times are taken from the legs that are left.
///
/// Pure, and applied at the two places a search's answer arrives — the results
/// controller and `searchPlannedJourney` — so everything downstream (the result
/// rows, the preview, the journey sheet, the import) reads one already-resolved
/// answer rather than each repairing it.
library;

import 'dart:math' as math;

import 'journey.dart';
import 'transit_mode.dart';

/// How far apart the two ends of a walk at a coordinate end of a journey may
/// lie for it to be no walk at all. The router answers a point that is a stop's
/// own position with `distance: 0.0`; a metre is there only so a coordinate
/// rounded on its way through the app still counts as the same spot.
const double kStandingWalkMeters = 1;

/// [results] with every option's ends resolved. [fromName] / [toName] are the
/// names the search was **issued** with — the place the user picked, or the
/// station the run being re-routed already called it.
JourneyResults resolvedEnds(
  JourneyResults results, {
  String? fromName,
  String? toName,
}) => JourneyResults(
  options: [
    for (final option in results.options)
      resolvedOptionEnds(option, fromName: fromName, toName: toName),
  ],
  direct: [
    for (final option in results.direct)
      resolvedOptionEnds(option, fromName: fromName, toName: toName),
  ],
  earlierCursor: results.earlierCursor,
  laterCursor: results.laterCursor,
);

/// One option with its ends resolved: see the library doc.
///
/// Only the run's **outer** ends are renamed, and only when they carry no
/// `stopId`. Everything in between is a real stop the router named itself, and
/// there would be no name to give it in any case — the search knows where the
/// journey starts and ends, not where it changes.
JourneyOption resolvedOptionEnds(
  JourneyOption option, {
  String? fromName,
  String? toName,
}) {
  option = _withoutStandingWalks(option);
  if (option.legs.isEmpty) return option;
  final zones = _zonesAcross(option.legs);
  final last = option.legs.length - 1;
  return option.withLegs([
    for (final (index, leg) in option.legs.indexed)
      leg.withEnds(
        from: leg.from.copyWith(
          name: index == 0 ? _placeholderName(leg.from, fromName) : null,
          timeZone: zones[index * 2],
        ),
        to: leg.to.copyWith(
          name: index == last ? _placeholderName(leg.to, toName) : null,
          timeZone: zones[index * 2 + 1],
        ),
      ),
  ]);
}

/// [option] without a walk at either coordinate end that goes nowhere: an
/// own-steam leg whose open end (no `stopId`) lies on the stop at its other end.
///
/// Only at the outer ends, and only where the end is the query's coordinate:
/// a walk between two stops is a change, which the router means and the journey
/// sheet reads. Never down to nothing either — a journey of nothing but such a
/// walk is the answer to "from here to here", and leaving it whole is truer than
/// leaving no legs. The departure and arrival then come from the legs that are
/// left, so the result row says the same as the legs beneath it.
JourneyOption _withoutStandingWalks(JourneyOption option) {
  var legs = option.legs;
  if (legs.length > 1 && _standing(legs.first, legs.first.from)) {
    legs = legs.sublist(1);
  }
  if (legs.length > 1 && _standing(legs.last, legs.last.to)) {
    legs = legs.sublist(0, legs.length - 1);
  }
  if (identical(legs, option.legs)) return option;
  final departure = legs.first.from.actual ?? legs.first.from.scheduled;
  final arrival = legs.last.to.actual ?? legs.last.to.scheduled;
  return JourneyOption(
    departure: departure,
    arrival: arrival,
    duration: arrival.difference(departure),
    transfers: option.transfers,
    legs: legs,
  );
}

/// Whether [leg] is a walk (or ride) whose coordinate end [open] stands on the
/// stop at its other end.
bool _standing(JourneyLeg leg, LegPoint open) {
  if (!leg.mode.isOwnSteam || open.stopId != null) return false;
  final a = leg.from;
  final b = leg.to;
  if (a.lat == null || a.lon == null || b.lat == null || b.lon == null) {
    return false;
  }
  return _meters(a.lat!, a.lon!, b.lat!, b.lon!) <= kStandingWalkMeters;
}

/// The distance between two positions along the earth's surface, in metres.
double _meters(double lat1, double lon1, double lat2, double lon2) {
  const radius = 6371000.0;
  double rad(double degrees) => degrees * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * radius * math.asin(math.min(1, math.sqrt(h)));
}

/// The name to put on [point], or null to leave it as the router gave it: an
/// end that *is* a stop keeps the stop's own name, which is more precise than
/// anything the query could offer ("Hamburg Hbf" against "Hamburg").
String? _placeholderName(LegPoint point, String? name) =>
    point.stopId == null ? name : null;

/// A zone for every end of [legs], in journey order — each leg's `from` then its
/// `to` — taking the **nearest** one that is known: the zone carried forward
/// from the last end that had one, else the next one that does.
///
/// A journey passes through the world in order, so the zone of the stop before
/// or after an unzoned point is the best available answer and is very nearly
/// always the right one: a door two streets from the station is in the station's
/// zone. It is also the only answer the response itself contains — the device's
/// zone would be wrong for exactly the traveller this app is for.
///
/// Every entry stays null when *nothing* in the journey is zoned, which is what
/// a walk-only answer between two coordinates is. `localParts` reads that as the
/// device's own zone, and says why there.
List<String?> _zonesAcross(List<JourneyLeg> legs) {
  final zones = <String?>[
    for (final leg in legs) ...[leg.from.timeZone, leg.to.timeZone],
  ];
  String? carried;
  for (var i = 0; i < zones.length; i++) {
    if (zones[i] == null) {
      zones[i] = carried;
    } else {
      carried = zones[i];
    }
  }
  carried = null;
  for (var i = zones.length - 1; i >= 0; i--) {
    if (zones[i] == null) {
      zones[i] = carried;
    } else {
      carried = zones[i];
    }
  }
  return zones;
}
