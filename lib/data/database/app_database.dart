import 'package:drift/drift.dart';

import '../../core/database/database_location.dart';
import 'daos/alternative_dao.dart';
import 'daos/checklist_dao.dart';
import 'daos/cost_dao.dart';
import 'daos/group_dao.dart';
import 'daos/itinerary_dao.dart';
import 'daos/sharing_dao.dart';
import 'daos/trip_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Trips,
    ItemGroups,
    AlternativeSets,
    Alternatives,
    ItineraryItems,
    Costs,
    CostReasons,
    People,
    TripParticipants,
    CostBeneficiaries,
    Checklists,
    ChecklistItems,
    CollapsedDays,
  ],
  daos: [
    TripDao,
    ItineraryDao,
    CostDao,
    ChecklistDao,
    GroupDao,
    AlternativeDao,
    SharingDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens (or creates) the database file at [path].
  AppDatabase.atPath(String path) : super(openExecutor(path));

  /// Constructs a database over a caller-provided executor. Used by tests to
  /// run against an in-memory database.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 18;

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
          // v11 added people.is_me: marks which person the user is, for the
          // "my expenses" view. Only add it when the people table predates this
          // version; a from-scratch createTable above (from < 8) already
          // includes the column.
          if (from >= 8 && from < 11) {
            await m.addColumn(people, people.isMe);
          }
          // v12 added checklists.collapsed to persist each card's collapse
          // state. Only add it when the checklists table predates this version;
          // a from-scratch createTable above (from < 7) already includes it.
          if (from >= 7 && from < 12) {
            await m.addColumn(checklists, checklists.collapsed);
          }
          // v13 added a table recording which itinerary days are collapsed in
          // the trip overview.
          if (from < 13) {
            await m.createTable(collapsedDays);
          }
          // v14 added item groups: several adjacent itinerary items sharing one
          // expense (e.g. a train ticket). Create the group table first, then
          // the nullable foreign keys pointing at it on items and costs.
          if (from < 14) {
            await m.createTable(itemGroups);
            await m.addColumn(itineraryItems, itineraryItems.groupId);
            await m.addColumn(costs, costs.groupId);
          }
          // v15 cleans up orphaned groups: a group left with no members (e.g.
          // after deleting all its items in an earlier build that didn't tidy
          // the group) still carried its shared costs, which were counted in the
          // trip total but shown nowhere. Drop those costs, then the empty
          // groups. Foreign keys may be off during migration, so delete the
          // costs explicitly rather than relying on the cascade.
          if (from < 15) {
            await customStatement('''
              DELETE FROM costs WHERE group_id IS NOT NULL AND group_id IN (
                SELECT g.id FROM item_groups g
                WHERE NOT EXISTS (
                  SELECT 1 FROM itinerary_items i WHERE i.group_id = g.id))
            ''');
            await customStatement('''
              DELETE FROM item_groups WHERE NOT EXISTS (
                SELECT 1 FROM itinerary_items i WHERE i.group_id = item_groups.id)
            ''');
          }
          // v16 added a "paid" flag on costs marking an expense as already
          // settled.
          if (from < 16) {
            await m.addColumn(costs, costs.paid);
          }
          // v17 added alternatives: competing versions of one stretch of a day,
          // one of which is chosen. Create the two tables, then the nullable
          // foreign key on items pointing at a branch. Nothing to backfill —
          // every existing item stays loose (alternative_id NULL).
          if (from < 17) {
            await m.createTable(alternativeSets);
            await m.createTable(alternatives);
            await m.addColumn(itineraryItems, itineraryItems.alternativeId);
          }
          // v18 dropped alternative_sets.decided, a flag marking the chosen
          // branch as the one actually taken. It was redundant: the chosen branch
          // is already what the trip counts, so after the fact you just point it
          // at what happened. Only reachable from v17, which shipped the column.
          if (from == 17) {
            await m.alterTable(TableMigration(alternativeSets));
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
