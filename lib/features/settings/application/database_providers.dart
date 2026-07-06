import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_location.dart';
import '../../../core/providers.dart';

final databaseControllerProvider =
    Provider<DatabaseController>((ref) => DatabaseController(ref));

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
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
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
    File(sourcePath).copySync(active);
    deleteSidecars(active);
    _ref.invalidate(databaseProvider);
    // Force the new instance to open eagerly.
    _ref.read(databaseProvider);
  }

  /// Checkpoints the WAL so the file is complete, then returns it for export.
  Future<File> exportFile() async {
    await _ref.read(databaseProvider).checkpoint();
    return File(currentPath);
  }

  /// Reverts to the default app-managed database location.
  Future<void> resetToDefault() async {
    final path = await defaultDatabaseFile();
    await _ref.read(activeDbPathProvider.notifier).setPath(path, persist: false);
  }
}
