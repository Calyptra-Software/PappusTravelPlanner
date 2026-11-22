import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'locale_provider.dart' show sharedPreferencesProvider;

/// The address of a server the app asks, as set in settings: the route
/// planner's, the connection search's.
class ServerSettingController extends Notifier<Uri> {
  ServerSettingController({
    required this.key,
    required this.fallback,
    required this.defaultPath,
    this.refused,
  });

  /// Where the address is kept in the preferences.
  final String key;

  /// The server asked unless another was set.
  final Uri fallback;

  /// The path an address typed without one is given (see [parseServer]).
  final String defaultPath;

  /// Whether an address must not be asked even when set: a host the server's
  /// operator has put off limits. A stored one falls back to [fallback].
  final bool Function(Uri server)? refused;

  /// Reads what the user typed as an address for this setting, or null when
  /// it is not one or is [refused].
  Uri? parse(String text) {
    final server = parseServer(text, defaultPath: defaultPath);
    return server == null || (refused?.call(server) ?? false) ? null : server;
  }

  @override
  Uri build() =>
      parse(ref.read(sharedPreferencesProvider).getString(key) ?? '') ??
      fallback;

  /// Whether the app asks the server it ships with.
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
