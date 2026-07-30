import 'domain/journey.dart';
import 'domain/transit_mode.dart';
import 'data/journey_mapper.dart' show localParts;

/// A journey as it is *read*: an ordered list of legs with their stops, times
/// and delays — whether it was just found by the router or has been part of the
/// trip for weeks.
///
/// One shape, two sources. The search knows a journey as [JourneyOption]s of UTC
/// instants plus timezones; the trip knows the same journey as [ItineraryItems]
/// rows of wall-clock minutes, having thrown the zones away (this app stores no
/// timezone anywhere — see the `.ics` export). Neither is a good input to read a
/// journey *from*, and reading them twice would be two chances to disagree, so
/// both are mapped onto this and [journeyPreview] folds the rows once.
///
/// The arithmetic that survives that fan-in is [ViewPoint.absolute]: a monotone
/// minute count each adapter defines in *its own* terms — real UTC minutes for a
/// routed journey, wall-clock minutes for a stored one. Differences of it are
/// therefore exact where the source is exact: a change straddling a change of
/// offset comes out right from the router, and comes out as the clock reads it
/// from the trip, which is all a database without timezones can say.
class JourneyView {
  const JourneyView({
    required this.legs,
    required this.transfers,
    this.duration,
  });

  final List<ViewLeg> legs;

  /// How many times the traveller changes service. Taken from the router where
  /// it counts them itself, derived from the legs otherwise.
  final int transfers;

  /// End to end, when both ends are timed — a stored journey may hold a leg
  /// nobody gave a time.
  final Duration? duration;
}

/// How a leg's means of transport is known — the one thing the two sources
/// cannot express in common terms.
///
/// The router names a mode from its own vocabulary; the trip points at a row in
/// the user's own [TransportModes] table, which may be a mode the router has
/// never heard of (and may be missing entirely, on a leg whose mode was
/// deleted). So the view carries whichever it has and the UI — which is where
/// the modes table and the icons live — resolves it.
sealed class ViewMode {
  const ViewMode();
}

/// A mode as the routing service named it.
class RoutedMode extends ViewMode {
  const RoutedMode(this.mode);

  final TransitMode mode;
}

/// A mode as the trip stores it: a `TransportModes` row id, or null when the leg
/// has none.
class StoredMode extends ViewMode {
  const StoredMode(this.modeId);

  final int? modeId;
}

/// One end of a leg: where, when, and how late.
class ViewPoint {
  const ViewPoint({
    required this.name,
    required this.date,
    required this.minutes,
    required this.absolute,
    this.actualAbsolute,
    this.track,
  });

  final String name;

  /// The calendar day this end falls on — what tells an overnight leg from an
  /// ordinary one.
  final DateTime date;

  /// The planned wall-clock time, minutes since midnight (0-1439), or null when
  /// the entry carries no time at all.
  final int? minutes;

  /// The planned time on this view's arithmetic scale (see [JourneyView]); null
  /// exactly when [minutes] is.
  final int? absolute;

  /// The real-time-adjusted time on the same scale, when one is known.
  final int? actualAbsolute;

  /// Platform/track, when the source has one. A stored leg does not: the app
  /// keeps its platforms in the leg's notes, where the user can edit them.
  final String? track;

  /// How late this end is running, in minutes (negative: early). Null when
  /// nothing real-time is known about it.
  int? get delay => actualAbsolute == null || absolute == null
      ? null
      : actualAbsolute! - absolute!;
}

/// A stop passed through, as it is shown: a name, the minute the service leaves
/// it, how late it is running, and — for a night train — how many days after the
/// leg's departure that is.
class ViewStop {
  const ViewStop({
    required this.name,
    required this.minutes,
    this.dayOffset = 0,
    this.delay,
  });

  final String name;
  final int minutes;
  final int dayOffset;

  /// How late the service leaves here, in minutes (negative: early), or null
  /// when nothing real-time is known about this stop. Printed beside the planned
  /// time exactly as a leg end's miss is — the plan is what a stop list is read
  /// against.
  final int? delay;
}

/// One leg of the journey.
class ViewLeg {
  const ViewLeg({
    required this.mode,
    required this.ownSteam,
    required this.from,
    required this.to,
    this.line,
    this.headsign,
    this.notes,
    this.stops = const [],
    this.cancelled = false,
    this.itemId,
    this.sourceTripId,
  });

  final ViewMode mode;

  /// Whether this stretch is covered under the traveller's own steam rather than
  /// by boarding a service — the distinction a *change* is defined against (see
  /// [TransitModeKind.isOwnSteam]). Resolved by the adapter, since each source
  /// answers it differently.
  final bool ownSteam;

  final ViewPoint from;
  final ViewPoint to;

  /// The service's public line label ("ICE 507"), when it has one.
  final String? line;

  /// The vehicle's destination sign, on a routed leg. A stored leg has it folded
  /// into [notes], where the import wrote it.
  final String? headsign;

  /// The stored leg's notes — direction and platforms as the import composed
  /// them, plus whatever the user has since written there. Null on a routed leg,
  /// which shows those structurally instead.
  final String? notes;

  final List<ViewStop> stops;
  final bool cancelled;

  /// The itinerary row this leg is, on a stored journey — what lets the sheet
  /// offer the leg's own live-times refresh. Null for a routed one.
  final int? itemId;

  /// The routing provider's trip id, when the leg has one to refresh against.
  final String? sourceTripId;

  /// How long the leg takes, when both ends are timed.
  Duration? get duration => from.absolute == null || to.absolute == null
      ? null
      : Duration(minutes: to.absolute! - from.absolute!);
}

/// Reads a routed [JourneyOption] as a [JourneyView]: each UTC instant projected
/// into *its own* stop's timezone for display, while the arithmetic stays on the
/// UTC scale where it is exact.
JourneyView journeyViewFromOption(JourneyOption option) => JourneyView(
  legs: [for (final leg in option.legs) _routedLeg(leg)],
  transfers: option.transfers,
  duration: option.duration,
);

ViewLeg _routedLeg(JourneyLeg leg) {
  final from = _routedPoint(leg.from);
  return ViewLeg(
    mode: RoutedMode(leg.mode),
    ownSteam: leg.mode.isOwnSteam,
    from: from,
    to: _routedPoint(leg.to),
    line: leg.line,
    headsign: leg.headsign,
    stops: [for (final stop in leg.stops) _routedStop(stop, from.date)],
    cancelled: leg.cancelled,
    sourceTripId: leg.tripId,
  );
}

ViewPoint _routedPoint(LegPoint point) {
  final local = localParts(point.scheduled, point.timeZone);
  return ViewPoint(
    name: point.name,
    date: local.date,
    minutes: local.minutes,
    absolute: _epochMinutes(point.scheduled),
    actualAbsolute: point.actual == null ? null : _epochMinutes(point.actual!),
    track: point.track,
  );
}

ViewStop _routedStop(LegStop stop, DateTime legDate) {
  final local = localParts(stop.scheduledDeparture, stop.timeZone);
  return ViewStop(
    name: stop.name,
    minutes: local.minutes,
    dayOffset: local.date.difference(legDate).inDays,
    // From the UTC instants, where no projection can make a miss wrong.
    delay: stop.actualDeparture?.difference(stop.scheduledDeparture).inMinutes,
  );
}

int _epochMinutes(DateTime utc) => utc.millisecondsSinceEpoch ~/ 60000;
