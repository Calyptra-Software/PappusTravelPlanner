import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:latlong2/latlong.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/attachments/attachment_import.dart';

/// Verifies the v31 -> v32 migration that let a file hang on part of a plan.
///
/// Two new tables and nothing else: no existing row changes meaning, and there
/// is nothing to backfill — the app has never had a file to store, so no column
/// anywhere was standing in for one. What this checks is that a real database
/// comes through with everything it already carried, and that the tables it
/// gained actually take an attachment on both of the two things one may hang on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tp_attachment_migration');
    path = p.join(tempDir.path, 'v31.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// A database at the v31 schema — entries with positions, colors and tracks,
  /// and the hand-marked countries — holding a trip whose day has a two-leg run
  /// sharing one ticket.
  void seedV31Database() {
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
      INSERT INTO trips (id, title) VALUES (1, 'Hamburg');
      INSERT INTO transport_modes (id, builtin_key, sort_order)
        VALUES (6, 'train', 5);
      INSERT INTO item_groups (id, trip_id, label) VALUES (1, 1, 'To Berlin');
      INSERT INTO itinerary_items
        (id, trip_id, group_id, date, sort_order, kind, title, mode,
         from_location, to_location, from_lat, from_lon, to_lat, to_lon,
         spans_next_day, color_value)
        VALUES
          (1, 1, 1, 0, 0, 1, 'ICE 802', 6,
           'Hamburg Hbf', 'Berlin Hbf', 53.553, 10.006, 52.525, 13.369, 0,
           4278216540),
          (2, 1, 1, 0, 1, 1, 'S-Bahn', 6,
           'Berlin Hbf', 'Alexanderplatz', 52.525, 13.369, 52.521, 13.411, 0,
           NULL);
      INSERT INTO visited_countries (code, marked_at) VALUES ('IS', 0);
    ''');
    raw.execute('PRAGMA user_version = 31');
    raw.close();
  }

  test('v31 -> v32 adds attachments, leaving the trip as it was', () async {
    seedV31Database();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    // Everything the database already held comes through untouched.
    final items = await db.itineraryDao.watchItemsForTrip(1).first;
    expect(items.map((i) => i.title), ['ICE 802', 'S-Bahn']);
    expect(items.first.colorValue, 4278216540);
    expect(items.first.fromLat, closeTo(53.553, 1e-9));
    expect(await db.visitedCountryDao.watchMarked().first, {'IS'});

    // And nothing carries a file, because nothing ever could.
    final counts = await db.attachmentDao.watchAttachmentCountsForTrip(1).first;
    expect(counts.byItem, isEmpty);
    expect(counts.byGroup, isEmpty);

    // The migrated schema takes one on an entry and one on a run, and hands the
    // payload back from the table it was split into.
    final onLeg = await db.attachmentDao.addAttachment(
      PreparedAttachment(
        kind: AttachmentKind.photo,
        mimeType: 'image/jpeg',
        bytes: Uint8List.fromList(List.filled(32, 3)),
        name: 'platform.jpg',
        thumbnail: Uint8List.fromList([9]),
        width: 40,
        height: 30,
        position: const LatLng(53.553, 10.006),
        positionSource: AttachmentPositionSource.exif,
      ),
      itemId: items.first.id,
    );
    final onRun = await db.attachmentDao.addAttachment(
      PreparedAttachment(
        kind: AttachmentKind.document,
        mimeType: 'application/pdf',
        bytes: Uint8List.fromList(List.filled(16, 1)),
        name: 'ticket.pdf',
      ),
      groupId: 1,
    );

    expect(await db.attachmentDao.readAttachmentBytes(onLeg), hasLength(32));
    expect(
      (await db.attachmentDao.attachment(onLeg))!.positionSource,
      AttachmentPositionSource.exif,
    );
    final after = await db.attachmentDao.watchAttachmentCountsForTrip(1).first;
    expect(after.byItem[items.first.id]!.photos, 1);
    expect(after.byGroup[1]!.documents, 1);
    expect(onRun, isNot(onLeg));
  });
}
