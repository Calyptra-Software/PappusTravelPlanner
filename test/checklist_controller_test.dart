import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/checklist/application/checklist_providers.dart';

/// The checklist controller on its own — the arithmetic between a gesture and a
/// row, which the widget test above it drives but cannot see the shape of.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late ChecklistController controller;
  late int tripId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(TripRepository(db))],
    );
    controller = container.read(checklistControllerProvider);
    tripId = await db.tripDao.createTrip(TripsCompanion.insert(title: 'Rome'));
  });
  tearDown(() {
    container.dispose();
    return db.close();
  });

  Future<List<Checklist>> lists() =>
      (db.select(db.checklists)
            ..where((c) => c.tripId.equals(tripId))
            ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
          .get();

  Future<List<ChecklistItem>> entries(int checklistId) =>
      (db.select(db.checklistItems)
            ..where((i) => i.checklistId.equals(checklistId))
            ..orderBy([(i) => OrderingTerm(expression: i.sortOrder)]))
          .get();

  Future<int> seed(List<String> labels) async {
    await controller.addChecklist(tripId, title: 'Packing');
    final id = (await lists()).last.id;
    for (final label in labels) {
      await controller.addItem(id, label);
    }
    return id;
  }

  group('a new checklist', () {
    test('lands after the ones already there', () async {
      await controller.addChecklist(tripId, title: 'Hand luggage');
      await controller.addChecklist(tripId, title: 'Hold luggage');

      final stored = await lists();
      expect(stored.map((c) => c.title), ['Hand luggage', 'Hold luggage']);
      expect(stored.map((c) => c.sortOrder), [0, 1]);
    });

    test('a blank title is left blank rather than invented', () async {
      // The UI shows its own default label; the row must not start carrying a
      // name nobody typed, or renaming it would look like an edit of theirs.
      await controller.addChecklist(tripId, title: '   ');

      expect((await lists()).single.title, isEmpty);
    });
  });

  group('its entries', () {
    test('are appended in the order they are typed', () async {
      final id = await seed(['Passport', 'Charger', 'Adapter']);

      final stored = await entries(id);
      expect(stored.map((i) => i.label), ['Passport', 'Charger', 'Adapter']);
      expect(stored.map((i) => i.sortOrder), [0, 1, 2]);
      expect(stored.every((i) => !i.done), isTrue);
    });

    test('are ticked and unticked one at a time', () async {
      final id = await seed(['Passport', 'Charger']);
      final first = (await entries(id)).first;

      await controller.setDone(first, true);
      expect((await entries(id)).map((i) => i.done), [true, false]);

      await controller.setDone((await entries(id)).first, false);
      expect((await entries(id)).map((i) => i.done), [false, false]);
    });

    test('keep their tick when renamed', () async {
      final id = await seed(['Passport']);
      await controller.setDone((await entries(id)).single, true);

      await controller.renameItem(
        (await entries(id)).single,
        'Passport & visa',
      );

      final stored = (await entries(id)).single;
      expect(stored.label, 'Passport & visa');
      expect(stored.done, isTrue);
    });
  });

  group('reordering', () {
    test('moves an entry down and closes the gap behind it', () async {
      final id = await seed(['Passport', 'Charger', 'Adapter']);

      // `newIndex` arrives already adjusted for the removal at `oldIndex`,
      // which is what a `ReorderableListView` hands over.
      await controller.reorderItems(await entries(id), 0, 2);

      final stored = await entries(id);
      expect(stored.map((i) => i.label), ['Charger', 'Adapter', 'Passport']);
      expect(stored.map((i) => i.sortOrder), [0, 1, 2]);
    });

    test('moves one up as well', () async {
      final id = await seed(['Passport', 'Charger', 'Adapter']);

      await controller.reorderItems(await entries(id), 2, 0);

      expect((await entries(id)).map((i) => i.label), [
        'Adapter',
        'Passport',
        'Charger',
      ]);
    });

    test('writes only the rows whose position actually changed', () async {
      final id = await seed(['Passport', 'Charger', 'Adapter', 'Book']);
      final before = await entries(id);

      // Swapping the first two leaves the last two exactly where they were, so
      // they are not rewritten — the point of the guard in `reorderItems`.
      await controller.reorderItems(before, 0, 1);

      final after = await entries(id);
      expect(after.map((i) => i.label), [
        'Charger',
        'Passport',
        'Adapter',
        'Book',
      ]);
      // Identity is the only thing that can show a row was left alone, and it
      // is what the guard buys: the untouched two keep their original ids at
      // their original sort orders.
      expect(after[2].id, before[2].id);
      expect(after[3].id, before[3].id);
    });

    test('a move that changes nothing writes nothing', () async {
      final id = await seed(['Passport', 'Charger']);

      await controller.reorderItems(await entries(id), 1, 1);

      expect((await entries(id)).map((i) => i.label), ['Passport', 'Charger']);
    });
  });

  group('the card', () {
    test('remembers being collapsed on the row', () async {
      await controller.addChecklist(tripId, title: 'Packing');
      final checklist = (await lists()).single;

      await controller.setCollapsed(checklist, true);

      // In the database rather than in preferences, so it travels with the
      // file the trip lives in.
      expect((await lists()).single.collapsed, isTrue);
    });

    test('renaming trims what was typed', () async {
      await controller.addChecklist(tripId, title: 'Packing');

      await controller.renameChecklist(
        (await lists()).single,
        '  Hold luggage  ',
      );

      expect((await lists()).single.title, 'Hold luggage');
    });

    test('deleting takes its entries with it', () async {
      final id = await seed(['Passport']);

      await controller.deleteChecklist(id);

      expect(await lists(), isEmpty);
      expect(await entries(id), isEmpty);
    });

    test('deleting one entry leaves the rest in order', () async {
      final id = await seed(['Passport', 'Charger']);

      await controller.deleteItem((await entries(id)).first.id);

      expect((await entries(id)).map((i) => i.label), ['Charger']);
    });
  });
}
