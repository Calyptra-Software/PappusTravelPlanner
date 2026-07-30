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
/// rather than mis-timed. [spansNextDay] places the arrival on the following day,
/// as the itinerary does.
///
/// A **cancellation** is reported the moment either end of the leg is skipped,
/// even though there are then no times to go with it: not being run is the most
/// important thing a live trip can say about a leg.
RefreshedTimes? refreshedActualTimes({
  required List<TripStop> stops,
  required DateTime date,
  required int startMinutes,
  required int endMinutes,
  required bool spansNextDay,
  required String fromName,
  required String toName,
}) {
  final arrivalDate = spansNextDay ? date.add(const Duration(days: 1)) : date;

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
List<Stopover> refreshedStopovers({
  required List<TripStop> stops,
  required List<Stopover> stopovers,
  required DateTime date,
}) => [
  for (final stopover in stopovers)
    stopover.withDelay(_stopoverDelay(stops, stopover, date)),
];

int? _stopoverDelay(List<TripStop> stops, Stopover stopover, DateTime date) {
  final match = _match(
    stops,
    name: stopover.name,
    wantDate: date.add(Duration(days: stopover.dayOffset)),
    wantMinutes: stopover.minutes,
    scheduled: (s) => s.scheduledDeparture,
  );
  final planned = match?.scheduledDeparture;
  final live = match?.departure;
  if (planned == null || live == null) return null;
  return live.difference(planned).inMinutes;
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
  TripStop? byName;
  for (final stop in stops) {
    final planned = scheduled(stop);
    if (planned != null) {
      final local = localParts(planned, stop.timeZone);
      if (local.date == wantDate && local.minutes == wantMinutes) return stop;
    }
    if (byName == null && stop.name == name && planned != null) byName = stop;
  }
  return byName;
}
