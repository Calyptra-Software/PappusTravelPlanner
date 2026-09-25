import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';

/// Verifies the v39 -> v40 migration that turned `spans_next_day` (a boolean)
/// into `end_day_offset` (a count of days): a flagged leg ends one day later, a
/// hand-entered night train the flag could never be set on is dated the same
/// way, an ordinary entry stays on its own day, and the old column is gone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tp_end_day_offset');
    path = p.join(tempDir.path, 'v39.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Builds a v39 database at [path]: the current schema with the count swapped
  /// back for the flag, declared the way drift declared it (a CHECK on the
  /// column itself, which is what `DROP COLUMN` has to get past), and the
  /// version stamped back. Returns the ids of the entries it seeds, by name.
  Future<Map<String, int>> seedV39Database() async {
    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    final tripId = await db
        .into(db.trips)
        .insert(TripsCompanion.insert(title: 'Vienna'));
    Future<int> entry({
      int? start,
      int? end,
      int? actualStart,
      int? actualEnd,
    }) => db
        .into(db.itineraryItems)
        .insert(
          ItineraryItemsCompanion.insert(
            tripId: tripId,
            date: DateTime(2026, 5, 1),
            kind: ItemKind.transport,
            startMinutes: Value(start),
            endMinutes: Value(end),
            actualStartMinutes: Value(actualStart),
            actualEndMinutes: Value(actualEnd),
          ),
        );
    final ids = {
      'imported': await entry(start: 1334, end: 432),
      'handEntered': await entry(start: 1320, end: 420),
      'ordinary': await entry(start: 540, end: 600),
      'actualOnly': await entry(actualStart: 1320, actualEnd: 420),
      'lateOrdinary': await entry(start: 540, end: 600, actualEnd: 590),
      'untimed': await entry(),
    };
    await db.close();

    final raw = sqlite3.open(path);
    raw.execute(
      'ALTER TABLE itinerary_items ADD COLUMN spans_next_day INTEGER NOT NULL '
      'DEFAULT 0 CHECK ("spans_next_day" IN (0, 1))',
    );
    raw.execute(
      'UPDATE itinerary_items SET spans_next_day = 1 '
      'WHERE id = ${ids['imported']}',
    );
    raw.execute('ALTER TABLE itinerary_items DROP COLUMN end_day_offset');
    raw.execute('PRAGMA user_version = 39');
    raw.close();
    return ids;
  }

  test('v39 -> v40 carries the flag over as a count of days', () async {
    final ids = await seedV39Database();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    Future<int> offsetOf(String name) async => (await (db.select(
      db.itineraryItems,
    )..where((i) => i.id.equals(ids[name]!))).getSingle()).endDayOffset;

    expect(await offsetOf('imported'), 1);
    // The form never offered the flag, so a night train typed in by hand read
    // as ending before it began; the only reading that is not an error is the
    // next morning.
    expect(await offsetOf('handEntered'), 1);
    expect(await offsetOf('actualOnly'), 1);
    expect(await offsetOf('ordinary'), 0);
    // An actual end a little before its planned one is early, not overnight.
    expect(await offsetOf('lateOrdinary'), 0);
    expect(await offsetOf('untimed'), 0);

    final columns =
        (await db.customSelect('PRAGMA table_info(itinerary_items)').get()).map(
          (r) => r.read<String>('name'),
        );
    expect(columns, isNot(contains('spans_next_day')));
    expect(columns, contains('end_day_offset'));
  });
}
