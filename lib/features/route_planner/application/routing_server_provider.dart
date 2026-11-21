import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import '../data/brouter_client.dart';
import '../data/ski/overpass_client.dart';

/// The BRouter server the route planner asks, remembered across launches.
///
/// [kBrouterBaseUrl] unless the user set another in settings: their own
/// server, so that no request goes to brouter.de, or another public one when
/// that one is slow. A setting of the device like the map style, so it stays
/// out of the database and out of a `.tpt`.
final routingServerProvider = NotifierProvider<ServerSettingController, Uri>(
  () => ServerSettingController(
    key: 'route_planner_server',
    fallback: kBrouterBaseUrl,
    defaultPath: kBrouterPath,
  ),
);

/// The Overpass server the ski router loads pistes and lifts from,
/// remembered across launches: [kOverpassUrl] unless the user set another,
/// for the reasons [routingServerProvider] gives.
final overpassServerProvider = NotifierProvider<ServerSettingController, Uri>(
  () => ServerSettingController(
    key: 'ski_overpass_server',
    fallback: kOverpassUrl,
    defaultPath: kOverpassPath,
  ),
);

/// The path a bare BRouter server answers routing requests under.
const String kBrouterPath = '/brouter';

/// The path a bare Overpass server answers queries under.
const String kOverpassPath = '/api/interpreter';

/// The address of a server the planner asks, as set in settings.
class ServerSettingController extends Notifier<Uri> {
  ServerSettingController({
    required this.key,
    required this.fallback,
    required this.defaultPath,
  });

  /// Where the address is kept in the preferences.
  final String key;

  /// The server asked unless another was set.
  final Uri fallback;

  /// The path an address typed without one is given (see [parseServer]).
  final String defaultPath;

  @override
  Uri build() =>
      parseServer(
        ref.read(sharedPreferencesProvider).getString(key) ?? '',
        defaultPath: defaultPath,
      ) ??
      fallback;

  /// Whether the planner asks the server it ships with.
  bool get isDefault => state == fallback;

  /// Asks [server] from now on; null goes back to [fallback].
  Future<void> set(Uri? server) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (server == null || server == fallback) {
      state = fallback;
      await prefs.remove(key);
      return;
    }
    state = server;
    await prefs.setString(key, server.toString());
  }
}

/// Reads what the user typed as the address of a server, or null when it is
/// not one: an `http` or `https` address with a host, nothing after a `?` or
/// `#`. An address without a path is given [defaultPath], the one the bare
/// server answers under; any other path is kept, for a server behind a proxy.
Uri? parseServer(String text, {required String defaultPath}) {
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
  return uri.replace(path: path.isEmpty ? defaultPath : path);
}

/// [parseServer] for a BRouter server.
Uri? parseRoutingServer(String text) =>
    parseServer(text, defaultPath: kBrouterPath);
