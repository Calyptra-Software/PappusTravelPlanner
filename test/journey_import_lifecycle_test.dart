import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/transport_search/application/transport_search_controller.dart';
import 'package:travelplanner/features/transport_search/domain/journey.dart';
import 'package:travelplanner/features/transport_search/domain/transit_mode.dart';
import 'package:travelplanner/features/trips/planned_journey.dart';

/// Importing a connection must not depend on **what is on screen**.
///
/// The modes a leg's kind is resolved against used to be read through
/// `transportModesProvider`, which is `autoDispose`: with no widget watching it
/// — the trips overview, the routine list — it was disposed while its query was
/// still in flight and the read threw. Stamping a trip out of a routine from the
/// overview therefore failed on the first accepted connection, left the legs a
/// copied plan with no `sourceTripId` to refresh, and never offered the
/// journeys after it. Nothing here listens to that provider, which is the whole
/// point of the test.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late TransportSearchController controller;

  final day = DateTime(2026, 8, 3);

  setUpAll(tzdata.initializeTimeZones);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(TripRepository(db))],
    );
    controller = container.read(transportSearchControllerProvider);
    await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Büro',
        startDate: Value(day),
        endDate: Value(day),
      ),
    );
  });
  tearDown(() {
    container.dispose();
    db.close();
  });

  /// A one-leg train journey, as the router hands one back: UTC instants plus
  /// the stop's zone.
  JourneyOption option({String tripId = 'run-1'}) {
    final leg = JourneyLeg(
      mode: TransitMode.regionalRail,
      line: 'RB81',
      tripId: tripId,
      realTime: false,
      from: LegPoint(
        name: 'Rahlstedt',
        scheduled: DateTime.utc(2026, 8, 3, 5, 32),
        timeZone: 'Europe/Berlin',
      ),
      to: LegPoint(
        name: 'Hamburg Hbf',
        scheduled: DateTime.utc(2026, 8, 3, 5, 48),
        timeZone: 'Europe/Berlin',
      ),
    );
    return JourneyOption(
      departure: leg.from.scheduled,
      arrival: leg.to.scheduled,
      duration: leg.to.scheduled.difference(leg.from.scheduled),
      transfers: 0,
      legs: [leg],
    );
  }

  test('an import resolves its modes with nothing watching them', () async {
    final ids = await controller.importJourney(1, option());

    expect(ids, hasLength(1));
    final leg = await (db.select(
      db.itineraryItems,
    )..where((i) => i.id.equals(ids.single))).getSingle();
    expect(leg.sourceTripId, 'run-1', reason: 'the leg must be refreshable');
    // Resolved against the seeded built-ins, not left unassigned.
    expect(leg.mode, isNotNull);
  });

  test('replacing a copied plan works the same way', () async {
    final planId = await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: 1,
        date: day,
        kind: ItemKind.transport,
        title: const Value('RB81'),
        startMinutes: const Value(452),
        endMinutes: const Value(468),
        fromLocation: const Value('Rahlstedt'),
        toLocation: const Value('Hamburg Hbf'),
      ),
    );
    final plan = await (db.select(
      db.itineraryItems,
    )..where((i) => i.id.equals(planId))).getSingle();

    await controller.replaceJourney(
      1,
      journey: PlannedJourney(groupId: null, legs: [plan]),
      option: option(tripId: 'run-2'),
      labels: (
        track: (t) => 'Pl. $t',
        fromTrack: (t) => 'from Pl. $t',
        toTrack: (t) => 'to Pl. $t',
        direction: (d) => '→ $d',
      ),
    );

    final legs = await (db.select(
      db.itineraryItems,
    )..where((i) => i.tripId.equals(1))).get();
    expect(legs, hasLength(1), reason: 'the plan leg was replaced, not kept');
    expect(legs.single.sourceTripId, 'run-2');
    expect(legs.single.mode, isNotNull);
  });
}
