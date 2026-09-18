import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:travelplanner/data/database/app_database.dart';

import 'currency_fixture.dart';

/// Verifies the v37 -> v38 migration that added `cost_beneficiaries.invited`,
/// marking a beneficiary the payer invited. Every split already recorded was
/// one to be repaid, so it must come through still owing what it owed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tp_invited');
    path = p.join(tempDir.path, 'v37.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Builds a v37 database at [path]: the current schema less the column, with
  /// the version stamped back — written through the app, for the reason
  /// `reimbursement_migration_test.dart` gives.
  Future<int> seedV37Database() async {
    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    final tripId = await db
        .into(db.trips)
        .insert(TripsCompanion.insert(title: 'Hamburg'));
    final costId = await db.costDao.addCost(
      CostsCompanion.insert(
        tripId: Value(tripId),
        amountMinor: 6000,
        currency: eurId,
        reason: 'Food',
        paidBy: const Value('Ann'),
      ),
    );
    await db.costDao.setBeneficiaries(costId, ['Ann', 'Bo']);
    await db.close();

    final raw = sqlite3.open(path);
    raw.execute('ALTER TABLE cost_beneficiaries DROP COLUMN invited');
    raw.execute('PRAGMA user_version = 37');
    raw.close();
    return costId;
  }

  test('v37 -> v38 keeps every split one to be repaid', () async {
    final costId = await seedV37Database();

    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    final beneficiaries = await db.costDao.watchBeneficiaries(costId).first;
    expect(beneficiaries.map((p) => p.name), ['Ann', 'Bo']);
    expect(await db.costDao.watchInvited(costId).first, isEmpty);

    // And the migrated schema really takes the flag.
    await db.costDao.setBeneficiaries(costId, ['Ann', 'Bo'], invited: {'Bo'});
    expect(await db.costDao.watchInvited(costId).first, {'Bo'});
  });
}
