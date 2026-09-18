import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:travelplanner/data/database/app_database.dart';

import 'currency_fixture.dart';

/// Verifies the v36 -> v37 migration that added `costs.is_reimbursement`,
/// marking a settlement as money from outside the group. Every settlement
/// already recorded was booked as one between travelers, so it must come
/// through still moving the balances it moved before.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tp_reimbursement');
    path = p.join(tempDir.path, 'v36.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Builds a v36 database at [path]: the current schema less the column, with
  /// the version stamped back. Written through the app rather than by hand
  /// because the column is the only difference, and a hand-written copy of
  /// thirty tables would be the thing most likely to be wrong here.
  Future<void> seedV36Database() async {
    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    final tripId = await db
        .into(db.trips)
        .insert(TripsCompanion.insert(title: 'Hamburg'));
    await db.costDao.addCost(
      CostsCompanion.insert(
        tripId: Value(tripId),
        amountMinor: 2000,
        currency: eurId,
        reason: '',
        paidBy: const Value('Bo'),
        paid: const Value(true),
        isTransfer: const Value(true),
      ),
    );
    await db.close();

    final raw = sqlite3.open(path);
    raw.execute('ALTER TABLE costs DROP COLUMN is_reimbursement');
    // And everything a later version added, so the file is a v36 one.
    raw.execute('ALTER TABLE cost_beneficiaries DROP COLUMN invited');
    raw.execute('PRAGMA user_version = 36');
    raw.close();
  }

  test('v36 -> v37 keeps every settlement one between travelers', () async {
    await seedV36Database();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    final costs = await db.select(db.costs).get();
    expect(costs.single.isTransfer, isTrue);
    expect(costs.single.isReimbursement, isFalse);

    // And the migrated schema really takes the flag.
    await db.costDao.updateCost(costs.single.copyWith(isReimbursement: true));
    final updated = await db.select(db.costs).getSingle();
    expect(updated.isReimbursement, isTrue);
  });
}
