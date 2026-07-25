import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';

/// Verifies the v22 -> v23 migration that turned the fixed `Currency` enum into
/// a user-managed `currencies` table. Real user databases are migrated in place:
/// the built-ins must be seeded, and every existing expense must come through in
/// the same currency it was in — its old enum index (0..3) repointed onto the
/// seeded row for that currency (id = index + 1).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tp_currency_migr');
    path = p.join(tempDir.path, 'v22.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Builds a database file at [path] with the v22 schema — costs storing their
  /// currency as the `Currency` enum index — holding one trip with a EUR cost
  /// (index 0), a GBP cost (index 2) and a EUR settlement.
  void seedV22Database() {
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
        mode INTEGER,
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
        is_transfer INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT 0
      );
      INSERT INTO trips (id, title) VALUES (1, 'Highlands');
      INSERT INTO costs
        (id, trip_id, amount_minor, currency, reason, paid_by, is_transfer)
        VALUES
          (1, 1, 4990, 0, 'Hotel', 'Ada', 0),   -- EUR (index 0)
          (2, 1, 2500, 2, 'Train', 'Bo', 0),    -- GBP (index 2)
          (3, 1, 1000, 0, '', 'Bo', 1);         -- a EUR settlement
    ''');
    raw.execute('PRAGMA user_version = 22');
    raw.close();
  }

  test('v22 -> v23 seeds the currencies and repoints every cost', () async {
    seedV22Database();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    // The four built-ins are seeded, EUR the base and the only one with a rate.
    final currencies = await db.currencyDao.watchCurrencies().first;
    expect(currencies.map((c) => c.code), ['EUR', 'USD', 'GBP', 'CHF']);
    expect(currencies.where((c) => c.isBase).map((c) => c.code), ['EUR']);
    expect(currencies.first.rateMicros, kRateOne);

    // Each cost now points at the seeded row for the currency it was in.
    final byId = {for (final c in currencies) c.id: c};
    final costs = await db.costDao.watchCostsForTrip(1).first;
    final byCostId = {for (final c in costs) c.id: c};
    expect(byId[byCostId[1]!.currency]!.code, 'EUR');
    expect(byId[byCostId[2]!.currency]!.code, 'GBP');
    expect(byId[byCostId[3]!.currency]!.code, 'EUR');

    // Amounts and the settlement flag came through untouched.
    expect(byCostId[1]!.amountMinor, 4990);
    expect(byCostId[2]!.reason, 'Train');
    expect(byCostId[3]!.isTransfer, isTrue);

    // And the trip's totals now key by code.
    final totals = await db.costDao.watchTotalsByTrip().first;
    expect(totals[1], {'EUR': 4990, 'GBP': 2500});
  });
}
