/// Where something the app can always fetch again is kept between launches: a
/// directory of the app's cache, on a platform that has one.
///
/// Split by platform like `open_file.dart`: native keeps a file per key under
/// the app's own cache directory, the web keeps nothing beyond the session's
/// memory, which each cache holds on every platform itself.
library;

export 'cache_files_io.dart'
    if (dart.library.js_interop) 'cache_files_web.dart';

/// A flat store of text files, one per key. Every call is best effort: a cache
/// that cannot be read or written is a cache that is empty, never an error
/// the screen has to deal with.
abstract interface class CacheFiles {
  Future<String?> read(String key);
  Future<void> write(String key, String content);
  Future<List<String>> keys();
  Future<void> delete(String key);
}
