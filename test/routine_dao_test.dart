import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/core/format/civil_date.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';

import 'currency_fixture.dart';

/// A routine's occurrences are virtual until one is touched. These cover what
/// happens at that moment — what travels into the outing, and what deliberately
/// does not.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> makeRoutine({String title = 'To work'}) => db.tripDao.createTrip(
    TripsCompanion.insert(
      title: title,
      destination: const Value('Office'),
      kind: const Value(TripKind.routine),
    ),
  );

  Future<int> makeLeg(
    int tripId, {
    String from = 'Home',
    String to = 'Office',
    int? start,
    int? end,
    int sortOrder = 0,
    int? alternativeId,
    int dayOffset = 0,
    String? fromPlaceId,
    String? toPlaceId,
  }) => db.itineraryDao.addItem(
    ItineraryItemsCompanion.insert(
      tripId: tripId,
      date: addDays(kRoutineAnchorDay, dayOffset),
      fromPlaceId: Value(fromPlaceId),
      toPlaceId: Value(toPlaceId),
      kind: ItemKind.transport,
      sortOrder: Value(sortOrder),
      alternativeId: Value(alternativeId),
      fromLocation: Value(from),
      toLocation: Value(to),
      startMinutes: Value(start),
      endMinutes: Value(end),
    ),
  );

  group('materializeRoutine', () {
    test('writes an outing on the day, carrying the plan', () async {
      final routineId = await makeRoutine();
      await makeLeg(routineId, start: 462, end: 495);
      await makeLeg(routineId, from: 'Office', to: 'Desk', sortOrder: 1);

      final outingId = await db.routineDao.materializeRoutine(
        routineId,
        startDate: DateTime(2026, 7, 31, 8, 12),
      );

      final outing = await db.tripDao.findTrip(outingId);
      expect(outing!.kind, TripKind.trip);
      expect(outing.title, 'To work');
      expect(outing.destination, 'Office');
      // Both ends are the day, stripped of the time it happened to be called at.
      expect(outing.startDate, DateTime(2026, 7, 31));
      expect(outing.endDate, DateTime(2026, 7, 31));
      // The trip records where it came from, so the app can warn before the
      // same routine is recorded twice on one day.
      expect(outing.fromRoutineId, routineId);

      final items = await db.itineraryDao.watchItemsForTrip(outingId).first;
      expect(items, hasLength(2));
      expect(items.every((i) => i.date == DateTime(2026, 7, 31)), isTrue);
      expect(items.first.fromLocation, 'Home');
      expect(items.first.startMinutes, 462);
    });

    test('leaves the routine untouched', () async {
      final routineId = await makeRoutine();
      await makeLeg(routineId);
      await db.routineDao.materializeRoutine(
        routineId,
        startDate: DateTime(2026, 8),
      );

      final routine = await db.tripDao.findTrip(routineId);
      expect(routine!.kind, TripKind.routine);
      final items = await db.itineraryDao.watchItemsForTrip(routineId).first;
      expect(items, hasLength(1));
      expect(items.single.date, kRoutineAnchorDay);
    });

    test('leaves the routine\'s own costs where they are', () async {
      // The fare is copied (see "a routine carries the fare" below), but the
      // template keeps its own: that is where the price is edited.
      final routineId = await makeRoutine();
      final legId = await makeLeg(routineId);
      await db.costDao.addCost(
        CostsCompanion.insert(
          itemId: Value(legId),
          amountMinor: 4900,
          currency: eurId,
          reason: 'Monatskarte',
        ),
      );

      await db.routineDao.materializeRoutine(
        routineId,
        startDate: DateTime(2026, 8),
      );

      expect(await db.costDao.watchCostsForTrip(routineId).first, hasLength(1));
    });

    test('clones a shared ticket into a group of its own', () async {
      final routineId = await makeRoutine();
      final a = await makeLeg(routineId);
      final b = await makeLeg(routineId, from: 'Change', sortOrder: 1);
      final groupId = await db.groupDao.groupItems(a, b);

      final outingId = await db.routineDao.materializeRoutine(
        routineId,
        startDate: DateTime(2026, 8),
      );

      final items = await db.itineraryDao.watchItemsForTrip(outingId).first;
      final groupIds = items.map((i) => i.groupId).toSet();
      expect(groupIds, hasLength(1));
      // A fresh bundle, not a share of the template's.
      expect(groupIds.single, isNotNull);
      expect(groupIds.single, isNot(groupId));
    });

    test('participants travel with the occurrence', () async {
      final routineId = await makeRoutine();
      await makeLeg(routineId);
      await db.tripDao.addParticipant(routineId, 'Sam');

      final outingId = await db.routineDao.materializeRoutine(
        routineId,
        startDate: DateTime(2026, 8),
      );

      final people = await db.tripDao.watchParticipants(outingId).first;
      expect(people.map((p) => p.name), ['Sam']);
    });

    test(
      'a decision arrives as a decision, still pointed the same way',
      () async {
        final routineId = await makeRoutine();
        final seed = await makeLeg(routineId, to: 'Tram stop');
        // Seeding a decision from an item yields two branches: the one holding
        // that item (chosen) and an empty alternative to fill in.
        final setId = await db.alternativeDao.createSetFromItem(seed);
        final branches = (await db.alternativeDao
            .watchBranchesForTrip(routineId)
            .first)[setId]!;
        final chosen = branches.firstWhere((b) => b.chosen);
        final other = branches.firstWhere((b) => !b.chosen);
        await makeLeg(routineId, to: 'Bike path', alternativeId: other.id);

        final outingId = await db.routineDao.materializeRoutine(
          routineId,
          startDate: DateTime(2026, 8),
        );

        final sets = await db.alternativeDao.watchSetsForTrip(outingId).first;
        expect(sets, hasLength(1));
        final copiedBranches =
            (await db.alternativeDao.watchBranchesForTrip(outingId).first)
                .values
                .single;
        expect(copiedBranches, hasLength(branches.length));
        // Exactly one chosen, and it is the same option the routine was set to.
        expect(copiedBranches.where((b) => b.chosen), hasLength(1));
        expect(
          copiedBranches.firstWhere((b) => b.chosen).sortOrder,
          chosen.sortOrder,
        );
        // The copy's branches are its own, not the template's.
        expect(copiedBranches.map((b) => b.id), isNot(contains(chosen.id)));

        final items = await db.itineraryDao.watchItemsForTrip(outingId).first;
        expect(items.where((i) => i.alternativeId != null), hasLength(2));
      },
    );

    test('refuses a trip that is not a routine', () async {
      final tripId = await db.tripDao.createTrip(
        TripsCompanion.insert(title: 'Rome'),
      );
      expect(
        () => db.routineDao.materializeRoutine(
          tripId,
          startDate: DateTime(2026, 8),
        ),
        throwsArgumentError,
      );
    });
  });

  group('duplicateReversed', () {
    test('reverses the legs and swaps their endpoints', () async {
      final routineId = await makeRoutine();
      await makeLeg(routineId, from: 'Home', to: 'Station', sortOrder: 0);
      await makeLeg(routineId, from: 'Station', to: 'Office', sortOrder: 1);

      final backId = await db.routineDao.duplicateReversed(
        routineId,
        title: 'To work (return)',
      );

      final back = await db.tripDao.findTrip(backId);
      expect(back!.kind, TripKind.routine);

      final items = await db.itineraryDao.watchItemsForTrip(backId).first;
      expect(items.map((i) => (i.fromLocation, i.toLocation)), [
        ('Office', 'Station'),
        ('Station', 'Home'),
      ]);
    });

    test('keeps no times: the way home is not the way out backwards', () async {
      final routineId = await makeRoutine();
      await makeLeg(routineId, start: 462, end: 495);

      final backId = await db.routineDao.duplicateReversed(
        routineId,
        title: 'return',
      );

      final leg =
          (await db.itineraryDao.watchItemsForTrip(backId).first).single;
      expect(leg.startMinutes, isNull);
      expect(leg.endMinutes, isNull);
      expect(leg.stopovers, isNull);
      expect(leg.date, kRoutineAnchorDay);
    });

    test('refuses a trip that is not a routine', () async {
      final tripId = await db.tripDao.createTrip(
        TripsCompanion.insert(title: 'Rome'),
      );
      expect(
        () => db.routineDao.duplicateReversed(tripId, title: 'x'),
        throwsArgumentError,
      );
    });
  });

  group('multi-day routines', () {
    test('day offsets survive onto the target dates', () async {
      final routineId = await makeRoutine();
      await makeLeg(routineId, to: 'Hotel');
      await makeLeg(routineId, from: 'Hotel', to: 'Summit', dayOffset: 1);
      await makeLeg(routineId, from: 'Summit', to: 'Home', dayOffset: 2);

      expect(await db.routineDao.routineDaySpan(routineId), 3);

      final tripId = await db.routineDao.materializeRoutine(
        routineId,
        startDate: DateTime(2026, 7, 30),
      );

      final trip = await db.tripDao.findTrip(tripId);
      expect(trip!.startDate, DateTime(2026, 7, 30));
      expect(trip.endDate, DateTime(2026, 8, 1));

      final items = await db.itineraryDao.watchItemsForTrip(tripId).first;
      expect(items.map((i) => i.date), [
        DateTime(2026, 7, 30),
        DateTime(2026, 7, 31),
        DateTime(2026, 8, 1),
      ]);
    });

    test('the shape holds across a daylight-saving change', () async {
      // Europe/Berlin springs forward on 2026-03-29, so that local day is 23
      // hours: a Duration of days would fall a day short.
      final routineId = await makeRoutine();
      await makeLeg(routineId);
      await makeLeg(routineId, dayOffset: 1);
      await makeLeg(routineId, dayOffset: 2);

      final tripId = await db.routineDao.materializeRoutine(
        routineId,
        startDate: DateTime(2026, 3, 28),
      );

      final items = await db.itineraryDao.watchItemsForTrip(tripId).first;
      expect(items.map((i) => i.date), [
        DateTime(2026, 3, 28),
        DateTime(2026, 3, 29),
        DateTime(2026, 3, 30),
      ]);
    });

    test('an empty routine is still a plan for one day', () async {
      final routineId = await makeRoutine();
      expect(await db.routineDao.routineDaySpan(routineId), 1);

      final tripId = await db.routineDao.materializeRoutine(
        routineId,
        startDate: DateTime(2026, 8, 5),
      );
      final trip = await db.tripDao.findTrip(tripId);
      expect(trip!.startDate, DateTime(2026, 8, 5));
      expect(trip.endDate, DateTime(2026, 8, 5));
    });
  });

  group('tags and provenance', () {
    test('a trip inherits the tags its routine is filed under', () async {
      final routineId = await makeRoutine();
      final commute = await db.tagDao.ensureTag('commute');
      await db.tagDao.setTagsForTrip(routineId, {commute});

      final tripId = await db.routineDao.materializeRoutine(
        routineId,
        startDate: DateTime(2026, 8),
      );

      // The whole point: the trips that would crowd the overview are exactly
      // the ones stamped out of a routine, so they file themselves.
      final tags = await db.tagDao.watchTagsForTrip(tripId).first;
      expect(tags.map((t) => t.name), ['commute']);
    });

    test(
      'tripsFromRoutineOn finds what was already recorded that day',
      () async {
        final routineId = await makeRoutine();
        await db.routineDao.materializeRoutine(
          routineId,
          startDate: DateTime(2026, 8, 3),
        );

        expect(
          await db.routineDao.tripsFromRoutineOn(
            routineId,
            DateTime(2026, 8, 3),
          ),
          hasLength(1),
        );
        // A different day, and a time of day on the same one, are not the same
        // question — the second must still match.
        expect(
          await db.routineDao.tripsFromRoutineOn(
            routineId,
            DateTime(2026, 8, 4),
          ),
          isEmpty,
        );
        expect(
          await db.routineDao.tripsFromRoutineOn(
            routineId,
            DateTime(2026, 8, 3, 17, 40),
          ),
          hasLength(1),
        );
      },
    );

    test('deleting a routine leaves the trips it produced', () async {
      final routineId = await makeRoutine();
      final tripId = await db.routineDao.materializeRoutine(
        routineId,
        startDate: DateTime(2026, 8),
      );

      await db.tripDao.deleteTrip(routineId);

      // A trip that happened does not stop having happened because the template
      // was thrown away — it only loses the pointer back.
      final trip = await db.tripDao.findTrip(tripId);
      expect(trip, isNotNull);
      expect(trip!.fromRoutineId, isNull);
    });
  });

  group('replaceJourneyLegs', () {
    test('swaps the legs but keeps the group and its ticket', () async {
      final routineId = await makeRoutine();
      final tripId = await db.routineDao.materializeRoutine(
        routineId,
        startDate: DateTime(2026, 8),
      );
      final a = await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: DateTime(2026, 8),
          kind: ItemKind.transport,
          fromLocation: const Value('Home'),
          toLocation: const Value('Change'),
        ),
      );
      final b = await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: DateTime(2026, 8),
          kind: ItemKind.transport,
          sortOrder: const Value(1),
          fromLocation: const Value('Change'),
          toLocation: const Value('Office'),
        ),
      );
      final groupId = await db.groupDao.groupItems(a, b);
      await db.costDao.addCost(
        CostsCompanion.insert(
          groupId: Value(groupId),
          amountMinor: 320,
          currency: eurId,
          reason: 'Ticket',
        ),
      );

      await db.routineDao.replaceJourneyLegs(
        tripId,
        oldLegIds: [a, b],
        groupId: groupId,
        legs: [
          ItineraryItemsCompanion.insert(
            tripId: tripId,
            date: DateTime(2026, 8),
            kind: ItemKind.transport,
            fromLocation: const Value('Home'),
            toLocation: const Value('Office'),
            sourceTripId: const Value('live-trip-1'),
          ),
        ],
      );

      final items = await db.itineraryDao.watchItemsForTrip(tripId).first;
      expect(items, hasLength(1));
      // The fresh leg is refreshable, which is the whole point of looking it up.
      expect(items.single.sourceTripId, 'live-trip-1');
      // It is still in the bundle, and the fare is still attached to it.
      expect(items.single.groupId, groupId);
      final costs = await db.costDao.watchCostsForTrip(tripId).first;
      expect(costs.map((c) => c.reason), ['Ticket']);
    });

    /// A leg standing on its own, with a fare of its own — a hand-entered ride,
    /// or one the import left ungrouped because it was a single leg.
    Future<({int tripId, int legId})> looseLeg({int? costMinor}) async {
      final tripId = await db.tripDao.createTrip(
        TripsCompanion.insert(
          title: 'Trip',
          startDate: Value(DateTime(2026, 8)),
          endDate: Value(DateTime(2026, 8)),
        ),
      );
      final legId = await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: DateTime(2026, 8),
          kind: ItemKind.transport,
          fromLocation: const Value('Home'),
          toLocation: const Value('Office'),
          startMinutes: const Value(452),
        ),
      );
      if (costMinor != null) {
        await db.costDao.addCost(
          CostsCompanion.insert(
            itemId: Value(legId),
            amountMinor: costMinor,
            currency: eurId,
            reason: 'Ticket',
          ),
        );
      }
      return (tripId: tripId, legId: legId);
    }

    ItineraryItemsCompanion newLeg(
      int tripId, {
      required String from,
      required String to,
      int dayOffset = 0,
      int? start,
    }) => ItineraryItemsCompanion.insert(
      tripId: tripId,
      date: DateTime(2026, 8, 1 + dayOffset),
      kind: ItemKind.transport,
      fromLocation: Value(from),
      toLocation: Value(to),
      startMinutes: Value(start),
      sourceTripId: const Value('live'),
    );

    test('a run that arrives where there was no group is given one', () async {
      // The timetable answers a one-leg plan with a change: two legs sharing one
      // ticket, which is exactly what a group is for.
      final loose = await looseLeg(costMinor: 480);

      await db.routineDao.replaceJourneyLegs(
        loose.tripId,
        oldLegIds: [loose.legId],
        legs: [
          newLeg(loose.tripId, from: 'Home', to: 'Change', start: 452),
          newLeg(loose.tripId, from: 'Change', to: 'Office', start: 470),
        ],
      );

      final items = await db.itineraryDao.watchItemsForTrip(loose.tripId).first;
      expect(items, hasLength(2));
      final groupId = items.first.groupId;
      expect(groupId, isNotNull, reason: 'the run is one bundle');
      expect(items.every((i) => i.groupId == groupId), isTrue);
      // And the fare rescued off the old leg hangs on that bundle, covering the
      // whole run rather than clinging to its first leg.
      final costs = await db.costDao.watchCostsForTrip(loose.tripId).first;
      expect(costs.single.groupId, groupId);
      expect(costs.single.itemId, isNull);
    });

    test('a single leg is left loose: one leg is no bundle', () async {
      final loose = await looseLeg(costMinor: 480);

      await db.routineDao.replaceJourneyLegs(
        loose.tripId,
        oldLegIds: [loose.legId],
        legs: [newLeg(loose.tripId, from: 'Home', to: 'Office', start: 452)],
      );

      final items = await db.itineraryDao.watchItemsForTrip(loose.tripId).first;
      expect(items.single.groupId, isNull);
      expect(await db.select(db.itemGroups).get(), isEmpty);
      // With no bundle to hold it, the fare rides on the leg itself.
      final costs = await db.costDao.watchCostsForTrip(loose.tripId).first;
      expect(costs.single.itemId, items.single.id);
    });

    test('a replacement that crosses midnight bundles each day', () async {
      final loose = await looseLeg();
      final groupId = await db
          .into(db.itemGroups)
          .insert(
            ItemGroupsCompanion.insert(
              tripId: loose.tripId,
              label: const Value('Heimweg'),
            ),
          );
      await (db.update(db.itineraryItems)
            ..where((i) => i.id.equals(loose.legId)))
          .write(ItineraryItemsCompanion(groupId: Value(groupId)));

      await db.routineDao.replaceJourneyLegs(
        loose.tripId,
        oldLegIds: [loose.legId],
        groupId: groupId,
        legs: [
          newLeg(loose.tripId, from: 'Home', to: 'Change', start: 1380),
          newLeg(
            loose.tripId,
            from: 'Change',
            to: 'Office',
            dayOffset: 1,
            start: 30,
          ),
        ],
      );

      final items = await db.itineraryDao.watchItemsForTrip(loose.tripId).first;
      expect(items, hasLength(2));
      final first = items.firstWhere((i) => i.date == DateTime(2026, 8));
      final second = items.firstWhere((i) => i.date == DateTime(2026, 8, 2));
      // The surviving group keeps the evening — with the ticket that hangs on it
      // — and the small hours are not dragged into it: a group may not straddle
      // two days. A single leg on the far side of midnight is left loose, exactly
      // as importing an overnight journey leaves one.
      expect(first.groupId, groupId);
      expect(second.groupId, isNull);
      // And the trip now admits to the day its journey lands on.
      final trip = await db.tripDao.findTrip(loose.tripId);
      expect(trip!.endDate, DateTime(2026, 8, 2));
      expect(
        trip.startDate,
        DateTime(2026, 8),
        reason: 'the near end is unmoved',
      );
    });
  });

  group('a routine whose entries carry real dates', () {
    // Regression: importing a connection into a routine dated its legs by the
    // *search* date rather than by the routine's own day one, so the span read
    // as the fifty-odd years since the anchor and a one-day routine stamped out
    // a trip ending in 2083.
    test('spans the days it shows, not the years since the anchor', () async {
      final routineId = await makeRoutine();
      await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: routineId,
          date: DateTime(2026, 8, 3),
          kind: ItemKind.transport,
          fromLocation: const Value('Home'),
          toLocation: const Value('Office'),
        ),
      );

      expect(await db.routineDao.routineDaySpan(routineId), 1);

      final tripId = await db.routineDao.materializeRoutine(
        routineId,
        startDate: DateTime(2026, 8, 1),
      );
      final trip = await db.tripDao.findTrip(tripId);
      expect(trip!.startDate, DateTime(2026, 8, 1));
      expect(trip.endDate, DateTime(2026, 8, 1));

      final items = await db.itineraryDao.watchItemsForTrip(tripId).first;
      expect(items.single.date, DateTime(2026, 8, 1));
    });

    test('several such days keep their order and their gaps close up', () async {
      // The timeline shows a routine's days as the days its entries occupy, so
      // the span must be the same count — whatever absolute dates they carry.
      final routineId = await makeRoutine();
      for (final date in [
        DateTime(2026, 8, 3),
        DateTime(2026, 8, 4),
        DateTime(2026, 8, 9),
      ]) {
        await db.itineraryDao.addItem(
          ItineraryItemsCompanion.insert(
            tripId: routineId,
            date: date,
            kind: ItemKind.transport,
          ),
        );
      }

      expect(await db.routineDao.routineDaySpan(routineId), 3);

      final tripId = await db.routineDao.materializeRoutine(
        routineId,
        startDate: DateTime(2026, 9, 10),
      );
      final items = await db.itineraryDao.watchItemsForTrip(tripId).first;
      expect(items.map((i) => i.date), [
        DateTime(2026, 9, 10),
        DateTime(2026, 9, 11),
        DateTime(2026, 9, 12),
      ]);
      expect(
        (await db.tripDao.findTrip(tripId))!.endDate,
        DateTime(2026, 9, 12),
      );
    });
  });

  group('replaceJourneyLegs keeps the run in its place', () {
    /// A day holding an imported run of [legCount] legs followed by one
    /// hand-added place. Returns the leg ids and the group they share.
    Future<({int tripId, List<int> legIds, int groupId})> dayWithRunThenPlace(
      int legCount,
    ) async {
      final tripId = await db.tripDao.createTrip(
        TripsCompanion.insert(title: 'Commute'),
      );
      final day = DateTime(2026, 8, 3);
      final legIds = <int>[];
      for (var i = 0; i < legCount; i++) {
        legIds.add(
          await db.itineraryDao.addItem(
            ItineraryItemsCompanion.insert(
              tripId: tripId,
              date: day,
              kind: ItemKind.transport,
              sortOrder: Value(i),
              fromLocation: Value('Stop $i'),
              toLocation: Value('Stop ${i + 1}'),
            ),
          ),
        );
      }
      // Added by hand afterwards, and so *after* the run in the day.
      await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: day,
          kind: ItemKind.place,
          sortOrder: Value(legCount),
          location: const Value('Desk'),
        ),
      );
      final groupId = await db.groupDao.groupItems(legIds[0], legIds[1]);
      return (tripId: tripId, legIds: legIds, groupId: groupId);
    }

    Future<List<String>> dayOrder(int tripId) async {
      final items = await db.itineraryDao.watchItemsForTrip(tripId).first;
      items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return [
        for (final i in items)
          i.location ?? '${i.fromLocation}>${i.toLocation}',
      ];
    }

    ItineraryItemsCompanion freshLeg(int tripId, int index) =>
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: DateTime(2026, 8, 3),
          kind: ItemKind.transport,
          fromLocation: Value('New $index'),
          toLocation: Value('New ${index + 1}'),
        );

    test('a shorter connection still sits before what followed it', () async {
      final setup = await dayWithRunThenPlace(2);
      await db.routineDao.replaceJourneyLegs(
        setup.tripId,
        oldLegIds: setup.legIds,
        groupId: setup.groupId,
        legs: [freshLeg(setup.tripId, 0)],
      );
      // Regression: the fresh legs used to be appended to the end of the day,
      // putting the hand-added place *before* the journey it comes after.
      expect(await dayOrder(setup.tripId), ['New 0>New 1', 'Desk']);
    });

    test(
      'a longer connection pushes what followed it out of the way',
      () async {
        final setup = await dayWithRunThenPlace(2);
        await db.routineDao.replaceJourneyLegs(
          setup.tripId,
          oldLegIds: setup.legIds,
          groupId: setup.groupId,
          legs: [
            freshLeg(setup.tripId, 0),
            freshLeg(setup.tripId, 1),
            freshLeg(setup.tripId, 2),
          ],
        );
        expect(await dayOrder(setup.tripId), [
          'New 0>New 1',
          'New 1>New 2',
          'New 2>New 3',
          'Desk',
        ]);
      },
    );

    test('a run that was not first keeps its middle slot', () async {
      final tripId = await db.tripDao.createTrip(
        TripsCompanion.insert(title: 'Commute'),
      );
      final day = DateTime(2026, 8, 3);
      await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: day,
          kind: ItemKind.place,
          sortOrder: const Value(0),
          location: const Value('Home'),
        ),
      );
      final a = await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: day,
          kind: ItemKind.transport,
          sortOrder: const Value(1),
          fromLocation: const Value('Home'),
          toLocation: const Value('Change'),
        ),
      );
      final b = await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: day,
          kind: ItemKind.transport,
          sortOrder: const Value(2),
          fromLocation: const Value('Change'),
          toLocation: const Value('Office'),
        ),
      );
      await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: day,
          kind: ItemKind.place,
          sortOrder: const Value(3),
          location: const Value('Desk'),
        ),
      );
      final groupId = await db.groupDao.groupItems(a, b);

      await db.routineDao.replaceJourneyLegs(
        tripId,
        oldLegIds: [a, b],
        groupId: groupId,
        legs: [freshLeg(tripId, 0)],
      );

      expect(await dayOrder(tripId), ['Home', 'New 0>New 1', 'Desk']);
    });
  });

  group('a routine carries the fare', () {
    Future<int> costOn(
      int tripId, {
      int? itemId,
      int? groupId,
      int minor = 320,
      String reason = 'Ticket',
      bool isTransfer = false,
      String? paidBy,
    }) => db.costDao.addCost(
      CostsCompanion.insert(
        itemId: Value(itemId),
        groupId: Value(groupId),
        tripId: Value(itemId == null && groupId == null ? tripId : null),
        amountMinor: minor,
        currency: eurId,
        reason: reason,
        isTransfer: Value(isTransfer),
        paidBy: Value(paidBy),
        paid: const Value(true),
      ),
    );

    test('a fare on the routine is on every trip stamped out of it', () async {
      // The whole reason to price a routine: otherwise the number sits on a
      // template and is never counted anywhere.
      final routineId = await makeRoutine();
      await makeLeg(routineId);
      await costOn(routineId, minor: 4900, reason: 'Monatskarte');

      final tripId = await db.routineDao.materializeRoutine(
        routineId,
        startDate: DateTime(2026, 8),
      );

      final copied = await db.costDao.watchCostsForTrip(tripId).first;
      expect(copied.map((c) => c.reason), ['Monatskarte']);
      expect(copied.single.amountMinor, 4900);
      // Paying is something an occurrence does, not something a plan records —
      // the same rule as a copied checklist arriving unticked.
      expect(copied.single.paid, isFalse);
    });

    test('a fare on a leg and on a group both come across', () async {
      final routineId = await makeRoutine();
      final a = await makeLeg(routineId);
      final b = await makeLeg(routineId, from: 'Change', sortOrder: 1);
      final groupId = await db.groupDao.groupItems(a, b);
      final lone = await makeLeg(routineId, from: 'Bus', sortOrder: 2);
      await costOn(routineId, groupId: groupId, minor: 320, reason: 'Ticket');
      await costOn(routineId, itemId: lone, minor: 150, reason: 'Bus');

      final tripId = await db.routineDao.materializeRoutine(
        routineId,
        startDate: DateTime(2026, 8),
      );

      final copied = await db.costDao.watchCostsForTrip(tripId).first;
      expect(copied.map((c) => c.reason).toSet(), {'Ticket', 'Bus'});
      // Each hangs off the *copy* of what it was attached to, never the
      // routine's own rows.
      final items = await db.itineraryDao.watchItemsForTrip(tripId).first;
      final newGroupIds = {for (final i in items) i.groupId}..remove(null);
      final ticket = copied.firstWhere((c) => c.reason == 'Ticket');
      expect(newGroupIds, contains(ticket.groupId));
      expect(ticket.groupId, isNot(groupId));
      final bus = copied.firstWhere((c) => c.reason == 'Bus');
      expect(items.map((i) => i.id), contains(bus.itemId));
      expect(bus.itemId, isNot(lone));
    });

    test('a settlement is left behind', () async {
      final routineId = await makeRoutine();
      await makeLeg(routineId);
      await costOn(routineId, isTransfer: true, reason: '', paidBy: 'Sam');

      final tripId = await db.routineDao.materializeRoutine(
        routineId,
        startDate: DateTime(2026, 8),
      );

      // A repayment squares up one trip; a template cannot be owed.
      expect(await db.costDao.watchCostsForTrip(tripId).first, isEmpty);
    });

    test('the split travels with the fare', () async {
      final routineId = await makeRoutine();
      await makeLeg(routineId);
      final costId = await costOn(routineId, minor: 640);
      await db.costDao.setBeneficiaries(costId, ['Sam']);

      final tripId = await db.routineDao.materializeRoutine(
        routineId,
        startDate: DateTime(2026, 8),
      );

      final copied = (await db.costDao.watchCostsForTrip(tripId).first).single;
      final people = await db.costDao.watchBeneficiaries(copied.id).first;
      expect(people.map((p) => p.name), ['Sam']);
    });

    test('looking a journey up keeps the fare that was on its leg', () async {
      // A single-leg commute has no group to hang its fare on, so without a
      // rescue the price would vanish the moment its connection was refreshed.
      final routineId = await makeRoutine();
      await makeLeg(routineId, fromPlaceId: 'stop:a', toPlaceId: 'stop:b');
      final tripId = await db.routineDao.materializeRoutine(
        routineId,
        startDate: DateTime(2026, 8),
      );
      final leg =
          (await db.itineraryDao.watchItemsForTrip(tripId).first).single;
      await costOn(tripId, itemId: leg.id, minor: 290, reason: 'Fahrschein');

      await db.routineDao.replaceJourneyLegs(
        tripId,
        oldLegIds: [leg.id],
        legs: [
          ItineraryItemsCompanion.insert(
            tripId: tripId,
            date: DateTime(2026, 8),
            kind: ItemKind.transport,
            fromLocation: const Value('Home'),
            toLocation: const Value('Office'),
            sourceTripId: const Value('live-1'),
          ),
        ],
      );

      final after = await db.costDao.watchCostsForTrip(tripId).first;
      expect(after.map((c) => c.reason), ['Fahrschein']);
      final fresh =
          (await db.itineraryDao.watchItemsForTrip(tripId).first).single;
      expect(after.single.itemId, fresh.id);
    });
  });
  group('a routine carries its checklists', () {
    Future<int> makeList(int tripId, String title, List<String> entries) async {
      final id = await db.checklistDao.addChecklist(
        ChecklistsCompanion.insert(tripId: tripId, title: Value(title)),
      );
      for (final entry in entries) {
        await db.checklistDao.addItem(
          ChecklistItemsCompanion.insert(checklistId: id, label: entry),
        );
      }
      return id;
    }

    test('the list travels, and arrives unticked', () async {
      final routineId = await makeRoutine();
      final listId = await makeList(routineId, 'Take with', [
        'Badge',
        'Laptop',
      ]);
      // Ticked on the template — which says nothing about this morning.
      final entries = await db.checklistDao.watchItems(listId).first;
      await db.checklistDao.updateItem(entries.first.copyWith(done: true));

      final tripId = await db.routineDao.materializeRoutine(
        routineId,
        startDate: DateTime(2026, 8, 3),
      );

      final lists = await db.checklistDao.watchChecklists(tripId).first;
      expect(lists, hasLength(1));
      expect(lists.single.title, 'Take with');
      expect(
        lists.single.id,
        isNot(listId),
        reason: 'a copy, not the template',
      );
      final copied = await db.checklistDao.watchItems(lists.single.id).first;
      expect(copied.map((i) => i.label), ['Badge', 'Laptop']);
      expect(
        copied.every((i) => !i.done),
        isTrue,
        reason: 'packing is the trip\'s',
      );

      // And the routine keeps its own, ticks included.
      final template = await db.checklistDao.watchChecklists(routineId).first;
      expect(template, hasLength(1));
      expect(template.single.id, listId);
      expect(
        (await db.checklistDao.watchItems(listId).first).first.done,
        isTrue,
      );
    });

    test('several lists keep the order the routine keeps them in', () async {
      final routineId = await makeRoutine();
      await makeList(routineId, 'Morning', ['Badge']);
      await makeList(routineId, 'Evening', ['Bottle']);

      final tripId = await db.routineDao.materializeRoutine(
        routineId,
        startDate: DateTime(2026, 8, 3),
      );

      final lists = await db.checklistDao.watchChecklists(tripId).first;
      expect(lists.map((c) => c.title), ['Morning', 'Evening']);
    });

    test('a routine with no lists gives a trip with none', () async {
      final routineId = await makeRoutine();
      final tripId = await db.routineDao.materializeRoutine(
        routineId,
        startDate: DateTime(2026, 8, 3),
      );

      expect(await db.checklistDao.watchChecklists(tripId).first, isEmpty);
    });
  });
}
