import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:travelplanner/data/database/app_database.dart';

/// Verifies the v16 -> v17 migration that added alternatives (competing versions
/// of one stretch of a day). Real user databases are migrated in place, so an
/// existing itinerary must come through untouched, with every item simply
/// staying loose (`alternative_id` NULL).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tp_alternative_migration');
    path = p.join(tempDir.path, 'v16.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Builds a database file at [path] with the v16 schema (no alternatives) and
  /// a trip whose day holds two items, one of them carrying a cost.
  void seedV16Database() {
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
      CREATE TABLE itinerary_items (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER NOT NULL REFERENCES trips (id),
        group_id INTEGER REFERENCES item_groups (id),
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
      INSERT INTO itinerary_items (id, trip_id, date, sort_order, kind, title)
        VALUES (1, 1, 0, 0, 0, 'Louvre'),
               (2, 1, 0, 1, 0, 'Dinner');
      INSERT INTO costs (item_id, amount_minor, currency, reason)
        VALUES (1, 2200, 0, 'Ticket');
    ''');
    raw.execute('PRAGMA user_version = 16');
    raw.close();
  }

  test(
    'v16 -> v17 adds alternatives, leaving the existing itinerary loose',
    () async {
      seedV16Database();

      final db = AppDatabase.forTesting(NativeDatabase(File(path)));
      addTearDown(db.close);

      // The itinerary survives, every item still sitting directly on its day.
      final items = await db.itineraryDao.watchItemsForTrip(1).first;
      expect(items.map((i) => i.title), ['Louvre', 'Dinner']);
      expect(items.every((i) => i.alternativeId == null), isTrue);

      // The new tables exist and are empty; costs are untouched.
      expect(await db.alternativeDao.watchSetsForTrip(1).first, isEmpty);
      expect(await db.alternativeDao.watchBranchesForTrip(1).first, isEmpty);
      final costs = await db.costDao.watchCostsForTrip(1).first;
      expect(costs.single.amountMinor, 2200);

      // And the migrated schema really does support a new decision point.
      final setId = await db.alternativeDao.createSetFromItem(items.first.id);
      expect(
        (await db.alternativeDao.watchBranchesForTrip(1).first)[setId],
        hasLength(2),
      );
    },
  );

  /// Builds a database file at [path] with the v17 schema — alternatives as they
  /// first shipped, with the since-removed `alternative_sets.decided` flag — and
  /// a day whose museum is one option of a decision.
  void seedV17Database() {
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
        label TEXT,
        decided INTEGER NOT NULL DEFAULT 0
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
      INSERT INTO alternative_sets (id, trip_id, date, sort_order, label, decided)
        VALUES (1, 1, 0, 1, 'Saturday afternoon', 1);
      INSERT INTO alternatives (id, set_id, label, sort_order, chosen)
        VALUES (1, 1, 'Museum day', 0, 1),
               (2, 1, NULL, 1, 0);
      INSERT INTO itinerary_items
        (id, trip_id, alternative_id, date, sort_order, kind, title)
        VALUES (1, 1, 1, 0, 0, 0, 'Louvre'),
               (2, 1, 2, 0, 0, 0, 'Boat trip'),
               (3, 1, NULL, 0, 0, 0, 'Dinner');
      INSERT INTO costs (item_id, amount_minor, currency, reason)
        VALUES (1, 2200, 0, 'Ticket');
    ''');
    raw.execute('PRAGMA user_version = 17');
    raw.close();
  }

  test(
    'v17 -> v18 drops the "decided" flag, keeping the decision itself',
    () async {
      seedV17Database();

      final db = AppDatabase.forTesting(NativeDatabase(File(path)));
      addTearDown(db.close);

      // The decision, its options and their items all survive the column going.
      final sets = await db.alternativeDao.watchSetsForTrip(1).first;
      expect(sets.values.single.label, 'Saturday afternoon');
      expect(sets.values.single.sortOrder, 1);
      final branches = (await db.alternativeDao
          .watchBranchesForTrip(1)
          .first)[1]!;
      expect(branches.map((b) => b.label), ['Museum day', null]);
      expect(branches.where((b) => b.chosen).map((b) => b.id), [1]);

      // Items still point at their option — the foreign key survived the table
      // being rebuilt — and only the chosen option's cost counts.
      final items = await db.itineraryDao.watchItemsForTrip(1).first;
      ItineraryItem item(String title) =>
          items.firstWhere((i) => i.title == title);
      expect(item('Louvre').alternativeId, 1);
      expect(item('Boat trip').alternativeId, 2);
      expect(item('Dinner').alternativeId, isNull);
      final counted = await db.costDao.watchCountedCostsForTrip(1).first;
      expect(counted.single.amountMinor, 2200);

      // Choosing still works against the rebuilt table.
      await db.alternativeDao.chooseAlternative(2);
      final after = (await db.alternativeDao.watchBranchesForTrip(1).first)[1]!;
      expect(after.where((b) => b.chosen).map((b) => b.id), [2]);
    },
  );
}
