import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> makeItem(int tripId) => db.itineraryDao.addItem(
    ItineraryItemsCompanion.insert(
      tripId: tripId,
      date: DateTime(2026, 7, 5),
      kind: ItemKind.place,
      location: const Value('Somewhere'),
    ),
  );

  CostsCompanion cost(int itemId, int minor, Currency c, String reason) =>
      CostsCompanion.insert(
        itemId: Value(itemId),
        amountMinor: minor,
        currency: c,
        reason: reason,
      );

  CostsCompanion tripCost(int tripId, int minor, Currency c, String reason) =>
      CostsCompanion.insert(
        tripId: Value(tripId),
        amountMinor: minor,
        currency: c,
        reason: reason,
      );

  test('watchCostsForTrip returns all costs across the trip items', () async {
    final tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(title: 'T'),
    );
    final a = await makeItem(tripId);
    final b = await makeItem(tripId);
    await db.costDao.addCost(cost(a, 4990, Currency.eur, 'Hotel'));
    await db.costDao.addCost(cost(a, 1500, Currency.eur, 'Dinner'));
    await db.costDao.addCost(cost(b, 2000, Currency.usd, 'Train ticket'));

    final costs = await db.costDao.watchCostsForTrip(tripId).first;
    expect(costs.length, 3);
    expect(
      costs.map((c) => c.reason),
      containsAll(['Hotel', 'Dinner', 'Train ticket']),
    );
  });

  test(
    'watchCostsForTrip includes trip-level costs not tied to an item',
    () async {
      final tripId = await db.tripDao.createTrip(
        TripsCompanion.insert(title: 'T'),
      );
      final item = await makeItem(tripId);
      await db.costDao.addCost(cost(item, 4990, Currency.eur, 'Hotel'));
      await db.costDao.addCost(
        tripCost(tripId, 3000, Currency.eur, 'Insurance'),
      );

      final costs = await db.costDao.watchCostsForTrip(tripId).first;
      expect(costs.length, 2);
      expect(costs.map((c) => c.reason), containsAll(['Hotel', 'Insurance']));
      final tripLevel = costs.singleWhere((c) => c.itemId == null);
      expect(tripLevel.tripId, tripId);
      expect(tripLevel.reason, 'Insurance');
    },
  );

  test('trip-level costs stay scoped to their trip', () async {
    final tripA = await db.tripDao.createTrip(
      TripsCompanion.insert(title: 'A'),
    );
    final tripB = await db.tripDao.createTrip(
      TripsCompanion.insert(title: 'B'),
    );
    await db.costDao.addCost(tripCost(tripA, 3000, Currency.eur, 'Insurance'));

    expect(await db.costDao.watchCostsForTrip(tripB).first, isEmpty);
  });

  group('settlements between people', () {
    /// A settlement: [from] hands [minor] over to someone.
    CostsCompanion transfer(int tripId, int minor, String from) =>
        CostsCompanion.insert(
          tripId: Value(tripId),
          amountMinor: minor,
          currency: Currency.eur,
          reason: '',
          paidBy: Value(from),
          paid: const Value(true),
          isTransfer: const Value(true),
        );

    test('a settlement stays out of the trip totals', () async {
      final tripId = await db.tripDao.createTrip(
        TripsCompanion.insert(title: 'T'),
      );
      await db.costDao.addCost(tripCost(tripId, 6000, Currency.eur, 'Dinner'));
      await db.costDao.addCost(transfer(tripId, 2000, 'Bo'));

      final totals = await db.costDao.watchTotalsByTrip().first;
      expect(totals[tripId], {Currency.eur: 6000});
    });

    test('a trip with only settlements has no total at all', () async {
      final tripId = await db.tripDao.createTrip(
        TripsCompanion.insert(title: 'T'),
      );
      await db.costDao.addCost(transfer(tripId, 2000, 'Bo'));

      expect(await db.costDao.watchTotalsByTrip().first, isEmpty);
    });

    test('but the splitting does see it — it is what settles up', () async {
      final tripId = await db.tripDao.createTrip(
        TripsCompanion.insert(title: 'T'),
      );
      await db.costDao.addCost(transfer(tripId, 2000, 'Bo'));

      final counted = await db.costDao.watchCountedCostsForTrip(tripId).first;
      expect(counted.single.isTransfer, isTrue);
      expect(counted.single.paidBy, 'Bo');
    });
  });

  test('deleting a trip cascades to its trip-level costs', () async {
    final tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(title: 'T'),
    );
    await db.costDao.addCost(tripCost(tripId, 3000, Currency.eur, 'Insurance'));

    await db.tripDao.deleteTrip(tripId);

    expect(await db.costDao.watchCostsForTrip(tripId).first, isEmpty);
  });

  test('upsertReason dedupes and watchReasons is sorted', () async {
    await db.costDao.upsertReason('Hotel');
    await db.costDao.upsertReason('Hotel'); // duplicate, ignored
    await db.costDao.upsertReason('Dinner');

    expect(await db.costDao.watchReasons().first, ['Dinner', 'Hotel']);
  });

  test('setReasonIcon creates a reason and assigns its icon', () async {
    await db.costDao.setReasonIcon('Hotel', 6);

    final rows = await db.costDao.watchReasonRows().first;
    expect(rows.single.label, 'Hotel');
    expect(rows.single.iconId, 6);
  });

  test(
    'setReasonIcon updates an existing reason without duplicating it',
    () async {
      await db.costDao.upsertReason('Hotel');
      await db.costDao.setReasonIcon('Hotel', 6);
      await db.costDao.setReasonIcon('Hotel', 8); // change icon
      await db.costDao.setReasonIcon('Hotel', null); // clear icon

      final rows = await db.costDao.watchReasonRows().first;
      expect(rows.length, 1);
      expect(rows.single.iconId, null);
    },
  );

  test('deleteReason forgets a saved reason', () async {
    await db.costDao.upsertReason('Hotel');
    await db.costDao.upsertReason('Dinner');

    await db.costDao.deleteReason('Hotel');

    expect(await db.costDao.watchReasons().first, ['Dinner']);
  });

  test('renameReason repoints every cost and keeps the icon', () async {
    final tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(title: 'T'),
    );
    final item = await makeItem(tripId);
    await db.costDao.setReasonIcon('Hotel', 5);
    await db.costDao.addCost(cost(item, 4990, Currency.eur, 'Hotel'));
    await db.costDao.addCost(tripCost(tripId, 3000, Currency.eur, 'Hotel'));

    await db.costDao.renameReason('Hotel', 'Lodging');

    final costs = await db.costDao.watchCostsForTrip(tripId).first;
    expect(costs.map((c) => c.reason), everyElement('Lodging'));
    final rows = await db.costDao.watchReasonRows().first;
    expect(rows.single.label, 'Lodging');
    expect(rows.single.iconId, 5); // icon carried over
  });

  test('renameReason onto an existing reason merges them', () async {
    final tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(title: 'T'),
    );
    final item = await makeItem(tripId);
    await db.costDao.addCost(cost(item, 1000, Currency.eur, 'Food'));
    await db.costDao.upsertReason('Dinner');
    await db.costDao.addCost(tripCost(tripId, 2000, Currency.eur, 'Dinner'));

    await db.costDao.renameReason('Food', 'Dinner');

    // Only one reason survives, and both costs now point at it.
    expect(await db.costDao.watchReasons().first, ['Dinner']);
    final costs = await db.costDao.watchCostsForTrip(tripId).first;
    expect(costs.map((c) => c.reason), everyElement('Dinner'));
  });

  test('upsertPerson dedupes and watchPeople is sorted', () async {
    await db.costDao.upsertPerson('Bob');
    await db.costDao.upsertPerson('Bob'); // duplicate, ignored
    await db.costDao.upsertPerson('Alex');

    expect(await db.costDao.watchPeople().first, ['Alex', 'Bob']);
  });

  test('deletePerson forgets a saved person', () async {
    await db.costDao.upsertPerson('Alex');
    await db.costDao.upsertPerson('Bob');

    await db.costDao.deletePerson('Alex');

    expect(await db.costDao.watchPeople().first, ['Bob']);
  });

  test('setMePerson marks one person and clears any previous', () async {
    await db.costDao.upsertPerson('Alex');
    await db.costDao.upsertPerson('Bob');
    final rows = await db.costDao.watchPeopleRows().first;
    final alex = rows.firstWhere((p) => p.name == 'Alex');
    final bob = rows.firstWhere((p) => p.name == 'Bob');

    // No one is "me" initially.
    expect(await db.costDao.watchMePerson().first, equals(null));

    await db.costDao.setMePerson(alex.id);
    expect((await db.costDao.watchMePerson().first)?.name, 'Alex');

    // Switching "me" clears the previous one, so only Bob is flagged.
    await db.costDao.setMePerson(bob.id);
    expect((await db.costDao.watchMePerson().first)?.name, 'Bob');
    final flagged = (await db.costDao.watchPeopleRows().first).where(
      (p) => p.isMe,
    );
    expect(flagged.map((p) => p.name), ['Bob']);

    // Passing null clears the flag entirely.
    await db.costDao.setMePerson(null);
    expect(await db.costDao.watchMePerson().first, equals(null));
  });

  test('renamePerson repoints every cost they paid', () async {
    final tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(title: 'T'),
    );
    final item = await makeItem(tripId);
    await db.costDao.upsertPerson('Alex');
    await db.costDao.addCost(
      CostsCompanion.insert(
        itemId: Value(item),
        amountMinor: 4990,
        currency: Currency.eur,
        reason: 'Hotel',
        paidBy: const Value('Alex'),
      ),
    );
    await db.costDao.addCost(
      CostsCompanion.insert(
        tripId: Value(tripId),
        amountMinor: 3000,
        currency: Currency.eur,
        reason: 'Insurance',
        paidBy: const Value('Alex'),
      ),
    );

    await db.costDao.renamePerson('Alex', 'Alexandra');

    expect(await db.costDao.watchPeople().first, ['Alexandra']);
    final costs = await db.costDao.watchCostsForTrip(tripId).first;
    expect(costs.map((c) => c.paidBy), everyElement('Alexandra'));
  });

  test('renamePerson onto an existing person merges them', () async {
    final tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(title: 'T'),
    );
    final item = await makeItem(tripId);
    await db.costDao.addCost(
      CostsCompanion.insert(
        itemId: Value(item),
        amountMinor: 1000,
        currency: Currency.eur,
        reason: 'Food',
        paidBy: const Value('Alex'),
      ),
    );
    await db.costDao.upsertPerson('Bob');

    await db.costDao.renamePerson('Alex', 'Bob');

    // Only one person survives, and the cost now points at them.
    expect(await db.costDao.watchPeople().first, ['Bob']);
    final costs = await db.costDao.watchCostsForTrip(tripId).first;
    expect(costs.single.paidBy, 'Bob');
  });

  test('setBeneficiaries creates people, links them, and is sorted', () async {
    final tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(title: 'T'),
    );
    final id = await db.costDao.addCost(
      tripCost(tripId, 3000, Currency.eur, 'Taxi'),
    );

    await db.costDao.setBeneficiaries(id, ['Bob', 'Alex']);

    final people = await db.costDao.watchBeneficiaries(id).first;
    expect(people.map((p) => p.name), ['Alex', 'Bob']);
    // The people also land in the shared roster.
    expect(await db.costDao.watchPeople().first, ['Alex', 'Bob']);
  });

  test(
    'watchBeneficiariesForTrip maps every cost in the trip, and only it',
    () async {
      final tripId = await db.tripDao.createTrip(
        TripsCompanion.insert(title: 'T'),
      );
      final other = await db.tripDao.createTrip(
        TripsCompanion.insert(title: 'Other'),
      );
      final item = await makeItem(tripId);
      final itemCostId = await db.costDao.addCost(
        cost(item, 4990, Currency.eur, 'Hotel'),
      );
      final tripCostId = await db.costDao.addCost(
        tripCost(tripId, 3000, Currency.eur, 'Taxi'),
      );
      final otherCostId = await db.costDao.addCost(
        tripCost(other, 1000, Currency.eur, 'Bus'),
      );

      await db.costDao.setBeneficiaries(itemCostId, ['Bob', 'Alex']);
      await db.costDao.setBeneficiaries(tripCostId, ['Alex']);
      await db.costDao.setBeneficiaries(otherCostId, ['Cara']);

      final byCost = await db.costDao.watchBeneficiariesForTrip(tripId).first;
      expect(byCost.keys.toSet(), {itemCostId, tripCostId});
      expect(byCost[itemCostId]!.map((p) => p.name), ['Alex', 'Bob']);
      expect(byCost[tripCostId]!.map((p) => p.name), ['Alex']);
    },
  );

  test('setBeneficiaries reconciles the set: adds and removes links', () async {
    final tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(title: 'T'),
    );
    final id = await db.costDao.addCost(
      tripCost(tripId, 3000, Currency.eur, 'Taxi'),
    );

    await db.costDao.setBeneficiaries(id, ['Alex', 'Bob']);
    await db.costDao.setBeneficiaries(id, [
      'Bob',
      'Cara',
    ]); // drop Alex, add Cara

    final people = await db.costDao.watchBeneficiaries(id).first;
    expect(people.map((p) => p.name), ['Bob', 'Cara']);
  });

  test('setBeneficiaries with an empty list clears the split', () async {
    final tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(title: 'T'),
    );
    final id = await db.costDao.addCost(
      tripCost(tripId, 3000, Currency.eur, 'Taxi'),
    );
    await db.costDao.setBeneficiaries(id, ['Alex']);

    await db.costDao.setBeneficiaries(id, const []);

    expect(await db.costDao.watchBeneficiaries(id).first, isEmpty);
    // The person stays in the shared roster.
    expect(await db.costDao.watchPeople().first, ['Alex']);
  });

  test('deleting a cost cascades to its beneficiary links', () async {
    final tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(title: 'T'),
    );
    final id = await db.costDao.addCost(
      tripCost(tripId, 3000, Currency.eur, 'Taxi'),
    );
    await db.costDao.setBeneficiaries(id, ['Alex']);

    await db.costDao.deleteCost(id);

    // The link is gone (no orphan), but the person remains in the roster.
    expect(await db.costDao.watchPeople().first, ['Alex']);
  });

  test('deleting a person removes them from every cost split', () async {
    final tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(title: 'T'),
    );
    final id = await db.costDao.addCost(
      tripCost(tripId, 3000, Currency.eur, 'Taxi'),
    );
    await db.costDao.setBeneficiaries(id, ['Alex', 'Bob']);

    await db.costDao.deletePerson('Alex');

    final people = await db.costDao.watchBeneficiaries(id).first;
    expect(people.map((p) => p.name), ['Bob']);
  });

  test('deleting an item cascades to its costs', () async {
    final tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(title: 'T'),
    );
    final item = await makeItem(tripId);
    await db.costDao.addCost(cost(item, 4990, Currency.eur, 'Hotel'));

    await db.itineraryDao.deleteItem(item);

    expect(await db.costDao.watchCostsForTrip(tripId).first, isEmpty);
  });

  test('deleting a trip cascades to its items and their costs', () async {
    final tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(title: 'T'),
    );
    final item = await makeItem(tripId);
    await db.costDao.addCost(cost(item, 4990, Currency.eur, 'Hotel'));

    await db.tripDao.deleteTrip(tripId);

    expect(await db.costDao.watchCostsForTrip(tripId).first, isEmpty);
  });
}
