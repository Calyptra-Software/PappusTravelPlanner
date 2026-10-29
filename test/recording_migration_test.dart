import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:travelplanner/data/database/app_database.dart';

/// Verifies the v40 -> v41 migration that added the tables a recording is kept
/// in while it is made. Nothing existing changes, and the new tables take a
/// recording — with the foreign keys a fresh database has, since the trip a
/// recording was started from is only a hint.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tp_recordings');
    path = p.join(tempDir.path, 'v40.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Builds a v40 database at [path]: the current schema less the two tables,
  /// with the version stamped back — written through the app, for the reason
  /// `reimbursement_migration_test.dart` gives.
  Future<int> seedV40Database() async {
    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    final tripId = await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(title: 'Hamburg', destination: const Value('')),
        );
    await db.close();

    final raw = sqlite3.open(path);
    raw.execute('DROP TABLE recording_fixes');
    raw.execute('DROP TABLE recordings');
    raw.execute('PRAGMA user_version = 40');
    raw.close();
    return tripId;
  }

  test('v40 -> v41 keeps the trips and takes a recording', () async {
    final tripId = await seedV40Database();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    expect((await db.select(db.trips).getSingle()).title, 'Hamburg');

    final id = await db.recordingDao.startRecording(
      tripId: tripId,
      startedAt: DateTime.utc(2026, 5, 1, 12),
      utcOffset: const Duration(hours: 2),
    );
    await db.recordingDao.addFixes(id, 0, [
      (position: const LatLng(53.5, 9.9), at: DateTime.utc(2026, 5, 1, 12)),
    ]);
    expect(await db.recordingDao.fixesOf(id), hasLength(1));

    // The references came through: the trip going nulls the hint, and the
    // recording going takes its fixes.
    await (db.delete(db.trips)..where((t) => t.id.equals(tripId))).go();
    expect(
      (await db.recordingDao.watchRecordings().first).single.tripId,
      isNull,
    );
    await db.recordingDao.deleteRecording(id);
    expect(await db.select(db.recordingFixes).get(), isEmpty);
  });
}
