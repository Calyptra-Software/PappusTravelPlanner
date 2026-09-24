import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';

/// Verifies the v38 -> v39 migration that added
/// `itinerary_items.chord_display`, saying whether the map draws the straight
/// segment between a leg's ends. Every existing leg has been drawn by the
/// default rule, so it must come through as `auto`, its ends untouched.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tp_chord_display');
    path = p.join(tempDir.path, 'v38.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Builds a v38 database at [path]: the current schema less the column, with
  /// the version stamped back — written through the app, for the reason
  /// `reimbursement_migration_test.dart` gives.
  Future<int> seedV38Database() async {
    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    final tripId = await db
        .into(db.trips)
        .insert(TripsCompanion.insert(title: 'Hamburg'));
    final legId = await db
        .into(db.itineraryItems)
        .insert(
          ItineraryItemsCompanion.insert(
            tripId: tripId,
            date: DateTime(2026, 5, 1),
            kind: ItemKind.transport,
            fromLat: const Value(53.5511),
            fromLon: const Value(9.9937),
            toLat: const Value(53.5600),
            toLon: const Value(10.0100),
          ),
        );
    await db.close();

    final raw = sqlite3.open(path);
    raw.execute('ALTER TABLE itinerary_items DROP COLUMN chord_display');
    raw.execute('PRAGMA user_version = 38');
    raw.close();
    return legId;
  }

  test('v38 -> v39 leaves every leg drawn by the default rule', () async {
    final legId = await seedV38Database();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    final leg = await (db.select(
      db.itineraryItems,
    )..where((i) => i.id.equals(legId))).getSingle();
    expect(leg.chordDisplay, TrackDisplay.auto);
    expect(leg.fromLat, 53.5511);
    expect(leg.toLon, 10.0100);

    // And the migrated schema really takes the setting.
    await db.itineraryDao.setChordDisplay(legId, TrackDisplay.hidden);
    final hidden = await (db.select(
      db.itineraryItems,
    )..where((i) => i.id.equals(legId))).getSingle();
    expect(hidden.chordDisplay, TrackDisplay.hidden);
    // Hiding the line keeps the ends it would have been drawn between.
    expect(hidden.fromLat, 53.5511);
  });
}
