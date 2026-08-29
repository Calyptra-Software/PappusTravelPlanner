import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/map/track_summary.dart';

/// Verifies the v35 -> v36 migration that lets the user say whether a stored
/// line is drawn on the map.
///
/// One defaulted column, and the default is not "missing data": every line ever
/// stored has been drawn by the map's own rule, which is exactly what
/// [TrackDisplay.auto] means. A trip that arrives from an older database must
/// therefore draw precisely what it drew before.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tp_track_display');
    path = p.join(tempDir.path, 'v35.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// A leg carrying both kinds of line: the route the search computed, and the
  /// recording made while actually travelling it — the arrangement the override
  /// exists for.
  void seedV35Database() {
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
        from_routine_id INTEGER REFERENCES trips (id),
        photos_collapsed INTEGER NOT NULL DEFAULT 0,
        cover_attachment_id INTEGER,
        cover_hidden INTEGER NOT NULL DEFAULT 0
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
        to_place_id TEXT,
        color_value INTEGER
      );
      CREATE TABLE tracks (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER NOT NULL REFERENCES itinerary_items (id),
        source INTEGER NOT NULL DEFAULT 0,
        name TEXT,
        points TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE visited_countries (
        code TEXT NOT NULL PRIMARY KEY,
        marked_at INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE attachments (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER REFERENCES itinerary_items (id),
        group_id INTEGER REFERENCES item_groups (id),
        trip_id INTEGER REFERENCES trips (id),
        kind INTEGER NOT NULL,
        mime_type TEXT NOT NULL,
        name TEXT,
        byte_size INTEGER NOT NULL,
        width INTEGER,
        height INTEGER,
        lat REAL,
        lon REAL,
        position_source INTEGER,
        thumbnail BLOB,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE attachment_blobs (
        attachment_id INTEGER NOT NULL PRIMARY KEY
          REFERENCES attachments (id),
        bytes BLOB NOT NULL
      );
      INSERT INTO trips (id, title) VALUES (1, 'Hamburg');
      INSERT INTO itinerary_items
        (id, trip_id, date, sort_order, kind, title, spans_next_day,
         from_lat, from_lon, to_lat, to_lon)
        VALUES (1, 1, 0, 0, 1, 'To the station', 0, 53.55, 9.99, 53.56, 10.01);
      INSERT INTO tracks (id, item_id, source, name, points, sort_order)
        VALUES
          (1, 1, 2, NULL, '_p~iF~ps|U_ulLnnqC', 0),
          (2, 1, 1, 'tunnel.gpx', '_p~iF~ps|U_ulLnnqC', 1);
    ''');
    raw.execute('PRAGMA user_version = 35');
    raw.close();
  }

  test('v35 -> v36 leaves every line drawn as it was', () async {
    seedV35Database();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    final rows = await db.trackDao.watchTracksForItem(1).first;
    expect(rows.map((t) => t.name), [null, 'tunnel.gpx']);
    // Nothing is overruled, which is what every existing row means.
    expect(rows.every((t) => t.display == TrackDisplay.auto), isTrue);

    // And the picture is the one this database already drew: the recording, not
    // the computed route beside it.
    final before = summarizeTracks(rows);
    expect(before.map((t) => t.drawn), [false, true]);
  });

  test('and the migrated schema really takes an override', () async {
    seedV35Database();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    // The case the column exists for: the trace is wrong in the tunnel, so it
    // is put away — and the computed route comes forward, without the recording
    // being deleted to get at it.
    await db.trackDao.setTrackDisplay(2, TrackDisplay.hidden);

    final rows = await db.trackDao.watchTracksForItem(1).first;
    expect(summarizeTracks(rows).map((t) => t.drawn), [true, false]);
    // The line itself is still there, which is the whole difference between
    // hiding and deleting.
    expect(rows.map((t) => t.points), everyElement(isNotEmpty));
  });
}
