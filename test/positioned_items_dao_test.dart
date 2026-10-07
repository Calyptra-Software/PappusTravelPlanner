import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';

/// Which entries the cross-trip reading hands over: the all-trips map and the
/// all-trips countries both read it.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> makeTrip() => db
      .into(db.trips)
      .insert(
        TripsCompanion.insert(
          title: 'Trip',
          destination: const Value(''),
          startDate: Value(DateTime(2026, 5, 1)),
          endDate: Value(DateTime(2026, 5, 2)),
        ),
      );

  Future<int> add(
    int tripId,
    ItemKind kind, {
    double? lat,
    double? lon,
    double? fromLat,
    double? fromLon,
    double? toLat,
    double? toLon,
  }) => db
      .into(db.itineraryItems)
      .insert(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: DateTime(2026, 5, 1),
          kind: kind,
          lat: Value(lat),
          lon: Value(lon),
          fromLat: Value(fromLat),
          fromLon: Value(fromLon),
          toLat: Value(toLat),
          toLon: Value(toLon),
        ),
      );

  Future<Set<int>> positioned() async => {
    for (final item in await db.itineraryDao.watchPositionedItems().first)
      item.id,
  };

  test('a place and a leg placed at both ends are handed over', () async {
    final trip = await makeTrip();
    final place = await add(trip, ItemKind.place, lat: 53.55, lon: 9.99);
    final leg = await add(
      trip,
      ItemKind.transport,
      fromLat: 53.55,
      fromLon: 9.99,
      toLat: 55.67,
      toLon: 12.57,
    );
    expect(await positioned(), {place, leg});
  });

  test('a leg placed at one end alone is handed over too', () async {
    // That end is where somebody stood, and a single trip's countries already
    // count it; the all-trips reading used to drop the leg, so the same trip
    // counted a country on its own tab and not in the total.
    final trip = await makeTrip();
    final fromOnly = await add(
      trip,
      ItemKind.transport,
      fromLat: 53.55,
      fromLon: 9.99,
    );
    final toOnly = await add(
      trip,
      ItemKind.transport,
      toLat: 55.67,
      toLon: 12.57,
    );
    expect(await positioned(), {fromOnly, toOnly});
  });

  test('half a coordinate is no position', () async {
    final trip = await makeTrip();
    await add(trip, ItemKind.place);
    await add(trip, ItemKind.place, lat: 53.55);
    await add(trip, ItemKind.transport, fromLat: 53.55, toLon: 12.57);
    expect(await positioned(), isEmpty);
  });
}
