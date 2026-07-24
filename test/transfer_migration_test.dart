import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';

/// Verifies the v21 -> v22 migration that added `costs.is_transfer`, marking a
/// row as money handed from one person to another instead of money spent. Real
/// user databases are migrated in place: every expense already recorded must
/// come through unchanged, and reading as an expense.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tp_transfer_migration');
    path = p.join(tempDir.path, 'v21.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Builds a database file at [path] with the v21 schema — costs without the
  /// transfer flag — holding a trip with one expense.
  void seedV21Database() {
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
        created_at INTEGER NOT NULL DEFAULT 0
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
        name TEXT,
        builtin_key TEXT,
        icon_id INTEGER,
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
        notes TEXT,
        location TEXT,
        mode INTEGER REFERENCES transport_modes (id),
        from_location TEXT,
        to_location TEXT
      );
      CREATE TABLE costs (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER REFERENCES itinerary_items (id),
        group_id INTEGER REFERENCES item_groups (id),
        trip_id INTEGER REFERENCES trips (id),
        amount_minor INTEGER NOT NULL,
        currency INTEGER NOT NULL,
        reason TEXT NOT NULL,
        paid_by TEXT,
        paid INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE people (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        is_me INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE cost_beneficiaries (
        cost_id INTEGER NOT NULL REFERENCES costs (id),
        person_id INTEGER NOT NULL REFERENCES people (id),
        PRIMARY KEY (cost_id, person_id)
      );
      INSERT INTO trips (id, title) VALUES (1, 'Lisbon');
      INSERT INTO costs (id, trip_id, amount_minor, currency, reason, paid_by)
        VALUES (1, 1, 6000, 0, 'Dinner', 'Ann');
    ''');
    raw.execute('PRAGMA user_version = 21');
    raw.close();
  }

  test('v21 -> v22 leaves every recorded cost an expense', () async {
    seedV21Database();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    final costs = await db.costDao.watchCostsForTrip(1).first;
    expect(costs.single.reason, 'Dinner');
    expect(costs.single.amountMinor, 6000);
    expect(costs.single.paidBy, 'Ann');
    expect(costs.single.isTransfer, isFalse);

    // The trip's total is unchanged by the new column.
    final totals = await db.costDao.watchTotalsByTrip().first;
    expect(totals[1], {Currency.eur: 6000});

    // And the migrated schema really does take a settlement, which the total
    // then leaves alone.
    await db.costDao.addCost(
      CostsCompanion.insert(
        tripId: const Value(1),
        amountMinor: 3000,
        currency: Currency.eur,
        reason: '',
        paidBy: const Value('Bo'),
        isTransfer: const Value(true),
      ),
    );
    expect((await db.costDao.watchTotalsByTrip().first)[1], {
      Currency.eur: 6000,
    });
  });
}
