import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_location.dart';
import '../../../core/providers.dart';

final databaseControllerProvider = Provider<DatabaseController>(
  (ref) => DatabaseController(ref),
);

/// Coordinates switching the active database and moving data in/out of it.
class DatabaseController {
  DatabaseController(this._ref);

  final Ref _ref;

  /// Current active database path.
  String get currentPath => _ref.read(activeDbPathProvider);

  /// Opens an existing database file at [path] in place (desktop). The choice
  /// is remembered across launches.
  Future<void> openExisting(String path) {
    return _ref.read(activeDbPathProvider.notifier).setPath(path);
  }

  /// Creates a fresh, empty database at [path] and switches to it (desktop).
  /// Any existing file at [path] is replaced.
  Future<void> createNew(String path) async {
    if (path != currentPath) {
      deleteDatabaseFile(path);
      deleteSidecars(path);
    }
    await _ref.read(activeDbPathProvider.notifier).setPath(path);
  }

  /// Replaces the active database with the file at [sourcePath] (Android import).
  /// The active path is unchanged — only its contents are swapped.
  Future<void> importFrom(String sourcePath) async {
    final active = currentPath;
    // Close the live database before touching the file, then reopen after.
    await _ref.read(databaseProvider).close();
    copyDatabaseFile(sourcePath, active);
    deleteSidecars(active);
    _ref.invalidate(databaseProvider);
    // Force the new instance to open eagerly.
    _ref.read(databaseProvider);
  }

  /// Replaces the active database with a `.sqlite` file's [bytes] (web import).
  ///
  /// The browser has no filesystem, so the imported bytes seed browser storage:
  /// close the live connection, clear the current store, then reopen — drift's
  /// `initializeDatabase` hook picks up the queued bytes for the fresh store.
  Future<void> importFromBytes(Uint8List bytes) async {
    await _ref.read(databaseProvider).close();
    // Clear storage while no connection holds it, then queue the seed bytes
    // before anything reopens the database.
    await webDeleteStorage();
    webSetPendingImport(bytes);
    _ref.invalidate(databaseProvider);
    _ref.read(databaseProvider);
  }

  /// Returns the current database as raw `.sqlite` bytes for export (e.g. saving
  /// via a file picker).
  Future<Uint8List> exportBytes() async {
    if (kIsWeb) {
      // OPFS grants exclusive access, so read from storage with no live
      // connection open, then reopen for continued use.
      await _ref.read(databaseProvider).close();
      try {
        final bytes = await webExportBytes();
        if (bytes == null) {
          throw StateError('No database has been created yet.');
        }
        return bytes;
      } finally {
        _ref.invalidate(databaseProvider);
        _ref.read(databaseProvider);
      }
    }
    await _ref.read(databaseProvider).checkpoint();
    return readDatabaseBytes(currentPath);
  }

  /// Reverts to the default app-managed database location.
  Future<void> resetToDefault() async {
    final path = await defaultDatabaseFile();
    await _ref
        .read(activeDbPathProvider.notifier)
        .setPath(path, persist: false);
  }
}
