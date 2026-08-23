import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/attachments/attachment_import.dart';

/// Verifies the v32 -> v33 migration that let a file belong to the whole trip
/// rather than to one part of it.
///
/// One nullable column and nothing else: every row written before this hangs on
/// an entry or a run, which is still exactly what it means, so there is nothing
/// to backfill and nothing that changes reading.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tp_trip_attachment');
    path = p.join(tempDir.path, 'v32.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// A database at the v32 schema, holding a leg with a photo on it and a run
  /// with the shared ticket.
  void seedV32Database() {
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
      INSERT INTO transport_modes (id, builtin_key, sort_order)
        VALUES (6, 'train', 5);
      INSERT INTO item_groups (id, trip_id, label) VALUES (1, 1, 'To Berlin');
      INSERT INTO itinerary_items
        (id, trip_id, group_id, date, sort_order, kind, mode, spans_next_day)
        VALUES (1, 1, 1, 0, 0, 1, 6, 0);
      INSERT INTO attachments
        (id, item_id, group_id, kind, mime_type, name, byte_size, sort_order,
         created_at)
        VALUES
          (1, 1, NULL, 0, 'image/jpeg', 'platform.jpg', 3, 0, 0),
          (2, NULL, 1, 1, 'application/pdf', 'ticket.pdf', 3, 0, 0);
      INSERT INTO attachment_blobs (attachment_id, bytes)
        VALUES (1, x'010203'), (2, x'040506');
    ''');
    raw.execute('PRAGMA user_version = 32');
    raw.close();
  }

  test('v32 -> v33 adds the trip level, leaving the rest as it was', () async {
    seedV32Database();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    // What was already filed stays filed where it was.
    final counts = await db.attachmentDao.watchAttachmentCountsForTrip(1).first;
    expect(counts.byItem[1]!.photos, 1);
    expect(counts.byGroup[1]!.documents, 1);
    expect(await db.attachmentDao.readAttachmentBytes(1), hasLength(3));
    // And nothing has quietly become the trip's.
    expect(await db.attachmentDao.watchAttachmentsForTrip(1).first, isEmpty);

    // The migrated schema takes one at the new level, and keeps it apart from
    // the other two.
    final id = await db.attachmentDao.addAttachment(
      PreparedAttachment(
        kind: AttachmentKind.document,
        mimeType: 'application/pdf',
        bytes: Uint8List.fromList(List.filled(12, 9)),
        name: 'insurance.pdf',
        position: const LatLng(53.55, 9.99),
        positionSource: AttachmentPositionSource.picked,
      ),
      tripId: 1,
    );

    final own = await db.attachmentDao.watchAttachmentsForTrip(1).first;
    expect(own.single.id, id);
    expect(own.single.name, 'insurance.pdf');
    expect(own.single.itemId, isNull);
    expect(own.single.groupId, isNull);
    expect(
      (await db.attachmentDao.watchAttachmentCountsForTrip(1).first)
          .byItem[1]!
          .total,
      1,
    );
  });
}
