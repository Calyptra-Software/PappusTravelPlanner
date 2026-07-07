import 'package:drift/drift.dart';

import '../../core/database/database_location.dart';
import 'daos/checklist_dao.dart';
import 'daos/cost_dao.dart';
import 'daos/itinerary_dao.dart';
import 'daos/trip_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Trips,
    ItineraryItems,
    Costs,
    CostReasons,
    People,
    TripParticipants,
    CostBeneficiaries,
    Checklists,
    ChecklistItems,
  ],
  daos: [TripDao, ItineraryDao, CostDao, ChecklistDao],
)
class AppDatabase extends _$AppDatabase {
  /// Opens (or creates) the database file at [path].
  AppDatabase.atPath(String path) : super(openExecutor(path));

  /// Constructs a database over a caller-provided executor. Used by tests to
  /// run against an in-memory database.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 10;

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
          // Checklists. v5 introduced a single per-trip checklist (items keyed
          // by trip_id) and v6 added an optional custom heading on the trip.
          // v7 replaced that with any number of named checklists per trip.
          if (from < 5) {
            // No prior checklist data: create straight to the current schema.
            await m.createTable(checklists);
            await m.createTable(checklistItems);
          } else if (from < 7) {
            // Fold each trip's items (and its custom title, if set) into one
            // named checklist, repointing items from trip_id to checklist_id.
            if (from < 6) {
              // v6's column never existed on this DB; add it so the migration
              // below can read it uniformly. It is abandoned afterwards.
              await customStatement(
                  'ALTER TABLE trips ADD COLUMN checklist_title TEXT');
            }
            await m.createTable(checklists);
            await customStatement('''
              INSERT INTO checklists (trip_id, title, sort_order, created_at)
              SELECT t.id, COALESCE(t.checklist_title, ''), 0,
                     CAST(strftime('%s', 'now') AS INTEGER)
              FROM trips t
              WHERE (t.checklist_title IS NOT NULL AND t.checklist_title != '')
                 OR EXISTS (
                   SELECT 1 FROM checklist_items ci WHERE ci.trip_id = t.id)
            ''');
            await customStatement(
                'ALTER TABLE checklist_items RENAME TO _checklist_items_old');
            await m.createTable(checklistItems);
            await customStatement('''
              INSERT INTO checklist_items
                (id, checklist_id, label, done, sort_order, created_at)
              SELECT o.id,
                     (SELECT c.id FROM checklists c WHERE c.trip_id = o.trip_id),
                     o.label, o.done, o.sort_order, o.created_at
              FROM _checklist_items_old o
            ''');
            await customStatement('DROP TABLE _checklist_items_old');
          }
          // v8 added a reusable list of people and an optional payer on each
          // cost (costs.paid_by), so an expense can record who paid it.
          if (from < 8) {
            await m.createTable(people);
            await m.addColumn(costs, costs.paidBy);
          }
          // v9 added trip participants: a many-to-many linking people to trips.
          if (from < 9) {
            await m.createTable(tripParticipants);
          }
          // v10 added cost beneficiaries: the people a cost was paid *for*.
          if (from < 10) {
            await m.createTable(costBeneficiaries);
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
