import 'dart:convert';

/// One stop a transport leg passes through, as the trip stores it.
///
/// Wall-clock like every other time in this app: [minutes] is minutes since
/// midnight (0-1439) of the day [dayOffset] days after the leg's own `date`, so
/// a night train's 02:14 in Nuremberg is `(134, dayOffset: 1)`. The time is the
/// **departure** — see `LegStop` on why — except at the end of a vehicle's run,
/// which has none and is timed by its arrival (only [RunStops.after] can hold
/// such a stop). A stop the vehicle calls at *before* the leg's own departure
/// day has a negative [dayOffset].
class Stopover {
  const Stopover({
    required this.name,
    required this.minutes,
    this.dayOffset = 0,
    this.delayMinutes,
    this.cancelled = false,
    this.dwellMinutes,
    this.lat,
    this.lon,
    this.timeZone,
  });

  final String name;
  final int minutes;
  final int dayOffset;

  /// How long the vehicle is planned to stand here, in minutes: its departure
  /// less its arrival. Null where the feed gave only one of the two, and for
  /// stops stored before this was kept. Not shown; it is what lets a position
  /// estimated from the timetable wait at a station rather than glide through.
  final int? dwellMinutes;

  /// Where the stop is, when the router said. Null for stops stored before
  /// this was kept.
  final double? lat;
  final double? lon;

  /// The IANA zone [minutes] is wall-clock time in (`Europe/Berlin`). The trip
  /// otherwise keeps no zones at all, so this is what turns a stored minute
  /// back into an instant, which "where is the train now" needs.
  final String? timeZone;

  /// Whether the service **skips** this stop — a partial cancellation, the train
  /// still running but no longer calling here.
  ///
  /// It is kept beside the plan rather than removing the stop: the timetable
  /// still says the train passes at this minute, and a stop that quietly
  /// vanished would leave a traveller waiting for it. A skipped stop never
  /// carries a [delayMinutes]: there is no departure to be late for, and the
  /// feed repeats the planned time for it, which would otherwise print as a
  /// confident "(+0)".
  final bool cancelled;

  /// How late the service is leaving here, in minutes (negative: early), or null
  /// when nothing real-time is known about this stop. Captured at import when
  /// the search already carried real-time, and rewritten by the leg's own
  /// live-times refresh — the same act that updates its ends.
  ///
  /// The **miss** is stored rather than the actual time, unlike the leg's ends
  /// (`actualStartMinutes`). It is what is printed either way, it is computed
  /// from UTC instants and so is exact, and — unlike a wall-clock actual — a
  /// delay past midnight cannot make it read as a day early: 23:58 running five
  /// late is `(+5)`, where an actual of `3` would be −1435.
  final int? delayMinutes;

  /// This stop as the live trip now has it: skipped, or running [delay] late.
  /// The two are exclusive — see [cancelled].
  Stopover withLive({int? delay, bool cancelled = false}) => Stopover(
    name: name,
    minutes: minutes,
    dayOffset: dayOffset,
    delayMinutes: cancelled ? null : delay,
    cancelled: cancelled,
    dwellMinutes: dwellMinutes,
    lat: lat,
    lon: lon,
    timeZone: timeZone,
  );

