/// Finding an imported leg's run again after the router has forgotten its id.
///
/// The router reissues its trip ids with every timetable it loads, so a leg
/// imported a few days ago asks `/trip` about an id that answers 404, although
/// the train it names runs exactly as planned. What does not change is the
/// service itself: the same train, leaving the same station at the same
/// minute. So the leg is looked up on that station's departure board and the
/// one departure that is unmistakably it supplies the current id.
///
/// Pure, so which departure counts as "unmistakably it" is testable without a
/// network.
library;

import 'package:timezone/timezone.dart' as tz;

import '../../../data/database/stopovers.dart';
import '../domain/journey.dart';
import 'journey_mapper.dart' show localParts;

/// How far either side of the planned departure the board is read. The match
/// itself is to the minute, so this only has to make sure the departure is on
/// the page; it is kept small because a busy station's board runs to a few
/// kilobytes a minute. It does not absorb a zone guessed an hour wrong (see
/// [relocationWindowStart]): that leg is reported as not found.
const Duration kRelocationSlack = Duration(minutes: 15);

/// The current trip id of the run a stored leg names, read off its boarding
/// station's [departures], or null when that cannot be said for certain.
///
/// A departure is the leg's run when it carries the leg's [line] (the label
/// the import stored as the title, compared as the router writes it) **and**
/// leaves at the leg's planned departure, [startMinutes] on [date], read in
/// the station's own zone. Exactly one run may match: none means the service
/// has changed (renumbered, retimed, withdrawn, or a title edited by hand),
/// and two would be a guess. Either way null, since the cost of a wrong id is
/// another train's delays shown as this one's.
String? relocatedTripId({
  required List<StopDeparture> departures,
  required String? line,
  required DateTime date,
  required int startMinutes,
}) {
  final wanted = line?.trim();
  if (wanted == null || wanted.isEmpty) return null;
  final matches = {
    for (final departure in departures)
      if (departure.name.trim() == wanted &&
          _leavesAt(departure, date: date, minutes: startMinutes))
        departure.tripId,
  };
  return matches.length == 1 ? matches.single : null;
}

bool _leavesAt(
  StopDeparture departure, {
  required DateTime date,
  required int minutes,
}) {
  final local = localParts(departure.scheduledDeparture, departure.timeZone);
  return local.date == date && local.minutes == minutes;
}

/// Where to start reading the board for a leg leaving at [startMinutes] on
/// [date]: [kRelocationSlack] before that wall-clock time, made an instant in
/// the zone of the leg's own stops.
///
/// The trip stores no zone for a leg's ends, but its stops have carried one
/// since v42, and the stop nearest the boarding station shares its zone in all
/// but a border case. Without any (a leg imported before v42, or one with no
/// stops between its ends) the device's zone stands in, as it does wherever a
/// time from the router arrives unzoned. That is right in the case this is
/// for: a leg refreshed on the day, by someone standing in the station's zone.
DateTime relocationWindowStart({
  required DateTime date,
  required int startMinutes,
  required List<Stopover> stopovers,
  RunStops? run,
}) {
  final zone = _zoneOf([...?run?.before.reversed, ...stopovers]);
  final hour = startMinutes ~/ 60;
  final minute = startMinutes % 60;
  final planned = zone == null
      ? DateTime(date.year, date.month, date.day, hour, minute).toUtc()
      : tz.TZDateTime(
          zone,
          date.year,
          date.month,
          date.day,
          hour,
          minute,
        ).toUtc();
  return planned.subtract(kRelocationSlack);
}

/// The zone of the first stop in [stops] that names one this build knows.
tz.Location? _zoneOf(List<Stopover> stops) {
  for (final stop in stops) {
    final name = stop.timeZone;
    if (name == null) continue;
    try {
      return tz.getLocation(name);
    } on tz.LocationNotFoundException {
      continue;
    }
  }
  return null;
}
