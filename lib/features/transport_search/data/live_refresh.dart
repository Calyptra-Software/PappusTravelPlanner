import '../../../core/format/civil_date.dart';
import '../../../data/database/stopovers.dart';
import '../domain/journey.dart';
import 'journey_mapper.dart' show localParts;

/// What the live trip says about a stored leg: its actual times, in
/// minutes-since-midnight (the same encoding as the itinerary), or that the
/// service is not running at all. Either end may be null when the live trip had
/// no real-time value for it.
class RefreshedTimes {
  const RefreshedTimes({
    this.actualStartMinutes,
    this.actualEndMinutes,
    this.cancelled = false,
  });

  final int? actualStartMinutes;
  final int? actualEndMinutes;

  /// Whether the service will not call at the stops this leg uses — the whole
  /// trip cancelled, or just this stretch of it skipped.
  ///
  /// A cancelled trip carries **no** real-time times (the service reports
  /// `realTime: false` for it), so this never arrives alongside actual times;
  /// it is the answer *instead* of them, and the reason the refresh cannot
  /// simply say "nothing to update".
  final bool cancelled;
}

/// Reads a stored leg's *actual* departure/arrival from its trip's live [stops]
/// — the pure heart of the live-times refresh.
///
/// The board and alight stops are found within the trip by matching their
/// **planned** local time (and name) against what the leg stored at import, then
/// their real-time [TripStop.departure]/[TripStop.arrival] are projected into the
/// stop's timezone to minutes-since-midnight. Returns null when neither end could
/// be matched — so a leg whose schedule has since changed is left untouched
/// rather than mis-timed. [endDayOffset] places the arrival that many days
/// after [date], as the itinerary does.
///
/// A **cancellation** is reported the moment either end of the leg is skipped,
/// even though there are then no times to go with it: not being run is the most
/// important thing a live trip can say about a leg.
RefreshedTimes? refreshedActualTimes({
  required List<TripStop> stops,
  required DateTime date,
  required int startMinutes,
  required int endMinutes,
  required int endDayOffset,
  required String fromName,
  required String toName,
}) {
  final arrivalDate = addDays(date, endDayOffset);

  final board = _match(
    stops,
    name: fromName,
    wantDate: date,
    wantMinutes: startMinutes,
    scheduled: (s) => s.scheduledDeparture,
  );
  final alight = _match(
    stops,
    name: toName,
    wantDate: arrivalDate,
    wantMinutes: endMinutes,
    scheduled: (s) => s.scheduledArrival,
  );

  final actualStart = board?.departure == null
      ? null
      : localParts(board!.departure!, board.timeZone).minutes;
  final actualEnd = alight?.arrival == null
      ? null
      : localParts(alight!.arrival!, alight.timeZone).minutes;

  // Either end being skipped strands the leg, so either end is enough to
  // report — and a matched-but-cancelled stop is a finding, not a miss.
  final cancelled = (board?.cancelled ?? false) || (alight?.cancelled ?? false);
  if (actualStart == null && actualEnd == null && !cancelled) return null;
  return RefreshedTimes(
    actualStartMinutes: actualStart,
    actualEndMinutes: actualEnd,
    cancelled: cancelled,
  );
}

/// Re-reads the delay at each of a leg's stored [stopovers] from the same live
/// [stops] the leg's own ends are refreshed from — so one tap updates the whole
/// leg, ends and everything in between.
///
/// Each stopover is found in the trip the same way the ends are: by its planned
/// local time, dated from the leg's [date] plus its own day offset, with a name
/// fallback. A stop that cannot be found, or that the live trip has nothing to
/// say about, comes back with **no** delay rather than the one it had: we have
/// just asked, and an answer that no longer mentions the stop is not evidence
/// for the old figure.
///
/// A stop the trip now **skips** is marked as such instead of timed. This is the
/// one thing a stop list must not get wrong: a partially cancelled service goes
/// on reporting the planned departure for the stops it is dropping, so reading
/// that as a time would tell a traveller their station is served, punctually, by
/// a train that will pass straight through it.
List<Stopover> refreshedStopovers({
  required List<TripStop> stops,
  required List<Stopover> stopovers,
  required DateTime date,
}) => [
  for (final stopover in stopovers) _refreshedStopover(stops, stopover, date),
];

