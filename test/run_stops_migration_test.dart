import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/stopovers.dart';
import 'package:travelplanner/data/database/tables.dart';

/// Verifies the v41 -> v42 migration that added `itinerary_items.run_stops`,
/// the stops of a vehicle's run outside the leg. No existing leg has ever had
/// its run loaded, so every one must come through with none (null, which is
/// what "never asked for" means), its own stops untouched.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tp_run_stops');
    path = p.join(tempDir.path, 'v41.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Builds a v41 database at [path]: the current schema less the column, with
  /// the version stamped back — written through the app, for the reason
  /// `reimbursement_migration_test.dart` gives.
  Future<int> seedV41Database() async {
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
            sourceTripId: const Value('trip-1'),
            stopovers: Value(
              encodeStopovers(const [Stopover(name: 'Büchen', minutes: 511)]),
            ),
          ),
        );
    await db.close();

    final raw = sqlite3.open(path);
    raw.execute('ALTER TABLE itinerary_items DROP COLUMN run_stops');
    raw.execute('PRAGMA user_version = 41');
    raw.close();
    return legId;
  }

  test('v41 -> v42 leaves every leg with its run not yet loaded', () async {
    final legId = await seedV41Database();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    Future<ItineraryItem> leg() => (db.select(
      db.itineraryItems,
    )..where((i) => i.id.equals(legId))).getSingle();

    final migrated = await leg();
    expect(migrated.runStops, isNull);
    expect(decodeStopovers(migrated.stopovers).single.name, 'Büchen');
    expect(migrated.sourceTripId, 'trip-1');

    // And the migrated schema really takes a run.
    await db.itineraryDao.setRunStops(
      legId,
      encodeRunStops(
        const RunStops(before: [Stopover(name: 'Rostock', minutes: 424)]),
      ),
    );
    expect(
      decodeRunStops((await leg()).runStops)!.before.single.name,
      'Rostock',
    );
  });
}
