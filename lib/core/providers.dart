import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/repositories/trip_repository.dart';
import 'settings/locale_provider.dart';

/// The database path resolved at startup (stored preference, or the default
/// location). Overridden in `main` so it can be read synchronously.
final bootstrapDbPathProvider = Provider<String>((ref) {
  throw UnimplementedError('bootstrapDbPathProvider must be overridden');
});

/// The running app's version (`1.0.0+1`), read from the platform's own package
/// metadata at startup and overridden in `main` beside the database path, so
/// that — like it — it can be read synchronously.
///
/// It exists for the two things that talk to someone else's server: the
/// connection search and the map's tile requests both send it in their
/// `User-Agent` (see `core/app_info.dart`), which the donated Transitous
/// instance and the OpenStreetMap tile policy each ask for by name.
/// Deliberately unimplemented rather than defaulted to a literal, which would
/// go stale at the first release and misname the build making the requests.
final appVersionProvider = Provider<String>((ref) {
  throw UnimplementedError('appVersionProvider must be overridden');
});

/// Whether this is the side-by-side CI build (see [isCiBuild]).
///
/// Resolved once at startup from `PackageInfo` and overridden into the scope
/// beside [appVersionProvider], so a widget can read it synchronously.
final isCiBuildProvider = Provider<bool>((ref) {
  throw UnimplementedError('isCiBuildProvider must be overridden');
});

/// SharedPreferences key holding the user-chosen database path (desktop).
const String kDbPathPrefKey = 'db_path';

/// The path of the database the app is currently using. Changing it rebuilds
/// [databaseProvider] (and everything downstream) against the new file.
final activeDbPathProvider = NotifierProvider<ActiveDbPath, String>(
  ActiveDbPath.new,
);

class ActiveDbPath extends Notifier<String> {
  @override
  String build() => ref.read(bootstrapDbPathProvider);

  /// Switches to [path]. When [persist] is true the choice is remembered across
  /// launches; pass false (e.g. resetting to default) to clear the preference.
  Future<void> setPath(String path, {bool persist = true}) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (persist) {
      await prefs.setString(kDbPathPrefKey, path);
    } else {
      await prefs.remove(kDbPathPrefKey);
    }
    state = path;
  }
}

/// The active database, opened at [activeDbPathProvider]'s path. Closed on
/// dispose so a path change (or invalidation) cleanly releases the file.
final databaseProvider = Provider<AppDatabase>((ref) {
  final path = ref.watch(activeDbPathProvider);
  final db = AppDatabase.atPath(path);
  // Guarded: import closes the instance manually before replacing the file, so
  // the dispose-time close may find it already closed.
  ref.onDispose(() async {
    try {
      await db.close();
    } catch (_) {
      // Already closed — nothing to do.
    }
  });
  return db;
});

/// Repository built over the database; the entry point for all data access.
final repositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(ref.watch(databaseProvider));
});