Stopover _refreshedStopover(
  List<TripStop> stops,
  Stopover stopover,
  DateTime date,
) {
  final match = _match(
    stops,
    name: stopover.name,
    wantDate: addDays(date, stopover.dayOffset),
    wantMinutes: stopover.minutes,
    scheduled: (s) => s.scheduledDeparture,
  );
  if (match == null) return stopover.withLive();
  // A stop imported before its position and zone were kept learns them here,
  // from the same answer that times it.
  final located = stopover.filledFrom(
    dwellMinutes: _dwell(match),
    lat: match.lat,
    lon: match.lon,
    timeZone: match.timeZone,
  );
  if (match.cancelled) return located.withLive(cancelled: true);
  final planned = match.scheduledDeparture;
  final live = match.departure;
  return located.withLive(
    delay: planned == null || live == null
        ? null
        : live.difference(planned).inMinutes,
  );
}

/// The rest of the vehicle's run around a stored leg, read off the same live
/// [stops] its times are refreshed from: every stop before the one the leg
/// boards at, and every stop after the one it gets off at.
///
/// The two ends are found exactly as [refreshedActualTimes] finds them, by
/// their planned local time with a name fallback. Null when either cannot be
/// found, or when they come out in the wrong order: a run that cannot be lined
/// up with the leg is left unstored rather than split at a guess.
///
/// Each stop is timed by its departure, the terminus by its arrival, and both
/// are dated in days from the leg's [date] — negative for a stop the vehicle
/// called at the day before.
RunStops? runStopsAround({
  required List<TripStop> stops,
  required DateTime date,
  required int startMinutes,
  required int endMinutes,
  required int endDayOffset,
  required String fromName,
  required String toName,
}) {
  final board = _matchIndex(
    stops,
    name: fromName,
    wantDate: date,
    wantMinutes: startMinutes,
    scheduled: (s) => s.scheduledDeparture,
  );
  final alight = _matchIndex(
    stops,
    name: toName,
    wantDate: addDays(date, endDayOffset),
    wantMinutes: endMinutes,
    scheduled: (s) => s.scheduledArrival,
  );
  if (board == null || alight == null || alight <= board) return null;
  return RunStops(
    before: [for (final stop in stops.take(board)) ?_runStop(stop, date)],
    after: [for (final stop in stops.skip(alight + 1)) ?_runStop(stop, date)],
  );
}

/// One stop of the run as the trip stores it, or null for one the service gave
/// no planned time at all.
Stopover? _runStop(TripStop stop, DateTime date) {
  // The departure where there is one, so the run reads like the stops in
  // between; the terminus, which has none, by its arrival.
  final departs = stop.scheduledDeparture != null;
  final planned = stop.scheduledDeparture ?? stop.scheduledArrival;
  if (planned == null) return null;
  final live = departs ? stop.departure : stop.arrival;
  final local = localParts(planned, stop.timeZone);
  return Stopover(
    name: stop.name,
    minutes: local.minutes,
    dayOffset: daysBetween(date, local.date),
    delayMinutes: stop.cancelled || live == null
        ? null
        : live.difference(planned).inMinutes,
    cancelled: stop.cancelled,
    dwellMinutes: _dwell(stop),
    lat: stop.lat,
    lon: stop.lon,
    timeZone: stop.timeZone,
  );
}

/// How long the timetable has the vehicle standing at [stop], when it gives
/// both an arrival and a departure there.
int? _dwell(TripStop stop) {
  final arrival = stop.scheduledArrival;
  final departure = stop.scheduledDeparture;
  if (arrival == null || departure == null) return null;
  return departure.difference(arrival).inMinutes;
}

/// Finds the stop whose planned local time equals ([wantDate], [wantMinutes]);
/// falls back to a name match if the schedule has since shifted.
TripStop? _match(
  List<TripStop> stops, {
  required String name,
  required DateTime wantDate,
  required int wantMinutes,
  required DateTime? Function(TripStop) scheduled,
}) {
  final index = _matchIndex(
    stops,
    name: name,
    wantDate: wantDate,
    wantMinutes: wantMinutes,
    scheduled: scheduled,
  );
  return index == null ? null : stops[index];
}

/// Where in [stops] [_match] finds its stop.
int? _matchIndex(
  List<TripStop> stops, {
  required String name,
  required DateTime wantDate,
  required int wantMinutes,
  required DateTime? Function(TripStop) scheduled,
}) {
  int? byName;
  for (final (index, stop) in stops.indexed) {
    final planned = scheduled(stop);
    if (planned != null) {
      final local = localParts(planned, stop.timeZone);
      if (local.date == wantDate && local.minutes == wantMinutes) return index;
    }
    if (byName == null && stop.name == name && planned != null) byName = index;
  }
  return byName;
}
