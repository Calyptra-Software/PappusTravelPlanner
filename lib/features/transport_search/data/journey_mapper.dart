import 'package:drift/drift.dart';

import '../../../core/format/civil_date.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../data/database/app_database.dart';
import '../../../data/database/stopovers.dart';
import '../../../data/database/tables.dart';
import '../domain/journey.dart';
import '../domain/transit_mode.dart';

/// Turns a routed [JourneyOption] into itinerary-ready legs — the pure heart of
/// importing a connection.
///
/// Two conversions happen here, both deliberately away from the network layer so
/// they test without one:
///
///  * **UTC → wall-clock.** MOTIS times are UTC instants plus a per-stop IANA
///    timezone; each end is projected into *its own* zone (a leg can depart in
///    Berlin and arrive in a different offset), giving the day it belongs to and
///    minutes-since-midnight. When arrival lands on the next calendar day the leg
///    is flagged [MappedLeg.spansNextDay] rather than split — an overnight train
///    stays one entry anchored to its departure day.
///  * **Mode fan-in.** The routing vocabulary ([TransitMode]) collapses onto the
///    app's built-in [TransportMode] catalogue via [builtinTransportModeFor],
///    then onto a concrete row id through the caller's [resolveMode] — which
///    returns null when the built-in was deleted, exactly as an unmapped mode
///    does. The two steps are split so a future user-defined override can slot in
///    at [resolveMode] without touching the fan-in.
///
/// Requires the timezone database to be initialised (`initializeTimeZones()`)
/// before it runs; an unknown or missing zone falls back to the device's own
/// rather than throwing, so a leg still imports (see [localParts]).
/// Formats a platform label (e.g. "Pl. 20") for a leg's auto-notes; supply a
/// localized one, else the neutral default is used.
typedef TrackLabel = String Function(String track);

/// Formats a direction label (e.g. "to München Hbf") for a leg's auto-notes.
typedef DirectionLabel = String Function(String destination);

String _neutralTrackLabel(String track) => 'Pl. $track';
String _neutralFromTrackLabel(String track) => 'from Pl. $track';
String _neutralToTrackLabel(String track) => 'to Pl. $track';
String _neutralDirectionLabel(String destination) => '→ $destination';

List<MappedLeg> journeyToLegs(
  JourneyOption journey, {
  required int? Function(TransitMode mode) resolveMode,
  TrackLabel? trackLabel,
  TrackLabel? fromTrackLabel,
  TrackLabel? toTrackLabel,
  DirectionLabel? directionLabel,
}) {
  final labels = _NoteLabels(
    track: trackLabel ?? _neutralTrackLabel,
    fromTrack: fromTrackLabel ?? _neutralFromTrackLabel,
    toTrack: toTrackLabel ?? _neutralToTrackLabel,
    direction: directionLabel ?? _neutralDirectionLabel,
  );
  return journey.legs
      .map((leg) => _mapLeg(leg, resolveMode, labels))
      .toList(growable: false);
}

/// The four label formatters `_composeNotes` writes with, travelling together
/// because they only ever appear together.
class _NoteLabels {
  const _NoteLabels({
    required this.track,
    required this.fromTrack,
    required this.toTrack,
    required this.direction,
  });

  final TrackLabel track;
  final TrackLabel fromTrack;
  final TrackLabel toTrack;
  final DirectionLabel direction;
}

/// The day a leg found on [foundOn] takes when the journey is laid onto
/// [planDay] — how a connection searched on a real date enters a **routine**,
/// which has no dates of its own.
///
/// The shape is what survives: a leg on the search day lands on [planDay], and
/// one that ran past midnight lands a day further into the plan, so an overnight
/// journey stays overnight. Counted in whole calendar days, since the search day
/// and the plan day are both civil dates and a [Duration] would be an hour short
/// across a daylight-saving change.
DateTime rebasedLegDay(
  DateTime legDate, {
  required DateTime foundOn,
  required DateTime planDay,
}) => addDays(planDay, daysBetween(foundOn, legDate));

