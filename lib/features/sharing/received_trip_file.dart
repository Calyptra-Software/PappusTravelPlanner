/// Taking over a `.tpt` file the Android side copied into the app's cache
/// after the app was opened with it (see `MainActivity.kt`).
///
/// Split by platform like `open_file.dart`: only native platforms have a file
/// to read, and only Android ever hands one over.
library;

export 'received_trip_file_io.dart'
    if (dart.library.js_interop) 'received_trip_file_web.dart';
