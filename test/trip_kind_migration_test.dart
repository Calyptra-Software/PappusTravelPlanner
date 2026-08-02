import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';

/// Verifies the v26 -> v27 migration that brought tags and routines. Real user
/// databases are migrated in place, so every trip written before must come
/// through as exactly what it was: an ordinary trip, filed under nothing,
/// pointing at no routine.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tp_trip_kind_migration');
    path = p.join(tempDir.path, 'v26.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// A v26 database — `trips` with no `kind`, `itinerary_items` with no place
  /// ids — holding one dated trip and one still being sketched out.
  void seedV26Database() {
    final raw = sqlite3.open(path);
    raw.execute('''
      CREATE TABLE trips (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        destination TEXT NOT NULL DEFAULT '',
        start_date INTEGER,
        end_date INTEGER,
        notes TEXT,
        color_value INTEGER NOT NULL DEFAULT 4278216540,
        created_at INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE itinerary_items (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER NOT NULL REFERENCES trips (id),
        group_id INTEGER,
        alternative_id INTEGER,
        date INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        kind INTEGER NOT NULL,
        title TEXT,
        start_minutes INTEGER,
        end_minutes INTEGER,
        actual_start_minutes INTEGER,
        actual_end_minutes INTEGER,
        spans_next_day INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        location TEXT,
        mode INTEGER,
        from_location TEXT,
        to_location TEXT,
        from_lat REAL,
        from_lon REAL,
        to_lat REAL,
        to_lon REAL,
        source_trip_id TEXT,
        stopovers TEXT
      );
      INSERT INTO trips (id, title, destination, start_date, end_date)
        VALUES (1, 'Rome', 'Italy', 1780000000, 1780400000),
               (2, 'Someday', '', NULL, NULL);
    ''');
    raw.execute('PRAGMA user_version = 26');
    raw.close();
  }

  test('v26 -> v27 reads every existing trip as an ordinary trip', () async {
    seedV26Database();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    final rome = await db.tripDao.findTrip(1);
    expect(rome!.title, 'Rome');
    expect(rome.destination, 'Italy');
    expect(rome.kind, TripKind.trip);
    expect(rome.fromRoutineId, isNull);
    // The dates it already had are untouched by the migration.
    expect(rome.startDate, isNotNull);
    expect(rome.endDate, isNotNull);

    // A trip with no dates yet is still a trip, not a routine: not knowing the
    // dates and having none by nature are different things.
    final someday = await db.tripDao.findTrip(2);
    expect(someday!.kind, TripKind.trip);

    // Tags start empty — only the user can say how their trips should be filed.
    expect(await db.tagDao.watchAllTags().first, isEmpty);

    // The legs gained the ids that let a journey be looked up again; existing
    // ones simply have none, and are copied as a plan rather than re-searched.
    final columns = await db
        .customSelect('PRAGMA table_info(itinerary_items)')
        .get();
    final names = columns.map((r) => r.read<String>('name')).toSet();
    expect(names, containsAll(['from_place_id', 'to_place_id']));
  });

  test('the migrated database can hold routines and tags', () async {
    seedV26Database();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    final routineId = await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'To work',
        kind: const Value(TripKind.routine),
      ),
    );
    expect((await db.tripDao.findTrip(routineId))!.kind, TripKind.routine);

    final commute = await db.tagDao.ensureTag('commute');
    await db.tagDao.setTagsForTrip(1, {commute});
    expect((await db.tagDao.watchTagsForTrip(1).first).map((t) => t.name), [
      'commute',
    ]);

    // And the trips already there are unaffected by any of it.
    expect((await db.tripDao.findTrip(1))!.kind, TripKind.trip);
  });
}
