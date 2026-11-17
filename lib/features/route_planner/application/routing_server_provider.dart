import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import '../data/brouter_client.dart';

/// The BRouter server the route planner asks, remembered across launches.
///
/// [kBrouterBaseUrl] unless the user set another in settings: their own
/// server, so that no request goes to brouter.de, or another public one when
/// that one is slow. A setting of the device like the map style, so it stays
/// out of the database and out of a `.tpt`.
final routingServerProvider = NotifierProvider<RoutingServerController, Uri>(
  RoutingServerController.new,
);

class RoutingServerController extends Notifier<Uri> {
  static const _key = 'route_planner_server';

  @override
  Uri build() =>
      parseRoutingServer(
        ref.read(sharedPreferencesProvider).getString(_key) ?? '',
      ) ??
      kBrouterBaseUrl;

  /// Whether the planner asks the server it ships with.
  bool get isDefault => state == kBrouterBaseUrl;

  /// Asks [server] from now on; null goes back to [kBrouterBaseUrl].
  Future<void> set(Uri? server) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (server == null || server == kBrouterBaseUrl) {
      state = kBrouterBaseUrl;
      await prefs.remove(_key);
      return;
    }
    state = server;
    await prefs.setString(_key, server.toString());
  }
}

/// Reads what the user typed as the address of a BRouter server, or null when
/// it is not one: an `http` or `https` address with a host, nothing after a
/// `?` or `#`. The bare server answers routing requests under `/brouter`, so an
/// address without a path is given that one; any other path is kept, for a
/// server behind a proxy.
Uri? parseRoutingServer(String text) {
  final uri = Uri.tryParse(text.trim());
  if (uri == null ||
      !(uri.scheme == 'https' || uri.scheme == 'http') ||
      uri.host.isEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    return null;
  }
  final path = uri.path.endsWith('/')
      ? uri.path.substring(0, uri.path.length - 1)
      : uri.path;
  return uri.replace(path: path.isEmpty ? '/brouter' : path);
}
