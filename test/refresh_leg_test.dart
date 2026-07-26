import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/transport_search/application/transport_search.dart';
import 'package:travelplanner/features/transport_search/application/transport_search_controller.dart';
import 'package:travelplanner/features/transport_search/application/transport_search_providers.dart';
import 'package:travelplanner/features/transport_search/data/motis_parser.dart';
import 'package:travelplanner/features/transport_search/domain/journey.dart';
import 'package:travelplanner/features/transport_search/domain/journey_options.dart';
import 'package:travelplanner/features/transport_search/domain/transport_place.dart';

/// A backend that only answers tripStops (all the refresh needs), from a fixed
/// list of stops.
class _FakeSearch implements TransportSearch {
  _FakeSearch(this.stops);
  final List<TripStop> stops;

  @override
  Future<List<TripStop>> tripStops(String tripId) async => stops;

  @override
  Future<List<TransportPlace>> searchPlaces(String query) =>
      throw UnimplementedError();
  @override
  Future<JourneyResults> journeys({
    required String fromId,
    required String toId,
    required DateTime time,
    bool arriveBy = false,
    JourneySearchOptions options = const JourneySearchOptions(),
    String? pageCursor,
  }) => throw UnimplementedError();
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  late AppDatabase db;
  late TripRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
  });
  tearDown(() => db.close());

  // Berlin +2 in July: 'A' departs 5 min late, 'B' arrives on time.
  List<TripStop> stopsWithDelay() => parseTripResponse({
    'legs': [
      {
        'realTime': true,
        'from': {
          'name': 'A',
          'tz': 'Europe/Berlin',
          'scheduledDeparture': '2026-07-26T14:00:00Z', // 16:00 local
          'departure': '2026-07-26T14:05:00Z', // 16:05, +5
        },
        'intermediateStops': [],
        'to': {
          'name': 'B',
          'tz': 'Europe/Berlin',
          'scheduledArrival': '2026-07-26T15:00:00Z', // 17:00 local
          'arrival': '2026-07-26T15:00:00Z',
        },
      },
    ],
  });

  Future<ItineraryItem> seedLeg({String? sourceTripId}) async {
    final tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(title: 'T'),
    );
    final id = await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: DateTime(2026, 7, 26),
        kind: ItemKind.transport,
        sortOrder: const Value(0),
        fromLocation: const Value('A'),
        toLocation: const Value('B'),
        startMinutes: const Value(16 * 60), // 16:00
        endMinutes: const Value(17 * 60), // 17:00
        sourceTripId: Value(sourceTripId),
      ),
    );
    return (db.select(
      db.itineraryItems,
    )..where((i) => i.id.equals(id))).getSingle();
  }

  ProviderContainer containerWith(TransportSearch search) {
    final c = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        transportSearchProvider.overrideWithValue(search),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('writes the actual times read from the live trip', () async {
    final item = await seedLeg(sourceTripId: 'trip-1');
    final controller = containerWith(
      _FakeSearch(stopsWithDelay()),
    ).read(transportSearchControllerProvider);

    final updated = await controller.refreshLeg(item);

    expect(updated, isTrue);
    final after = await (db.select(
      db.itineraryItems,
    )..where((i) => i.id.equals(item.id))).getSingle();
    expect(after.actualStartMinutes, 16 * 60 + 5); // the +5 delay
    expect(after.actualEndMinutes, 17 * 60); // on time
  });

  test('a leg with no source trip id is a no-op (no query)', () async {
    final item = await seedLeg(sourceTripId: null);
    // A search that would throw if queried — proving refreshLeg never calls it.
    final controller = containerWith(
      _FakeSearch(const []),
    ).read(transportSearchControllerProvider);

    expect(await controller.refreshLeg(item), isFalse);
    final after = await (db.select(
      db.itineraryItems,
    )..where((i) => i.id.equals(item.id))).getSingle();
    expect(after.actualStartMinutes, isNull);
  });
}
