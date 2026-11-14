import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'run_shape_files.dart';

/// The run routes' directory, `<cache>/run_shapes/`: the app's own cache, per
/// application id, which the system may empty whenever it needs the space. That
/// is the right home for something the app can always ask for again, and the
/// wrong one for anything else.
Future<RunShapeFiles?> openRunShapeFiles() async {
  try {
    final base = await getApplicationCacheDirectory();
    final dir = Directory(p.join(base.path, 'run_shapes'));
    await dir.create(recursive: true);
    return DirectoryRunShapeFiles(dir);
  } on Object {
    // No cache directory on this platform, or none we may write to.
    return null;
  }
}

/// [RunShapeFiles] as one file per key in [dir]. Public so a test can point it
/// at a temporary directory.
class DirectoryRunShapeFiles implements RunShapeFiles {
  DirectoryRunShapeFiles(this.dir);

  final Directory dir;

  File _file(String key) => File(p.join(dir.path, '$key.json'));

  @override
  Future<String?> read(String key) async {
    try {
      return await _file(key).readAsString();
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> write(String key, String content) async {
    try {
      await _file(key).writeAsString(content, flush: true);
    } on FileSystemException {
      // A full disk or a vanished directory costs the cache, nothing else.
    }
  }

  @override
  Future<List<String>> keys() async {
    try {
      return [
        await for (final entry in dir.list())
          if (entry is File && entry.path.endsWith('.json'))
            p.basenameWithoutExtension(entry.path),
      ];
    } on FileSystemException {
      return const [];
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _file(key).delete();
    } on FileSystemException {
      // Already gone.
    }
  }
}
