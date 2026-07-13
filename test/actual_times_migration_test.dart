import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:travelplanner/data/database/app_database.dart';

/// Verifies the v18 -> v19 migration that added an itinerary entry's *actual*
/// start/end times beside its planned ones. Real user databases are migrated in
/// place: an existing plan must come through unchanged, simply carrying no
/// record yet of how it really went.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tp_actual_times_migration');
    path = p.join(tempDir.path, 'v18.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Builds a database file at [path] with the v18 schema — itinerary entries
  /// with planned times only — holding a trip whose day has a timed museum visit
  /// and an untimed dinner.
  void seedV18Database() {
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
      CREATE TABLE item_groups (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER NOT NULL REFERENCES trips (id),
        label TEXT,
        collapsed INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE alternative_sets (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER NOT NULL REFERENCES trips (id),
        date INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        label TEXT
      );
      CREATE TABLE alternatives (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        set_id INTEGER NOT NULL REFERENCES alternative_sets (id),
        label TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        chosen INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE itinerary_items (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER NOT NULL REFERENCES trips (id),
        group_id INTEGER REFERENCES item_groups (id),
        alternative_id INTEGER REFERENCES alternatives (id),
        date INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        kind INTEGER NOT NULL,
        title TEXT,
        start_minutes INTEGER,
        end_minutes INTEGER,
        notes TEXT,
        location TEXT,
        mode INTEGER,
        from_location TEXT,
        to_location TEXT
      );
      CREATE TABLE costs (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER REFERENCES itinerary_items (id),
        group_id INTEGER REFERENCES item_groups (id),
        trip_id INTEGER REFERENCES trips (id),
        amount_minor INTEGER NOT NULL,
        currency INTEGER NOT NULL,
        reason TEXT NOT NULL,
        paid_by TEXT,
        paid INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT 0
      );
      INSERT INTO trips (id, title) VALUES (1, 'Paris');
      INSERT INTO itinerary_items
        (id, trip_id, date, sort_order, kind, title, start_minutes, end_minutes)
        VALUES (1, 1, 0, 0, 0, 'Louvre', 540, 660),
               (2, 1, 0, 1, 0, 'Dinner', NULL, NULL);
    ''');
    raw.execute('PRAGMA user_version = 18');
    raw.close();
  }

  test('v18 -> v19 adds the actual times, leaving the plan as it was', () async {
    seedV18Database();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    final items = await db.itineraryDao.watchItemsForTrip(1).first;
    expect(items.map((i) => i.title), ['Louvre', 'Dinner']);

    // The planned times survive; nothing claims to know how the day really went.
    final louvre = items.first;
    expect(louvre.startMinutes, 540);
    expect(louvre.endMinutes, 660);
    expect(items.every((i) => i.actualStartMinutes == null), isTrue);
    expect(items.every((i) => i.actualEndMinutes == null), isTrue);

    // And the migrated schema really does take a record of what happened.
    await db.itineraryDao.updateItem(
      louvre.copyWith(
        actualStartMinutes: const Value(555),
        actualEndMinutes: const Value(650),
      ),
    );
    final updated = (await db.itineraryDao.watchItemsForTrip(1).first).first;
    expect(updated.actualStartMinutes, 555);
    expect(updated.actualEndMinutes, 650);
    expect(updated.startMinutes, 540);
  });
}
