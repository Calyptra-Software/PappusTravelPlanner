import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:travelplanner/features/transport_search/data/run_shape_cache.dart';
import 'package:travelplanner/features/transport_search/data/run_shape_files_io.dart';

/// The routes of whole runs, kept outside the database: in memory for the
/// session, and in a cache directory between launches, until a few days after
/// the run.
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tp_run_shapes');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  RunShapeCache cacheOn(Directory dir, {DateTime? today}) => RunShapeCache(
    Future.value(DirectoryRunShapeFiles(dir)),
    today: () => today ?? DateTime(2026, 11, 15),
  );

  // A trip id as the router writes them: colons and all.
  const ice = '20261115_07:04_de-DELFI_3478804983';

  test('a route kept is read back, also after a restart', () async {
    await cacheOn(dir).write(ice, 'route', lastDay: DateTime(2026, 11, 15));

    // A new cache over the same directory: the app launched again.
    expect(await cacheOn(dir).read(ice), 'route');
    expect(await cacheOn(dir).read('another'), isNull);
    // One file, named so that any file system takes it.
    final names = dir.listSync().map((e) => p.basename(e.path)).toList();
    expect(names.single, isNot(contains(':')));
  });

  test('without a directory, the session remembers all the same', () async {
    final cache = RunShapeCache(Future.value());

    await cache.write(ice, 'route', lastDay: DateTime(2026, 11, 15));

    expect(await cache.read(ice), 'route');
  });

  test('a run some days past is dropped, a recent one kept', () async {
    final earlier = cacheOn(dir, today: DateTime(2026, 11, 1));
    await earlier.write('old', 'a', lastDay: DateTime(2026, 11, 1));
    await earlier.write('recent', 'b', lastDay: DateTime(2026, 11, 13));
    File(p.join(dir.path, 'garbage.json')).writeAsStringSync('{not json');

    // Four days after the first run's day, two after the second's.
    final later = cacheOn(dir, today: DateTime(2026, 11, 15));

    expect(await later.read('old'), isNull);
    expect(await later.read('recent'), 'b');
    expect(dir.listSync(), hasLength(1));
  });
}
