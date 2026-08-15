import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

/// One line read out of a GPX file: the points, and the name the file gave it.
///
/// Pure data, and deliberately less than the file held — see [parseGpx].
class GpxTrack {
  const GpxTrack({required this.points, this.name});

  final List<LatLng> points;

  /// The `<name>` of the `<trk>` or `<rte>` this came from, when it had one.
  final String? name;
}

/// Reads the lines out of a GPX document.
///
/// What is taken is every `<trkseg>` of every `<trk>`, and every `<rte>` — the
/// two things in the format that are a *line*. What is left behind is
/// deliberate and worth stating, because each omission is a claim this app
/// would otherwise be making:
///
/// * **`<wpt>` is ignored.** A waypoint is a place, and places in this app are
///   itinerary entries with names, times and costs hanging off them. Turning
///   marks in a file into entries in a plan is an import of a different kind,
///   and inventing a dozen untimed places from a route file is not something to
///   do behind the user's back.
/// * **Segments are not joined.** A break between two `<trkseg>` is where the
///   recording stopped — a tunnel, a pause, a lost fix — so joining them would
///   draw a straight line through ground nobody covered. They come back as
///   separate tracks under one name, which is the same rule the map already
///   follows between two places: the plan says one followed the other, not that
///   anyone walked the line between.
/// * **Elevation and time are dropped.** What is stored is a line on a map, and
///   the app has no reading for a profile or a moving average. The file remains
///   the place those live; importing it again is the way back.
///
/// Throws [FormatException] on anything that is not a GPX document, on a point
/// without usable coordinates, and on one outside the world. A file picked from
/// a phone is a file from outside, and a track quietly missing the points it
/// could not read would be a line through the wrong valley.
List<GpxTrack> parseGpx(String source) {
  final XmlDocument document;
  try {
    document = XmlDocument.parse(source);
  } on XmlException catch (e) {
    throw FormatException('Not an XML document: $e');
  }

  final root = document.rootElement;
  if (root.name.local != 'gpx') {
    throw FormatException('Not a GPX document: <${root.name.local}>');
  }

  final tracks = <GpxTrack>[];
  for (final trk in _children(root, 'trk')) {
    final name = _name(trk);
    for (final segment in _children(trk, 'trkseg')) {
      _add(tracks, name, _children(segment, 'trkpt'));
    }
  }
  for (final rte in _children(root, 'rte')) {
    _add(tracks, _name(rte), _children(rte, 'rtept'));
  }
  return tracks;
}

/// Collects one line, unless it is too short to be one.
///
/// A single point is a place rather than a line, and an empty segment is a
/// recording that never started; drawing either would put a dot on the map where
/// the file says nothing happened.
void _add(List<GpxTrack> into, String? name, Iterable<XmlElement> points) {
  final read = [for (final point in points) _point(point)];
  if (read.length < 2) return;
  into.add(GpxTrack(points: read, name: name));
}

LatLng _point(XmlElement element) {
  final lat = double.tryParse(element.getAttribute('lat') ?? '');
  final lon = double.tryParse(element.getAttribute('lon') ?? '');
  if (lat == null || lon == null) {
    throw const FormatException('GPX point without coordinates');
  }
  if (lat.isNaN ||
      lon.isNaN ||
      lat < -90 ||
      lat > 90 ||
      lon < -180 ||
      lon > 180) {
    throw FormatException('GPX point outside the world: $lat,$lon');
  }
  return LatLng(lat, lon);
}

String? _name(XmlElement element) {
  final name = _children(element, 'name').firstOrNull?.innerText.trim();
  return name == null || name.isEmpty ? null : name;
}

/// Direct children by *local* name.
///
/// By local name because a GPX file may or may not carry its namespace on a
/// prefix (`<gpx:trkpt>` and `<trkpt>` are both in the wild, and a file written
/// by one program is read by another); direct rather than descendant so a
/// `<rtept>` cannot be collected as though it were a track's.
Iterable<XmlElement> _children(XmlElement parent, String local) =>
    parent.childElements.where((e) => e.name.local == local);
