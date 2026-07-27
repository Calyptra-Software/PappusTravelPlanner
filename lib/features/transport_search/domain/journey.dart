import 'transit_mode.dart';

/// One end (boarding or alighting point) of a routed [JourneyLeg].
///
/// [scheduled] is the planned time; [actual] the real-time-adjusted time when
/// the service reported one (otherwise null). **Both are UTC instants** — the
/// routing service returns times as UTC plus a per-stop [timeZone], so wall-
/// clock time is only obtained by projecting [scheduled]/[actual] into
/// [timeZone]. That projection is deliberately *not* done here; it lives in the
/// itinerary mapper and the results UI, which share one timezone-aware helper.
class LegPoint {
  const LegPoint({
    required this.name,
    required this.scheduled,
    this.actual,
    this.lat,
    this.lon,
    this.track,
    this.timeZone,
  });

  final String name;
  final DateTime scheduled;
  final DateTime? actual;
  final double? lat;
  final double? lon;

  /// Platform/track designation, when the service provided one.
  final String? track;

  /// The IANA timezone of this stop (e.g. `Europe/Vienna`).
  final String? timeZone;

  /// The best-known time at this point: the real-time value if present, else the
  /// plan. Still a UTC instant (see the class doc).
  DateTime get effective => actual ?? scheduled;
}

/// A single leg of a journey — one vehicle run, or a walking transfer between
/// two of them ([mode] == [TransitMode.walk]).
class JourneyLeg {
  const JourneyLeg({
    required this.mode,
    required this.from,
    required this.to,
    required this.realTime,
    this.line,
    this.headsign,
    this.tripId,
  });

  final TransitMode mode;
  final LegPoint from;
  final LegPoint to;

  /// Whether the times on this leg carry real-time information.
  final bool realTime;

  /// The public line label (e.g. `ICE 607`, `FlixBus N60`), when the leg is a
  /// vehicle run. Null for a walking transfer.
  final String? line;

  /// The vehicle's destination sign, when given.
  final String? headsign;

  /// The routing service's trip identifier, when given.
  final String? tripId;
}

/// One stop of a vehicle's whole trip, as returned by the per-trip live query.
/// Carries both the planned and the real-time-adjusted arrival/departure (all
/// UTC instants, plus the stop's [timeZone]); a terminus has no arrival or no
/// departure. Used to refresh an imported leg's actual times.
class TripStop {
  const TripStop({
    required this.name,
    this.timeZone,
    this.scheduledArrival,
    this.arrival,
    this.scheduledDeparture,
    this.departure,
  });

  final String name;
  final String? timeZone;
  final DateTime? scheduledArrival;
  final DateTime? arrival;
  final DateTime? scheduledDeparture;
  final DateTime? departure;
}

/// The journeys found, plus the handles that fetch the ones either side.
///
/// A plan query is answered with the options in a **time window** around the
/// requested time — not with every connection that day — so "earlier" and
/// "later" are first-class: [earlierCursor] and [laterCursor] are the routing
/// service's opaque handles for the neighbouring windows, null when it offers
/// none. Repeating the *original* query with one of them returns that window,
/// which [merge] joins onto this one; the same type therefore describes both a
/// single window and everything loaded so far.
class JourneyResults {
  const JourneyResults({
    required this.options,
    this.direct = const [],
    this.earlierCursor,
    this.laterCursor,
  });

  final List<JourneyOption> options;

  /// Ways to make the journey **without public transport** — on foot, over
  /// whatever distance the router was willing to walk.
  ///
  /// These are not a window and have no real departure: they start whenever the
  /// traveller does, so the service dates them from the requested time and
  /// returns them **only for the first query**, not for a paging one. They also
  /// explain an otherwise baffling result: transit options slower than the
  /// fastest direct one are cut off during routing, so a fast walker on a short
  /// hop gets *no* [options] at all and the whole answer is here.
  final List<JourneyOption> direct;

  final String? earlierCursor;
  final String? laterCursor;

  /// Joins a freshly loaded window onto these results: an [earlier] one goes in
  /// front, a later one behind. Only that end's cursor advances — the other
  /// keeps pointing just past the edge of what is on screen. Windows are
  /// contiguous, so concatenating them preserves the order the service put them
  /// in and nothing is re-sorted.
  ///
  /// An option already on screen is not added a second time. The service is
  /// meant to hand out disjoint windows, but a duplicate row would read as a
  /// bug rather than as the edge case it is.
  JourneyResults merge(JourneyResults page, {required bool earlier}) {
    final seen = {for (final option in options) _signature(option)};
    final added = [
      // `add` is false for a signature already there — first occurrence wins.
      for (final option in page.options)
        if (seen.add(_signature(option))) option,
    ];
    return JourneyResults(
      options: earlier ? [...added, ...options] : [...options, ...added],
      // Walking the whole way does not belong to a window, so a further window
      // neither adds to it nor replaces it — the service is entitled to leave
      // it out of a paging response, and usually does.
      direct: direct.isNotEmpty ? direct : page.direct,
      earlierCursor: earlier ? page.earlierCursor : earlierCursor,
      laterCursor: earlier ? laterCursor : page.laterCursor,
    );
  }

  /// What makes two rows the same journey: when it runs, and what it is made
  /// of. Deliberately structural — the service's own itinerary id is
  /// experimental, and this is only ever used to keep a row from appearing
  /// twice.
  static String _signature(JourneyOption option) => [
    option.departure.toIso8601String(),
    option.arrival.toIso8601String(),
    for (final leg in option.legs) leg.tripId ?? leg.line ?? leg.mode.name,
  ].join('|');
}

/// One end-to-end option the router returned: an ordered list of [legs] with an
/// overall [departure]/[arrival] and interchange count. Times are UTC instants
/// (see [LegPoint]).
class JourneyOption {
  const JourneyOption({
    required this.departure,
    required this.arrival,
    required this.duration,
    required this.transfers,
    required this.legs,
  });

  final DateTime departure;
  final DateTime arrival;
  final Duration duration;
  final int transfers;
  final List<JourneyLeg> legs;
}
