import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_location.dart';
import '../../../core/providers.dart';

final databaseControllerProvider = Provider<DatabaseController>(
  (ref) => DatabaseController(ref),
);

/// How long a close on the web is waited for before carrying on regardless.
///
/// Generous rather than tight: the close itself is a message to a worker and
/// takes no time at all, so this is not a budget but a ceiling on how long a
/// button may sit there saying nothing. See
/// [DatabaseController._closeLiveDatabase] for why it can be exceeded at all.
const Duration _webCloseTimeout = Duration(seconds: 5);

/// Coordinates switching the active database and moving data in/out of it.
class DatabaseController {
  DatabaseController(this._ref);

  final Ref _ref;

  /// Current active database path.
  String get currentPath => _ref.read(activeDbPathProvider);

  /// Closes the live connection — waiting for the acknowledgement on native,
  /// and only up to [_webCloseTimeout] for it on the web.
  ///
  /// On the web a close is a *request* to the worker holding the database, and
  /// drift answers it by shutting that worker down: `server_impl.dart` handles
  /// `terminateAll` by calling `shutdown()`, which closes the channels the
  /// reply would have travelled on, so the reply cannot arrive.
  /// `client_impl.dart` covers exactly that by catching the
  /// `ConnectionClosedException` the closing channel is expected to raise on
  /// the request still pending — but where no exception is raised either, the
  /// wait never ends. Measured in Firefox served without cross-origin
  /// isolation, where the missing `SharedArrayBuffer` puts the database in a
  /// *shared* worker: exporting stopped here and stayed there, with no file,
  /// no message and no error.
  ///
  /// Waiting forever is the one outcome worth ruling out. What the callers
  /// need is not the acknowledgement but that nothing holds the storage any
  /// more — and the step each of them takes next (probing it, or deleting it)
  /// establishes that for itself, saying so by working or by failing out loud.
  /// So the wait is bounded and the failure moves into the open.
  ///
  /// Native platforms keep waiting, deliberately: there a close is a local
  /// operation with nothing to answer it, and carrying on early would mean
  /// copying or deleting a file that is still open.
  Future<void> _closeLiveDatabase() {
    final closed = _ref.read(databaseProvider).close();
    return kIsWeb ? closed.timeout(_webCloseTimeout, onTimeout: () {}) : closed;
  }

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

  /// Empties the active database, leaving a fresh one in its place (mobile and
  /// web, where the storage location is fixed so "new database" can't mean a
  /// path). This is the import flow with nothing to copy in: close the live
  /// connection, discard the stored data, reopen onto an empty schema.
  Future<void> createEmpty() async {
    await _closeLiveDatabase();
    if (kIsWeb) {
      await webDeleteStorage();
      // Guard against a queued import left over from a failed attempt: the
      // fresh store must seed from nothing.
      webSetPendingImport(null);
    } else {
      final active = currentPath;
      deleteDatabaseFile(active);
      deleteSidecars(active);
    }
    _ref.invalidate(databaseProvider);
    // Force the new instance to open eagerly.
    _ref.read(databaseProvider);
  }

  /// Replaces the active database with the file at [sourcePath] (Android import).
  /// The active path is unchanged — only its contents are swapped.
  Future<void> importFrom(String sourcePath) async {
    final active = currentPath;
    // Close the live database before touching the file, then reopen after.
    await _closeLiveDatabase();
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
    await _closeLiveDatabase();
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
      await _closeLiveDatabase();
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
    final path = await defaultDatabaseFile(
      ciBuild: _ref.read(isCiBuildProvider),
    );
    await _ref
        .read(activeDbPathProvider.notifier)
        .setPath(path, persist: false);
  }
}
