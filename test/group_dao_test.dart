import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> makeTrip() =>
      db.tripDao.createTrip(TripsCompanion.insert(title: 'T'));

  Future<int> makeItem(int tripId, {int sortOrder = 0}) =>
      db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: DateTime(2026, 7, 5),
          kind: ItemKind.transport,
          sortOrder: Value(sortOrder),
          mode: const Value(6), // seeded 'train' mode (enum index 5 + 1)
        ),
      );

  Future<ItineraryItem?> readItem(int id) => (db.select(
    db.itineraryItems,
  )..where((i) => i.id.equals(id))).getSingleOrNull();

  test('groupItems creates a group holding both items', () async {
    final tripId = await makeTrip();
    final a = await makeItem(tripId, sortOrder: 0);
    final b = await makeItem(tripId, sortOrder: 1);

    final groupId = await db.groupDao.groupItems(a, b);

    expect((await readItem(a))!.groupId, groupId);
    expect((await readItem(b))!.groupId, groupId);
    final groups = await db.groupDao.watchGroupsForTrip(tripId).first;
    expect(groups.keys, [groupId]);
  });

  test(
    'groupItems extends an existing group when only one item is grouped',
    () async {
      final tripId = await makeTrip();
      final a = await makeItem(tripId, sortOrder: 0);
      final b = await makeItem(tripId, sortOrder: 1);
      final c = await makeItem(tripId, sortOrder: 2);

      final groupId = await db.groupDao.groupItems(a, b);
      final same = await db.groupDao.groupItems(b, c);

      expect(same, groupId);
      expect((await readItem(c))!.groupId, groupId);
    },
  );

  test(
    'groupItems merges two groups and re-points the second group costs',
    () async {
      final tripId = await makeTrip();
      final a = await makeItem(tripId, sortOrder: 0);
      final b = await makeItem(tripId, sortOrder: 1);
      final c = await makeItem(tripId, sortOrder: 2);
      final d = await makeItem(tripId, sortOrder: 3);

      final g1 = await db.groupDao.groupItems(a, b);
      final g2 = await db.groupDao.groupItems(c, d);
      await db.costDao.addCost(
        CostsCompanion.insert(
          groupId: Value(g2),
          amountMinor: 5000,
          currency: Currency.eur,
          reason: 'Ticket',
        ),
      );

      final merged = await db.groupDao.groupItems(b, c);

      expect(merged, g1);
      // All four items now share g1; g2 is gone.
      for (final id in [a, b, c, d]) {
        expect((await readItem(id))!.groupId, g1);
      }
      final groups = await db.groupDao.watchGroupsForTrip(tripId).first;
      expect(groups.keys, [g1]);
      // The cost followed the merge onto g1.
      final costs = await db.costDao.watchCostsForTrip(tripId).first;
      expect(costs.single.groupId, g1);
    },
  );

  test('removeFromGroup auto-dissolves a group left with one member, '
      'preserving its costs on that member', () async {
    final tripId = await makeTrip();
    final a = await makeItem(tripId, sortOrder: 0);
    final b = await makeItem(tripId, sortOrder: 1);
    final groupId = await db.groupDao.groupItems(a, b);
    await db.costDao.addCost(
      CostsCompanion.insert(
        groupId: Value(groupId),
        amountMinor: 5000,
        currency: Currency.eur,
        reason: 'Ticket',
      ),
    );

    await db.groupDao.removeFromGroup(b);

    // b is freed; a is freed too because a lone group is dissolved.
    expect((await readItem(b))!.groupId, isNull);
    expect((await readItem(a))!.groupId, isNull);
    expect((await db.groupDao.watchGroupsForTrip(tripId).first), isEmpty);
    // The shared cost survived, re-pointed onto the first member (a).
    final costs = await db.costDao.watchCostsForTrip(tripId).first;
    expect(costs.single.groupId, isNull);
    expect(costs.single.itemId, a);
  });

  test(
    'dissolveGroup frees all members and preserves costs on the first',
    () async {
      final tripId = await makeTrip();
      final a = await makeItem(tripId, sortOrder: 0);
      final b = await makeItem(tripId, sortOrder: 1);
      final c = await makeItem(tripId, sortOrder: 2);
      final groupId = await db.groupDao.groupItems(a, b);
      await db.groupDao.groupItems(b, c);
      await db.costDao.addCost(
        CostsCompanion.insert(
          groupId: Value(groupId),
          amountMinor: 5000,
          currency: Currency.eur,
          reason: 'Ticket',
        ),
      );

      await db.groupDao.dissolveGroup(groupId);

      for (final id in [a, b, c]) {
        expect((await readItem(id))!.groupId, isNull);
      }
      expect(await db.groupDao.watchGroupsForTrip(tripId).first, isEmpty);
      final costs = await db.costDao.watchCostsForTrip(tripId).first;
      expect(costs.single.itemId, a);
    },
  );

  test('deleting the trip cascades to its groups', () async {
    final tripId = await makeTrip();
    final a = await makeItem(tripId, sortOrder: 0);
    final b = await makeItem(tripId, sortOrder: 1);
    await db.groupDao.groupItems(a, b);

    await db.tripDao.deleteTrip(tripId);

    expect(await db.groupDao.watchGroupsForTrip(tripId).first, isEmpty);
  });

  test(
    'deleteItem dissolves a 2-member group, preserving cost on the survivor',
    () async {
      final tripId = await makeTrip();
      final a = await makeItem(tripId, sortOrder: 0);
      final b = await makeItem(tripId, sortOrder: 1);
      final groupId = await db.groupDao.groupItems(a, b);
      await db.costDao.addCost(
        CostsCompanion.insert(
          groupId: Value(groupId),
          amountMinor: 5000,
          currency: Currency.eur,
          reason: 'Ticket',
        ),
      );

      await db.groupDao.deleteItem(b);

      expect(await readItem(b), isNull);
      expect((await readItem(a))!.groupId, isNull);
      expect(await db.groupDao.watchGroupsForTrip(tripId).first, isEmpty);
      // The shared cost survived on the remaining item — not stranded on a group.
      final costs = await db.costDao.watchCostsForTrip(tripId).first;
      expect(costs.single.itemId, a);
      expect(costs.single.groupId, isNull);
    },
  );

  test('deleting the last member leaves no orphan group or cost', () async {
    final tripId = await makeTrip();
    final a = await makeItem(tripId, sortOrder: 0);
    final b = await makeItem(tripId, sortOrder: 1);
    final groupId = await db.groupDao.groupItems(a, b);
    await db.costDao.addCost(
      CostsCompanion.insert(
        groupId: Value(groupId),
        amountMinor: 5000,
        currency: Currency.eur,
        reason: 'Ticket',
      ),
    );

    await db.groupDao.deleteItem(b);
    await db.groupDao.deleteItem(a);

    // No group and no phantom cost left counting toward the trip total.
    expect(await db.groupDao.watchGroupsForTrip(tripId).first, isEmpty);
    expect(await db.costDao.watchCostsForTrip(tripId).first, isEmpty);
  });

  test('setGroupLabel stores a trimmed label and clears on empty', () async {
    final tripId = await makeTrip();
    final a = await makeItem(tripId, sortOrder: 0);
    final b = await makeItem(tripId, sortOrder: 1);
    final groupId = await db.groupDao.groupItems(a, b);

    await db.groupDao.setGroupLabel(groupId, '  Train to Rome  ');
    var groups = await db.groupDao.watchGroupsForTrip(tripId).first;
    expect(groups[groupId]!.label, 'Train to Rome');

    await db.groupDao.setGroupLabel(groupId, '   ');
    groups = await db.groupDao.watchGroupsForTrip(tripId).first;
    expect(groups[groupId]!.label, isNull);
  });
}
