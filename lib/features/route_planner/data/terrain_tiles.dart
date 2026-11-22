import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../core/app_info.dart';
import '../../../core/cache_files.dart';
import '../application/terrain_heights.dart';
import '../domain/terrain.dart';

/// The terrain tiles ski runs take their heights from: Mapterhorn's, served
/// at `<server>/{z}/{x}/{y}.webp` in the Terrarium encoding.
final Uri kTerrainTilesUrl = Uri.parse('https://tiles.mapterhorn.com');

/// How long a terrain tile is used before it is fetched again: as long as a
/// ski area's map data is kept, so one rule covers both.
const Duration kTerrainTileMaxAge = Duration(days: 30);

/// How many decoded tiles are held in memory, a megabyte each at 512 px: more
/// than a ski day crosses.
const int kTerrainTilesInMemory = 24;

/// Fetches terrain tiles from a server laid out like [kTerrainTilesUrl].
class TerrainTileClient {
  TerrainTileClient({
    http.Client? httpClient,
    Uri? server,
    String? userAgent,
    this.sendUserAgent = true,
  }) : _http = httpClient ?? http.Client(),
       server = server ?? kTerrainTilesUrl,
       userAgent = userAgent ?? buildUserAgent('dev');

  final http.Client _http;
  final Uri server;
  final String userAgent;

  /// Whether [userAgent] goes out as a header: not from a browser, for the
  /// reason `BrouterRouteEngine.sendUserAgent` gives.
  final bool sendUserAgent;

  /// The address of [tile].
  Uri urlOf(TileKey tile) {
    final base = server.path.endsWith('/')
        ? server.path.substring(0, server.path.length - 1)
        : server.path;
    return server.replace(path: '$base/${tile.z}/${tile.x}/${tile.y}.webp');
  }

  /// The bytes of [tile]. Throws [TerrainTileException] when none came;
  /// nothing here asks again by itself.
  Future<Uint8List> fetch(TileKey tile) async {
    final http.Response response;
    try {
      response = await _http
          .get(
            urlOf(tile),
            headers: {if (sendUserAgent) 'User-Agent': userAgent},
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const TerrainTileException('Terrain tile timed out');
    } on http.ClientException catch (e) {
      throw TerrainTileException('Terrain tile failed: ${e.message}');
    }
    if (response.statusCode != 200) {
      throw TerrainTileException(
        'Terrain tile request failed (${response.statusCode})',
      );
    }
    return response.bodyBytes;
  }

  /// Releases the underlying HTTP client.
  void close() => _http.close();
}

/// A terrain tile that could not be had.
class TerrainTileException implements Exception {
  const TerrainTileException(this.message);

  final String message;

  @override
  String toString() => 'TerrainTileException: $message';
}

/// [TerrainHeights] read from terrain tiles.
///
/// A tile is fetched the first time a line crosses it, never before, and kept:
/// decoded in memory for the session ([kTerrainTilesInMemory] at most), and on
/// a platform with a cache directory ([CacheFiles]) as fetched for
/// [kTerrainTileMaxAge] on disk, so a ski day planned at home gets its heights
/// again on the mountain without a connection.
class TerrainTileHeights implements TerrainHeights {
  TerrainTileHeights(
    this._client, {
    Future<CacheFiles?>? files,
    DateTime Function()? now,
    Future<TerrainTile> Function(Uint8List bytes)? decode,
  }) : _files = files ?? Future.value(),
       _now = now ?? DateTime.now,
       _decode = decode ?? ((bytes) async => decodeTerrainTile(bytes));

  final TerrainTileClient _client;
  final Future<CacheFiles?> _files;
  final DateTime Function() _now;
  final Future<TerrainTile> Function(Uint8List bytes) _decode;

  // In the order they were last used, the least recent first.
  final _tiles = <TileKey, TerrainTile>{};
  final _loading = <TileKey, Future<TerrainTile>>{};
  Future<void>? _pruned;

  @override
  Future<List<double>?> at(List<LatLng> points) async {
    if (points.isEmpty) return const [];
    final keys = tilesFor(points);
    final Map<TileKey, TerrainTile> tiles;
    try {
      final loaded = await Future.wait([for (final key in keys) _tile(key)]);
      tiles = {for (final (i, key) in keys.indexed) key: loaded[i]};
    } on TerrainTileException {
      return null;
    } on FormatException {
      return null;
    }
    // Tiles of different sizes, from servers changed in between, do not
    // blend.
    if (tiles.values.map((tile) => tile.size).toSet().length != 1) return null;
    return heightsAt(points, tiles);
  }

  Future<TerrainTile> _tile(TileKey key) async {
    final held = _tiles.remove(key);
    if (held != null) return _tiles[key] = held;
    final loading = _loading[key];
    if (loading != null) return loading;
    final load = _load(key);
    _loading[key] = load;
    try {
      final tile = await load;
      _tiles[key] = tile;
      while (_tiles.length > kTerrainTilesInMemory) {
        _tiles.remove(_tiles.keys.first);
      }
      return tile;
    } finally {
      _loading.remove(key);
    }
  }

  Future<TerrainTile> _load(TileKey key) async {
    final files = await _files;
    if (files != null) {
      await (_pruned ??= _prune(files));
      final cached = await _cached(files, key);
      if (cached != null) {
        try {
          return await _decode(base64Decode(cached.content));
        } on FormatException {
          // A file that does not read is no cache; fetch the tile again.
          await files.delete(cached.name);
        }
      }
    }
    final bytes = await _client.fetch(key);
    final tile = await _decode(bytes);
    // Kept as fetched, a fifth of the decoded size; the cache holds text.
    await files?.write(
      '${_tileName(key)}_${_dayKey(_now())}',
      base64Encode(bytes),
    );
    return tile;
  }

  Future<({String name, String content})?> _cached(
    CacheFiles files,
    TileKey key,
  ) async {
    final prefix = '${_tileName(key)}_';
    String? newest;
    for (final name in await files.keys()) {
      if (!name.startsWith(prefix) || _parseDay(name) == null) continue;
      if (newest == null || name.compareTo(newest) > 0) newest = name;
    }
    if (newest == null) return null;
    final content = await files.read(newest);
    return content == null ? null : (name: newest, content: content);
  }

  /// Drops every tile older than [kTerrainTileMaxAge], and every file that is
  /// not one, once, the first time a tile is loaded.
  Future<void> _prune(CacheFiles files) async {
    final oldest = _now().subtract(kTerrainTileMaxAge);
    for (final name in await files.keys()) {
      final day = _parseDay(name);
      if (day == null || day.isBefore(oldest)) await files.delete(name);
    }
  }

  static String _tileName(TileKey key) => '${key.z}_${key.x}_${key.y}';

  static String _dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}'
      '${day.month.toString().padLeft(2, '0')}'
      '${day.day.toString().padLeft(2, '0')}';

  /// The day of a file named `z_x_y_yyyymmdd`; null for any other name.
  static DateTime? _parseDay(String name) {
    final parts = name.split('_');
    if (parts.length != 4) return null;
    if (parts.take(3).any((part) => int.tryParse(part) == null)) return null;
    final day = parts[3];
    if (day.length != 8) return null;
    final year = int.tryParse(day.substring(0, 4));
    final month = int.tryParse(day.substring(4, 6));
    final date = int.tryParse(day.substring(6));
    if (year == null || month == null || date == null) return null;
    return DateTime(year, month, date);
  }
}
