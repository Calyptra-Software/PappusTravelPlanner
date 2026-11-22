import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';

/// The zoom level terrain tiles are read at: about 13 m a pixel in the Alps
/// for a 512 px tile, finer than a piste is drawn in the map data.
const int kTerrainZoom = 12;

/// How far apart a line drawn by hand is given points for its heights: about
/// a pixel and a half of a tile at [kTerrainZoom], so the line follows the
/// ground rather than jumping from one end's height to the other's.
const double kStraightHeightStep = 20;

/// [points] with points set in between, evenly, so that no two are more than
/// [step] meters apart. Straight in degrees between two points, which over
/// the length of a hand-drawn section is the line the map draws.
List<LatLng> densify(List<LatLng> points, {double step = kStraightHeightStep}) {
  const distance = Distance(calculator: Haversine());
  final dense = <LatLng>[];
  for (var i = 0; i < points.length; i++) {
    final point = points[i];
    if (i > 0) {
      final from = points[i - 1];
      final pieces = (distance.distance(from, point) / step).ceil();
      for (var k = 1; k < pieces; k++) {
        final share = k / pieces;
        dense.add(
          LatLng(
            from.latitude + (point.latitude - from.latitude) * share,
            from.longitude + (point.longitude - from.longitude) * share,
          ),
        );
      }
    }
    dense.add(point);
  }
  return dense;
}

/// One terrain tile on the Web Mercator grid, by zoom, column and row.
typedef TileKey = ({int z, int x, int y});

/// The heights of one terrain tile, row by row from its north-west corner.
class TerrainTile {
  TerrainTile(this.size, this.heights) : assert(heights.length == size * size);

  /// Pixels along each side.
  final int size;

  /// The height of each pixel in meters.
  final Float32List heights;

  double at(int column, int row) => heights[row * size + column];
}

/// Reads a terrain tile in the Terrarium encoding, PNG or WebP: a pixel's
/// height is `red × 256 + green + blue / 256 − 32768` meters.
///
/// Only those two decoders see the bytes, picked by their signature, since
/// the bytes come from a server: no other format is offered them.
///
/// Throws [FormatException] for bytes that are not a square image in either.
/// Top level, so that it can run in `compute`.
TerrainTile decodeTerrainTile(Uint8List bytes) {
  final img.Decoder decoder;
  if (_startsWith(bytes, 0, const [0x89, 0x50, 0x4E, 0x47])) {
    decoder = img.PngDecoder();
  } else if (_startsWith(bytes, 0, 'RIFF'.codeUnits) &&
      _startsWith(bytes, 8, 'WEBP'.codeUnits)) {
    decoder = img.WebPDecoder();
  } else {
    throw const FormatException('Not a PNG or WebP terrain tile');
  }
  final img.Image? image;
  try {
    image = decoder.decode(bytes);
  } on Object catch (e) {
    throw FormatException('Unreadable terrain tile: $e');
  }
  if (image == null || image.width != image.height || image.width == 0) {
    throw const FormatException('Not a terrain tile');
  }
  final size = image.width;
  final heights = Float32List(size * size);
  for (var row = 0; row < size; row++) {
    for (var column = 0; column < size; column++) {
      final pixel = image.getPixel(column, row);
      heights[row * size + column] =
          pixel.r * 256 + pixel.g + pixel.b / 256 - 32768;
    }
  }
  return TerrainTile(size, heights);
}

bool _startsWith(Uint8List bytes, int offset, List<int> signature) {
  if (bytes.length < offset + signature.length) return false;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[offset + i] != signature[i]) return false;
  }
  return true;
}

/// Where [point] lies on the tile grid of [zoom], in tiles: the whole part is
/// the tile's column or row, the rest the position within it.
({double x, double y}) tilePosition(LatLng point, int zoom) {
  final n = math.pow(2, zoom).toDouble();
  // Web Mercator ends at about 85.05°; clamped, a point beyond lies on the
  // grid's edge rather than off it.
  final latitude = point.latitude.clamp(-85.05112878, 85.05112878);
  final radians = latitude * math.pi / 180;
  final y =
      (1 - math.log(math.tan(radians) + 1 / math.cos(radians)) / math.pi) /
      2 *
      n;
  final x = (point.longitude + 180) / 360 * n;
  return (x: x.clamp(0, n - 1e-9), y: y.clamp(0, n - 1e-9));
}

