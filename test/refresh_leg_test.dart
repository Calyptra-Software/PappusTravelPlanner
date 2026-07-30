import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/stopovers.dart';
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

  // Berlin +2 in July: 'A' departs 5 min late, 'B' arrives on time, and the one
  // stop in between is 8 late by the time the train gets there.
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
        'intermediateStops': [
          {
            'name': 'Mid',
            'tz': 'Europe/Berlin',
            'scheduledDeparture': '2026-07-26T14:30:00Z', // 16:30 local
            'departure': '2026-07-26T14:38:00Z', // 16:38, +8
          },
        ],
        'to': {
          'name': 'B',
          'tz': 'Europe/Berlin',
          'scheduledArrival': '2026-07-26T15:00:00Z', // 17:00 local
          'arrival': '2026-07-26T15:00:00Z',
        },
      },
    ],
  });

  Future<ItineraryItem> seedLeg({
    String? sourceTripId,
    List<Stopover> stopovers = const [],
  }) async {
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
        stopovers: Value(encodeStopovers(stopovers)),
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

    expect(updated, LegRefresh.updated);
    final after = await (db.select(
      db.itineraryItems,
    )..where((i) => i.id.equals(item.id))).getSingle();
    expect(after.actualStartMinutes, 16 * 60 + 5); // the +5 delay
    expect(after.actualEndMinutes, 17 * 60); // on time
  });

  test('the stops in between are refreshed with the ends', () async {
    // One tap, one leg — all of it: the stop's delay comes from the same live
    // trip the ends do, so the journey sheet cannot show a fresh departure over
    // stale stops.
    final item = await seedLeg(
      sourceTripId: 'trip-1',
      stopovers: const [Stopover(name: 'Mid', minutes: 16 * 60 + 30)],
    );
    final controller = containerWith(
      _FakeSearch(stopsWithDelay()),
    ).read(transportSearchControllerProvider);

    expect(await controller.refreshLeg(item), LegRefresh.updated);

    final after = await (db.select(
      db.itineraryItems,
    )..where((i) => i.id.equals(item.id))).getSingle();
    expect(decodeStopovers(after.stopovers), [
      const Stopover(name: 'Mid', minutes: 16 * 60 + 30, delayMinutes: 8),
    ]);
    // The plan itself is untouched — a delay is a miss against it, not a new one.
    expect(after.startMinutes, 16 * 60);
  });

  test(
    'a stop the live trip no longer calls at drops its stale delay',
    () async {
      final item = await seedLeg(
        sourceTripId: 'trip-1',
        stopovers: const [
          Stopover(name: 'Mid', minutes: 16 * 60 + 30, delayMinutes: 8),
          // A stop this train no longer makes; its "+12" is last week's news.
          Stopover(name: 'Gone', minutes: 16 * 60 + 45, delayMinutes: 12),
        ],
      );
      final controller = containerWith(
        _FakeSearch(stopsWithDelay()),
      ).read(transportSearchControllerProvider);

      await controller.refreshLeg(item);

      final after = await (db.select(
        db.itineraryItems,
      )..where((i) => i.id.equals(item.id))).getSingle();
      final stops = decodeStopovers(after.stopovers);
      expect(stops[0].delayMinutes, 8);
      // Kept as a stop of the plan, but with nothing claimed about it.
      expect(stops[1].name, 'Gone');
      expect(stops[1].delayMinutes, isNull);
    },
  );

  /// A cancelled trip, exactly as the service reports one: every stop flagged,
  /// and — the trap — `realTime: false`, so there are no live times to read.
  List<TripStop> cancelledStops() => parseTripResponse({
    'legs': [
      {
        'realTime': false,
        'cancelled': true,
        'from': {
          'name': 'A',
          'tz': 'Europe/Berlin',
          'scheduledDeparture': '2026-07-26T14:00:00Z', // 16:00 local
          'cancelled': true,
        },
        'intermediateStops': [],
        'to': {
          'name': 'B',
          'tz': 'Europe/Berlin',
          'scheduledArrival': '2026-07-26T15:00:00Z', // 17:00 local
          'cancelled': true,
        },
      },
    ],
  });

  test('a cancelled service is reported, and no times are invented', () async {
    final item = await seedLeg(sourceTripId: 'trip-1');
    final controller = containerWith(
      _FakeSearch(cancelledStops()),
    ).read(transportSearchControllerProvider);

    // Without this the leg looks like "nothing to update" — the one answer that
    // reads as "all is well" about a train that is not running.
    expect(await controller.refreshLeg(item), LegRefresh.cancelled);

    final after = await (db.select(
      db.itineraryItems,
    )..where((i) => i.id.equals(item.id))).getSingle();
    // A cancelled leg has no actual times: writing one would say it ran.
    expect(after.actualStartMinutes, isNull);
    expect(after.actualEndMinutes, isNull);
  });

  test('a leg with no source trip id is a no-op (no query)', () async {
    final item = await seedLeg(sourceTripId: null);
    // A search that would throw if queried — proving refreshLeg never calls it.
    final controller = containerWith(
      _FakeSearch(const []),
    ).read(transportSearchControllerProvider);

    expect(await controller.refreshLeg(item), LegRefresh.nothing);
    final after = await (db.select(
      db.itineraryItems,
    )..where((i) => i.id.equals(item.id))).getSingle();
    expect(after.actualStartMinutes, isNull);
  });
}
