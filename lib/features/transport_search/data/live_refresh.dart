import '../domain/journey.dart';
import 'journey_mapper.dart' show localParts;

/// The refreshed actual times for a stored leg, in minutes-since-midnight (the
/// same encoding as the itinerary). Either end may be null when the live trip
/// had no real-time value for it.
class RefreshedTimes {
  const RefreshedTimes({this.actualStartMinutes, this.actualEndMinutes});

  final int? actualStartMinutes;
  final int? actualEndMinutes;
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

  if (actualStart == null && actualEnd == null) return null;
  return RefreshedTimes(
    actualStartMinutes: actualStart,
    actualEndMinutes: actualEnd,
  );
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
