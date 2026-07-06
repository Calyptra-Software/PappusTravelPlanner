import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/repositories/trip_repository.dart';
import 'settings/locale_provider.dart';

/// The database path resolved at startup (stored preference, or the default
/// location). Overridden in `main` so it can be read synchronously.
final bootstrapDbPathProvider = Provider<String>((ref) {
  throw UnimplementedError('bootstrapDbPathProvider must be overridden');
});

/// SharedPreferences key holding the user-chosen database path (desktop).
const String kDbPathPrefKey = 'db_path';

/// The path of the database the app is currently using. Changing it rebuilds
/// [databaseProvider] (and everything downstream) against the new file.
final activeDbPathProvider =
    NotifierProvider<ActiveDbPath, String>(ActiveDbPath.new);

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
