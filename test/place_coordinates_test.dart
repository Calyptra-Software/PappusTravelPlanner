import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/sharing/trip_bundle.dart';

/// Where an entry *is* — a place's own position and a leg's two ends — is part
/// of the plan, so it must survive every way an entry is carried somewhere else:
/// a copy onto another day, and a trip shared as a `.tpt` bundle.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> seedTrip() => db.tripDao.createTrip(
    TripsCompanion.insert(
      title: 'Frankfurt',
      startDate: Value(DateTime(2026, 5, 1)),
      endDate: Value(DateTime(2026, 5, 2)),
    ),
  );

  Future<int> addPlace(int tripId) => db.itineraryDao.addItem(
    ItineraryItemsCompanion.insert(
      tripId: tripId,
      date: DateTime(2026, 5, 1),
      kind: ItemKind.place,
      title: const Value('Städel'),
      location: const Value('Schaumainkai 63'),
      lat: const Value(50.103611),
      lon: const Value(8.674167),
    ),
  );

  Future<int> addLeg(int tripId) => db.itineraryDao.addItem(
    ItineraryItemsCompanion.insert(
      tripId: tripId,
      date: DateTime(2026, 5, 1),
      kind: ItemKind.transport,
      mode: const Value(6), // seeded 'train' mode (enum index 5 + 1)
      fromLocation: const Value('Hamburg Hbf'),
      toLocation: const Value('Frankfurt(Main) Hbf'),
      fromLat: const Value(53.552736),
      fromLon: const Value(10.006909),
      toLat: const Value(50.107145),
      toLon: const Value(8.663789),
    ),
  );

  test('a copy takes the place with it', () async {
    final tripId = await seedTrip();
    final placeId = await addPlace(tripId);

    await db.itineraryDao.duplicateItem(placeId, day: DateTime(2026, 5, 2));

    final copy = (await db.itineraryDao.watchItemsForTrip(tripId).first)
        .firstWhere((i) => i.date == DateTime(2026, 5, 2));
    expect(copy.title, 'Städel');
    expect(copy.location, 'Schaumainkai 63');
    expect(copy.lat, closeTo(50.103611, 1e-9));
    expect(copy.lon, closeTo(8.674167, 1e-9));
  });

  test('a shared trip arrives with every position it left with', () async {
    final source = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(source.close);

    final tripId = await source.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Frankfurt',
        startDate: Value(DateTime(2026, 5, 1)),
        endDate: Value(DateTime(2026, 5, 2)),
      ),
    );
    await source.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: DateTime(2026, 5, 1),
        kind: ItemKind.place,
        title: const Value('Städel'),
        lat: const Value(50.103611),
        lon: const Value(8.674167),
      ),
    );
    await source.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: DateTime(2026, 5, 1),
        kind: ItemKind.transport,
        mode: const Value(6),
        fromLocation: const Value('Hamburg Hbf'),
        toLocation: const Value('Frankfurt(Main) Hbf'),
        fromLat: const Value(53.552736),
        fromLon: const Value(10.006909),
        toLat: const Value(50.107145),
        toLon: const Value(8.663789),
      ),
    );

    final bundle = await source.sharingDao.exportTrip(tripId);
    // Through the wire and back, not just through the object: the coordinates
    // have to survive JSON, where a whole-numbered double is the usual trap.
    final received = await db.sharingDao.importTrip(
      TripBundle.decode(bundle!.encode()),
    );

    final items = await db.itineraryDao.watchItemsForTrip(received).first;
    final place = items.firstWhere((i) => i.kind == ItemKind.place);
    final leg = items.firstWhere((i) => i.kind == ItemKind.transport);

    expect(place.lat, closeTo(50.103611, 1e-9));
    expect(place.lon, closeTo(8.674167, 1e-9));
    expect(leg.fromLat, closeTo(53.552736, 1e-9));
    expect(leg.fromLon, closeTo(10.006909, 1e-9));
    expect(leg.toLat, closeTo(50.107145, 1e-9));
    expect(leg.toLon, closeTo(8.663789, 1e-9));
  });

  test('a whole-numbered coordinate survives the encoding', () async {
    final tripId = await seedTrip();
    await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: DateTime(2026, 5, 1),
        kind: ItemKind.place,
        title: const Value('Null Island'),
        lat: const Value(0),
        lon: const Value(0),
      ),
    );

    final bundle = await db.sharingDao.exportTrip(tripId);
    final decoded = TripBundle.decode(bundle!.encode());
    final place = decoded.items.single;
    expect(place.lat, 0);
    expect(place.lon, 0);
  });

  test('a leg with no position is left without one', () async {
    final tripId = await seedTrip();
    await addLeg(tripId);
    await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: DateTime(2026, 5, 1),
        kind: ItemKind.transport,
        fromLocation: const Value('Rahlstedt'),
        toLocation: const Value('Wandsbek'),
      ),
    );

    final bundle = await db.sharingDao.exportTrip(tripId);
    final received = await db.sharingDao.importTrip(
      TripBundle.decode(bundle!.encode()),
    );
    final items = await db.itineraryDao.watchItemsForTrip(received).first;
    final handEntered = items.firstWhere((i) => i.fromLocation == 'Rahlstedt');
    expect(handEntered.fromLat, isNull);
    expect(handEntered.toLon, isNull);
  });
}
