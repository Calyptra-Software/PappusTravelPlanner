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
