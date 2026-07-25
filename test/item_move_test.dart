import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/itinerary/day_blocks.dart';

import 'currency_fixture.dart';

/// Covers moving and copying an entry between lists — the two-step act that
/// crosses the boundaries dragging cannot: to another day, into one option of a
/// decision, and back out of it.
void main() {
  late AppDatabase db;

  final day1 = DateTime(2026, 7, 5);
  final day2 = DateTime(2026, 7, 6);

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
      date: date ?? day1,
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
      currency: eurId,
      reason: 'Ticket',
    ),
  );

  Future<ItineraryItem> readItem(int id) =>
      (db.select(db.itineraryItems)..where((i) => i.id.equals(id))).getSingle();

  /// A day's entries in the order the timeline reads them.
  Future<List<String>> dayTitles(int tripId, DateTime day) async {
    final blocks = buildDayBlocks(
      day: day,
      items: await db.itineraryDao.watchItemsForTrip(tripId).first,
      sets: await db.alternativeDao.watchSetsForTrip(tripId).first,
      branchesBySet: await db.alternativeDao.watchBranchesForTrip(tripId).first,
    );
    return [for (final item in itemsInDayOrder(blocks)) item.title!];
  }

  test('an entry moves to the end of another day', () async {
    final tripId = await makeTrip();
    await makeItem(tripId, title: 'Breakfast', sortOrder: 0);
    final museum = await makeItem(tripId, title: 'Museum', sortOrder: 1);
    await makeItem(tripId, title: 'Dinner', sortOrder: 2);
    await makeItem(tripId, title: 'Market', sortOrder: 0, date: day2);

    await db.itineraryDao.moveItem(museum, day: day2);

    expect(await dayTitles(tripId, day1), ['Breakfast', 'Dinner']);
    expect(await dayTitles(tripId, day2), ['Market', 'Museum']);
  });

  test('an entry moves into an option, and keeps its own costs', () async {
    final tripId = await makeTrip();
    final beach = await makeItem(tripId, title: 'Beach', sortOrder: 0);
    final lunch = await makeItem(tripId, title: 'Lunch', sortOrder: 1);
    await makeCost(lunch, 1200);
    final setId = await db.alternativeDao.createSetFromItem(beach);
    final branches = (await db.alternativeDao
        .watchBranchesForTrip(tripId)
        .first)[setId]!;

    await db.itineraryDao.moveItem(
      lunch,
      day: day1,
      alternativeId: branches.first.id,
    );

    // The chosen option now runs Beach → Lunch, in that order, and the decision
    // still holds the day's first slot.
    expect(await dayTitles(tripId, day1), ['Beach', 'Lunch']);
    expect((await readItem(lunch)).alternativeId, branches.first.id);
    // A cost hangs off the item, so it travels with it — unlike a copy's.
    final costs = await db.costDao.watchCostsForTrip(tripId).first;
    expect(costs.single.amountMinor, 1200);
  });

  test('an entry moves back out of an option onto its day', () async {
    final tripId = await makeTrip();
    final beach = await makeItem(tripId, title: 'Beach');
    await db.alternativeDao.createSetFromItem(beach);

    await db.itineraryDao.moveItem(beach, day: day2);

    expect((await readItem(beach)).alternativeId, isNull);
    expect(await dayTitles(tripId, day2), ['Beach']);
  });

  test('a moved entry leaves its group behind', () async {
    final tripId = await makeTrip();
    final leg1 = await makeItem(tripId, title: 'Leg 1', sortOrder: 0);
    final leg2 = await makeItem(tripId, title: 'Leg 2', sortOrder: 1);
    final leg3 = await makeItem(tripId, title: 'Leg 3', sortOrder: 2);
    final groupId = await db.groupDao.groupItems(leg1, leg2);
    await db.groupDao.groupItems(leg2, leg3);

    await db.itineraryDao.moveItem(leg3, day: day2);

    // A group means "these share a ticket", so it has to stay one run inside one
    // day: the traveller leaves it, the two that stayed keep it.
    expect((await readItem(leg3)).groupId, isNull);
    expect((await readItem(leg1)).groupId, groupId);
    expect((await readItem(leg2)).groupId, groupId);
  });

  test('a group left with one member is dissolved, keeping its cost', () async {
    final tripId = await makeTrip();
    final leg1 = await makeItem(tripId, title: 'Leg 1', sortOrder: 0);
    final leg2 = await makeItem(tripId, title: 'Leg 2', sortOrder: 1);
    final groupId = await db.groupDao.groupItems(leg1, leg2);
    await db.costDao.addCost(
      CostsCompanion.insert(
        groupId: Value(groupId),
        amountMinor: 4500,
        currency: eurId,
        reason: 'Ticket',
      ),
    );

    await db.itineraryDao.moveItem(leg2, day: day2);

    expect((await readItem(leg1)).groupId, isNull);
    // The shared expense survives on the member left behind rather than
    // cascading away with the group.
    final costs = await db.costDao.watchCostsForTrip(tripId).first;
    expect(costs.single.amountMinor, 4500);
    expect(costs.single.itemId, leg1);
  });

  test('a copy takes the plan but not the money', () async {
    final tripId = await makeTrip();
    final dinner = await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: day1,
        kind: ItemKind.place,
        title: const Value('Dinner'),
        location: const Value('Trastevere'),
        startMinutes: const Value(20 * 60),
        notes: const Value('book ahead'),
      ),
    );
    await makeCost(dinner, 6000);

    final copyId = await db.itineraryDao.duplicateItem(dinner, day: day2);
    final copy = await readItem(copyId);

    expect(copy.title, 'Dinner');
    expect(copy.location, 'Trastevere');
    expect(copy.startMinutes, 20 * 60);
    expect(copy.notes, 'book ahead');
    expect(copy.date, day2);
    // A cost records a payment that happened once; duplicating it would invent
    // money inside the trip's totals and its settle-up.
    final costs = await db.costDao.watchCostsForTrip(tripId).first;
    expect(costs.single.itemId, dinner);
  });

  test('a copy does not join the original\'s group', () async {
    final tripId = await makeTrip();
    final leg1 = await makeItem(tripId, title: 'Leg 1', sortOrder: 0);
    final leg2 = await makeItem(tripId, title: 'Leg 2', sortOrder: 1);
    await db.groupDao.groupItems(leg1, leg2);

    final copyId = await db.itineraryDao.duplicateItem(leg2, day: day1);

    // Joining would put a third leg on a two-leg ticket, and break the run's
    // adjacency besides.
    expect((await readItem(copyId)).groupId, isNull);
  });

  test('copying into an option leaves the original where it was', () async {
    final tripId = await makeTrip();
    final beach = await makeItem(tripId, title: 'Beach', sortOrder: 0);
    final museum = await makeItem(tripId, title: 'Museum', sortOrder: 1);
    final setId = await db.alternativeDao.createSetFromItem(beach);
    final branches = (await db.alternativeDao
        .watchBranchesForTrip(tripId)
        .first)[setId]!;

    await db.itineraryDao.duplicateItem(
      museum,
      day: day1,
      alternativeId: branches.last.id,
    );

    // The unchosen option holds the copy, so the day still reads as before —
    // and the copy is priced by nothing, counted by nothing.
    expect(await dayTitles(tripId, day1), ['Beach', 'Museum']);
    expect((await readItem(museum)).alternativeId, isNull);
  });

  group('moving and copying a whole group', () {
    test(
      'a moved group travels together, staying grouped, cost and all',
      () async {
        final tripId = await makeTrip();
        final leg1 = await makeItem(tripId, title: 'Leg 1', sortOrder: 0);
        final leg2 = await makeItem(tripId, title: 'Leg 2', sortOrder: 1);
        await makeItem(tripId, title: 'Solo', sortOrder: 2);
        final groupId = await db.groupDao.groupItems(leg1, leg2);
        await db.costDao.addCost(
          CostsCompanion.insert(
            groupId: Value(groupId),
            amountMinor: 8000,
            currency: eurId,
            reason: 'Train ticket',
          ),
        );

        await db.groupDao.moveGroup(groupId, day: day2);

        // Both legs cross over, in order, still one group; the loose item stays.
        expect(await dayTitles(tripId, day1), ['Solo']);
        expect(await dayTitles(tripId, day2), ['Leg 1', 'Leg 2']);
        expect((await readItem(leg1)).groupId, groupId);
        expect((await readItem(leg2)).groupId, groupId);
        // The shared ticket rides along — it hangs off the group, which survived.
        final costs = await db.costDao.watchCostsForTrip(tripId).first;
        expect(costs.single.amountMinor, 8000);
        expect(costs.single.groupId, groupId);
      },
    );

    test(
      'a group moves into an option, its members landing in the branch',
      () async {
        final tripId = await makeTrip();
        final beach = await makeItem(tripId, title: 'Beach', sortOrder: 0);
        final leg1 = await makeItem(tripId, title: 'Leg 1', sortOrder: 1);
        final leg2 = await makeItem(tripId, title: 'Leg 2', sortOrder: 2);
        final groupId = await db.groupDao.groupItems(leg1, leg2);
        final setId = await db.alternativeDao.createSetFromItem(beach);
        final chosen =
            (await db.alternativeDao.watchBranchesForTrip(tripId).first)[setId]!
                .first;

        await db.groupDao.moveGroup(
          groupId,
          day: day1,
          alternativeId: chosen.id,
        );

        // Both legs are now inside the option and still one group (a group inside
        // one branch is legal).
        expect((await readItem(leg1)).alternativeId, chosen.id);
        expect((await readItem(leg2)).alternativeId, chosen.id);
        expect((await readItem(leg1)).groupId, groupId);
        expect((await readItem(leg2)).groupId, groupId);
      },
    );

    test('a copied group is a fresh bundle with no money', () async {
      final tripId = await makeTrip();
      final leg1 = await makeItem(tripId, title: 'Leg 1', sortOrder: 0);
      final leg2 = await makeItem(tripId, title: 'Leg 2', sortOrder: 1);
      final groupId = await db.groupDao.groupItems(leg1, leg2);
      await db.groupDao.setGroupLabel(groupId, 'Rail pass');
      await makeCost(leg1, 500);
      await db.costDao.addCost(
        CostsCompanion.insert(
          groupId: Value(groupId),
          amountMinor: 8000,
          currency: eurId,
          reason: 'Train ticket',
        ),
      );

      final newGroupId = await db.groupDao.copyGroup(groupId, day: day2);

      // The original is untouched on its day; the copy is two new items on the
      // other, grouped under a new group with the same name.
      expect(await dayTitles(tripId, day1), ['Leg 1', 'Leg 2']);
      expect(await dayTitles(tripId, day2), ['Leg 1', 'Leg 2']);
      expect(newGroupId, isNot(groupId));
      final groups = await db.groupDao.watchGroupsForTrip(tripId).first;
      expect(groups[newGroupId]!.label, 'Rail pass');
      // Costs never copy: the two originals are the only ones in the trip.
      final costs = await db.costDao.watchCostsForTrip(tripId).first;
      expect(costs.length, 2);
      expect(costs.map((c) => c.groupId), everyElement(isNot(newGroupId)));
    });
  });
}
