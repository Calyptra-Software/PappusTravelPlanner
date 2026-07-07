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

  Future<int> makeChecklist(int tripId, {String title = ''}) =>
      db.checklistDao.addChecklist(
        ChecklistsCompanion.insert(tripId: tripId, title: Value(title)),
      );

  test('a trip can hold several named checklists, in order', () async {
    final tripId = await makeTrip();

    final o1 = await db.checklistDao.nextChecklistSortOrder(tripId);
    await makeChecklist(tripId, title: 'Packing');
    final o2 = await db.checklistDao.nextChecklistSortOrder(tripId);
    await db.checklistDao.addChecklist(ChecklistsCompanion.insert(
      tripId: tripId,
      title: const Value('To-do'),
      sortOrder: Value(o2),
    ));

    expect(o1, 0);
    expect(o2, 1);
    final lists = await db.checklistDao.watchChecklists(tripId).first;
    expect(lists.map((c) => c.title), ['Packing', 'To-do']);
  });

  test('items belong to a checklist and append via nextItemSortOrder',
      () async {
    final tripId = await makeTrip();
    final listId = await makeChecklist(tripId, title: 'Packing');

    final o1 = await db.checklistDao.nextItemSortOrder(listId);
    await db.checklistDao.addItem(
      ChecklistItemsCompanion.insert(
        checklistId: listId,
        label: 'Passport',
        sortOrder: Value(o1),
      ),
    );
    final o2 = await db.checklistDao.nextItemSortOrder(listId);
    await db.checklistDao.addItem(
      ChecklistItemsCompanion.insert(
        checklistId: listId,
        label: 'Sunscreen',
        sortOrder: Value(o2),
      ),
    );

    expect([o1, o2], [0, 1]);
    final items = await db.checklistDao.watchItems(listId).first;
    expect(items.map((i) => i.label), ['Passport', 'Sunscreen']);
    expect(items.every((i) => !i.done), isTrue);
  });

  test('items are scoped to their own checklist', () async {
    final tripId = await makeTrip();
    final a = await makeChecklist(tripId, title: 'A');
    final b = await makeChecklist(tripId, title: 'B');
    await db.checklistDao
        .addItem(ChecklistItemsCompanion.insert(checklistId: a, label: 'x'));

    expect((await db.checklistDao.watchItems(a).first).length, 1);
    expect((await db.checklistDao.watchItems(b).first), isEmpty);
  });

  test('renaming a checklist and toggling an item persist', () async {
    final tripId = await makeTrip();
    final listId = await makeChecklist(tripId, title: 'Old');

    final list = (await db.checklistDao.watchChecklists(tripId).first).single;
    await db.checklistDao.updateChecklist(list.copyWith(title: 'New'));
    expect(
      (await db.checklistDao.watchChecklists(tripId).first).single.title,
      'New',
    );

    final id = await db.checklistDao.addItem(
      ChecklistItemsCompanion.insert(checklistId: listId, label: 'Book hotel'),
    );
    final item = (await db.checklistDao.watchItems(listId).first).single;
    await db.checklistDao.updateItem(item.copyWith(done: true));
    expect((await db.checklistDao.watchItems(listId).first).single.done, isTrue);

    await db.checklistDao.deleteItem(id);
    expect(await db.checklistDao.watchItems(listId).first, isEmpty);
  });

  test('deleting a checklist cascades to its items', () async {
    final tripId = await makeTrip();
    final listId = await makeChecklist(tripId, title: 'Packing');
    await db.checklistDao
        .addItem(ChecklistItemsCompanion.insert(checklistId: listId, label: 'x'));

    await db.checklistDao.deleteChecklist(listId);

    expect(await db.checklistDao.watchItems(listId).first, isEmpty);
    expect(await db.checklistDao.watchChecklists(tripId).first, isEmpty);
  });

  test('deleting the trip cascades to checklists and their items', () async {
    final tripId = await makeTrip();
    final listId = await makeChecklist(tripId, title: 'Packing');
    await db.checklistDao.addItem(
      ChecklistItemsCompanion.insert(checklistId: listId, label: 'Charger'),
    );

    await db.tripDao.deleteTrip(tripId);

    expect(await db.checklistDao.watchChecklists(tripId).first, isEmpty);
    expect(await db.checklistDao.watchItems(listId).first, isEmpty);
  });
}
