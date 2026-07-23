import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';

/// Covers carrying a checklist between trips: moving one written down on the
/// wrong trip, and copying last trip's list into the next one — the reason the
/// feature exists, and the reason the copy arrives unticked.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> makeTrip(String title) =>
      db.tripDao.createTrip(TripsCompanion.insert(title: title));

  Future<int> makeChecklist(int tripId, String title, {int sortOrder = 0}) =>
      db.checklistDao.addChecklist(
        ChecklistsCompanion.insert(
          tripId: tripId,
          title: Value(title),
          sortOrder: Value(sortOrder),
        ),
      );

  Future<void> addEntry(
    int checklistId,
    String label, {
    bool done = false,
    int sortOrder = 0,
  }) => db.checklistDao.addItem(
    ChecklistItemsCompanion.insert(
      checklistId: checklistId,
      label: label,
      done: Value(done),
      sortOrder: Value(sortOrder),
    ),
  );

  Future<List<Checklist>> listsOf(int tripId) =>
      db.checklistDao.watchChecklists(tripId).first;

  Future<List<ChecklistItem>> entriesOf(int checklistId) =>
      db.checklistDao.watchItems(checklistId).first;

  test('a checklist moves to another trip, ticks and all', () async {
    final rome = await makeTrip('Rome');
    final oslo = await makeTrip('Oslo');
    final packing = await makeChecklist(rome, 'Packing');
    await addEntry(packing, 'Passport', done: true, sortOrder: 0);
    await addEntry(packing, 'Charger', sortOrder: 1);

    await db.checklistDao.moveChecklist(packing, oslo);

    expect(await listsOf(rome), isEmpty);
    expect((await listsOf(oslo)).single.title, 'Packing');
    // The same list, relocated: what was already done stays done.
    final entries = await entriesOf(packing);
    expect(entries.map((e) => e.label), ['Passport', 'Charger']);
    expect(entries.first.done, isTrue);
  });

  test('a moved checklist lands after the target trip\'s own lists', () async {
    final rome = await makeTrip('Rome');
    final oslo = await makeTrip('Oslo');
    await makeChecklist(oslo, 'Documents', sortOrder: 0);
    final packing = await makeChecklist(rome, 'Packing');

    await db.checklistDao.moveChecklist(packing, oslo);

    expect((await listsOf(oslo)).map((c) => c.title), ['Documents', 'Packing']);
  });

  test('a copy carries the entries but none of the ticks', () async {
    final rome = await makeTrip('Rome');
    final oslo = await makeTrip('Oslo');
    final packing = await makeChecklist(rome, 'Packing');
    await addEntry(packing, 'Passport', done: true, sortOrder: 0);
    await addEntry(packing, 'Charger', done: true, sortOrder: 1);

    final copyId = await db.checklistDao.copyChecklist(packing, oslo);

    // The original is untouched — it is still last trip's finished list.
    expect((await entriesOf(packing)).every((e) => e.done), isTrue);
    // A packing list that arrives already ticked is no use for packing again.
    final copied = await entriesOf(copyId);
    expect(copied.map((e) => e.label), ['Passport', 'Charger']);
    expect(copied.any((e) => e.done), isFalse);
  });

  test('a copy keeps its name across trips', () async {
    final rome = await makeTrip('Rome');
    final oslo = await makeTrip('Oslo');
    final packing = await makeChecklist(rome, 'Packing');

    final copyId = await db.checklistDao.copyChecklist(packing, oslo);

    expect((await listsOf(rome)).single.title, 'Packing');
    expect((await listsOf(oslo)).single.title, 'Packing');
    expect((await listsOf(oslo)).single.id, copyId);
  });

  test('duplicating within a trip takes the given name', () async {
    final rome = await makeTrip('Rome');
    final packing = await makeChecklist(rome, 'Packing');
    await addEntry(packing, 'Passport');

    await db.checklistDao.copyChecklist(packing, rome, title: 'Packing (copy)');

    // Two lists side by side, told apart by name — the same name twice would be
    // a puzzle in a way it is not across two different trips.
    expect((await listsOf(rome)).map((c) => c.title), [
      'Packing',
      'Packing (copy)',
    ]);
  });

  test('deleting the source leaves a copy in the other trip alone', () async {
    final rome = await makeTrip('Rome');
    final oslo = await makeTrip('Oslo');
    final packing = await makeChecklist(rome, 'Packing');
    await addEntry(packing, 'Passport');
    final copyId = await db.checklistDao.copyChecklist(packing, oslo);

    await db.checklistDao.deleteChecklist(packing);

    // A copy is its own list, not a view of the original — nothing cascades.
    expect((await entriesOf(copyId)).single.label, 'Passport');
  });
}
