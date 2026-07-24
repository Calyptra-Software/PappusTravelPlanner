import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:travelplanner/data/database/app_database.dart';

/// Verifies that a database file identifies itself: SQLite keeps a 32-bit
/// `application_id` in the file header, and the app stamps ours (`TRPL`) there
/// so the file can be told apart from any other `.sqlite` without opening a
/// table. The stamp happens on every open, not in a migration, because
/// databases already at the current schema version never reach `onUpgrade`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tp_application_id');
    path = p.join(tempDir.path, 'trip.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  int readApplicationId() {
    final raw = sqlite3.open(path);
    final id = raw.select('PRAGMA application_id').single.values.single as int;
    raw.close();
    return id;
  }

  void writeApplicationId(int id) {
    final raw = sqlite3.open(path);
    raw.execute('PRAGMA application_id = $id');
    raw.close();
  }

  /// Opens the database at [path] and runs one query, so drift resolves the
  /// connection and `beforeOpen` runs, then closes it again.
  Future<void> openAndClose() async {
    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    await db.tripDao.watchAllTrips().first;
    await db.close();
  }

  test('stamps a freshly created database', () async {
    await openAndClose();

    expect(readApplicationId(), kApplicationId);
    expect(kApplicationId, 0x5452504C, reason: 'ASCII TRPL — never change it');
  });

  test('stamps an existing database that predates the stamp', () async {
    await openAndClose();
    // An older build wrote no id, so the file carries the SQLite default.
    writeApplicationId(0);

    await openAndClose();

    expect(readApplicationId(), kApplicationId);
  });

  test('leaves another application\'s id alone', () async {
    await openAndClose();
    // 0x0F055112 is the id Fossil stamps on its repositories.
    const foreign = 0x0F055112;
    writeApplicationId(foreign);

    await openAndClose();

    expect(
      readApplicationId(),
      foreign,
      reason: 'the foreign id is the evidence the file is not ours',
    );
  });
}
