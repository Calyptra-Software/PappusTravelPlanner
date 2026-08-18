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
    this.stopId,
    this.lat,
    this.lon,
    this.track,
    this.timeZone,
  });

  final String name;
  final DateTime scheduled;
  final DateTime? actual;

  /// The routing service's id for the stop this end is, or null when it is not
  /// a stop at all — which is what an end the query addressed by **coordinate**
  /// comes back as. That is the structural fact behind the placeholder `START`
  /// / `END` the service names such an end with, and behind its missing
  /// [timeZone]: both are read off this rather than off the name, which is a
  /// label and could change.
  final String? stopId;
  final double? lat;
  final double? lon;

  /// Platform/track designation, when the service provided one.
  final String? track;

  /// The IANA timezone of this stop (e.g. `Europe/Vienna`).
  final String? timeZone;

  /// The best-known time at this point: the real-time value if present, else the
  /// plan. Still a UTC instant (see the class doc).
  DateTime get effective => actual ?? scheduled;

  /// This point with [name] and/or [timeZone] replaced; either omitted keeps
  /// what is here. Plain override rather than fill-in semantics — *whether* an
  /// end should be renamed or given a zone is a judgement, and it is made in
  /// one place (`journey_ends.dart`, the only caller) rather than half here.
  LegPoint copyWith({String? name, String? timeZone}) => LegPoint(
    name: name ?? this.name,
    scheduled: scheduled,
    actual: actual,
    stopId: stopId,
    lat: lat,
    lon: lon,
    track: track,
    timeZone: timeZone ?? this.timeZone,
  );
}

/// A stop the vehicle calls at **between** a leg's two ends.
///
/// Only the departure is carried: a stopover is read to answer *does this train
/// pass through, and when am I there?*, and the minute it leaves is the one a
/// traveller acts on (it is also the last one — an arrival plus a dwell says the
/// same thing twice).
class LegStop {
  const LegStop({
    required this.name,
    required this.scheduledDeparture,
    this.actualDeparture,
    this.timeZone,
    this.cancelled = false,
  });

  final String name;

  /// The planned departure, a **UTC instant** like every other time here (see
  /// [LegPoint]) — projected into [timeZone] to be read.
  final DateTime scheduledDeparture;

  /// The real-time departure, when the service reported one — read on the same
  /// terms as a leg end's [LegPoint.actual], and only ever shown as the miss
  /// against [scheduledDeparture].
  final DateTime? actualDeparture;
  final String? timeZone;

  /// Whether the service skips this stop.
  final bool cancelled;
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
    this.cancelled = false,
    this.stops = const [],
    this.shape,
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

  /// Whether the service has been **cancelled**. In practice a search never
  /// returns one — the router plans around cancellations — so this is read for
  /// the case where it does rather than as a promise that it will.
  final bool cancelled;

  /// The stops called at between [from] and [to], in order. Empty for a walking
  /// transfer, and for a service the router reported without them.
  final List<LegStop> stops;

  /// The route the leg actually takes — along the rails, around the corner —
  /// as the router's own encoded polyline, still at *its* precision
  /// ([kRoutedShapePrecision]) rather than the app's. Kept as the string it
  /// arrived as: nothing between here and the import needs the points, and
  /// decoding a shape nobody imports would be work done for every result in
  /// every search.
  ///
  /// Null when the router sent none — an older server, or a leg it has no
  /// geometry for — in which case the map falls back to the straight line
  /// between the ends, which is what it drew before this existed.
  final String? shape;

  /// This leg with either end replaced; everything that describes the *service*
  /// is carried through untouched. See `journey_ends.dart`.
  JourneyLeg withEnds({LegPoint? from, LegPoint? to}) => JourneyLeg(
    mode: mode,
    from: from ?? this.from,
    to: to ?? this.to,
    realTime: realTime,
    line: line,
    headsign: headsign,
    tripId: tripId,
    cancelled: cancelled,
    stops: stops,
    shape: shape,
  );
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
    this.cancelled = false,
  });

  final String name;
  final String? timeZone;
  final DateTime? scheduledArrival;
  final DateTime? arrival;
  final DateTime? scheduledDeparture;
  final DateTime? departure;

  /// Whether the service will not call here. A whole cancelled trip marks every
  /// stop; a partial cancellation marks only the ones being skipped — which is
  /// why this is asked of the two stops a leg actually uses rather than of the
  /// trip as a whole.
  final bool cancelled;
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

  /// This option with [legs] replaced. The times either side are the journey's
  /// own UTC instants and are unaffected by anything `journey_ends.dart` does
  /// to the legs, which only names an end and dates it.
  JourneyOption withLegs(List<JourneyLeg> legs) => JourneyOption(
    departure: departure,
    arrival: arrival,
    duration: duration,
    transfers: transfers,
    legs: legs,
  );
}
