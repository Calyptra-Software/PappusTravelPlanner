import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:travelplanner/data/database/app_database.dart';

/// Verifies the v19 -> v20 migration that turned the fixed `TransportMode` enum
/// into a user-managed `transport_modes` table. Real user databases are migrated
/// in place: the built-ins must be seeded, and every existing leg must come
/// through pointing at the same mode it did before — its old enum index (0..11)
/// repointed onto the seeded row for that mode (id = index + 1).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tp_transport_modes_migr');
    path = p.join(tempDir.path, 'v19.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Builds a database file at [path] with the v19 schema — legs storing their
  /// mode as the `TransportMode` enum index — holding a trip whose day has a
  /// train leg (index 5), a walk leg (index 0), and a leg with no mode set.
  /// [userVersion] stamps the schema version: 19 for a genuine old database, or
  /// 20 to simulate one that reached v20 without the transport-modes table (an
  /// intermediate build), which the v21 self-heal must repair.
  void seedV19Database({int userVersion = 19}) {
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
        actual_start_minutes INTEGER,
        actual_end_minutes INTEGER,
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
      INSERT INTO trips (id, title) VALUES (1, 'Alps');
      INSERT INTO itinerary_items
        (id, trip_id, date, sort_order, kind, title, mode, from_location,
         to_location)
        VALUES
          (1, 1, 0, 0, 1, NULL, 5, 'Zurich', 'Chur'),   -- train (index 5)
          (2, 1, 0, 1, 1, NULL, 0, 'Chur', 'Arosa'),    -- walk  (index 0)
          (3, 1, 0, 2, 1, NULL, NULL, 'Arosa', 'Peak'); -- no mode
    ''');
    raw.execute('PRAGMA user_version = $userVersion');
    raw.close();
  }

  test('v19 -> v20 seeds the built-ins and repoints each leg', () async {
    seedV19Database();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    // All twelve built-ins are seeded, each carrying its enum key.
    final modes = await db.transportModeDao.watchModes().first;
    expect(modes, hasLength(12));
    final byId = {for (final m in modes) m.id: m};
    final keyOf = {for (final m in modes) m.builtinKey: m.id};
    expect(keyOf.keys, containsAll(['walk', 'train', 'flight', 'ski']));

    // Each leg now points at the seeded row for the mode it had before; a leg
    // with no mode stays unassigned.
    final items = await db.itineraryDao.watchItemsForTrip(1).first;
    final legs = {for (final i in items) i.id: i};
    expect(byId[legs[1]!.mode!]!.builtinKey, 'train');
    expect(byId[legs[2]!.mode!]!.builtinKey, 'walk');
    expect(legs[3]!.mode, isNull);

    // The route survived unchanged.
    expect(legs[1]!.fromLocation, 'Zurich');
    expect(legs[1]!.toLocation, 'Chur');
  });

  test('v21 self-heals a v20 database left without the modes table', () async {
    // A database that reached v20 without ever getting the transport-modes
    // table (its legs still hold the old enum indices): the v21 branch must
    // create and seed the table and repoint the legs, exactly as v20 would.
    seedV19Database(userVersion: 20);

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    final modes = await db.transportModeDao.watchModes().first;
    expect(modes, hasLength(12));
    final byId = {for (final m in modes) m.id: m};

    final items = await db.itineraryDao.watchItemsForTrip(1).first;
    final legs = {for (final i in items) i.id: i};
    expect(byId[legs[1]!.mode!]!.builtinKey, 'train');
    expect(byId[legs[2]!.mode!]!.builtinKey, 'walk');
    expect(legs[3]!.mode, isNull);
  });
}
