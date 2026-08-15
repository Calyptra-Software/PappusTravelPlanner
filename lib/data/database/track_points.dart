import 'package:latlong2/latlong.dart';

/// How many digits of a degree survive the round trip: five, or about 1.1 m at
/// the equator.
///
/// A recorded track is a consumer GPS fix, good to a few metres on a clear day
/// and much worse under trees, so a metre of quantisation is well inside the
/// noise it already carries. What it buys is size: the encoding below writes
/// *differences* between consecutive points, and a walking track's steps then
/// fit in one or two bytes each instead of the sixteen a pair of doubles takes.
const int kTrackPrecision = 100000;

/// A track's points, packed into one string for the column that holds them.
///
/// This is Google's encoded-polyline format, which is worth using rather than
/// inventing: every mapping tool reads it, so a track can leave this app for
/// somewhere else without a decoder being written first. It stores each
/// coordinate as the **difference** from the one before, in units of
/// [kTrackPrecision], as a variable-length run of printable ASCII — so a dense
/// track of small steps costs far less than its point count suggests, which is
/// the whole reason a track can live in a column at all.
///
/// The inverse is [decodeTrackPoints]. Both are pure, and neither knows what a
/// track *is* — provenance, name and owner live in the row around this string.
String encodeTrackPoints(List<LatLng> points) {
  final out = StringBuffer();
  var lastLat = 0;
  var lastLon = 0;
  for (final point in points) {
    final lat = (point.latitude * kTrackPrecision).round();
    final lon = (point.longitude * kTrackPrecision).round();
    _writeValue(out, lat - lastLat);
    _writeValue(out, lon - lastLon);
    // Against the *rounded* previous value, not the original: otherwise each
    // step's rounding error is added to the next one and the line drifts.
    lastLat = lat;
    lastLon = lon;
  }
  return out.toString();
}

/// Reads back what [encodeTrackPoints] wrote.
///
/// Throws [FormatException] on a string that is not one of ours — a truncated
/// run of continuation bytes, or a coordinate outside the world. It is called
/// on rows this app wrote *and* on a shared bundle somebody else's copy of it
/// wrote, and the second of those is a file from outside.
List<LatLng> decodeTrackPoints(String encoded) {
  final points = <LatLng>[];
  var index = 0;
  var lat = 0;
  var lon = 0;
  while (index < encoded.length) {
    final start = index;
    final (dLat, afterLat) = _readValue(encoded, index);
    final (dLon, afterLon) = _readValue(encoded, afterLat);
    index = afterLon;
    if (index == start) throw const FormatException('Empty track segment');
    lat += dLat;
    lon += dLon;
    final latitude = lat / kTrackPrecision;
    final longitude = lon / kTrackPrecision;
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw FormatException(
        'Track point outside the world: $latitude,$longitude',
      );
    }
    points.add(LatLng(latitude, longitude));
  }
  return points;
}

/// One signed value, zig-zag encoded so a small negative step costs as little as
/// a small positive one, then written five bits at a time.
void _writeValue(StringBuffer out, int value) {
  var v = value < 0 ? ~(value << 1) : value << 1;
  while (v >= 0x20) {
    out.writeCharCode((0x20 | (v & 0x1f)) + 63);
    v >>= 5;
  }
  out.writeCharCode(v + 63);
}

/// The inverse of [_writeValue], returning the value and where it ended.
(int, int) _readValue(String encoded, int index) {
  var shift = 0;
  var result = 0;
  int byte;
  do {
    if (index >= encoded.length) {
      throw const FormatException('Truncated track point');
    }
    byte = encoded.codeUnitAt(index++) - 63;
    if (byte < 0) throw const FormatException('Bad character in track');
    result |= (byte & 0x1f) << shift;
    shift += 5;
    // Six groups cover the 32 bits a coordinate needs; more means the string is
    // not one of ours, and left unchecked would spin up an arbitrary integer.
    if (shift > 30 && byte >= 0x20) {
      throw const FormatException('Overlong track point');
    }
  } while (byte >= 0x20);
  return (result & 1 != 0 ? ~(result >> 1) : result >> 1, index);
}