  /// This stop with whatever it does not yet know about itself (its position,
  /// zone and dwell) filled in from an answer about the same stop. What it
  /// already knows is kept.
  Stopover filledFrom({
    int? dwellMinutes,
    double? lat,
    double? lon,
    String? timeZone,
  }) {
    final hasPosition = this.lat != null && this.lon != null;
    return Stopover(
      name: name,
      minutes: minutes,
      dayOffset: dayOffset,
      delayMinutes: delayMinutes,
      cancelled: cancelled,
      dwellMinutes: this.dwellMinutes ?? dwellMinutes,
      lat: hasPosition ? this.lat : lat,
      lon: hasPosition ? this.lon : lon,
      timeZone: this.timeZone ?? timeZone,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Stopover &&
      other.name == name &&
      other.minutes == minutes &&
      other.dayOffset == dayOffset &&
      other.delayMinutes == delayMinutes &&
      other.cancelled == cancelled &&
      other.dwellMinutes == dwellMinutes &&
      other.lat == lat &&
      other.lon == lon &&
      other.timeZone == timeZone;

  @override
  int get hashCode => Object.hash(
    name,
    minutes,
    dayOffset,
    delayMinutes,
    cancelled,
    dwellMinutes,
    lat,
    lon,
    timeZone,
  );

  @override
  String toString() =>
      'Stopover($name, $minutes, ${dayOffset < 0 ? '' : '+'}$dayOffset'
      '${delayMinutes == null ? '' : ', ${delayMinutes}late'}'
      '${cancelled ? ', cancelled' : ''})';
}

/// Encodes a leg's stopovers for its `ItineraryItems.stopovers` column, or null
/// when there are none — a leg without them stores nothing rather than an empty
/// list.
///
/// A JSON array of objects rather than a table of its own: stopovers belong to
/// exactly one leg, are written once by the import and read only when that leg
/// is looked at, so they ride in the row they describe. Objects (not tuples) and
/// omitted defaults are what let a later version carry more per stop without a
/// data migration — [decodeStopovers] ignores what it does not know.
String? encodeStopovers(List<Stopover> stops) {
  if (stops.isEmpty) return null;
  return jsonEncode(_encodeStops(stops));
}

List<Map<String, dynamic>> _encodeStops(List<Stopover> stops) => [
  for (final stop in stops)
    {
      'name': stop.name,
      'minutes': stop.minutes,
      if (stop.dayOffset != 0) 'day': stop.dayOffset,
      if (stop.delayMinutes != null) 'delay': stop.delayMinutes,
      if (stop.cancelled) 'cancelled': true,
      if (stop.dwellMinutes != null) 'dwell': stop.dwellMinutes,
      if (stop.lat != null && stop.lon != null) ...{
        'lat': stop.lat,
        'lon': stop.lon,
      },
      if (stop.timeZone != null) 'tz': stop.timeZone,
    },
];

/// Reads back what [encodeStopovers] wrote. Anything unreadable — a null column,
/// a truncated string, a value some other tool put there — decodes to no stops:
/// the leg is still a leg, and a timeline that threw over its garnish would be
/// the worse failure.
List<Stopover> decodeStopovers(String? encoded) {
  if (encoded == null || encoded.isEmpty) return const [];
  try {
    return _decodeStops(jsonDecode(encoded));
  } on FormatException {
    return const [];
  }
}

List<Stopover> _decodeStops(Object? decoded) {
  if (decoded is! List) return const [];
  return [
    for (final e in decoded)
      if (e is Map<String, dynamic> && e['minutes'] is int)
        Stopover(
          name: e['name'] as String? ?? '',
          minutes: e['minutes'] as int,
          dayOffset: e['day'] is int ? e['day'] as int : 0,
          delayMinutes: e['delay'] is int ? e['delay'] as int : null,
          cancelled: e['cancelled'] == true,
          dwellMinutes: e['dwell'] is int ? e['dwell'] as int : null,
          // Read as `num`: a coordinate that happens to be whole may come back
          // from JSON as an int.
          lat: e['lat'] is num && e['lon'] is num
              ? (e['lat'] as num).toDouble()
              : null,
          lon: e['lat'] is num && e['lon'] is num
              ? (e['lon'] as num).toDouble()
              : null,
          timeZone: e['tz'] is String ? e['tz'] as String : null,
        ),
  ];
}

/// [encoded] with what the live trip once said about each stop (the delays and
/// the skipped calls) taken off, and the timetable left.
///
/// For a leg put onto another day: a delay measured on one Tuesday is not part
/// of the plan, and a stop that was skipped then may well be served now. A value
/// that does not decode is returned as it is; there is nothing in it to strip.
String? stopoversWithoutLive(String? encoded) {
  final stops = decodeStopovers(encoded);
  if (stops.isEmpty) return encoded;
  return encodeStopovers([for (final stop in stops) stop.withLive()]);
}

/// The rest of the vehicle's run around a leg: the stops it calls at before the
/// traveler boards ([before]) and after they get off ([after]), each in the
/// order it calls at them. The leg's own ends are not among them, and neither
/// are its [Stopover]s in between.
///
/// Stored in a column of its own (`ItineraryItems.runStops`) rather than in the
/// stopovers beside the leg's own stops, because an app that predates it would
/// read every entry of a shared list as a stop *between* the ends and send the
/// traveler through stations that lie behind them. A column it does not know
/// it simply never reads.
///
/// Days are counted from the leg's own `date`, like a stopover's, so a night
/// train boarded after midnight has stops at `dayOffset: -1`.
class RunStops {
  const RunStops({this.before = const [], this.after = const []});

  final List<Stopover> before;
  final List<Stopover> after;

  /// Whether the leg covers the vehicle's whole run, origin to terminus.
  bool get isEmpty => before.isEmpty && after.isEmpty;

  /// These stops with what the live trip once said about each taken off — see
  /// [stopoversWithoutLive].
  RunStops withoutLive() => RunStops(
    before: [for (final stop in before) stop.withLive()],
    after: [for (final stop in after) stop.withLive()],
  );

  @override
  bool operator ==(Object other) =>
      other is RunStops &&
      _listEquals(other.before, before) &&
      _listEquals(other.after, after);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(before), Object.hashAll(after));
}

bool _listEquals(List<Stopover> a, List<Stopover> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Encodes a leg's [RunStops] for its `ItineraryItems.runStops` column.
///
/// Unlike [encodeStopovers] an empty run is **not** null: null means the run has
/// never been asked for, while `{"before":[],"after":[]}` is the answer that the
/// leg covers the vehicle's whole run, and the two are offered different things
/// (a button to load it, and nothing).
String encodeRunStops(RunStops run) => jsonEncode({
  'before': _encodeStops(run.before),
  'after': _encodeStops(run.after),
});

/// Reads back what [encodeRunStops] wrote: null for a run never loaded, and for
/// anything unreadable, which is then simply offered to be loaded again.
RunStops? decodeRunStops(String? encoded) {
  if (encoded == null || encoded.isEmpty) return null;
  try {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) return null;
    return RunStops(
      before: _decodeStops(decoded['before']),
      after: _decodeStops(decoded['after']),
    );
  } on FormatException {
    return null;
  }
}

/// [encoded] with the live part of every stop taken off, for a leg put onto
/// another day — the counterpart of [stopoversWithoutLive].
String? runStopsWithoutLive(String? encoded) {
  final run = decodeRunStops(encoded);
  if (run == null) return encoded;
  return encodeRunStops(run.withoutLive());
}
