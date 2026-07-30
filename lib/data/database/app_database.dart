import 'package:drift/drift.dart';

import '../../core/database/database_location.dart';
import 'daos/alternative_dao.dart';
import 'daos/checklist_dao.dart';
import 'daos/cost_dao.dart';
import 'daos/currency_dao.dart';
import 'daos/group_dao.dart';
import 'daos/itinerary_dao.dart';
import 'daos/sharing_dao.dart';
import 'daos/transport_mode_dao.dart';
import 'daos/trip_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Marks a file as a Travel Planner database. SQLite keeps this 32-bit value in
/// the file header (bytes 68-71), so the file says what it is without anything
/// having to open a table — `file(1)`, a backup tool, or a later validation
/// check can tell one of our databases from any other `.sqlite` a picker
/// happened to hand back. The value is ASCII `TRPL`.
const int kApplicationId = 0x5452504C;

@DriftDatabase(
  tables: [
    Trips,
    ItemGroups,
    AlternativeSets,
    Alternatives,
    ItineraryItems,
    Costs,
    CostReasons,
    Currencies,
    TransportModes,
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
    TransportModeDao,
    CurrencyDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens (or creates) the database file at [path].
  AppDatabase.atPath(String path) : super(openExecutor(path));

  /// Constructs a database over a caller-provided executor. Used by tests to
  /// run against an in-memory database.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 26;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // A fresh database starts with the built-in transport modes so a leg has
      // something to pick from; the user manages the list from there. Same for
      // the currencies an expense can be recorded in.
      await transportModeDao.seedBuiltinModes();
      await currencyDao.seedBuiltinCurrencies();
    },
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
            'ALTER TABLE trips ADD COLUMN checklist_title TEXT',
          );
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
          'ALTER TABLE checklist_items RENAME TO _checklist_items_old',
        );
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
      // v19 added the actual start/end times of an itinerary entry beside
      // the planned ones it already had. Nothing to backfill: an existing
      // entry has a plan and no record of how it really went.
      if (from < 19) {
        await m.addColumn(itineraryItems, itineraryItems.actualStartMinutes);
        await m.addColumn(itineraryItems, itineraryItems.actualEndMinutes);
      }
      // v20 turned the fixed TransportMode enum into a user-managed table:
      // built-ins are now seeded rows the user can extend, rename, re-icon,
      // reorder or delete. Create and seed the table (the built-ins go in in
      // enum order, so each gets id = its old enum index + 1), then repoint
      // every leg's `mode` from that old index onto its new row and recreate
      // the table so its foreign key to transport_modes takes effect.
      if (from < 20) {
        await _seedTransportModesAndRepointLegs(m);
      }
      // v21 self-heals a database that reached v20 without the transport-modes
      // table — an intermediate build bumped the version before the migration
      // above shipped, so `onUpgrade` never ran it and the table is missing
      // (every leg then reads as "Other"). If the table is absent, run the v20
      // steps now; if it's already there, v20 did its job and this is a no-op.
      if (from < 21) {
        final hasTable = (await customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' "
          "AND name = 'transport_modes'",
        ).get()).isNotEmpty;
        if (!hasTable) {
          await _seedTransportModesAndRepointLegs(m);
        }
      }
      // v22 added costs.is_transfer, marking a row as money handed from one
      // person to another instead of money spent. Nothing to backfill: every
      // existing row is an expense.
      if (from < 22) {
        await m.addColumn(costs, costs.isTransfer);
      }
      // v23 turned the fixed Currency enum into a user-managed table, the way
      // v20 did for transport modes: the built-ins are now seeded rows the user
      // can extend, re-code, reorder or delete, one of them is the base, and the
      // others carry an exchange rate against it. Create and seed the table (the
      // built-ins go in in enum order, so each gets id = its old enum index + 1),
      // then repoint every cost's `currency` from that old index onto its new
      // row and recreate the table so its foreign key to `currencies` takes
      // effect.
      if (from < 23) {
        await m.createTable(currencies);
        await currencyDao.seedBuiltinCurrencies();
        await m.alterTable(
          TableMigration(
            costs,
            columnTransformer: {
              costs.currency: costs.currency + const Constant(1),
            },
          ),
        );
      }
      // v24 prepares the itinerary for the connection-search feature: a flag
      // marking an entry whose end falls on the day after its date (an overnight
      // leg — a night train arriving next morning), and the coordinates of a
      // transport leg's endpoints (stored for a future map). All nullable/
      // defaulted, so there is nothing to backfill on existing rows.
      //
      // Add each only if it isn't already there: a database coming from below v20
      // is recreated by `_seedTransportModesAndRepointLegs` above, whose
      // TableMigration builds the table from the *current* schema and so already
      // carries these columns (listed in its `newColumns`). Adding them a second
      // time would fail. Coming from v20-v23 the recreation didn't run and the
      // columns are genuinely missing, so they are added here.
      if (from < 24) {
        await _addItineraryColumnsIfMissing(m, [
          itineraryItems.spansNextDay,
          itineraryItems.fromLat,
          itineraryItems.fromLon,
          itineraryItems.toLat,
          itineraryItems.toLon,
        ]);
      }
      // v25 keeps the routing provider's trip id on an imported leg, so the
      // live-times refresh can re-query it. Nullable, nothing to backfill; added
      // only when a recreation above hasn't already (as v24).
      if (from < 25) {
        await _addItineraryColumnsIfMissing(m, [itineraryItems.sourceTripId]);
      }
      // v26 keeps an imported leg's intermediate stops, so the journey it came
      // from can be read back — with the times it calls at each stop — offline
      // and long after the search that found it. Nullable, nothing to backfill:
      // legs imported before this simply have none.
      if (from < 26) {
        await _addItineraryColumnsIfMissing(m, [itineraryItems.stopovers]);
      }
    },
    beforeOpen: (details) async {
      // Enforce ON DELETE CASCADE for itinerary items and costs.
      await customStatement('PRAGMA foreign_keys = ON');
      await _stampApplicationId();
    },
  );

  /// Writes [kApplicationId] into the file header unless something already
  /// claimed it.
  ///
  /// This runs on every open rather than from a migration branch because the
  /// header is not part of the schema: every database already at the current
  /// [schemaVersion] — which is every existing user's — would never reach an
  /// `onUpgrade` branch, and bumping the version for a 4-byte header field
  /// would mean shipping an otherwise empty migration. A file that carries
  /// *another* application's id is left untouched: that id is the one piece of
  /// evidence it isn't ours, and overwriting it would destroy it.
  Future<void> _stampApplicationId() async {
    final row = await customSelect('PRAGMA application_id').getSingleOrNull();
    if (row == null || row.read<int>('application_id') != 0) return;
    // Pragma values can't be bound as parameters; the id is a compile-time
    // constant, so interpolating it is safe.
    await customStatement('PRAGMA application_id = $kApplicationId');
  }

  /// The v20 transport-modes setup, shared by the v20 branch and the v21
  /// self-heal: create and seed the table (built-ins go in in enum order, so
  /// each gets id = its old enum index + 1), then repoint every leg's `mode`
  /// from that old index onto its new row and recreate the table so its foreign
  /// key to `transport_modes` takes effect.
  /// Adds each of [columns] to itinerary_items unless it is already there.
  /// A database coming from below v20 is recreated by the transport-modes
  /// migration, whose TableMigration builds the table from the *current* schema
  /// and so already carries later columns (listed in its `newColumns`); adding
  /// one a second time would fail, while a database from v20 onward is missing
  /// them and needs them added.
  Future<void> _addItineraryColumnsIfMissing(
    Migrator m,
    List<GeneratedColumn> columns,
  ) async {
    final existing = (await customSelect(
      'PRAGMA table_info(itinerary_items)',
    ).get()).map((r) => r.read<String>('name')).toSet();
    for (final column in columns) {
      if (!existing.contains(column.name)) {
        await m.addColumn(itineraryItems, column);
      }
    }
  }

  Future<void> _seedTransportModesAndRepointLegs(Migrator m) async {
    await m.createTable(transportModes);
    await transportModeDao.seedBuiltinModes();
    await m.alterTable(
      TableMigration(
        itineraryItems,
        columnTransformer: {
          itineraryItems.mode: itineraryItems.mode + const Constant(1),
        },
        // This recreates itinerary_items from the *current* schema, so any
        // column added to the table *after* v20 must be declared new here —
        // otherwise the copy step selects a column the old table lacks. The v24,
        // v25 and v26 additions; extend this list when a later version adds more.
        newColumns: [
          itineraryItems.spansNextDay,
          itineraryItems.fromLat,
          itineraryItems.fromLon,
          itineraryItems.toLat,
          itineraryItems.toLon,
          itineraryItems.sourceTripId,
          itineraryItems.stopovers,
        ],
      ),
    );
  }

  /// Flushes the write-ahead log into the main database file so it is complete
  /// and safe to copy/export as a single file.
  Future<void> checkpoint() =>
      customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
}
