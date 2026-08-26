/// Fetches the demo database's public-transport legs from the live Transitous
/// instance and writes them to `tool/demo_journeys.json`, which
/// `seed_demo_db.dart` then reads.
///
///     dart run tool/fetch_demo_journeys.dart
///
/// Why a file in between, rather than either hand-written coordinates or a
/// lookup from inside the seed script:
///
/// * Hand-written ones were wrong. A hut placed off a map is a few hundred
///   metres out, which is invisible; a *stop* placed that way is the wrong stop,
///   and the demo's bus stops were up to four kilometres from the real ones.
///   Only the router knows where `Kops Gh Zeinisjoch` is, and only it can say
///   what line the bus actually is and where its road goes.
/// * Seeding straight off the network would make the demo database differ from
///   run to run and would put a request to somebody's donated server behind
///   every re-seed. Fetching is the rare act; seeding is the repeated one.
///
/// So this is run by hand when the demo route changes or the data goes stale,
/// and the result is committed. Re-running it against a later timetable will
/// produce different line numbers and minutes — that is the point of it being a
/// separate step, and the seed script is what decides how those minutes are used.
///
/// Walking transfers are dropped: the demo is authored, not an import, and a
/// station-internal hop between two platforms carries nothing the screenshots
/// want. The vehicle legs are what hold the coordinates and the shapes.
// ignore_for_file: avoid_print
library;

import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:travelplanner/data/database/track_points.dart';
import 'package:travelplanner/features/transport_search/data/motis_client.dart';
import 'package:travelplanner/features/transport_search/domain/journey.dart';
import 'package:travelplanner/features/transport_search/domain/transit_mode.dart';
import 'package:travelplanner/features/transport_search/domain/via_stop.dart';

/// The day every journey is asked about: a Wednesday in the walking season, so
/// the mountain buses run. The demo's own dates are relative to its `today`;
/// only the times of day and the routes are taken from the answers.
const String kQueryDay = '2026-08-26';

/// One journey to look up, and how to recognise the connection wanted among the
/// options the window comes back with.
///
/// [departsAt] is that recognition: the local departure of the first leg. An
/// index into the options would silently pick a different connection the next
/// time this is run, which is exactly the kind of drift a committed file must
/// not hide — so a journey whose departure is no longer offered is reported and
/// the file is not written.
class _Wanted {
  const _Wanted(
    this.key, {
    required this.from,
    required this.to,
    required this.at,
    required this.departsAt,
    this.via,
  });

  final String key;
  final String from;
  final String to;

  /// The UTC instant the search window is opened at.
  final String at;
  final String departsAt;
  final String? via;
}

const _wanted = <_Wanted>[
  // Day 1 — Würzburg to Klosters Platz, the long way out.
  _Wanted(
    'outward',
    from: 'de-DELFI_de:09663:177', // Würzburg Hbf
    to: 'ch-opentransportdataswiss26_Parentch:1:sloid:9068', // Klosters Platz
    at: '${kQueryDay}T05:00:00Z',
    departsAt: '08:55',
  ),
  // Day 4 — the Silvretta bus over to the Zeinisjoch.
  _Wanted(
    'zeinisjochBus',
    from: 'at-PTA-Tyrol-2026_at:48:1322:0:1', // Bielerhöhe Silvrettasee
    to: 'at-PTA-Tyrol-2026_at:48:1486:0:1', // Kops Gh Zeinisjoch
    at: '${kQueryDay}T08:00:00Z',
    departsAt: '10:10',
  ),
  // Day 6 — out of the Verwall, and on to Innsbruck.
  _Wanted(
    'verwallBus',
    from: 'at-PTA-Tyrol-2026_at:47:61096:0:2', // Verwall Wagner Hütte
    to: 'de-DELFI_at:47:1222', // St. Anton am Arlberg
    at: '${kQueryDay}T09:00:00Z',
    departsAt: '11:41',
  ),
  _Wanted(
    'arlbergTrain',
    from: 'de-DELFI_at:47:1222', // St. Anton am Arlberg
    to: 'at-Railway-Current-Reference-Data-2026_Pat:47:1187', // Innsbruck Hbf
    at: '${kQueryDay}T09:30:00Z',
    departsAt: '12:33',
  ),
  // Day 7 — the funicular up to the Hungerburg. The cable cars above it
  // (Seegrube, Hafelekar) are in no feed Transitous carries, so that half of the
  // ride stays authored in the seed script; see the note there.
  _Wanted(
    'hungerburgbahn',
    from: 'at-PTA-Tyrol-2026_at:47:64339:0:1', // Innsbruck Congress/Hofburg
    to: 'at-PTA-Tyrol-2026_Pat:47:61556', // Innsbruck Station Hungerburg
    at: '${kQueryDay}T07:00:00Z',
    departsAt: '09:12',
  ),
  // Day 9 — down the Rißtal and home.
  _Wanted(
    'rissBus',
    from: 'de-DELFI_at:47:62403:0:1', // Einstieg Johannestal
    to: 'de-DELFI_de:09173:4530:1:1', // Lenggries
    at: '${kQueryDay}T08:00:00Z',
    departsAt: '11:56',
  ),
  _Wanted(
    'homeward',
    from: 'de-DELFI_de:09173:4530:1:1', // Lenggries
    to: 'de-DELFI_de:09663:177', // Würzburg Hbf
    at: '${kQueryDay}T11:00:00Z',
    // Via München, because that is the way the trip is planned to go rather
    // than merely the way the router would send it.
    via: 'at-Railway-Current-Reference-Data-2026_de:09162:100:11:11',
    departsAt: '13:17',
  ),
];

