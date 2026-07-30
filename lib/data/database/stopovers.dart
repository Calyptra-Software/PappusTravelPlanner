import 'dart:convert';

/// One stop a transport leg passes through, as the trip stores it.
///
/// Wall-clock like every other time in this app: [minutes] is minutes since
/// midnight (0-1439) of the day [dayOffset] days after the leg's own `date`, so
/// a night train's 02:14 in Nuremberg is `(134, dayOffset: 1)`. Only the
/// departure is kept — see `LegStop` on why.
class Stopover {
  const Stopover({
    required this.name,
    required this.minutes,
    this.dayOffset = 0,
    this.delayMinutes,
    this.cancelled = false,
  });

  final String name;
  final int minutes;
  final int dayOffset;

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
  );

  @override
  bool operator ==(Object other) =>
      other is Stopover &&
      other.name == name &&
      other.minutes == minutes &&
      other.dayOffset == dayOffset &&
      other.delayMinutes == delayMinutes &&
      other.cancelled == cancelled;

  @override
  int get hashCode =>
      Object.hash(name, minutes, dayOffset, delayMinutes, cancelled);

  @override
  String toString() =>
      'Stopover($name, $minutes, +$dayOffset'
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
  return jsonEncode([
    for (final stop in stops)
      {
        'name': stop.name,
        'minutes': stop.minutes,
        if (stop.dayOffset != 0) 'day': stop.dayOffset,
        if (stop.delayMinutes != null) 'delay': stop.delayMinutes,
        if (stop.cancelled) 'cancelled': true,
      },
  ]);
}

/// Reads back what [encodeStopovers] wrote. Anything unreadable — a null column,
/// a truncated string, a value some other tool put there — decodes to no stops:
/// the leg is still a leg, and a timeline that threw over its garnish would be
/// the worse failure.
List<Stopover> decodeStopovers(String? encoded) {
  if (encoded == null || encoded.isEmpty) return const [];
  try {
    final decoded = jsonDecode(encoded);
    if (decoded is! List) return const [];
    return [
      for (final e in decoded)
        if (e is Map<String, dynamic> && e['minutes'] is int)
          Stopover(
            name: e['name'] as String? ?? '',
            minutes: e['minutes'] as int,
            dayOffset: e['day'] as int? ?? 0,
            delayMinutes: e['delay'] is int ? e['delay'] as int : null,
            cancelled: e['cancelled'] == true,
          ),
    ];
  } on FormatException {
    return const [];
  }
}
