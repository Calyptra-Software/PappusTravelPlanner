import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The file name used for the default (app-managed) database.
///
/// Renamed with the app. A database written under the old name is not migrated
/// and not looked for: on a desktop it is still openable through the settings
/// screen's *open database*, and everywhere else the way across is the export
/// the app already has. Guessing at a predecessor's file name is how an app
/// silently adopts a file that is not its own.
const String kDatabaseFileName = 'pappus.sqlite';

/// Resolves the default database path in the app's documents directory.
Future<String> defaultDatabaseFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, kDatabaseFileName);
}

/// Opens a Drift executor over the file at [path], creating it if needed.
QueryExecutor openExecutor(String path) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  return NativeDatabase.createInBackground(file);
}

/// SQLite writes a `-wal` and `-shm` sidecar alongside the main file in WAL
/// mode. After the database is closed and checkpointed the main file is
/// complete on its own; these helpers keep copies/imports to a single file.
List<File> sidecarFiles(String path) => [File('$path-wal'), File('$path-shm')];

/// Deletes any stale `-wal`/`-shm` sidecars for [path] (used before importing
/// a replacement database so leftover journal data can't shadow it).
void deleteSidecars(String path) {
  for (final file in sidecarFiles(path)) {
    if (file.existsSync()) file.deleteSync();
  }
}

/// Deletes the database file at [path] if it exists (used before creating a
/// fresh database in its place).
void deleteDatabaseFile(String path) {
  final file = File(path);
  if (file.existsSync()) file.deleteSync();
}

/// Copies the database file from [from] onto [to] (used when importing).
void copyDatabaseFile(String from, String to) {
  File(from).copySync(to);
}

/// Reads the raw bytes of the database file at [path] (used when exporting).
Future<Uint8List> readDatabaseBytes(String path) => File(path).readAsBytes();

Never _webOnly() => throw UnsupportedError(
  'Browser-storage database operations are only available on the web.',
);

/// Web-only storage helpers; native platforms use the file-path operations
/// above. These exist so the platform-neutral facade presents one API.
Future<Uint8List?> webExportBytes() => _webOnly();
Future<void> webDeleteStorage() => _webOnly();
void webSetPendingImport(Uint8List? bytes) => _webOnly();
