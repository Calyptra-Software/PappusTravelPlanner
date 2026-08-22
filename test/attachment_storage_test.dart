import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:travelplanner/core/database/database_location.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/attachments/attachment_import.dart';

/// What deleting an attachment costs, and what the settings screen reports.
///
/// The file-shrinking half is the interesting one: SQLite keeps deleted pages
/// on a free list by default and never hands them back, which is the right
/// trade for a database of text and the wrong one the moment a row can be a
/// photograph. These tests stand on real files, since the whole question is
/// about a file's length.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tp_storage');
    path = p.join(dir.path, 'pappus.sqlite');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  AppDatabase open() => AppDatabase.forTesting(NativeDatabase(File(path)));

  Future<int> seedTrip(AppDatabase db) => db.tripDao.createTrip(
    TripsCompanion.insert(
      title: 'Rome',
      startDate: Value(DateTime(2026, 5, 1)),
      endDate: Value(DateTime(2026, 5, 2)),
    ),
  );

  Future<int> addLeg(AppDatabase db, int tripId) => db.itineraryDao.addItem(
    ItineraryItemsCompanion.insert(
      tripId: tripId,
      date: DateTime(2026, 5, 1),
      kind: ItemKind.transport,
    ),
  );

  PreparedAttachment bigPhoto(int index) => PreparedAttachment(
    kind: AttachmentKind.photo,
    mimeType: 'image/jpeg',
    // Not compressible to nothing and not identical between rows, so the file
    // really has to hold every byte of it.
    bytes: Uint8List.fromList(
      List.generate(400 * 1024, (i) => (i * 31 + index * 7) & 0xFF),
    ),
    name: 'photo-$index.jpg',
  );

  /// Lets the WAL fold back into the main file, which is what
  /// `databaseFileSize` measures — and what an export copies.
  Future<void> settle(AppDatabase db) =>
      db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');

  test('a fresh database vacuums itself, and says so', () async {
    final db = open();
    addTearDown(db.close);

    final mode = await db.customSelect('PRAGMA auto_vacuum').getSingle();
    expect(mode.read<int>('auto_vacuum'), 1);
  });

  test(
    'deleting an attachment gives the space back, with no one asking',
    () async {
      final db = open();
      addTearDown(db.close);
      final trip = await seedTrip(db);
      final leg = await addLeg(db, trip);

      final ids = [
        for (var i = 0; i < 10; i++)
          await db.attachmentDao.addAttachment(bigPhoto(i), itemId: leg),
      ];
      await settle(db);
      final full = databaseFileSize(path)!;
      expect(full, greaterThan(3 * 1024 * 1024));

      for (final id in ids) {
        await db.attachmentDao.deleteAttachment(id);
      }
      await settle(db);

      // No VACUUM anywhere in the app, and no button in the settings: the pages
      // come back at the commit that frees them. Without `auto_vacuum = FULL` the
      // file would still be its full size here, and would stay that way into
      // every export and every backup.
      expect(databaseFileSize(path)!, lessThan(full ~/ 4));
    },
  );

  test('deleting the entry underneath does it too, by cascade', () async {
    final db = open();
    addTearDown(db.close);
    final trip = await seedTrip(db);
    final leg = await addLeg(db, trip);
    for (var i = 0; i < 8; i++) {
      await db.attachmentDao.addAttachment(bigPhoto(i), itemId: leg);
    }
    await settle(db);
    final full = databaseFileSize(path)!;

    await db.itineraryDao.deleteItem(leg);
    await settle(db);

    // The reason this is a setting on the file and not a call after a delete:
    // an attachment dies in half a dozen places, and only one of them is its
    // own delete.
    expect(databaseFileSize(path)!, lessThan(full ~/ 4));
  });

  test('an existing database is switched over on the next open', () async {
    // A database written before this: pages on the free list, staying there.
    final before = open();
    final trip = await seedTrip(before);
    final leg = await addLeg(before, trip);
    await before.customStatement('PRAGMA auto_vacuum = NONE');
    await before.customStatement('VACUUM');
    expect(
      (await before.customSelect('PRAGMA auto_vacuum').getSingle()).read<int>(
        'auto_vacuum',
      ),
      0,
    );
    final id = await before.attachmentDao.addAttachment(
      bigPhoto(1),
      itemId: leg,
    );
    await before.attachmentDao.deleteAttachment(id);
    await settle(before);
    final stranded = databaseFileSize(path)!;
    await before.close();

    // Opening it again is all it takes — the switch lives beside the
    // application-id stamp, on every open, because it is a property of the file
    // and not of the schema.
    final after = open();
    addTearDown(after.close);
    await after.customSelect('PRAGMA auto_vacuum').getSingle();
    await settle(after);

    expect(
      (await after.customSelect('PRAGMA auto_vacuum').getSingle()).read<int>(
        'auto_vacuum',
      ),
      1,
    );
    // The one-time VACUUM also hands back what the old setting had stranded.
    expect(databaseFileSize(path)!, lessThan(stranded));
    // And the trip is still there: this rewrites the file, it does not empty it.
    expect(await after.itineraryDao.itemsFor(trip), hasLength(1));
  });

  group('what the settings screen reports', () {
    test('counts every attachment in the database, across trips', () async {
      final db = open();
      addTearDown(db.close);
      final first = await seedTrip(db);
      final second = await seedTrip(db);
      await db.attachmentDao.addAttachment(
        bigPhoto(1),
        itemId: await addLeg(db, first),
      );
      await db.attachmentDao.addAttachment(
        bigPhoto(2),
        itemId: await addLeg(db, second),
      );

      final storage = await db.attachmentDao.attachmentStorage();

      // The question is about the *file* — what it costs to copy, back up or
      // hand to another device — so it is not per trip.
      expect(storage.count, 2);
      expect(storage.bytes, 2 * 400 * 1024);
    });

    test('an empty database reports nothing rather than null', () async {
      final db = open();
      addTearDown(db.close);

      final storage = await db.attachmentDao.attachmentStorage();

      expect(storage.count, 0);
      expect(storage.bytes, 0);
    });
  });
}
