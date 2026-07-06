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
        itemId: itemId,
        amountMinor: minor,
        currency: c,
        reason: reason,
      );

  test('watchCostsForTrip returns all costs across the trip items', () async {
    final tripId =
        await db.tripDao.createTrip(TripsCompanion.insert(title: 'T'));
    final a = await makeItem(tripId);
    final b = await makeItem(tripId);
    await db.costDao.addCost(cost(a, 4990, Currency.eur, 'Hotel'));
    await db.costDao.addCost(cost(a, 1500, Currency.eur, 'Dinner'));
    await db.costDao.addCost(cost(b, 2000, Currency.usd, 'Train ticket'));

    final costs = await db.costDao.watchCostsForTrip(tripId).first;
    expect(costs.length, 3);
    expect(costs.map((c) => c.reason),
        containsAll(['Hotel', 'Dinner', 'Train ticket']));
  });

  test('upsertReason dedupes and watchReasons is sorted', () async {
    await db.costDao.upsertReason('Hotel');
    await db.costDao.upsertReason('Hotel'); // duplicate, ignored
    await db.costDao.upsertReason('Dinner');

    expect(await db.costDao.watchReasons().first, ['Dinner', 'Hotel']);
  });

  test('deleting an item cascades to its costs', () async {
    final tripId =
        await db.tripDao.createTrip(TripsCompanion.insert(title: 'T'));
    final item = await makeItem(tripId);
    await db.costDao.addCost(cost(item, 4990, Currency.eur, 'Hotel'));

    await db.itineraryDao.deleteItem(item);

    expect(await db.costDao.watchCostsForTrip(tripId).first, isEmpty);
  });

  test('deleting a trip cascades to its items and their costs', () async {
    final tripId =
        await db.tripDao.createTrip(TripsCompanion.insert(title: 'T'));
    final item = await makeItem(tripId);
    await db.costDao.addCost(cost(item, 4990, Currency.eur, 'Hotel'));

    await db.tripDao.deleteTrip(tripId);

    expect(await db.costDao.watchCostsForTrip(tripId).first, isEmpty);
  });
}