/// The tiles of [zoom] that the heights at [points] are read from.
///
/// A height is blended from the four pixels around it, so a point within
/// half a pixel of a tile's edge needs the tile beyond as well. The tile size
/// is not known before a tile is read; [edge] (in tiles) is half a pixel of
/// the smallest tile there is, 256 px, and so wide enough for every size.
Set<TileKey> tilesFor(
  List<LatLng> points, {
  int zoom = kTerrainZoom,
  double edge = 0.5 / 256,
}) {
  final n = 1 << zoom;
  final tiles = <TileKey>{};
  for (final point in points) {
    final (:x, :y) = tilePosition(point, zoom);
    final columns = {(x - edge).floor(), (x + edge).floor()};
    final rows = {(y - edge).floor(), (y + edge).floor()};
    for (final column in columns) {
      for (final row in rows) {
        tiles.add((z: zoom, x: column % n, y: row.clamp(0, n - 1)));
      }
    }
  }
  return tiles;
}

/// The height at each of [points], blended from the four pixels around it,
/// read from [tiles] (which must hold every tile [tilesFor] names). All tiles
/// are taken to be the same size.
List<double> heightsAt(
  List<LatLng> points,
  Map<TileKey, TerrainTile> tiles, {
  int zoom = kTerrainZoom,
}) {
  final size = tiles.values.first.size;
  final n = 1 << zoom;
  final pixels = n * size;

  double pixel(int column, int row) {
    final wrapped = column % pixels;
    final clamped = row.clamp(0, pixels - 1);
    final tile = tiles[(z: zoom, x: wrapped ~/ size, y: clamped ~/ size)]!;
    return tile.at(wrapped % size, clamped % size);
  }

  return [
    for (final point in points)
      () {
        final (:x, :y) = tilePosition(point, zoom);
        // A pixel's height stands for the middle of the pixel.
        final px = x * size - 0.5;
        final py = y * size - 0.5;
        final column = px.floor();
        final row = py.floor();
        final fx = px - column;
        final fy = py - row;
        final top = pixel(column, row) * (1 - fx) + pixel(column + 1, row) * fx;
        final bottom =
            pixel(column, row + 1) * (1 - fx) + pixel(column + 1, row + 1) * fx;
        return top * (1 - fy) + bottom * fy;
      }(),
  ];
}

/// [heights] with each point flagged in [aloft] lifted off the ground: its
/// height runs straight, by distance along [points], between the nearest
/// points before and after it that are not aloft.
///
/// What a lift is: the terrain under a cable can drop into a valley between
/// two pylons, and a profile following it would show a ride climbing and
/// falling, and count that as climb.
List<double> levelAloft(
  List<LatLng> points,
  List<double> heights,
  List<bool> aloft,
) {
  assert(points.length == heights.length && points.length == aloft.length);
  const distance = Distance(calculator: Haversine());
  final along = <double>[0];
  for (var i = 1; i < points.length; i++) {
    along.add(along.last + distance.distance(points[i - 1], points[i]));
  }
  final level = [...heights];
  var i = 0;
  while (i < points.length) {
    if (!aloft[i]) {
      i++;
      continue;
    }
    var end = i;
    while (end < points.length && aloft[end]) {
      end++;
    }
    final before = i - 1;
    // A path neither starts nor ends aloft; if one did, its heights stay.
    if (before >= 0 && end < points.length) {
      final span = along[end] - along[before];
      for (var k = i; k < end; k++) {
        final share = span == 0 ? 0.0 : (along[k] - along[before]) / span;
        level[k] = heights[before] + (heights[end] - heights[before]) * share;
      }
    }
    i = end;
  }
  return level;
}
