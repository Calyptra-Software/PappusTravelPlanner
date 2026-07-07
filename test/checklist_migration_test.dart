import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:travelplanner/data/database/app_database.dart';

/// Verifies the v6 -> v7 migration that turned the single per-trip checklist
/// (items keyed by trip_id, with an optional trips.checklist_title) into any
/// number of named checklists (items keyed by checklist_id).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tp_checklist_migration');
    path = p.join(tempDir.path, 'v6.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Builds a database file at [path] with the old v6 schema and some data.
  void seedV6Database() {
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
        created_at INTEGER NOT NULL DEFAULT 0,
        checklist_title TEXT
      );
      CREATE TABLE checklist_items (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER NOT NULL REFERENCES trips (id),
        label TEXT NOT NULL,
        done INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE cost_reasons (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        label TEXT NOT NULL UNIQUE,
        icon_id INTEGER
      );
      CREATE TABLE costs (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER,
        trip_id INTEGER,
        amount_minor INTEGER NOT NULL,
        currency INTEGER NOT NULL,
        reason TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT 0
      );
    ''');
    // Trip 1: a custom checklist title and two items.
    // Trip 2: no title but has an item (so it still gets a checklist).
    // Trip 3: neither title nor items (so it gets no checklist).
    raw.execute('''
      INSERT INTO trips (id, title, checklist_title) VALUES
        (1, 'Paris', 'Packing'),
        (2, 'Rome', NULL),
        (3, 'Oslo', NULL);
      INSERT INTO checklist_items (trip_id, label, done, sort_order) VALUES
        (1, 'Passport', 0, 0),
        (1, 'Tickets', 1, 1),
        (2, 'Camera', 0, 0);
    ''');
    raw.execute('PRAGMA user_version = 6');
    raw.close();
  }

  test('folds each trip\'s items and title into named checklists', () async {
    seedV6Database();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    final paris =
        (await db.checklistDao.watchChecklists(1).first);
    final rome = (await db.checklistDao.watchChecklists(2).first);
    final oslo = (await db.checklistDao.watchChecklists(3).first);

    // Trip 1 keeps its custom title; trip 2 gets an unnamed checklist; trip 3
    // gets none.
    expect(paris.map((c) => c.title), ['Packing']);
    expect(rome.map((c) => c.title), ['']);
    expect(oslo, isEmpty);

    // Items are repointed to the new checklist, order and done-state preserved.
    final parisItems =
        await db.checklistDao.watchItems(paris.single.id).first;
    expect(parisItems.map((i) => i.label), ['Passport', 'Tickets']);
    expect(parisItems.map((i) => i.done), [false, true]);

    final romeItems = await db.checklistDao.watchItems(rome.single.id).first;
    expect(romeItems.map((i) => i.label), ['Camera']);
  });
}
