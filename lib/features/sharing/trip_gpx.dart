import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

import '../../core/app_info.dart';
import '../../data/database/tables.dart';
import '../../data/database/track_points.dart';
import 'trip_bundle.dart';
import 'trip_pdf_sections.dart' show bundleItemIsLive, chosenBranchLocalIds;

/// MIME type of an exported set of lines.
const String tripGpxMimeType = 'application/gpx+xml';

/// File extension of an exported set of lines.
const String tripGpxExtension = 'gpx';

/// Renders the lines a trip's entries carry as a GPX 1.1 document — the format
/// every mapping tool reads — or **null** when the trip holds none.
///
/// This exists because half of what is stored has no original anywhere else:
/// importing one recording across several entries *cuts* it, and those pieces
/// live only here, as do the routes the connection search computed. The packed
/// column was chosen so a line could leave this app without a decoder having to
/// be written first; until there was a way to write one out, that was true only
/// for somebody willing to write the decoder.
///
/// A one-way view, like the PDF and the `.ics` — `.tpt` is still the export that
/// round-trips. What it keeps and what it cannot:
///
/// - **A recording is a `<trk>`, a computed route is an `<rte>`.** GPX draws
///   exactly the distinction [TrackSource] draws — a track is where something
///   went, a route is how it could go — and it is the same one the map draws
///   with its dash. `parseGpx` reads both, so what leaves as a route comes back
///   as one. The routes are written **before** the tracks because the GPX schema
///   says so (`metadata`, then `wpt*`, `rte*`, `trk*`), and a strict reader
///   rejects a file that orders them by anything else — including by the plan.
/// - **Only live entries**, the rule the PDF and the calendar already follow:
///   the road not taken does not leave the app.
/// - **A line the map is not drawing is still exported.** Hiding one is a
///   statement about the *picture* (see [TrackDisplay]); a GPX is the record.
///   An eye quietly changing what a file contains would be the worse surprise.
/// - **No elevation and no timestamps**, because the import dropped them
///   deliberately and this cannot invent them. The day the entry sits on is
///   written as the track's `<desc>` — that much is real — and nothing is
///   claimed about when anybody was at any point. So this is *not* the file that
///   was imported: it is the geometry, at the ~1 m the column stores.
/// - **A routine's lines carry no day at all.** Its entries sit on
///   `kRoutineAnchorDay`, which is a sort origin and not a date anybody
///   travelled; writing it out would be the "1970" fiction the app refuses
///   everywhere else. The lines themselves are worth having — the commute's
///   route is a route — so a routine is exported like anything else, minus the
///   one field that would lie.
///
/// Pure (no database, no `BuildContext`), like its two siblings.
/// [exportedAt] stamps the document (defaults to now); tests pass a fixed value
/// to get a byte-stable file.
String? buildTripGpx({
  required TripBundle bundle,
  String? creator,
  DateTime? exportedAt,
}) {
  final chosen = chosenBranchLocalIds(bundle);
  final isRoutine = bundle.trip.kind == TripKind.routine;
  final lines = <({BundleItem item, BundleTrack track})>[
    for (final item in bundle.items)
      if (bundleItemIsLive(item, chosen))
        for (final track in item.tracks) (item: item, track: track),
  ];
  if (lines.isEmpty) return null;

  final builder = XmlBuilder();
  builder.processing('xml', 'version="1.0" encoding="UTF-8"');
  builder.element(
    'gpx',
    attributes: {
      'version': '1.1',
      'creator': creator ?? kAppName,
      'xmlns': 'http://www.topografix.com/GPX/1/1',
    },
    nest: () {
      builder.element(
        'metadata',
        nest: () {
          _text(builder, 'name', bundle.trip.title);
          // The file's own creation time, which is the one time here nobody has
          // to guess at.
          _text(
            builder,
            'time',
            (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
          );
        },
      );
      // Routes first, tracks second — the schema's order, not the plan's.
      for (final line in lines) {
        if (line.track.source != TrackSource.routed) continue;
        _line(
          builder,
          line.item,
          line.track,
          'rte',
          'rtept',
          isRoutine: isRoutine,
        );
      }
      for (final line in lines) {
        if (line.track.source == TrackSource.routed) continue;
        _line(
          builder,
          line.item,
          line.track,
          'trk',
          'trkpt',
          isRoutine: isRoutine,
        );
      }
    },
  );
  return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
}

/// One stored line as its GPX element. A track's points sit in a `<trkseg>`, a
/// route's directly in the `<rte>` — the one place the two shapes differ.
void _line(
  XmlBuilder builder,
  BundleItem item,
  BundleTrack track,
  String element,
  String pointElement, {
  required bool isRoutine,
}) {
  final List<LatLng> points;
  try {
    points = decodeTrackPoints(track.points);
  } on FormatException {
    // A line that will not decode is left out rather than written as an empty
    // one: the same trade the map makes, where a row from somebody else's copy
    // must not cost the whole trip its drawing.
    return;
  }
  if (points.length < 2) return;

  builder.element(
    element,
    nest: () {
      final name = _nameOf(item, track);
      if (name != null) _text(builder, 'name', name);
      // The day this entry sits on, on a trip that has days. A date and not a
      // time: the points carry no clock, and writing one would invent the very
      // thing the import dropped.
      if (!isRoutine) _text(builder, 'desc', _isoDay(item.date));
      // The portable mode key the bundle already denormalized — "walk",
      // "train", or whatever the user called their own mode.
      if (item.mode != null) _text(builder, 'type', item.mode!);
      if (element == 'trk') {
        builder.element(
          'trkseg',
          nest: () => _points(builder, points, pointElement),
        );
      } else {
        _points(builder, points, pointElement);
      }
    },
  );
}

void _points(XmlBuilder builder, List<LatLng> points, String pointElement) {
  for (final point in points) {
    builder.element(
      pointElement,
      attributes: {
        // Five decimals is what the column holds (~1 m); more digits would be
        // precision this app does not have to give.
        'lat': point.latitude.toStringAsFixed(5),
        'lon': point.longitude.toStringAsFixed(5),
      },
    );
  }
}

/// What to call one line in a reader's list: the entry it belongs to, and the
/// name the file gave the line, when either exists.
///
/// Nothing is invented — an entry with no label and a line with no name simply
/// get no `<name>`, which is the rule the table itself follows.
String? _nameOf(BundleItem item, BundleTrack track) {
  final label =
      item.title ??
      (item.fromLocation != null || item.toLocation != null
          ? '${item.fromLocation ?? '?'} → ${item.toLocation ?? '?'}'
          : item.location);
  final parts = [?label, ?track.name];
  return parts.isEmpty ? null : parts.join(' · ');
}

String _isoDay(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

void _text(XmlBuilder builder, String name, String value) =>
    builder.element(name, nest: () => builder.text(value));
