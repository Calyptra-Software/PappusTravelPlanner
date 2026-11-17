import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_info.dart';
import '../../../core/providers.dart';
import '../data/brouter_client.dart';
import 'route_engine.dart';
import 'routing_server_provider.dart';

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
