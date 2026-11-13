import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/trips/application/trip_connections_controller.dart';

/// Which journeys of a stored trip are offered a fresh connection, read from a
/// real database: the mode table resolved, the chosen option applied.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late int tripId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(TripRepository(db))],
    );
    tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Ski',
        startDate: Value(DateTime(2027, 3, 1)),
      ),
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<int> modeId(TransportMode mode) async {
    final rows = await db.select(db.transportModes).get();
    return rows.singleWhere((r) => r.builtinKey == mode.name).id;
  }

  Future<int> addLeg(
    String title,
    TransportMode mode, {
    int start = 480,
  }) async => db.itineraryDao.addItem(
    ItineraryItemsCompanion.insert(
      tripId: tripId,
      date: DateTime(2027, 3, 1),
      kind: ItemKind.transport,
      title: Value(title),
      startMinutes: Value(start),
      fromPlaceId: const Value('stop:a'),
      toPlaceId: const Value('stop:b'),
      mode: Value(await modeId(mode)),
    ),
  );

  Future<List<String?>> offered() async => [
    for (final journey
        in await container
            .read(tripConnectionsControllerProvider)
            .lookUpCandidates(tripId))
      journey.legs.first.title,
  ];

  test('a train is offered; ski, flight, taxi and a walk are not', () async {
    await addLeg('Train', TransportMode.train, start: 480);
    await addLeg('Descent', TransportMode.ski, start: 600);
    await addLeg('Flight', TransportMode.flight, start: 700);
    await addLeg('Taxi', TransportMode.taxi, start: 800);
    await addLeg('Walk', TransportMode.walk, start: 900);

    expect(await offered(), ['Train']);
  });

  test('a journey in an option not chosen is not offered', () async {
    final bus = await addLeg('Bus', TransportMode.bus);
    await addLeg('Train', TransportMode.train, start: 600);
    // The bus becomes the chosen option of a decision; its second option is
    // empty. Choosing that one leaves the bus as a road not taken.
    final setId = await db.alternativeDao.createSetFromItem(bus);
    final branches =
        await (db.select(db.alternatives)
              ..where((a) => a.setId.equals(setId))
              ..orderBy([(a) => OrderingTerm(expression: a.sortOrder)]))
            .get();
    expect(await offered(), ['Bus', 'Train']);

    await db.alternativeDao.chooseAlternative(branches.last.id);
    expect(await offered(), ['Train']);
  });
}