/// Builds the transport [ItineraryItems] companion for a [MappedLeg] on
/// [tripId]. Sort order is left unset — the DAO appends each leg to the end of
/// its day on insert.
///
/// [fromPlaceId] / [toPlaceId] are how the router addresses the *journey's* own
/// endpoints — the ids the search was issued against — and so belong only to
/// the first and last leg of the run. The stations in between are changes, not
/// endpoints: a journey is searched again as a whole, from where it starts to
/// where it ends, so nothing needs an id for the middle.
ItineraryItemsCompanion mappedLegToCompanion(
  int tripId,
  MappedLeg leg, {
  String? fromPlaceId,
  String? toPlaceId,
}) => ItineraryItemsCompanion.insert(
  fromPlaceId: Value(fromPlaceId),
  toPlaceId: Value(toPlaceId),
  tripId: tripId,
  date: leg.date,
  kind: ItemKind.transport,
  title: Value(leg.title),
  startMinutes: Value(leg.startMinutes),
  endMinutes: Value(leg.endMinutes),
  actualStartMinutes: Value(leg.actualStartMinutes),
  actualEndMinutes: Value(leg.actualEndMinutes),
  spansNextDay: Value(leg.spansNextDay),
  mode: Value(leg.modeId),
  notes: Value(leg.notes),
  sourceTripId: Value(leg.sourceTripId),
  fromLocation: Value(leg.fromLocation),
  toLocation: Value(leg.toLocation),
  fromLat: Value(leg.fromLat),
  fromLon: Value(leg.fromLon),
  toLat: Value(leg.toLat),
  toLon: Value(leg.toLon),
  stopovers: Value(encodeStopovers(leg.stopovers)),
);

MappedLeg _mapLeg(
  JourneyLeg leg,
  int? Function(TransitMode) resolveMode,
  _NoteLabels labels,
) {
  final from = localParts(leg.from.scheduled, leg.from.timeZone);
  final to = localParts(leg.to.scheduled, leg.to.timeZone);
  // Capture real-time at import when the search result already carries it (an
  // imminent train) — the same live values a refresh would fill in — so a
  // just-imported leg shows its delay without waiting for a refresh. Null (and
  // so no actuals) for a purely-scheduled future search.
  final actualStart = leg.from.actual == null
      ? null
      : localParts(leg.from.actual!, leg.from.timeZone).minutes;
  final actualEnd = leg.to.actual == null
      ? null
      : localParts(leg.to.actual!, leg.to.timeZone).minutes;
  return MappedLeg(
    date: from.date,
    startMinutes: from.minutes,
    endMinutes: to.minutes,
    actualStartMinutes: actualStart,
    actualEndMinutes: actualEnd,
    spansNextDay: to.date.isAfter(from.date),
    modeId: resolveMode(leg.mode),
    title: leg.line,
    notes: _composeNotes(leg, labels),
    sourceTripId: leg.tripId,
    fromLocation: leg.from.name,
    toLocation: leg.to.name,
    fromLat: leg.from.lat,
    fromLon: leg.from.lon,
    toLat: leg.to.lat,
    toLon: leg.to.lon,
    stopovers: _mapStops(leg, from.date),
    // Carried through untouched, still at the router's precision: the import
    // writes it, and nothing between here and there needs the points.
    shape: leg.shape,
  );
}

/// The leg's intermediate stops in the app's own terms: each stop's departure as
/// wall-clock minutes, dated by how many days it falls after the leg's own
/// [legDate], plus any delay the search already knew of. Each stop is projected
/// into *its own* timezone, exactly as the leg's ends are — a night train
/// crosses zones between them — while the delay is taken from the UTC instants,
/// where no projection can make it wrong.
List<Stopover> _mapStops(JourneyLeg leg, DateTime legDate) => [
  for (final stop in leg.stops) _mapStop(stop, legDate),
];

