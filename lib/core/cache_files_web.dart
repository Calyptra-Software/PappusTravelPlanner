import 'cache_files.dart';

/// The web has no cache directory to keep files in; what is cached lives in
/// the session's memory only.
Future<CacheFiles?> openCacheFiles(String folder) async => null;
