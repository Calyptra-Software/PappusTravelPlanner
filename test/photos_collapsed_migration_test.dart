import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:travelplanner/data/database/app_database.dart';

/// Verifies the v33 -> v34 migration that remembers whether a trip's strip of
/// photographs is collapsed, the way a checklist and a day already do.
///
/// One defaulted column: every existing trip has been showing its photographs
/// all along, which is exactly what false means.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tp_photos_collapsed');
    path = p.join(tempDir.path, 'v33.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  void seedV33Database() {
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
        (id, trip_id, date, sort_order, kind, title, spans_next_day)
        VALUES (1, 1, 0, 0, 0, 'Kunsthalle', 0);
      INSERT INTO attachments
        (id, item_id, kind, mime_type, name, byte_size, sort_order, created_at)
        VALUES (1, 1, 0, 'image/jpeg', 'arena.jpg', 3, 0, 0);
      INSERT INTO attachment_blobs (attachment_id, bytes) VALUES (1, x'010203');
    ''');
    raw.execute('PRAGMA user_version = 33');
    raw.close();
  }

  test('v33 -> v34 starts every existing trip expanded', () async {
    seedV33Database();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    final trip = (await db.tripDao.findTrip(1))!;
    expect(trip.title, 'Hamburg');
    // False is not "missing data" here: it is the state every trip has been in.
    expect(trip.photosCollapsed, isFalse);
    // And nothing else moved.
    expect(await db.attachmentDao.readAttachmentBytes(1), hasLength(3));

    await db.tripDao.setPhotosCollapsed(1, true);
    expect((await db.tripDao.findTrip(1))!.photosCollapsed, isTrue);
    // A targeted write: the rest of the row is untouched.
    expect((await db.tripDao.findTrip(1))!.title, 'Hamburg');
  });
}