Stopover _mapStop(LegStop stop, DateTime legDate) {
  final local = localParts(stop.scheduledDeparture, stop.timeZone);
  return Stopover(
    name: stop.name,
    minutes: local.minutes,
    dayOffset: local.date.difference(legDate).inDays,
    // A skipped stop is not a punctual one: the feed goes on repeating its
    // planned departure, which would otherwise import as "(+0)".
    delayMinutes: stop.cancelled
        ? null
        : stop.actualDeparture?.difference(stop.scheduledDeparture).inMinutes,
    cancelled: stop.cancelled,
  );
}

/// The auto-notes for an imported leg: its direction (destination sign) and any
/// departure/arrival platforms, as one editable line — kept in the notes rather
/// than dedicated columns, so the user can adjust or clear it. Null when the
/// service gave neither. The direction is dropped when it merely repeats the
/// arrival stop.
///
/// Which end a platform belongs to is said by the arrow — "Pl. 5 → Pl. 20" —
/// but only a service that named *both* has an arrow to say it with. Where just
/// one end is known the label names the end instead ("from Pl. 5"), since a bare
/// "Pl. 5" reads identically whether it is where the leg starts or where it
/// ends: on a walking transfer between two platforms of the same station, the
/// difference is the whole content of the note.
///
/// The wording is *from/to*, not departure/arrival, because the note describes
/// the leg it sits on. On a transfer "departure" is the word for the next
/// train's platform, so "dep. Pl. 5" on the walk that leads away from platform
/// 5 would send a reader to the platform they just left.
String? _composeNotes(JourneyLeg leg, _NoteLabels labels) {
  final parts = <String>[];
  final headsign = leg.headsign;
  if (headsign != null && headsign.isNotEmpty && headsign != leg.to.name) {
    parts.add(labels.direction(headsign));
  }
  final from = _trackOrNull(leg.from.track);
  final to = _trackOrNull(leg.to.track);
  if (from != null && to != null) {
    parts.add('${labels.track(from)} → ${labels.track(to)}');
  } else if (from != null) {
    parts.add(labels.fromTrack(from));
  } else if (to != null) {
    parts.add(labels.toTrack(to));
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

String? _trackOrNull(String? track) =>
    track == null || track.isEmpty ? null : track;

/// Projects a UTC instant into [tzName]'s local wall-clock, returning the
/// calendar day and minutes-since-midnight. Shared by the mapper and the results
/// UI so both read a stop's local time the same way.
///
/// With no usable zone — none given, or one this build's tzdata does not know —
/// it falls back to the **device's** zone, not to UTC. Every end of a journey
/// normally carries one, and `journey_ends.dart` fills in an end the router left
/// unzoned from the journey around it; what reaches here unzoned is therefore a
/// journey with no zoned stop anywhere in it, which in practice means walking or
/// cycling between two coordinates. Reading that as UTC put a Hamburg walk in the
/// timeline two hours early — and, on import, two hours early in the database.
/// The device's zone is a guess too, but it is the one that is right for the
/// short hop this case actually is, and it is wrong only for a traveller who has
/// not yet changed their clock; UTC was wrong for everybody outside it.
({DateTime date, int minutes}) localParts(DateTime utc, String? tzName) {
  final location = _locationOrNull(tzName);
  final local = location == null
      ? utc.toLocal()
      : tz.TZDateTime.from(utc, location);
  return (
    date: DateTime(local.year, local.month, local.day),
    minutes: local.hour * 60 + local.minute,
  );
}

tz.Location? _locationOrNull(String? tzName) {
  if (tzName == null) return null;
  try {
    return tz.getLocation(tzName);
  } on tz.LocationNotFoundException {
    return null;
  }
}

/// A single leg reduced to the fields an [ItineraryItems] transport row needs:
/// local [date], planned start/end minutes, the overnight flag, a resolved
/// [modeId] (or null), endpoint names and coordinates. The repository turns a
/// list of these into rows — assigning the trip, sort order and any group.
class MappedLeg {
  const MappedLeg({
    required this.date,
    required this.startMinutes,
    required this.endMinutes,
    required this.actualStartMinutes,
    required this.actualEndMinutes,
    required this.spansNextDay,
    required this.modeId,
    required this.title,
    required this.notes,
    required this.sourceTripId,
    required this.fromLocation,
    required this.toLocation,
    required this.fromLat,
    required this.fromLon,
    required this.toLat,
    required this.toLon,
    this.stopovers = const [],
    this.shape,
  });

  final DateTime date;
  final int startMinutes;
  final int endMinutes;

  /// Real-time-adjusted times captured at import when the leg already had them
  /// (an imminent train); null for a purely-scheduled future search.
  final int? actualStartMinutes;
  final int? actualEndMinutes;
  final bool spansNextDay;
  final int? modeId;
  final String? title;

  /// Auto-composed direction/platform line (see `_composeNotes`); stored as the
  /// item's notes, editable by the user.
  final String? notes;

  /// The routing provider's trip id, kept so live times can be refreshed.
  final String? sourceTripId;
  final String fromLocation;
  final String toLocation;
  final double? fromLat;
  final double? fromLon;
  final double? toLat;
  final double? toLon;

  /// The stops passed through between the two ends, kept so the journey can be
  /// read back offline (see [Stopover]).
  final List<Stopover> stopovers;

  /// The route the leg takes, as the router's encoded polyline at *its*
  /// precision. Unlike everything else here this is not a column: it becomes a
  /// `Tracks` row beside the item, which is why `insertJourney` takes it
  /// separately rather than finding it on the companion.
  final String? shape;
}

/// Builds the resolver [journeyToLegs] needs: a routing mode → a concrete
/// [TransportModes] row id, or null.
///
/// It composes the pure fan-in ([builtinTransportModeFor]) with a lookup of the
/// live modes by their stable `builtinKey`. A built-in the user deleted is simply
/// absent from [modes], so it resolves to null — the leg imports without a mode,
/// exactly as an unmapped routing mode does — and it is never resurrected. A
/// renamed or re-iconed built-in still resolves, since it keeps its `builtinKey`.
int? Function(TransitMode) modeResolver(List<TransportModeRow> modes) {
  final idByBuiltinKey = {
    for (final m in modes)
      if (m.builtinKey != null) m.builtinKey!: m.id,
  };
  return (transit) {
    final builtin = builtinTransportModeFor(transit);
    if (builtin == null) return null;
    return idByBuiltinKey[builtin.name];
  };
}

/// The fan-in from a routing mode onto the app's built-in [TransportMode]
/// catalogue. Granular rail all collapses onto `train`; a coach onto `bus`; an
/// S-Bahn onto `train`. Modes with no sensible built-in (aerial lifts, funiculars
/// and the catch-all) return null so the leg imports without a mode rather than
/// being forced into `other`, which should stay a user's own choice.
TransportMode? builtinTransportModeFor(TransitMode mode) {
  switch (mode) {
    case TransitMode.walk:
      return TransportMode.walk;
    case TransitMode.bike:
      return TransportMode.bike;
    case TransitMode.car:
      return TransportMode.car;
    case TransitMode.bus:
    case TransitMode.coach:
      return TransportMode.bus;
    case TransitMode.tram:
      return TransportMode.tram;
    case TransitMode.subway:
    case TransitMode.monorail:
      return TransportMode.subway;
    case TransitMode.suburban:
    case TransitMode.rail:
    case TransitMode.highSpeedRail:
    case TransitMode.longDistanceRail:
    case TransitMode.nightRail:
    case TransitMode.regionalRail:
    case TransitMode.regionalFastRail:
      return TransportMode.train;
    case TransitMode.ferry:
      return TransportMode.ferry;
    case TransitMode.funicular:
    case TransitMode.gondola:
    case TransitMode.aerialLift:
    case TransitMode.other:
      return null;
  }
}
