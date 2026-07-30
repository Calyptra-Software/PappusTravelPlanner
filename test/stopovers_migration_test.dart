import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/stopovers.dart';

/// Verifies the v25 -> v26 migration that added a leg's intermediate stops.
/// Real user databases are migrated in place: every entry must come through
/// untouched, simply carrying no stops yet — a leg imported before this version
/// never recorded any, and the app must not pretend otherwise.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tp_stopovers_migration');
    path = p.join(tempDir.path, 'v25.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Builds a database file at [path] with the v25 schema — legs carrying their
  /// routing trip id and overnight flag, but no stops — holding a trip whose day
  /// has an imported train leg and a hand-entered place.
  void seedV25Database() {
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
      CREATE TABLE transport_modes (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        builtin_key TEXT UNIQUE,
        name TEXT,
        icon_id TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0
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
        spans_next_day INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        location TEXT,
        mode INTEGER REFERENCES transport_modes (id),
        from_location TEXT,
        to_location TEXT,
        from_lat REAL,
        from_lon REAL,
        to_lat REAL,
        to_lon REAL,
        source_trip_id TEXT
      );
      INSERT INTO trips (id, title) VALUES (1, 'Basel');
      INSERT INTO transport_modes (id, builtin_key, sort_order)
        VALUES (6, 'train', 5);
      INSERT INTO itinerary_items
        (id, trip_id, date, sort_order, kind, title, start_minutes, end_minutes,
         mode, from_location, to_location, source_trip_id, spans_next_day)
        VALUES
          (1, 1, 0, 0, 1, 'ICE 507', 480, 590, 6,
           'Hamburg Hbf', 'Frankfurt(Main) Hbf', 'trip-507', 0),
          (2, 1, 0, 1, 0, 'Museum', 600, 660, NULL, NULL, NULL, NULL, 0);
    ''');
    raw.execute('PRAGMA user_version = 25');
    raw.close();
  }

  test('v25 -> v26 adds the stops, leaving the itinerary as it was', () async {
    seedV25Database();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    final items = await db.itineraryDao.watchItemsForTrip(1).first;
    expect(items.map((i) => i.title), ['ICE 507', 'Museum']);

    // The plan survives; nothing claims to know where the train called.
    final leg = items.first;
    expect(leg.startMinutes, 480);
    expect(leg.endMinutes, 590);
    expect(leg.sourceTripId, 'trip-507');
    expect(leg.fromLocation, 'Hamburg Hbf');
    expect(items.every((i) => i.stopovers == null), isTrue);
    expect(decodeStopovers(leg.stopovers), isEmpty);

    // And the migrated schema really does take them.
    await db.itineraryDao.updateItem(
      leg.copyWith(
        stopovers: Value(
          encodeStopovers(const [Stopover(name: 'Hannover Hbf', minutes: 520)]),
        ),
      ),
    );
    final updated = (await db.itineraryDao.watchItemsForTrip(1).first).first;
    expect(decodeStopovers(updated.stopovers), [
      const Stopover(name: 'Hannover Hbf', minutes: 520),
    ]);
  });
}
