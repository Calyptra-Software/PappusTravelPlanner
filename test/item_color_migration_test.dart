import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:travelplanner/data/database/app_database.dart';

/// Verifies the v29 -> v30 migration that let an itinerary entry carry the color
/// it is drawn in on the map. Real user databases are migrated in place: every
/// entry must come through untouched and uncolored, because null is not "missing
/// data" here — it *is* the state "drawn in the trip's accent", which is how the
/// whole app has drawn everything until now.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tp_item_color_migration');
    path = p.join(tempDir.path, 'v29.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Builds a database file at [path] with the v29 schema — entries carrying
  /// their positions and a `tracks` table holding the lines they followed, but
  /// nothing about how any of it is drawn — holding a trip whose day has a
  /// recorded walk and a named place.
  void seedV29Database() {
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
        lat REAL,
        lon REAL,
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
      CREATE TABLE tracks (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER NOT NULL REFERENCES itinerary_items (id),
        source INTEGER NOT NULL DEFAULT 0,
        name TEXT,
        points TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      );
      INSERT INTO trips (id, title) VALUES (1, 'Hamburg');
      INSERT INTO transport_modes (id, builtin_key, sort_order)
        VALUES (2, 'walk', 1);
      INSERT INTO itinerary_items
        (id, trip_id, date, sort_order, kind, title, mode,
         from_location, to_location, from_lat, from_lon, to_lat, to_lon,
         location, lat, lon, spans_next_day)
        VALUES
          (1, 1, 0, 0, 1, 'Along the Alster', 2,
           'Jungfernstieg', 'Winterhude',
           53.553, 9.993, 53.590, 10.010, NULL, NULL, NULL, 0),
          (2, 1, 0, 1, 0, 'Kunsthalle', NULL, NULL, NULL,
           NULL, NULL, NULL, NULL, 'Glockengießerwall 5', 53.5555, 10.0055, 0);
      INSERT INTO tracks (id, item_id, source, name, points, sort_order)
        VALUES (1, 1, 0, 'alster.gpx', '_p~iF~ps|U_ulLnnqC', 0);
    ''');
    raw.execute('PRAGMA user_version = 29');
    raw.close();
  }

  test('v29 -> v30 adds an entry color, leaving the trip as it was', () async {
    seedV29Database();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    final items = await db.itineraryDao.watchItemsForTrip(1).first;
    expect(items.map((i) => i.title), ['Along the Alster', 'Kunsthalle']);

    // Everything the entries already carried survives, tracks included.
    final leg = items.first;
    expect(leg.fromLat, closeTo(53.553, 1e-9));
    expect(leg.toLon, closeTo(10.010, 1e-9));
    expect(
      (await db.trackDao.watchTracksForItem(leg.id).first).single.name,
      'alster.gpx',
    );

    // And nothing is colored: null here means "drawn in the trip's accent",
    // which is exactly how this trip has always been drawn.
    expect(items.every((i) => i.colorValue == null), isTrue);

    // The migrated schema really does take one, and it is written on its own.
    await db.itineraryDao.setItemColor(leg.id, 0xFF1B5E20);
    final coloredLeg = (await db.itineraryDao.watchItemsForTrip(1).first).first;
    expect(coloredLeg.colorValue, 0xFF1B5E20);
    expect(coloredLeg.title, 'Along the Alster');
    expect(coloredLeg.fromLat, closeTo(53.553, 1e-9));

    // Cleared again, it goes back to the trip's accent rather than to some
    // remembered color.
    await db.itineraryDao.setItemColor(leg.id, null);
    expect(
      (await db.itineraryDao.watchItemsForTrip(1).first).first.colorValue,
      isNull,
    );

    // A place takes one too — both kinds are drawn on the map.
    await db.itineraryDao.updateItem(
      items.last.copyWith(colorValue: const Value(0xFFB71C1C)),
    );
    expect(
      (await db.itineraryDao.watchItemsForTrip(1).first).last.colorValue,
      0xFFB71C1C,
    );
  });
}
