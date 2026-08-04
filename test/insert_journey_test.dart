import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/transport_search/data/journey_mapper.dart';

void main() {
  late AppDatabase db;
  late TripRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
  });
  tearDown(() => db.close());

  final dayA = DateTime(2026, 7, 27);
  final dayB = DateTime(2026, 7, 28);

  MappedLeg leg(
    DateTime date, {
    int? modeId = 6,
    bool spansNextDay = false,
    int startMinutes = 600,
    int endMinutes = 700,
    int? actualStartMinutes,
    int? actualEndMinutes,
    String? notes,
    String? sourceTripId,
  }) => MappedLeg(
    date: date,
    startMinutes: startMinutes,
    endMinutes: endMinutes,
    actualStartMinutes: actualStartMinutes,
    actualEndMinutes: actualEndMinutes,
    spansNextDay: spansNextDay,
    modeId: modeId,
    title: 'ICE 1',
    notes: notes,
    sourceTripId: sourceTripId,
    fromLocation: 'A',
    toLocation: 'B',
    fromLat: 53.5,
    fromLon: 10.0,
    toLat: 48.1,
    toLon: 11.6,
  );

  Future<int> makeTrip() =>
      db.tripDao.createTrip(TripsCompanion.insert(title: 'T'));

  Future<ItineraryItem> read(int id) =>
      (db.select(db.itineraryItems)..where((i) => i.id.equals(id))).getSingle();

  List<ItineraryItemsCompanion> companions(int tripId, List<MappedLeg> legs) =>
      [for (final l in legs) mappedLegToCompanion(tripId, l)];

  test('inserts each leg as a transport item, appended per day', () async {
    final tripId = await makeTrip();
    final ids = await repo.insertJourney(
      tripId,
      companions(tripId, [leg(dayA), leg(dayA), leg(dayB)]),
    );

    expect(ids, hasLength(3));
    final items = [for (final id in ids) await read(id)];
    expect(items.every((i) => i.kind == ItemKind.transport), isTrue);
    // Two legs on day A get 0,1; the day-B leg starts its own day at 0.
    expect(items.map((i) => i.date), [dayA, dayA, dayB]);
    expect(items.map((i) => i.sortOrder), [0, 1, 0]);
    expect(items[0].fromLat, 53.5); // coordinates carried through
    expect(items[0].toLon, 11.6);
  });

  test(
    'bundles each same-day run into one group, leaving singles loose',
    () async {
      final tripId = await makeTrip();
      final ids = await repo.insertJourney(
        tripId,
        companions(tripId, [leg(dayA), leg(dayA), leg(dayB)]),
      );
      final items = [for (final id in ids) await read(id)];

      // The two day-A legs share a group; the lone day-B leg stays ungrouped.
      expect(items[0].groupId, isNotNull);
      expect(items[1].groupId, items[0].groupId);
      expect(items[2].groupId, isNull);
      final groups = await db.groupDao.watchGroupsForTrip(tripId).first;
      expect(groups, hasLength(1));
    },
  );

  test('two same-day runs become two groups', () async {
    final tripId = await makeTrip();
    final ids = await repo.insertJourney(
      tripId,
      companions(tripId, [leg(dayA), leg(dayA), leg(dayB), leg(dayB)]),
    );
    final items = [for (final id in ids) await read(id)];

    expect(items[0].groupId, items[1].groupId);
    expect(items[2].groupId, items[3].groupId);
    expect(items[0].groupId, isNot(items[2].groupId));
    final groups = await db.groupDao.watchGroupsForTrip(tripId).first;
    expect(groups, hasLength(2));
  });

  test('group: false inserts the legs without grouping', () async {
    final tripId = await makeTrip();
    final ids = await repo.insertJourney(
      tripId,
      companions(tripId, [leg(dayA), leg(dayA)]),
      group: false,
    );
    final items = [for (final id in ids) await read(id)];
    expect(items.every((i) => i.groupId == null), isTrue);
  });

  test('preserves the overnight flag on a leg', () async {
    final tripId = await makeTrip();
    final ids = await repo.insertJourney(
      tripId,
      companions(tripId, [leg(dayA, spansNextDay: true)]),
      group: false,
    );
    expect((await read(ids.single)).spansNextDay, isTrue);
  });

  test('persists the composed notes (direction/platform)', () async {
    final tripId = await makeTrip();
    final ids = await repo.insertJourney(
      tripId,
      companions(tripId, [leg(dayA, notes: 'to München Hbf · Pl. 20')]),
      group: false,
    );
    expect((await read(ids.single)).notes, 'to München Hbf · Pl. 20');
  });

  test('persists the source trip id (for live refresh)', () async {
    final tripId = await makeTrip();
    final ids = await repo.insertJourney(
      tripId,
      companions(tripId, [leg(dayA, sourceTripId: 'trip-42')]),
      group: false,
    );
    expect((await read(ids.single)).sourceTripId, 'trip-42');
  });

  test(
    'into an option the legs land in it, after what it already holds',
    () async {
      final tripId = await makeTrip();
      // An option with one entry already planned in it.
      final walk = await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: dayA,
          kind: ItemKind.place,
        ),
      );
      final setId = await db.alternativeDao.createSetFromItem(walk);
      final branchId =
          (await db.alternativeDao.watchBranchesForTrip(tripId).first)[setId]!
              .first
              .id;
      // A loose entry on the same day, whose ordering space the option's does not
      // share — appending to the day would have put the run after this instead.
      await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: dayA,
          kind: ItemKind.place,
          sortOrder: const Value(9),
        ),
      );

      final ids = await repo.insertJourney(
        tripId,
        companions(tripId, [leg(dayA), leg(dayB)]),
        alternativeId: branchId,
      );

      final items = [for (final id in ids) await read(id)];
      expect(items.every((i) => i.alternativeId == branchId), isTrue);
      // One sequence, not one per day: inside an option a leg's date does not
      // place it in a day, so an overnight run stays a single ordered run after
      // the entry the option already held.
      expect(items.map((i) => i.sortOrder), [1, 2]);
      expect(items.map((i) => i.date), [dayA, dayB]);
    },
  );
}
