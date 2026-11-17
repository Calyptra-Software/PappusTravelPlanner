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
/// - **Every line is a `<trk>`, a computed route included**, in plan order.
///   GPX has an `<rte>` for how something could go, and this export once wrote
///   computed routes as one; but the apps it is read in analyze tracks only
///   (OsmAnd's elevation and speed analysis reads `<trk>` segments and nothing
///   else), and a planned route written as a track is what BRouter, Komoot and
///   OsmAnd's own planner export too. What [TrackSource] says about the line
///   (`routed`, `recorded`, `imported`) is kept in the track's `<src>`, the
///   element GPX has for where data came from.
/// - **Only live entries**, the rule the PDF and the calendar already follow:
///   the road not taken does not leave the app.
/// - **A line the map is not drawing is still exported.** Hiding one is a
///   statement about the *picture* (see [TrackDisplay]); a GPX is the record.
///   An eye quietly changing what a file contains would be the worse surprise.
/// - **Heights where the line has them, and no timestamps**, because the import
///   dropped the times deliberately and this cannot invent them. The day the
///   entry sits on is written as the track's `<desc>` — that much is real — and
///   nothing is claimed about when anybody was at any point. So this is *not*
///   the file that was imported: it is the geometry, at the ~1 m the column
///   stores, with a height on every point of a line stored with heights.
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
      for (final line in lines) {
        _line(builder, line.item, line.track, isRoutine: isRoutine);
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
  BundleTrack track, {
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
  final elevations = trackElevationsOrNull(track.elevations, points.length);

  // The children in the order GPX 1.1 fixes for a <trk>: name, desc, src,
  // type, then the segment. A strict reader rejects any other.
  builder.element(
    'trk',
    nest: () {
      final name = _nameOf(item, track);
      if (name != null) _text(builder, 'name', name);
      // The day this entry sits on, on a trip that has days. A date and not a
      // time: the points carry no clock, and writing one would invent the very
      // thing the import dropped.
      if (!isRoutine) _text(builder, 'desc', _isoDay(item.date));
      // Where the line came from: a router's proposal, a recording, a file.
      _text(builder, 'src', track.source.name);
      // The portable mode key the bundle already denormalized — "walk",
      // "train", or whatever the user called their own mode.
      if (item.mode != null) _text(builder, 'type', item.mode!);
      builder.element(
        'trkseg',
        nest: () => _points(builder, points, elevations, 'trkpt'),
      );
    },
  );
}

void _points(
  XmlBuilder builder,
  List<LatLng> points,
  List<double>? elevations,
  String pointElement,
) {
  for (final (index, point) in points.indexed) {
    builder.element(
      pointElement,
      attributes: {
        // Five decimals is what the column holds (~1 m); more digits would be
        // precision this app does not have to give.
        'lat': point.latitude.toStringAsFixed(5),
        'lon': point.longitude.toStringAsFixed(5),
      },
      // The height, where the line has one for every point: a tenth of a
      // meter, which is what the column holds.
      nest: elevations == null
          ? null
          : () => _text(builder, 'ele', elevations[index].toStringAsFixed(1)),
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
