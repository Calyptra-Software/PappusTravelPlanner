import 'package:drift/drift.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../data/database/app_database.dart';
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
/// before it runs; an unknown or missing zone falls back to UTC rather than
/// throwing, so a leg still imports.
/// Formats a platform label (e.g. "Pl. 20") for a leg's auto-notes; supply a
/// localized one, else the neutral default is used.
typedef TrackLabel = String Function(String track);

/// Formats a direction label (e.g. "to München Hbf") for a leg's auto-notes.
typedef DirectionLabel = String Function(String destination);

String _neutralTrackLabel(String track) => 'Pl. $track';
String _neutralDirectionLabel(String destination) => '→ $destination';

List<MappedLeg> journeyToLegs(
  JourneyOption journey, {
  required int? Function(TransitMode mode) resolveMode,
  TrackLabel? trackLabel,
  DirectionLabel? directionLabel,
}) {
  final track = trackLabel ?? _neutralTrackLabel;
  final direction = directionLabel ?? _neutralDirectionLabel;
  return journey.legs
      .map((leg) => _mapLeg(leg, resolveMode, track, direction))
      .toList(growable: false);
}

/// Builds the transport [ItineraryItems] companion for a [MappedLeg] on
/// [tripId]. Sort order is left unset — the DAO appends each leg to the end of
/// its day on insert.
ItineraryItemsCompanion mappedLegToCompanion(int tripId, MappedLeg leg) =>
    ItineraryItemsCompanion.insert(
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
    );

MappedLeg _mapLeg(
  JourneyLeg leg,
  int? Function(TransitMode) resolveMode,
  TrackLabel trackLabel,
  DirectionLabel directionLabel,
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
    notes: _composeNotes(leg, trackLabel, directionLabel),
    sourceTripId: leg.tripId,
    fromLocation: leg.from.name,
    toLocation: leg.to.name,
    fromLat: leg.from.lat,
    fromLon: leg.from.lon,
    toLat: leg.to.lat,
    toLon: leg.to.lon,
  );
}

/// The auto-notes for an imported leg: its direction (destination sign) and any
/// departure/arrival platforms, as one editable line — kept in the notes rather
/// than dedicated columns, so the user can adjust or clear it. Null when the
/// service gave neither. The direction is dropped when it merely repeats the
/// arrival stop.
String? _composeNotes(
  JourneyLeg leg,
  TrackLabel trackLabel,
  DirectionLabel directionLabel,
) {
  final parts = <String>[];
  final headsign = leg.headsign;
  if (headsign != null && headsign.isNotEmpty && headsign != leg.to.name) {
    parts.add(directionLabel(headsign));
  }
  final platforms = [
    if (leg.from.track != null && leg.from.track!.isNotEmpty)
      trackLabel(leg.from.track!),
    if (leg.to.track != null && leg.to.track!.isNotEmpty)
      trackLabel(leg.to.track!),
  ];
  if (platforms.isNotEmpty) parts.add(platforms.join(' → '));
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Projects a UTC instant into [tzName]'s local wall-clock, returning the
/// calendar day and minutes-since-midnight. Shared by the mapper and the results
/// UI so both read a stop's local time the same way. Unknown zone → UTC.
({DateTime date, int minutes}) localParts(DateTime utc, String? tzName) {
  final location = _locationOrUtc(tzName);
  final local = tz.TZDateTime.from(utc, location);
  return (
    date: DateTime(local.year, local.month, local.day),
    minutes: local.hour * 60 + local.minute,
  );
}

tz.Location _locationOrUtc(String? tzName) {
  if (tzName == null) return tz.UTC;
  try {
    return tz.getLocation(tzName);
  } on tz.LocationNotFoundException {
    return tz.UTC;
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
