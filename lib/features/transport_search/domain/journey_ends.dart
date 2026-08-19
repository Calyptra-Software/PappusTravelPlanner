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
/// Pure, and applied at the two places a search's answer arrives — the results
/// controller and `searchPlannedJourney` — so everything downstream (the result
/// rows, the preview, the journey sheet, the import) reads one already-resolved
/// answer rather than each repairing it.
library;

import 'journey.dart';

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