Future<void> main() async {
  tzdata.initializeTimeZones();
  final search = MotisTransportSearch();
  final journeys = <String, Object?>{};

  for (final want in _wanted) {
    print('--- ${want.key}');
    final results = await search.journeys(
      fromId: want.from,
      toId: want.to,
      time: DateTime.parse(want.at),
      via: want.via == null
          ? ViaStops.none
          : ViaStops([ViaStop(id: want.via!)]),
    );
    final option = results.options
        .where((o) => _hm(o.legs.first.from) == want.departsAt)
        .firstOrNull;
    if (option == null) {
      print(
        '  no option departing at ${want.departsAt}; the window offered '
        '${results.options.map((o) => _hm(o.legs.first.from)).join(', ')}',
      );
      exitCode = 1;
      return;
    }
    final legs = [
      for (final leg in option.legs)
        if (leg.mode != TransitMode.walk) _leg(leg),
    ];
    for (final leg in legs) {
      print(
        '  ${leg['line']}  ${leg['fromName']} → ${leg['toName']}  '
        '${_clock(leg['departMinutes'] as int)}–'
        '${_clock(leg['arriveMinutes'] as int)}  '
        '${leg['shapePoints']} pts',
      );
    }
    journeys[want.key] = {'departsAt': want.departsAt, 'legs': legs};
  }

  final out = File('tool/demo_journeys.json');
  out.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({'source': 'https://api.transitous.org', 'queriedFor': kQueryDay, 'fetched': DateTime.now().toUtc().toIso8601String(), 'journeys': journeys})}\n',
  );
  print('\nwrote ${out.path} (${out.lengthSync()} bytes)');
}

/// One vehicle leg, reduced to what an `ItineraryItems` row and its `Tracks` row
/// need. The shape is re-encoded at the app's own [kTrackPrecision]: the router
/// answers at [kRoutedShapePrecision], and a line read at the wrong one lands
/// ten times away, so the conversion happens here rather than being a divisor
/// the seed script has to remember.
Map<String, Object?> _leg(JourneyLeg leg) {
  final shape = leg.shape;
  final points = shape == null
      ? const <LatLng>[]
      : decodeTrackPoints(shape, precision: kRoutedShapePrecision);
  return {
    'mode': leg.mode.name,
    'line': leg.line,
    'fromName': leg.from.name,
    'fromStopId': leg.from.stopId,
    'fromLat': leg.from.lat,
    'fromLon': leg.from.lon,
    'toName': leg.to.name,
    'toStopId': leg.to.stopId,
    'toLat': leg.to.lat,
    'toLon': leg.to.lon,
    'departMinutes': _minutes(leg.from),
    'arriveMinutes': _minutes(leg.to),
    'shapePoints': points.length,
    'shape': points.isEmpty ? null : encodeTrackPoints(points),
  };
}

/// The stop's own wall-clock minute of the day.
///
/// Deliberately not the app's `localParts`, which falls back to the device's
/// zone for an end the router left unzoned: here that fallback would write a
/// plausible wrong minute into a committed file, so an unzoned end is a fault
/// to be shouted about instead. Every end of these journeys is a stop, and a
/// stop always carries its zone.
int _minutes(LegPoint p) {
  final zone = p.timeZone;
  if (zone == null) throw StateError('no timezone on ${p.name}');
  final local = tz.TZDateTime.from(p.scheduled, tz.getLocation(zone));
  return local.hour * 60 + local.minute;
}

String _hm(LegPoint p) => _clock(_minutes(p));

String _clock(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';
