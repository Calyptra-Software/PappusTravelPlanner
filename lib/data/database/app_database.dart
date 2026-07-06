import 'package:drift/drift.dart';

import '../../core/database/database_location.dart';
import 'daos/cost_dao.dart';
import 'daos/itinerary_dao.dart';
import 'daos/trip_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Trips, ItineraryItems, Costs, CostReasons],
  daos: [TripDao, ItineraryDao, CostDao],
)
class AppDatabase extends _$AppDatabase {
  /// Opens (or creates) the database file at [path].
  AppDatabase.atPath(String path) : super(openExecutor(path));

  /// Constructs a database over a caller-provided executor. Used by tests to
  /// run against an in-memory database.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          // v2 introduced costs attached to itinerary items.
          if (from < 2) {
            await m.createTable(costs);
            await m.createTable(costReasons);
          }
          // v3 relaxed costs.itemId to nullable and added costs.tripId so a
          // cost can be attached to the whole trip instead of a single item.
          if (from < 3) {
            await m.alterTable(TableMigration(costs, newColumns: [costs.tripId]));
          }
          // v4 added an optional icon to each saved cost reason.
          if (from < 4) {
            await m.addColumn(costReasons, costReasons.iconId);
          }
        },
        beforeOpen: (details) async {
          // Enforce ON DELETE CASCADE for itinerary items and costs.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Flushes the write-ahead log into the main database file so it is complete
  /// and safe to copy/export as a single file.
  Future<void> checkpoint() =>
      customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
}
