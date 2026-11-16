import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:travelplanner/data/database/app_database.dart';

/// Verifies the v43 -> v44 migration that added `recording_fixes.altitude`.
/// A fix recorded before it reported no height anybody kept, so every one
/// must come through with none, its position and time untouched.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tp_fix_altitude');
    path = p.join(tempDir.path, 'v43.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Builds a v43 database at [path] holding one recording of two fixes: the
  /// current schema less the column, written through the app, for the reason
  /// `reimbursement_migration_test.dart` gives.
  Future<int> seedV43Database() async {
    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    final at = DateTime.utc(2026, 5, 1, 12);
    final id = await db.recordingDao.startRecording(
      startedAt: at,
      utcOffset: const Duration(hours: 2),
    );
    await db.recordingDao.addFixes(id, 0, [
      (position: const LatLng(53.5, 9.9), at: at, altitude: null),
      (
        position: const LatLng(53.51, 9.9),
        at: at.add(const Duration(minutes: 1)),
        altitude: null,
      ),
    ]);
    await db.close();

    final raw = sqlite3.open(path);
    raw.execute('ALTER TABLE recording_fixes DROP COLUMN altitude');
    raw.execute('PRAGMA user_version = 43');
    raw.close();
    return id;
  }

  test('v43 -> v44 leaves every recorded fix without a height', () async {
    final id = await seedV43Database();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    final fixes = await db.select(db.recordingFixes).get();
    expect(fixes.map((f) => (f.lat, f.altitude)), [
      (53.5, null),
      (53.51, null),
    ]);

    // And the migrated schema really takes one.
    await db.recordingDao.addFixes(id, 0, [
      (
        position: const LatLng(53.52, 9.9),
        at: DateTime.utc(2026, 5, 1, 12, 2),
        altitude: 512.5,
      ),
    ]);
    expect((await db.select(db.recordingFixes).get()).last.altitude, 512.5);
  });
}
