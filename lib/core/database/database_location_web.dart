import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Storage key for the browser-backed database. The web has no filesystem, so
/// this doubles as the "path" shown in settings. It maps to an OPFS/IndexedDB
/// store managed by drift's WebAssembly backend.
const String kDatabaseFileName = 'travelplanner';

final Uri _sqlite3Wasm = Uri.parse('sqlite3.wasm');
final Uri _driftWorker = Uri.parse('drift_worker.js');

/// Bytes to seed the database with on the next fresh open (an import). Consumed
/// exactly once by [openExecutor]'s `initializeDatabase` callback, which drift
/// only invokes when no database exists yet — hence [webDeleteStorage] runs
/// first during an import.
Uint8List? _pendingImport;

/// The web has no concept of a file path; the default "path" is just the fixed
/// storage name.
Future<String> defaultDatabaseFile() async => kDatabaseFileName;

/// Opens a Drift executor backed by sqlite3 compiled to WebAssembly, persisting
/// to the best storage the browser offers (OPFS, falling back to IndexedDB).
///
/// [path] is ignored on the web — storage is keyed by [kDatabaseFileName]. The
/// `sqlite3.wasm` and `drift_worker.js` assets are served from the `web/`
/// directory (see the project's web setup).
QueryExecutor openExecutor(String path) {
  return driftDatabase(
    name: kDatabaseFileName,
    web: DriftWebOptions(
      sqlite3Wasm: _sqlite3Wasm,
      driftWorker: _driftWorker,
      initializeDatabase: () {
        final bytes = _pendingImport;
        _pendingImport = null;
        return bytes;
      },
    ),
  );
}

Future<WasmProbeResult> _probe() => WasmDatabase.probe(
  sqlite3Uri: _sqlite3Wasm,
  driftWorkerUri: _driftWorker,
  databaseName: kDatabaseFileName,
);

ExistingDatabase? _existing(WasmProbeResult probe) {
  for (final db in probe.existingDatabases) {
    if (db.$2 == kDatabaseFileName) return db;
  }
  return null;
}

/// Reads the current database out of browser storage as raw sqlite bytes, or
/// `null` if nothing has been stored yet. The live connection must be closed
/// first (OPFS grants exclusive access to a single handle).
Future<Uint8List?> webExportBytes() async {
  final probe = await _probe();
  final existing = _existing(probe);
  if (existing == null) return null;
  return probe.exportDatabase(existing);
}

/// Deletes the current database from browser storage. The live connection must
/// be closed first; the next open then seeds from [webSetPendingImport].
Future<void> webDeleteStorage() async {
  final probe = await _probe();
  final existing = _existing(probe);
  if (existing != null) {
    await probe.deleteDatabase(existing);
  }
}

/// Queues [bytes] to seed the database on the next open (see [_pendingImport]).
void webSetPendingImport(Uint8List? bytes) => _pendingImport = bytes;

/// No WAL sidecars exist in the browser backend.
void deleteSidecars(String path) {}

Never _unsupported() => throw UnsupportedError(
  'File-path database operations are not available on the web.',
);

/// File-path operations are native-only; the web uses the `web*` helpers above.
void deleteDatabaseFile(String path) => _unsupported();
void copyDatabaseFile(String from, String to) => _unsupported();
Future<Uint8List> readDatabaseBytes(String path) => _unsupported();
