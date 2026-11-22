import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/core/cache_files.dart';
import 'package:travelplanner/features/route_planner/data/terrain_tiles.dart';
import 'package:travelplanner/features/route_planner/domain/route_profile.dart';
import 'package:travelplanner/features/route_planner/domain/terrain.dart';
import 'package:travelplanner/features/route_planner/domain/tour.dart';

/// [CacheFiles] in memory.
class _MemoryFiles implements CacheFiles {
  final files = <String, String>{};

  @override
  Future<String?> read(String key) async => files[key];

  @override
  Future<void> write(String key, String content) async => files[key] = content;

  @override
  Future<List<String>> keys() async => files.keys.toList();

  @override
  Future<void> delete(String key) async => files.remove(key);
}

/// A Terrarium PNG of [size] px whose pixel at (column, row) is
/// `height(column, row)` meters.
Uint8List _png(int size, double Function(int column, int row) height) {
  final image = img.Image(width: size, height: size);
  for (var row = 0; row < size; row++) {
    for (var column = 0; column < size; column++) {
      final value = height(column, row) + 32768;
      final whole = value.floor();
      image.setPixelRgb(
        column,
        row,
        whole ~/ 256,
        whole % 256,
        ((value - whole) * 256).round(),
      );
    }
  }
  return img.encodePng(image);
}

/// The point at tile position ([x], [y]) on the grid of [zoom]: the inverse
/// of [tilePosition].
LatLng _pointAt(double x, double y, {int zoom = kTerrainZoom}) {
  final n = math.pow(2, zoom);
  final longitude = x / n * 360 - 180;
  final latitude =
      math.atan(
        (math.exp(math.pi * (1 - 2 * y / n)) -
                math.exp(-math.pi * (1 - 2 * y / n))) /
            2,
      ) *
      180 /
      math.pi;
  return LatLng(latitude, longitude);
}

