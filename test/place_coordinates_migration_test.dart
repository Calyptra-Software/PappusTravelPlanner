import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:travelplanner/data/database/app_database.dart';

/// Verifies the v27 -> v28 migration that gave a *place* the coordinates a
/// transport leg's ends have carried since v24. Real user databases are migrated
/// in place: every entry must come through untouched, the legs keeping the
/// positions they already had and the places simply having none yet — a place
/// recorded before this version was only ever named, and the app must not invent
/// a position from a name.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'tp_place_coords_migration',
    );
    path = p.join(tempDir.path, 'v27.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Builds a database file at [path] with the v27 schema — legs carrying their
  /// endpoint coordinates, stops and place ids, but no position on a place —
  /// holding a trip whose day has an imported train leg and a named place.
  void seedV27Database() {
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
        kind INTEGER NOT NULL DEFAULT 0,
        from_routine_id INTEGER REFERENCES trips (id)
      );
      CREATE TABLE tags (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color_value INTEGER NOT NULL DEFAULT 4283653998,
        sort_order INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE trip_tags (
        trip_id INTEGER NOT NULL REFERENCES trips (id),
        tag_id INTEGER NOT NULL REFERENCES tags (id),
        PRIMARY KEY (trip_id, tag_id)
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
        source_trip_id TEXT,
        stopovers TEXT,
        from_place_id TEXT,
        to_place_id TEXT
      );
      INSERT INTO trips (id, title) VALUES (1, 'Basel');
      INSERT INTO transport_modes (id, builtin_key, sort_order)
        VALUES (6, 'train', 5);
      INSERT INTO itinerary_items
        (id, trip_id, date, sort_order, kind, title, start_minutes, end_minutes,
         mode, from_location, to_location, from_lat, from_lon, to_lat, to_lon,
         source_trip_id, location, spans_next_day)
        VALUES
          (1, 1, 0, 0, 1, 'ICE 507', 480, 590, 6,
           'Hamburg Hbf', 'Frankfurt(Main) Hbf',
           53.552736, 10.006909, 50.107145, 8.663789,
           'trip-507', NULL, 0),
          (2, 1, 0, 1, 0, 'Museum', 600, 660, NULL, NULL, NULL,
           NULL, NULL, NULL, NULL, NULL, 'Museumsufer', 0);
    ''');
    raw.execute('PRAGMA user_version = 27');
    raw.close();
  }

  test(
    'v27 -> v28 adds a place position, leaving the itinerary as it was',
    () async {
      seedV27Database();

      final db = AppDatabase.forTesting(NativeDatabase(File(path)));
      addTearDown(db.close);

      final items = await db.itineraryDao.watchItemsForTrip(1).first;
      expect(items.map((i) => i.title), ['ICE 507', 'Museum']);

      // The leg keeps the positions it already had.
      final leg = items.first;
      expect(leg.startMinutes, 480);
      expect(leg.sourceTripId, 'trip-507');
      expect(leg.fromLat, closeTo(53.552736, 1e-9));
      expect(leg.fromLon, closeTo(10.006909, 1e-9));
      expect(leg.toLat, closeTo(50.107145, 1e-9));
      expect(leg.toLon, closeTo(8.663789, 1e-9));

      // The place keeps its name and gains no position: nothing is derived from
      // "Museumsufer", which is the whole point of the two being separate.
      final place = items.last;
      expect(place.location, 'Museumsufer');
      expect(items.every((i) => i.lat == null && i.lon == null), isTrue);

      // And the migrated schema really does take one.
      await db.itineraryDao.updateItem(
        place.copyWith(lat: const Value(50.105), lon: const Value(8.679)),
      );
      final updated = (await db.itineraryDao.watchItemsForTrip(1).first).last;
      expect(updated.lat, closeTo(50.105, 1e-9));
      expect(updated.lon, closeTo(8.679, 1e-9));
      expect(updated.location, 'Museumsufer');
    },
  );
}
