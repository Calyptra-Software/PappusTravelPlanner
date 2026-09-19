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

/// What the routing service encodes its leg shapes at — a tenth of a degree
/// finer than ours, and reported by the API in every `legGeometry`. Named here
/// rather than passed as a literal because getting it wrong is not a small
/// error: the line lands ten times too far away.
const int kRoutedShapePrecision = 1000000;

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
/// [precision] is what the column stores at and needs no argument; it exists so
/// the two halves of the codec agree about what is configurable. A codec whose
/// writer hardcodes what its reader takes as a parameter is a trap waiting for
/// the first line that has to be written in somebody else's units.
///
/// The inverse is [decodeTrackPoints]. Both are pure, and neither knows what a
/// track *is* — provenance, name and owner live in the row around this string.
String encodeTrackPoints(
  List<LatLng> points, {
  int precision = kTrackPrecision,
}) {
  final out = StringBuffer();
  var lastLat = 0;
  var lastLon = 0;
  for (final point in points) {
    final lat = (point.latitude * precision).round();
    final lon = (point.longitude * precision).round();
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
/// [precision] is the divisor the *writer* used, and it is a parameter because
/// the encoding does not carry it: the same characters mean a tenth of the
/// distance at 1e-6 that they mean at 1e-5. Our column is always
/// [kTrackPrecision], but the routing service answers at 1e-6 (measured, not
/// assumed), and a line read at the wrong one lands ten times too far from
/// where it belongs — off the map rather than visibly wrong, which is worse.
///
/// Throws [FormatException] on a string that is not one of ours — a truncated
/// run of continuation bytes, or a coordinate outside the world. It is called
/// on rows this app wrote *and* on a shared bundle somebody else's copy of it
/// wrote, and the second of those is a file from outside.
List<LatLng> decodeTrackPoints(
  String encoded, {
  int precision = kTrackPrecision,
}) {
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
    final latitude = lat / precision;
    final longitude = lon / precision;
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
///
/// Written as multiplication and division rather than shifts and masks, which
/// is not a matter of taste: on the web an `int` is a JavaScript number and the
/// bitwise operators truncate to **32 bits, unsigned**, so `~n` answers
/// `2^32 - n - 1` where the VM answers `-n - 1`. The two halves of this codec
/// then disagree across platforms — see [_readValue], where that cost every
/// negative value in the database. The arithmetic below is exact on both: five
/// bits at a time is a factor of 32, and the values stay far inside the 2^53 a
/// double holds whole (a longitude at the router's 1e-6 is 1.8e8).
void _writeValue(StringBuffer out, int value) {
  var v = value < 0 ? -value * 2 - 1 : value * 2;
  while (v >= 0x20) {
    out.writeCharCode(0x20 + v % 0x20 + 63);
    v ~/= 0x20;
  }
  out.writeCharCode(v + 63);
}

/// The inverse of [_writeValue], returning the value and where it ended.
///
/// The zig-zag is undone by arithmetic for the reason [_writeValue] gives, and
/// this is the half that was measured going wrong: `~(result >> 1)` on the web
/// turned a step of −22402 into 4294944894, so a line's first move south or
/// west threw it out of the world — every recorded track, and every country
/// outline, since both are read through here.
(int, int) _readValue(String encoded, int index) {
  var bits = 0;
  var place = 1;
  var result = 0;
  int byte;
  do {
    if (index >= encoded.length) {
      throw const FormatException('Truncated track point');
    }
    byte = encoded.codeUnitAt(index++) - 63;
    if (byte < 0) throw const FormatException('Bad character in track');
    result += (byte % 0x20) * place;
    place *= 0x20;
    bits += 5;
    // Six groups cover the 32 bits a coordinate needs; more means the string is
    // not one of ours, and left unchecked would spin up an arbitrary integer.
    if (bits > 30 && byte >= 0x20) {
      throw const FormatException('Overlong track point');
    }
  } while (byte >= 0x20);
  return (result.isOdd ? -((result + 1) ~/ 2) : result ~/ 2, index);
}
