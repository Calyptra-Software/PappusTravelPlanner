/// Platform-neutral entry point for opening and managing the database file.
///
/// The real implementation is selected at compile time: native platforms use a
/// file on disk (`database_location_io.dart`), while the web uses a browser
/// storage-backed WebAssembly database (`database_location_web.dart`). Both
/// implementations expose the same API:
///
/// - `kDatabaseFileName`, `defaultDatabaseFile()`, `openExecutor(path)`
/// - file-portability helpers used by `DatabaseController`:
///   `deleteSidecars`, `deleteDatabaseFile`, `copyDatabaseFile`,
///   `readDatabaseBytes` (the latter three are unsupported on the web, whose UI
///   never calls them).
library;

export 'database_location_io.dart'
    if (dart.library.js_interop) 'database_location_web.dart';
