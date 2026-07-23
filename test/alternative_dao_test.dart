import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';

/// Covers [AlternativeDao]: turning an item into a decision point, choosing a
/// branch, and the two invariants it maintains — exactly one chosen branch, and
/// never a set with fewer than two branches.
void main() {
  late AppDatabase db;

  final day = DateTime(2026, 7, 5);

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> makeTrip() =>
      db.tripDao.createTrip(TripsCompanion.insert(title: 'T'));

  Future<int> makeItem(
    int tripId, {
    required String title,
    int sortOrder = 0,
    int? alternativeId,
    DateTime? date,
  }) => db.itineraryDao.addItem(
    ItineraryItemsCompanion.insert(
      tripId: tripId,
      date: date ?? day,
      kind: ItemKind.place,
      title: Value(title),
      sortOrder: Value(sortOrder),
      alternativeId: Value(alternativeId),
    ),
  );

  Future<int> makeCost(int itemId, int amountMinor) => db.costDao.addCost(
    CostsCompanion.insert(
      itemId: Value(itemId),
      amountMinor: amountMinor,
      currency: Currency.eur,
      reason: 'Ticket',
    ),
  );

  Future<ItineraryItem?> readItem(int id) => (db.select(
    db.itineraryItems,
  )..where((i) => i.id.equals(id))).getSingleOrNull();

  /// The branches of the trip's only set, in swipe order.
  Future<List<Alternative>> branchesOf(int tripId, int setId) async =>
      (await db.alternativeDao.watchBranchesForTrip(tripId).first)[setId]!;

  /// The trip's loose items (those not inside a branch), in day order, by title.
  Future<List<String>> looseTitles(int tripId) async {
    final items = await db.itineraryDao.watchItemsForTrip(tripId).first;
    return [
      for (final i in items)
        if (i.alternativeId == null) i.title!,
    ];
  }

  test(
    'createSetFromItem moves the item into a chosen branch and adds an empty '
    'second one',
    () async {
      final tripId = await makeTrip();
      final museum = await makeItem(tripId, title: 'Museum');

      final setId = await db.alternativeDao.createSetFromItem(museum);

      final branches = await branchesOf(tripId, setId);
      expect(branches, hasLength(2));
      // The existing plan becomes the chosen branch, so nothing changes for the
      // user until they pick the new one.
      expect(branches.first.chosen, isTrue);
      expect(branches.last.chosen, isFalse);
      expect((await readItem(museum))!.alternativeId, branches.first.id);
      // The second branch starts empty, ready to be planned.
      final items = await db.itineraryDao.watchItemsForTrip(tripId).first;
      expect(items.where((i) => i.alternativeId == branches.last.id), isEmpty);
    },
  );

  test('createSetFromItem takes over the item\'s slot in the day', () async {
    final tripId = await makeTrip();
    await makeItem(tripId, title: 'Breakfast', sortOrder: 0);
    final museum = await makeItem(tripId, title: 'Museum', sortOrder: 1);
    await makeItem(tripId, title: 'Dinner', sortOrder: 2);

    final setId = await db.alternativeDao.createSetFromItem(museum);

    final set = (await db.alternativeDao
        .watchSetsForTrip(tripId)
        .first)[setId]!;
    expect(set.date, day);
    // The set sits where the item sat, so the day still reads breakfast -> set
    // -> dinner.
    expect(set.sortOrder, 1);
    // Inside the branch, the item's sortOrder now orders it among its siblings.
    expect((await readItem(museum))!.sortOrder, 0);
  });

  test('createSetFromItem takes the item\'s whole group along', () async {
    final tripId = await makeTrip();
    final a = await makeItem(tripId, title: 'Leg 1', sortOrder: 0);
    final b = await makeItem(tripId, title: 'Leg 2', sortOrder: 1);
    await db.groupDao.groupItems(a, b);

    final setId = await db.alternativeDao.createSetFromItem(a);

    final branches = await branchesOf(tripId, setId);
    // Both legs move into the branch — a group never straddles two branches.
    expect((await readItem(a))!.alternativeId, branches.first.id);
    expect((await readItem(b))!.alternativeId, branches.first.id);
    expect((await readItem(a))!.sortOrder, 0);
    expect((await readItem(b))!.sortOrder, 1);
  });

  test('createSetFromItem rejects an item already inside a branch', () async {
    final tripId = await makeTrip();
    final museum = await makeItem(tripId, title: 'Museum');
    await db.alternativeDao.createSetFromItem(museum);

    expect(
      () => db.alternativeDao.createSetFromItem(museum),
      throwsArgumentError,
    );
  });

  test(
    'chooseAlternative moves the choice and leaves exactly one chosen',
    () async {
      final tripId = await makeTrip();
      final museum = await makeItem(tripId, title: 'Museum');
      final setId = await db.alternativeDao.createSetFromItem(museum);
      final third = await db.alternativeDao.addAlternative(setId);

      await db.alternativeDao.chooseAlternative(third);

      final branches = await branchesOf(tripId, setId);
      expect(branches.where((b) => b.chosen).map((b) => b.id), [third]);
    },
  );

  test(
    'deleteAlternative deletes the branch\'s items and their costs',
    () async {
      final tripId = await makeTrip();
      final museum = await makeItem(tripId, title: 'Museum');
      final setId = await db.alternativeDao.createSetFromItem(museum);
      final branches = await branchesOf(tripId, setId);
      // A third branch, so deleting one does not make the set degenerate.
      await db.alternativeDao.addAlternative(setId);
      final beach = await makeItem(
        tripId,
        title: 'Beach',
        alternativeId: branches.last.id,
      );
      await makeCost(beach, 2000);

      await db.alternativeDao.deleteAlternative(branches.last.id);

      // The rejected plan goes away with its branch, cost and all.
      expect(await readItem(beach), isNull);
      expect(await db.costDao.watchCostsForTrip(tripId).first, isEmpty);
      expect((await readItem(museum))!.alternativeId, branches.first.id);
    },
  );

  test(
    'deleting the chosen branch falls back to the first remaining one',
    () async {
      final tripId = await makeTrip();
      final museum = await makeItem(tripId, title: 'Museum');
      final setId = await db.alternativeDao.createSetFromItem(museum);
      await db.alternativeDao.addAlternative(setId);
      var branches = await branchesOf(tripId, setId);

      await db.alternativeDao.deleteAlternative(branches.first.id);

      branches = await branchesOf(tripId, setId);
      // Two branches remain, and one of them is chosen — a set is never left
      // without a plan to show.
      expect(branches, hasLength(2));
      expect(branches.where((b) => b.chosen), hasLength(1));
      expect(branches.first.chosen, isTrue);
    },
  );

  test('a set left with one branch is flattened back into the day, keeping its '
      'items and costs and the day\'s order', () async {
    final tripId = await makeTrip();
    await makeItem(tripId, title: 'Breakfast', sortOrder: 0);
    final museum = await makeItem(tripId, title: 'Museum', sortOrder: 1);
    await makeItem(tripId, title: 'Dinner', sortOrder: 2);
    final setId = await db.alternativeDao.createSetFromItem(museum);
    final branches = await branchesOf(tripId, setId);
    // The kept branch holds two items, so the day must make room for both.
    await makeItem(
      tripId,
      title: 'Cafe',
      sortOrder: 1,
      alternativeId: branches.first.id,
    );
    await makeCost(museum, 1500);

    await db.alternativeDao.deleteAlternative(branches.last.id);

    // The set is gone and its items are ordinary items of the day again, in the
    // slot the set held — dinner shifted down to make room.
    expect(await db.alternativeDao.watchSetsForTrip(tripId).first, isEmpty);
    expect(await db.alternativeDao.watchBranchesForTrip(tripId).first, isEmpty);
    expect(await looseTitles(tripId), [
      'Breakfast',
      'Museum',
      'Cafe',
      'Dinner',
    ]);
    expect((await readItem(museum))!.alternativeId, isNull);
    final costs = await db.costDao.watchCostsForTrip(tripId).first;
    expect(costs.single.itemId, museum);
  });

  test('keepOnly promotes the kept branch and discards the rest', () async {
    final tripId = await makeTrip();
    final museum = await makeItem(tripId, title: 'Museum', sortOrder: 0);
    final setId = await db.alternativeDao.createSetFromItem(museum);
    final branches = await branchesOf(tripId, setId);
    final beach = await makeItem(
      tripId,
      title: 'Beach',
      alternativeId: branches.last.id,
    );

    await db.alternativeDao.keepOnly(branches.last.id);

    // The beach happened; the museum plan is discarded along with the set.
    expect(await looseTitles(tripId), ['Beach']);
    expect((await readItem(beach))!.alternativeId, isNull);
    expect((await readItem(beach))!.sortOrder, 0);
    expect(await readItem(museum), isNull);
    expect(await db.alternativeDao.watchSetsForTrip(tripId).first, isEmpty);
  });

  test('deleteSet discards every branch and its items', () async {
    final tripId = await makeTrip();
    final museum = await makeItem(tripId, title: 'Museum');
    final setId = await db.alternativeDao.createSetFromItem(museum);
    await makeCost(museum, 1500);

    await db.alternativeDao.deleteSet(setId);

    expect(await readItem(museum), isNull);
    expect(await db.alternativeDao.watchBranchesForTrip(tripId).first, isEmpty);
    expect(await db.costDao.watchCostsForTrip(tripId).first, isEmpty);
  });

  test('labels are trimmed and cleared when empty', () async {
    final tripId = await makeTrip();
    final museum = await makeItem(tripId, title: 'Museum');
    final setId = await db.alternativeDao.createSetFromItem(museum);
    final branch = (await branchesOf(tripId, setId)).first;

    await db.alternativeDao.setSetLabel(setId, '  Saturday afternoon  ');
    await db.alternativeDao.setAlternativeLabel(branch.id, ' Museum day ');
    var sets = await db.alternativeDao.watchSetsForTrip(tripId).first;
    expect(sets[setId]!.label, 'Saturday afternoon');
    expect((await branchesOf(tripId, setId)).first.label, 'Museum day');

    await db.alternativeDao.setSetLabel(setId, '   ');
    await db.alternativeDao.setAlternativeLabel(branch.id, null);
    sets = await db.alternativeDao.watchSetsForTrip(tripId).first;
    expect(sets[setId]!.label, isNull);
    expect((await branchesOf(tripId, setId)).first.label, isNull);
  });

  test(
    'deleting the trip cascades to its sets, branches and their items',
    () async {
      final tripId = await makeTrip();
      final museum = await makeItem(tripId, title: 'Museum');
      await db.alternativeDao.createSetFromItem(museum);

      await db.tripDao.deleteTrip(tripId);

      expect(await db.alternativeDao.watchSetsForTrip(tripId).first, isEmpty);
      expect(
        await db.alternativeDao.watchBranchesForTrip(tripId).first,
        isEmpty,
      );
      expect(await readItem(museum), isNull);
    },
  );

  test('groupItems refuses to group across branches', () async {
    final tripId = await makeTrip();
    final museum = await makeItem(tripId, title: 'Museum');
    final setId = await db.alternativeDao.createSetFromItem(museum);
    final branches = await branchesOf(tripId, setId);
    final beach = await makeItem(
      tripId,
      title: 'Beach',
      alternativeId: branches.last.id,
    );

    // A group's shared cost has to belong to one branch or to neither.
    expect(() => db.groupDao.groupItems(museum, beach), throwsArgumentError);
  });

  test(
    'nextSortOrder counts sets as day blocks and ignores items in branches',
    () async {
      final tripId = await makeTrip();
      final museum = await makeItem(tripId, title: 'Museum', sortOrder: 0);
      final setId = await db.alternativeDao.createSetFromItem(museum);
      final branches = await branchesOf(tripId, setId);
      // A crowded branch must not push the day's next slot along: its items are
      // ordered within the branch, not within the day.
      await makeItem(
        tripId,
        title: 'Beach',
        sortOrder: 0,
        alternativeId: branches.last.id,
      );
      await makeItem(
        tripId,
        title: 'Bar',
        sortOrder: 1,
        alternativeId: branches.last.id,
      );

      // The day holds one block — the set, at slot 0 — so the next slot is 1.
      expect(await db.itineraryDao.nextSortOrder(tripId, day), 1);
      expect(
        await db.itineraryDao.nextSortOrderInAlternative(branches.last.id),
        2,
      );
    },
  );

  /// One branch's items, in order, by title.
  Future<List<String>> branchTitles(int alternativeId) async {
    final items = await db.itineraryDao.watchItemsForTrip(1).first;
    return [
      for (final i in items)
        if (i.alternativeId == alternativeId) i.title!,
    ];
  }

  group('duplicateAlternative', () {
    test('adds an unchosen copy of the option, carrying its entries', () async {
      final tripId = await makeTrip();
      final beach = await makeItem(tripId, title: 'Beach');
      final setId = await db.alternativeDao.createSetFromItem(beach);
      final chosen = (await branchesOf(tripId, setId)).first;
      await makeItem(
        tripId,
        title: 'Bar',
        sortOrder: 1,
        alternativeId: chosen.id,
      );

      final copyId = await db.alternativeDao.duplicateAlternative(chosen.id);
      final branches = await branchesOf(tripId, setId);

      // A third option, at the end, and the plan still follows the original.
      expect(branches.map((b) => b.id), containsAll([chosen.id, copyId]));
      expect(branches.firstWhere((b) => b.id == copyId).chosen, isFalse);
      expect(branches.firstWhere((b) => b.id == chosen.id).chosen, isTrue);
      // The copy holds its own entries, in order — new rows, not the originals.
      expect(await branchTitles(copyId), ['Beach', 'Bar']);
      expect(await branchTitles(chosen.id), ['Beach', 'Bar']);
    });

    test('takes the plan of each entry but none of its costs', () async {
      final tripId = await makeTrip();
      final beach = await makeItem(tripId, title: 'Beach');
      final setId = await db.alternativeDao.createSetFromItem(beach);
      final chosen = (await branchesOf(tripId, setId)).first;
      await makeCost(beach, 2000);

      final copyId = await db.alternativeDao.duplicateAlternative(chosen.id);

      // The one cost is still the original's; the copy's entry has none.
      final costs = await db.costDao.watchCostsForTrip(tripId).first;
      expect(costs.single.itemId, beach);
      final items = await db.itineraryDao.watchItemsForTrip(tripId).first;
      final copyEntry = items.firstWhere((i) => i.alternativeId == copyId);
      final copyCosts = costs.where((c) => c.itemId == copyEntry.id);
      expect(copyCosts, isEmpty);
    });

    test('clones grouping inside the option into a fresh group', () async {
      final tripId = await makeTrip();
      final beach = await makeItem(tripId, title: 'Beach');
      final setId = await db.alternativeDao.createSetFromItem(beach);
      final chosen = (await branchesOf(tripId, setId)).first;
      final leg1 = await makeItem(
        tripId,
        title: 'Leg 1',
        sortOrder: 1,
        alternativeId: chosen.id,
      );
      final leg2 = await makeItem(
        tripId,
        title: 'Leg 2',
        sortOrder: 2,
        alternativeId: chosen.id,
      );
      final sourceGroup = await db.groupDao.groupItems(leg1, leg2);

      final copyId = await db.alternativeDao.duplicateAlternative(chosen.id);

      // The copy's legs are grouped too — but under their own group, not the
      // original's (a group is internal to the option it lives in).
      final items = await db.itineraryDao.watchItemsForTrip(tripId).first;
      final copyLegs = items
          .where((i) => i.alternativeId == copyId && i.groupId != null)
          .toList();
      expect(copyLegs, hasLength(2));
      final copyGroup = copyLegs.first.groupId;
      expect(copyGroup, isNot(sourceGroup));
      expect(copyLegs.every((i) => i.groupId == copyGroup), isTrue);
    });
  });
}
