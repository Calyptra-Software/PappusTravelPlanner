import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_info.dart';
import '../../../core/cache_files.dart';
import '../../../core/providers.dart';
import '../data/brouter_client.dart';
import '../data/ski/overpass_client.dart';
import '../data/ski/overpass_ski_router.dart';
import '../data/terrain_tiles.dart';
import '../domain/terrain.dart';
import 'route_engine.dart';
import 'routing_server_provider.dart';
import 'ski_router.dart';
import 'terrain_heights.dart';

/// The router the tour planner asks: the BRouter server set in settings
/// ([routingServerProvider]), brouter.de unless another was. It holds an HTTP
/// client, so it lives for the app session and is closed on dispose.
///
/// Like the connection search it talks to a server somebody else runs: a
/// provider that calls it carries `retry: noAutomaticRetry`, and a request is
/// made for a waypoint that was set, never while one is being moved.
final routeEngineProvider = Provider<RouteEngine>((ref) {
  final engine = BrouterRouteEngine(
    baseUrl: ref.watch(routingServerProvider),
    userAgent: buildUserAgent(ref.watch(appVersionProvider)),
    // Not from the web build: see [BrouterRouteEngine.sendUserAgent].
    sendUserAgent: !kIsWeb,
  );
  ref.onDispose(engine.close);
  return engine;
});

/// Where lines without heights of their own get them: the terrain tiles of
/// the server set in settings ([terrainServerProvider]). A ski run's map data
/// has none, nor does a line drawn by hand. Lives for the app session, so a
/// tile fetched once is not fetched again while the app runs; decoding one
/// runs off the main isolate.
final terrainHeightsProvider = Provider<TerrainHeights>((ref) {
  final tiles = TerrainTileClient(
    server: ref.watch(terrainServerProvider),
    userAgent: buildUserAgent(ref.watch(appVersionProvider)),
    sendUserAgent: !kIsWeb,
  );
  ref.onDispose(tiles.close);
  return TerrainTileHeights(
    tiles,
    files: openCacheFiles('terrain_tiles'),
    decode: (bytes) => compute(decodeTerrainTile, bytes),
  );
});

/// The router for ski runs: map data from the Overpass server set in settings
/// ([overpassServerProvider]), routed on the device ([OverpassSkiRouter]),
/// with heights from [terrainHeightsProvider]. Lives for the app session, so
/// an area loaded once is not loaded again while the app runs.
///
/// Reading an area's answer (a few megabytes of JSON for a large one) and
/// building its graph runs off the main isolate, where there is another one.
final skiRouterProvider = Provider<SkiRouter>((ref) {
  final client = OverpassClient(
    url: ref.watch(overpassServerProvider),
    userAgent: buildUserAgent(ref.watch(appVersionProvider)),
    sendUserAgent: !kIsWeb,
  );
  ref.onDispose(client.close);
  return OverpassSkiRouter(
    client,
    heights: ref.watch(terrainHeightsProvider),
    files: openCacheFiles('ski_areas'),
    build: (answer) => compute(buildSkiGraph, answer),
  );
});
