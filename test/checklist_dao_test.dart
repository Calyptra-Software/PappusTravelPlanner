import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> makeTrip() =>
      db.tripDao.createTrip(TripsCompanion.insert(title: 'T'));

  test('adds items and appends them via nextSortOrder', () async {
    final tripId = await makeTrip();

    final o1 = await db.checklistDao.nextSortOrder(tripId);
    await db.checklistDao.addChecklistItem(
      ChecklistItemsCompanion.insert(
        tripId: tripId,
        label: 'Passport',
        sortOrder: Value(o1),
      ),
    );
    final o2 = await db.checklistDao.nextSortOrder(tripId);
    await db.checklistDao.addChecklistItem(
      ChecklistItemsCompanion.insert(
        tripId: tripId,
        label: 'Sunscreen',
        sortOrder: Value(o2),
      ),
    );

    expect(o1, 0);
    expect(o2, 1);
    final items = await db.checklistDao.watchChecklist(tripId).first;
    expect(items.map((i) => i.label), ['Passport', 'Sunscreen']);
    expect(items.every((i) => !i.done), isTrue);
  });

  test('toggling done and deleting is reflected in the stream', () async {
    final tripId = await makeTrip();
    final id = await db.checklistDao.addChecklistItem(
      ChecklistItemsCompanion.insert(tripId: tripId, label: 'Book hotel'),
    );

    var items = await db.checklistDao.watchChecklist(tripId).first;
    await db.checklistDao.updateChecklistItem(
      items.single.copyWith(done: true),
    );
    items = await db.checklistDao.watchChecklist(tripId).first;
    expect(items.single.done, isTrue);

    await db.checklistDao.deleteChecklistItem(id);
    items = await db.checklistDao.watchChecklist(tripId).first;
    expect(items, isEmpty);
  });

  test('setChecklistTitle stores and clears a custom heading', () async {
    final tripId = await makeTrip();

    await db.tripDao.setChecklistTitle(tripId, 'Packing list');
    expect((await db.tripDao.findTrip(tripId))!.checklistTitle, 'Packing list');

    await db.tripDao.setChecklistTitle(tripId, null);
    expect((await db.tripDao.findTrip(tripId))!.checklistTitle, null);
  });

  test('deleting the trip cascades to its checklist', () async {
    final tripId = await makeTrip();
    await db.checklistDao.addChecklistItem(
      ChecklistItemsCompanion.insert(tripId: tripId, label: 'Charger'),
    );

    await db.tripDao.deleteTrip(tripId);

    final items = await db.checklistDao.watchChecklist(tripId).first;
    expect(items, isEmpty);
  });
}
