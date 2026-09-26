import '../../../data/database/app_database.dart';
import '../../../data/database/stopovers.dart';
import '../../../data/database/tables.dart';
import '../../itinerary/entry_times.dart';
import '../journey_view.dart';

/// Reads itinerary rows back as the journey they were imported from — the
/// counterpart of [journeyViewFromOption], and the reason a trip can still show
/// a connection leg by leg with the routing service out of reach.
///
/// [items] are one journey's entries in timeline order: the members of a group,
/// or a single leg standing alone. Only transport entries take part (a place
/// somebody grouped in with a train is not a leg of it), and each leg's mode is
/// resolved through [modesById] — the user's own [TransportModes] rows — which is
/// what decides whether a stretch is walked or ridden.
///
/// Times come out on a wall-clock scale, since that is all the rows hold. Each
/// day is counted in whole days from the epoch and each entry's times are placed
/// by `entry_times.dart`, so an overnight leg still runs forwards, a change
/// across midnight still comes out positive, and a departure planned for 23:55
/// that left at 00:10 is fifteen minutes late rather than a day early.
JourneyView journeyViewFromItems(
  List<ItineraryItem> items,
  Map<int, TransportModeRow> modesById,
) {
  final legs = [
    for (final item in items)
      if (item.kind == ItemKind.transport) _storedLeg(item, modesById),
  ];
  final services = legs.where((leg) => !leg.ownSteam).length;
  final start = legs.isEmpty ? null : legs.first.from.absolute;
  final end = legs.isEmpty ? null : legs.last.to.absolute;
  return JourneyView(
    legs: legs,
    transfers: services == 0 ? 0 : services - 1,
    duration: start == null || end == null
        ? null
        : Duration(minutes: end - start),
  );
}

ViewLeg _storedLeg(ItineraryItem item, Map<int, TransportModeRow> modesById) {
  final builtin = modesById[item.mode]?.builtinKey;
  final endDate = endDateOf(item);
  final day = _absolute(item.date, 0)!;
  final times = item.times;
  int? onLine(int? minutes) => minutes == null ? null : day + minutes;
  return ViewLeg(
    mode: StoredMode(item.mode),
    ownSteam:
        builtin == TransportMode.walk.name ||
        builtin == TransportMode.bike.name ||
        builtin == TransportMode.car.name,
    from: ViewPoint(
      name: item.fromLocation ?? '',
      date: item.date,
      minutes: item.startMinutes,
      absolute: onLine(times.plannedStart),
      actualAbsolute: onLine(times.actualStart),
    ),
    to: ViewPoint(
      name: item.toLocation ?? '',
      date: endDate,
      minutes: item.endMinutes,
      absolute: onLine(times.plannedEnd),
      actualAbsolute: onLine(times.actualEnd),
    ),
    line: item.title,
    notes: item.notes,
    stops: [
      for (final stop in decodeStopovers(item.stopovers))
        ViewStop(
          name: stop.name,
          minutes: stop.minutes,
          dayOffset: stop.dayOffset,
          delay: stop.delayMinutes,
          cancelled: stop.cancelled,
        ),
    ],
    itemId: item.id,
    sourceTripId: item.sourceTripId,
  );
}

/// [minutes] into [date] as one count of minutes, on the wall-clock scale this
/// view does its arithmetic on. The day is taken as a whole number of days from
/// the epoch — not as the local instant of its midnight, which the clocks going
/// forward would make an hour short.
int? _absolute(DateTime date, int? minutes) {
  if (minutes == null) return null;
  final days =
      DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
  return days * Duration.minutesPerDay + minutes;
}