void main() {
  group('decodeTerrainTile', () {
    test('reads the Terrarium encoding from a PNG', () {
      final tile = decodeTerrainTile(_png(4, (c, r) => 1000 + c * 10 + r / 2));

      expect(tile.size, 4);
      expect(tile.at(0, 0), 1000);
      expect(tile.at(3, 2), 1031);
      expect(tile.at(1, 1), 1010.5);
    });

    test('reads a Mapterhorn tile, which is WebP', () {
      // Fetched once on 2026-11-22 from tiles.mapterhorn.com; terrain data
      // from the sources at https://mapterhorn.com/attribution.
      final tile = decodeTerrainTile(
        File('test/fixtures/mapterhorn_12_2157_1444.webp').readAsBytesSync(),
      );
      final point = const LatLng(46.7781, 9.6497);

      final [height] = heightsAt([point], {(z: 12, x: 2157, y: 1444): tile});

      expect(tile.size, 512);
      // Open-Meteo and OpenTopoData both said 2032 m for this point.
      expect(height, closeTo(2032, 3));
    });

    test('offers the bytes to no decoder but PNG and WebP', () {
      final gif = img.encodeGif(img.Image(width: 4, height: 4));

      expect(img.decodeImage(gif), isNotNull, reason: 'a readable image');
      expect(() => decodeTerrainTile(gif), throwsFormatException);
    });

    test('refuses bytes that are no image', () {
      expect(
        () => decodeTerrainTile(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
    });
  });

  group('tilesFor', () {
    test('a point inside a tile needs that tile', () {
      expect(tilesFor([_pointAt(10.5, 20.5)]), {(z: 12, x: 10, y: 20)});
    });

    test('a point at an edge needs the tile beyond, at a corner all four', () {
      expect(tilesFor([_pointAt(11.0001, 20.5)]), {
        (z: 12, x: 10, y: 20),
        (z: 12, x: 11, y: 20),
      });
      expect(tilesFor([_pointAt(11.0001, 20.9999)]), {
        (z: 12, x: 10, y: 20),
        (z: 12, x: 11, y: 20),
        (z: 12, x: 10, y: 21),
        (z: 12, x: 11, y: 21),
      });
    });

    test('wraps around the antimeridian', () {
      final tiles = tilesFor([const LatLng(0, -179.99999)]);

      expect(tiles.map((t) => t.x), containsAll([0, 4095]));
    });
  });

  group('heightsAt', () {
    test('blends the four pixels around a point', () {
      final tiles = {
        (z: 12, x: 10, y: 20): decodeTerrainTile(
          _png(4, (c, r) => c * 10.0 + r),
        ),
      };
      // Pixel (1, 2) is centered at 1.5 / 4 and 2.5 / 4 of the tile; halfway
      // to pixel (2, 3).
      final [atPixel, between] = heightsAt([
        _pointAt(10 + 1.5 / 4, 20 + 2.5 / 4),
        _pointAt(10 + 2 / 4, 20 + 3 / 4),
      ], tiles);

      expect(atPixel, closeTo(12, 1e-6));
      expect(between, closeTo(17.5, 1e-6));
    });

    test('blends across the edge of two tiles', () {
      final tiles = {
        (z: 12, x: 10, y: 20): decodeTerrainTile(_png(4, (c, r) => c * 1.0)),
        (z: 12, x: 11, y: 20): decodeTerrainTile(
          _png(4, (c, r) => 4 + c * 1.0),
        ),
      };

      final [height] = heightsAt([_pointAt(11, 20.5)], tiles);

      expect(height, closeTo(3.5, 1e-6));
    });
  });

  group('densify', () {
    test('sets points evenly between the ends, none farther apart', () {
      const from = LatLng(47, 11);
      const to = LatLng(47.001, 11); // About 111 m.

      final dense = densify(const [from, to]);

      expect(dense.first, from);
      expect(dense.last, to);
      expect(dense, hasLength(7)); // Six steps of about 18.5 m.
      const distance = Distance(calculator: Haversine());
      for (var i = 1; i < dense.length; i++) {
        expect(
          distance.distance(dense[i - 1], dense[i]),
          lessThanOrEqualTo(kStraightHeightStep),
        );
      }
    });

    test('leaves a line already that fine as it is', () {
      const line = [LatLng(47, 11), LatLng(47.0001, 11)];

      expect(densify(line), line);
    });
  });

  group('lineKey', () {
    final tour = Tour(
      waypoints: const [
        TourWaypoint(LatLng(47, 11)),
        TourWaypoint(LatLng(47.1, 11)),
        TourWaypoint(LatLng(47.2, 11)),
      ],
      modes: const [StraightMode(), RoutedMode(RouteProfile.foot)],
    );

    test('keys a straight section, never one the router is asked', () {
      expect(lineKey(tour, 0), startsWith('line|'));
      expect(lineKey(tour, 1), isNull);
      expect(sectionKey(tour, 0), isNull);
      expect(lineKey(tour, 0), isNot(sectionKey(tour, 1)));
    });

    test('a straight run is keyed by its waypoints', () {
      final [straight, routed] = tourRuns(tour);

      expect(lineRunKey(tour, straight), lineKey(tour, 0));
      expect(lineRunKey(tour, routed), isNull);
    });
  });

  group('levelAloft', () {
    test('runs the points aloft straight between the ground around them', () {
      final points = [
        const LatLng(47, 11),
        const LatLng(47.001, 11),
        const LatLng(47.003, 11),
        const LatLng(47.004, 11),
      ];

      final level = levelAloft(
        points,
        [1000, 900, 950, 1400],
        [false, true, true, false],
      );

      expect(level.first, 1000);
      expect(level.last, 1400);
      // A quarter and three quarters of the way.
      expect(level[1], closeTo(1100, 0.5));
      expect(level[2], closeTo(1300, 0.5));
    });

    test('leaves a path without points aloft as it is', () {
      final points = [const LatLng(47, 11), const LatLng(47.001, 11)];

      expect(levelAloft(points, [1, 2], [false, false]), [1, 2]);
    });
  });

  group('TerrainTileHeights', () {
    late List<http.Request> requests;
    late http.Response Function(http.Request request) answer;
    late _MemoryFiles files;
    late DateTime now;
    final tile = _png(4, (c, r) => 2000);

    setUp(() {
      requests = [];
      answer = (_) => http.Response.bytes(tile, 200);
      files = _MemoryFiles();
      now = DateTime(2026, 11, 22);
    });

    TerrainTileHeights heights({bool withFiles = true}) => TerrainTileHeights(
      TerrainTileClient(
        httpClient: MockClient((request) async {
          requests.add(request);
          return answer(request);
        }),
        userAgent: 'Test/1.0',
      ),
      files: Future.value(withFiles ? files : null),
      now: () => now,
    );

    final points = [_pointAt(10.5, 20.5), _pointAt(10.6, 20.4)];

    test('fetches the tile a line crosses, once, and names the app', () async {
      final terrain = heights();

      expect(await terrain.at(points), [2000, 2000]);
      expect(await terrain.at(points), [2000, 2000]);

      final request = requests.single;
      expect(
        request.url,
        Uri.parse('https://tiles.mapterhorn.com/12/10/20.webp'),
      );
      expect(request.headers['User-Agent'], 'Test/1.0');
    });

    test('a server behind a path keeps it', () {
      final client = TerrainTileClient(
        server: Uri.parse('https://example.org/terrain/'),
      );

      expect(
        client.urlOf((z: 12, x: 1, y: 2)),
        Uri.parse('https://example.org/terrain/12/1/2.webp'),
      );
    });

    test('a tile kept on disk is read again without asking', () async {
      await heights().at(points);
      expect(files.files.keys, ['12_10_20_20261122']);
      expect(base64Decode(files.files.values.single), tile);

      now = DateTime(2026, 12, 10);
      expect(await heights().at(points), [2000, 2000]);
      expect(requests, hasLength(1));
    });

    test('a tile older than a month is fetched again', () async {
      await heights().at(points);

      now = DateTime(2026, 12, 23);
      await heights().at(points);

      expect(requests, hasLength(2));
      expect(files.files.keys, ['12_10_20_20261223']);
    });

    test('a file that does not read is fetched again', () async {
      files.files['12_10_20_20261122'] = base64Encode([1, 2, 3]);

      expect(await heights().at(points), [2000, 2000]);
      expect(requests, hasLength(1));
    });

    test('without the tiles there are no heights, and no retry', () async {
      answer = (_) => http.Response('busy', 503);

      expect(await heights().at(points), isNull);
      expect(requests, hasLength(1));
    });

    test('no answer at all is no heights either', () async {
      final terrain = TerrainTileHeights(
        TerrainTileClient(
          httpClient: MockClient((_) async => throw http.ClientException('x')),
        ),
      );

      expect(await terrain.at(points), isNull);
    });
  });
}
