import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  DateTime day(int d) => DateTime(2026, 7, d);

  test('items are ordered by day, then sortOrder, then start time', () async {
    final tripId =
        await db.tripDao.createTrip(TripsCompanion.insert(title: 'Trip'));

    // Insert intentionally out of order.
    await db.itineraryDao.addItem(ItineraryItemsCompanion.insert(
      tripId: tripId,
      date: day(2),
      kind: ItemKind.place,
      sortOrder: const Value(0),
      location: const Value('Day2-A'),
    ));
    await db.itineraryDao.addItem(ItineraryItemsCompanion.insert(
      tripId: tripId,
      date: day(1),
      kind: ItemKind.place,
      sortOrder: const Value(1),
      location: const Value('Day1-second'),
    ));
    await db.itineraryDao.addItem(ItineraryItemsCompanion.insert(
      tripId: tripId,
      date: day(1),
      kind: ItemKind.place,
      sortOrder: const Value(0),
      location: const Value('Day1-first'),
    ));

    final items = await db.itineraryDao.watchItemsForTrip(tripId).first;

    expect(items.map((i) => i.location).toList(),
        ['Day1-first', 'Day1-second', 'Day2-A']);
  });

  test('nextSortOrder increments per day and resets for a new day', () async {
    final tripId =
        await db.tripDao.createTrip(TripsCompanion.insert(title: 'Trip'));

    expect(await db.itineraryDao.nextSortOrder(tripId, day(1)), 0);

    await db.itineraryDao.addItem(ItineraryItemsCompanion.insert(
      tripId: tripId,
      date: day(1),
      kind: ItemKind.place,
      sortOrder: const Value(0),
      location: const Value('A'),
    ));

    expect(await db.itineraryDao.nextSortOrder(tripId, day(1)), 1);
    // A different day starts from zero again.
    expect(await db.itineraryDao.nextSortOrder(tripId, day(2)), 0);
  });

  test('deleting a trip cascades to its itinerary items', () async {
    final tripId =
        await db.tripDao.createTrip(TripsCompanion.insert(title: 'Trip'));
    await db.itineraryDao.addItem(ItineraryItemsCompanion.insert(
      tripId: tripId,
      date: day(1),
      kind: ItemKind.transport,
      mode: const Value(TransportMode.train),
      fromLocation: const Value('Rome'),
      toLocation: const Value('Florence'),
    ));

    await db.tripDao.deleteTrip(tripId);

    final remaining = await db.itineraryDao.watchItemsForTrip(tripId).first;
    expect(remaining, isEmpty);
  });
}
