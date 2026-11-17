import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/route_plan.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/database/track_points.dart';

/// Verifies the v42 -> v43 migration that added `tracks.elevations` and
/// `itinerary_items.route_plan`. No line was ever stored with heights and no
/// entry came from the route planner, so both must come through null with
/// everything else untouched.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tp_route_plan');
    path = p.join(tempDir.path, 'v42.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Builds a v42 database at [path]: the current schema less the two columns,
  /// with the version stamped back — written through the app, for the reason
  /// `reimbursement_migration_test.dart` gives.
  Future<({int legId, int trackId})> seedV42Database() async {
    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    final tripId = await db
        .into(db.trips)
        .insert(TripsCompanion.insert(title: 'Karwendel'));
    final legId = await db
        .into(db.itineraryItems)
        .insert(
          ItineraryItemsCompanion.insert(
            tripId: tripId,
            date: DateTime(2026, 5, 1),
            kind: ItemKind.transport,
            fromLocation: const Value('Car park'),
          ),
        );
    final trackId = await db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            itemId: legId,
            source: const Value(TrackSource.recorded),
            points: '_p~iF~ps|U_ulLnnqC',
          ),
        );
    await db.close();

    final raw = sqlite3.open(path);
    raw.execute('ALTER TABLE itinerary_items DROP COLUMN route_plan');
    raw.execute('ALTER TABLE tracks DROP COLUMN elevations');
    // And what v44 added, so the file is a v42 one.
    raw.execute('ALTER TABLE recording_fixes DROP COLUMN altitude');
    raw.execute('PRAGMA user_version = 42');
    raw.close();
    return (legId: legId, trackId: trackId);
  }

  test('v42 -> v43 leaves every line without heights and every entry '
      'without a plan', () async {
    final ids = await seedV42Database();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    Future<ItineraryItem> leg() => (db.select(
      db.itineraryItems,
    )..where((i) => i.id.equals(ids.legId))).getSingle();
    Future<Track> track() => (db.select(
      db.tracks,
    )..where((t) => t.id.equals(ids.trackId))).getSingle();

    expect((await leg()).routePlan, isNull);
    expect((await leg()).fromLocation, 'Car park');
    expect((await track()).elevations, isNull);
    expect((await track()).points, '_p~iF~ps|U_ulLnnqC');
    expect((await track()).source, TrackSource.recorded);

    // And the migrated schema really takes both.
    await (db.update(
      db.itineraryItems,
    )..where((i) => i.id.equals(ids.legId))).write(
      ItineraryItemsCompanion(
        routePlan: Value(encodeRoutePlan(const RoutePlan(tour: 't1'))),
      ),
    );
    await (db.update(db.tracks)..where((t) => t.id.equals(ids.trackId))).write(
      TracksCompanion(
        elevations: Value(encodeTrackElevations(const [500, 510])),
      ),
    );
    expect(decodeRoutePlan((await leg()).routePlan)!.tour, 't1');
    expect(trackElevationsOrNull((await track()).elevations, 2), [500, 510]);
  });
}
