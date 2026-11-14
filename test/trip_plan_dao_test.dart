import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/stopovers.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/attachments/attachment_import.dart';

import 'currency_fixture.dart';
import 'support/dst.dart';

/// A trip's plan put onto other dates: copied as a new trip, or moved in place.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> makeTrip({
    String title = 'Lisbon',
    DateTime? start,
    DateTime? end,
  }) => db.tripDao.createTrip(
    TripsCompanion.insert(
      title: title,
      destination: const Value('Portugal'),
      notes: const Value('Pastéis'),
      colorValue: const Value(0xFF123456),
      startDate: Value(start),
      endDate: Value(end ?? start),
    ),
  );

  Future<int> makeEntry(
    int tripId,
    DateTime date, {
    String title = 'Stop',
    int sortOrder = 0,
  }) => db.itineraryDao.addItem(
    ItineraryItemsCompanion.insert(
      tripId: tripId,
      date: date,
      kind: ItemKind.place,
      title: Value(title),
      sortOrder: Value(sortOrder),
    ),
  );

  Future<List<ItineraryItem>> entriesOf(int tripId) =>
      db.itineraryDao.watchItemsForTrip(tripId).first;

  group('duplicateTrip', () {
    test('every day moves by the same distance, free days included', () async {
      final tripId = await makeTrip(
        start: DateTime(2026, 5, 1),
        end: DateTime(2026, 5, 6),
      );
      await makeEntry(tripId, DateTime(2026, 5, 1), title: 'Arrive');
      // The 2nd is a free day, and the 6th is left open at the end.
      await makeEntry(tripId, DateTime(2026, 5, 3), title: 'Sintra');
      await makeEntry(tripId, DateTime(2026, 5, 5), title: 'Leave');

      final copyId = await db.tripPlanDao.duplicateTrip(
        tripId,
        title: 'Lisbon again',
        startDate: DateTime(2026, 6, 10, 15, 30),
      );

      final copy = await db.tripDao.findTrip(copyId);
      expect(copy!.title, 'Lisbon again');
      expect(copy.kind, TripKind.trip);
      expect(copy.destination, 'Portugal');
      expect(copy.notes, 'Pastéis');
      expect(copy.colorValue, 0xFF123456);
      expect(copy.startDate, DateTime(2026, 6, 10));
      expect(
        copy.endDate,
        DateTime(2026, 6, 15),
        reason: 'the open day at the end is part of the trip',
      );
      expect(copy.fromRoutineId, isNull);

      final entries = await entriesOf(copyId);
      expect(
        {for (final e in entries) e.title: e.date},
        {
          'Arrive': DateTime(2026, 6, 10),
          'Sintra': DateTime(2026, 6, 12),
          'Leave': DateTime(2026, 6, 14),
        },
      );

      // The original is untouched.
      final original = await db.tripDao.findTrip(tripId);
      expect(original!.startDate, DateTime(2026, 5, 1));
      expect((await entriesOf(tripId)).map((e) => e.date).toSet(), {
        DateTime(2026, 5, 1),
        DateTime(2026, 5, 3),
        DateTime(2026, 5, 5),
      });
    });

    test('the copy takes the plan, not the money or the files', () async {
      final tripId = await makeTrip(start: DateTime(2026, 5, 1));
      final entryId = await makeEntry(tripId, DateTime(2026, 5, 1));
      await db.costDao.addCost(
        CostsCompanion.insert(
          tripId: Value(tripId),
          amountMinor: 50000,
          currency: eurId,
          reason: 'Hotel',
          paidBy: const Value('Ana'),
          paid: const Value(true),
        ),
      );
      await db.costDao.addCost(
        CostsCompanion.insert(
          itemId: Value(entryId),
          amountMinor: 1200,
          currency: eurId,
          reason: 'Tickets',
        ),
      );
      final pdf = Uint8List.fromList(utf8.encode('%PDF-1.4\n%booking\n'));
      await db.attachmentDao.addAttachment(
        prepareAttachment(
          pdf,
          name: 'booking.pdf',
          kind: AttachmentKind.document,
        ),
        tripId: tripId,
      );
      await db.attachmentDao.addAttachment(
        prepareAttachment(
          pdf,
          name: 'ticket.pdf',
          kind: AttachmentKind.document,
        ),
        itemId: entryId,
      );

      final copyId = await db.tripPlanDao.duplicateTrip(
        tripId,
        title: 'Again',
        startDate: DateTime(2026, 9, 1),
      );

      expect(await db.costDao.watchCostsForTrip(copyId).first, isEmpty);
      expect(
        await db.attachmentDao.watchAttachmentsForTrip(copyId).first,
        isEmpty,
      );
      final copiedEntry = (await entriesOf(copyId)).single;
      expect(
        await db.attachmentDao.watchAttachmentsForItem(copiedEntry.id).first,
        isEmpty,
      );
      // And the original keeps all of it.
      expect(await db.costDao.watchCostsForTrip(tripId).first, hasLength(2));
      expect(
        await db.attachmentDao.watchAttachmentsForTrip(tripId).first,
        hasLength(1),
      );
    });

    test('what the original day recorded stays behind', () async {
      final tripId = await makeTrip(start: DateTime(2026, 5, 1));
      await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: DateTime(2026, 5, 1),
          kind: ItemKind.transport,
          title: const Value('IC 2021'),
          startMinutes: const Value(600),
          endMinutes: const Value(700),
          actualStartMinutes: const Value(612),
          actualEndMinutes: const Value(715),
          sourceTripId: const Value('20260501_10:00_ic2021'),
          fromPlaceId: const Value('id:A'),
          toPlaceId: const Value('id:B'),
          stopovers: Value(
            encodeStopovers(const [
              Stopover(name: 'X', minutes: 630, delayMinutes: 12),
              Stopover(name: 'Y', minutes: 660, cancelled: true),
            ]),
          ),
          runStops: Value(
            encodeRunStops(
              const RunStops(
                before: [Stopover(name: 'W', minutes: 570, delayMinutes: 9)],
              ),
            ),
          ),
        ),
      );

      final copyId = await db.tripPlanDao.duplicateTrip(
        tripId,
        title: 'Again',
        startDate: DateTime(2026, 9, 1),
      );

      final leg = (await entriesOf(copyId)).single;
      // The plan travels…
      expect(leg.startMinutes, 600);
      expect(leg.endMinutes, 700);
      expect(leg.fromPlaceId, 'id:A');
      expect(leg.toPlaceId, 'id:B');
      expect(decodeStopovers(leg.stopovers), const [
        Stopover(name: 'X', minutes: 630),
        Stopover(name: 'Y', minutes: 660),
      ]);
      expect(
        decodeRunStops(leg.runStops),
        const RunStops(before: [Stopover(name: 'W', minutes: 570)]),
      );
      // …but not the one dated run it was, nor how that run went.
      expect(leg.sourceTripId, isNull);
      expect(leg.actualStartMinutes, isNull);
      expect(leg.actualEndMinutes, isNull);
    });

    test(
      'decisions, groups, people, tags, lists and lines come along',
      () async {
        final tripId = await makeTrip(start: DateTime(2026, 5, 1));
        final a = await makeEntry(tripId, DateTime(2026, 5, 1), title: 'A');
        final b = await makeEntry(
          tripId,
          DateTime(2026, 5, 1),
          title: 'B',
          sortOrder: 1,
        );
        await db.groupDao.groupItems(a, b);
        final c = await makeEntry(
          tripId,
          DateTime(2026, 5, 2),
          title: 'Museum',
        );
        await db.alternativeDao.createSetFromItem(c, label: 'Afternoon');
        await db.trackDao.addTracks(a, [
          (
            points: [const LatLng(38.7, -9.1), const LatLng(38.8, -9.2)],
            name: null,
          ),
        ]);
        await db.tripDao.addParticipant(tripId, 'Ana');
        final tagId = await db.tagDao.createTag(
          TagsCompanion.insert(name: 'City'),
        );
        await db.tagDao.setTagsForTrip(tripId, {tagId});
        final listId = await db.checklistDao.addChecklist(
          ChecklistsCompanion.insert(
            tripId: tripId,
            title: const Value('Pack'),
          ),
        );
        await db.checklistDao.addItem(
          ChecklistItemsCompanion.insert(
            checklistId: listId,
            label: 'Passport',
            done: const Value(true),
          ),
        );

        final copyId = await db.tripPlanDao.duplicateTrip(
          tripId,
          title: 'Again',
          startDate: DateTime(2026, 9, 1),
        );

        final entries = await entriesOf(copyId);
        final byTitle = {for (final e in entries) e.title: e};
        expect(byTitle['A']!.groupId, isNotNull);
        expect(byTitle['A']!.groupId, byTitle['B']!.groupId);
        expect(
          byTitle['A']!.groupId,
          isNot((await entriesOf(tripId)).first.groupId),
          reason: 'a bundle of its own',
        );
        final sets = await db.alternativeDao.setsForTrip(copyId);
        expect(sets.values.single.date, DateTime(2026, 9, 2));
        expect(sets.values.single.label, 'Afternoon');
        expect(byTitle['Museum']!.alternativeId, isNotNull);
        expect(
          await db.trackDao.watchTracksForItem(byTitle['A']!.id).first,
          hasLength(1),
        );
        expect(
          (await db.tripDao.watchParticipants(copyId).first).map((p) => p.name),
          ['Ana'],
        );
        expect(
          (await db.tagDao.watchTagsForTrip(copyId).first).map((t) => t.id),
          [tagId],
        );
        final lists = await db.checklistDao.watchChecklists(copyId).first;
        expect(lists.single.title, 'Pack');
        final ticks = await db.checklistDao.watchItems(lists.single.id).first;
        expect(ticks.single.done, isFalse, reason: 'packing is the trip\'s');
      },
    );

    test('a trip without dates is moved from its first entry', () async {
      final tripId = await makeTrip();
      await makeEntry(tripId, DateTime(2026, 3, 3));
      await makeEntry(tripId, DateTime(2026, 3, 5));

      final copyId = await db.tripPlanDao.duplicateTrip(
        tripId,
        title: 'Again',
        startDate: DateTime(2026, 4, 1),
      );

      final copy = await db.tripDao.findTrip(copyId);
      expect(copy!.startDate, DateTime(2026, 4, 1));
      expect(copy.endDate, DateTime(2026, 4, 3));
      expect((await entriesOf(copyId)).map((e) => e.date).toSet(), {
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 3),
      });
    });

    test('an empty trip without dates becomes a day', () async {
      final tripId = await makeTrip();
      final copyId = await db.tripPlanDao.duplicateTrip(
        tripId,
        title: 'Again',
        startDate: DateTime(2026, 4, 1),
      );
      final copy = await db.tripDao.findTrip(copyId);
      expect(copy!.startDate, DateTime(2026, 4, 1));
      expect(copy.endDate, DateTime(2026, 4, 1));
    });

    test(
      'the shape holds across a daylight-saving change',
      skip: skipWithoutEuropeanDst,
      () async {
        // Out of the spring change and into the autumn one: both a 23- and a
        // 25-hour day sit inside the ranges.
        final tripId = await makeTrip(
          start: DateTime(2026, 3, 28),
          end: DateTime(2026, 3, 30),
        );
        await makeEntry(tripId, DateTime(2026, 3, 28), title: 'Sat');
        await makeEntry(tripId, DateTime(2026, 3, 29), title: 'Sun');
        await makeEntry(tripId, DateTime(2026, 3, 30), title: 'Mon');

        final copyId = await db.tripPlanDao.duplicateTrip(
          tripId,
          title: 'Again',
          startDate: DateTime(2026, 10, 24),
        );

        final copy = await db.tripDao.findTrip(copyId);
        expect(copy!.endDate, DateTime(2026, 10, 26));
        expect(
          {for (final e in await entriesOf(copyId)) e.title: e.date},
          {
            'Sat': DateTime(2026, 10, 24),
            'Sun': DateTime(2026, 10, 25),
            'Mon': DateTime(2026, 10, 26),
          },
        );
      },
    );

    test('refuses a routine', () async {
      final routineId = await db.tripDao.createTrip(
        TripsCompanion.insert(
          title: 'Commute',
          kind: const Value(TripKind.routine),
        ),
      );
      expect(
        () => db.tripPlanDao.duplicateTrip(
          routineId,
          title: 'Again',
          startDate: DateTime(2026, 4, 1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('moveTrip', () {
    Future<Trip> withDates(int tripId, DateTime start, DateTime end) async {
      final trip = (await db.tripDao.findTrip(tripId))!;
      return trip.copyWith(startDate: Value(start), endDate: Value(end));
    }

    test('every dated part of the plan moves, nothing is added', () async {
      final tripId = await makeTrip(
        start: DateTime(2026, 5, 1),
        end: DateTime(2026, 5, 3),
      );
      await makeEntry(tripId, DateTime(2026, 5, 1), title: 'Arrive');
      final museum = await makeEntry(
        tripId,
        DateTime(2026, 5, 3),
        title: 'Museum',
      );
      await db.alternativeDao.createSetFromItem(museum);
      await db.itineraryDao.setDayCollapsed(tripId, DateTime(2026, 5, 1), true);
      await db.itineraryDao.setDayCollapsed(tripId, DateTime(2026, 5, 2), true);

      await db.tripPlanDao.moveTrip(
        await withDates(tripId, DateTime(2026, 5, 2), DateTime(2026, 5, 4)),
        days: 1,
      );

      final trip = await db.tripDao.findTrip(tripId);
      expect(trip!.startDate, DateTime(2026, 5, 2));
      expect(trip.endDate, DateTime(2026, 5, 4));
      expect(
        {for (final e in await entriesOf(tripId)) e.title: e.date},
        {'Arrive': DateTime(2026, 5, 2), 'Museum': DateTime(2026, 5, 4)},
      );
      final sets = await db.alternativeDao.setsForTrip(tripId);
      expect(sets.values.single.date, DateTime(2026, 5, 4));
      // Shifting by one day moves the 1st onto the 2nd, which was itself
      // collapsed: the rows must not collide on the way.
      expect(await db.itineraryDao.watchCollapsedDays(tripId).first, {
        DateTime(2026, 5, 2),
        DateTime(2026, 5, 3),
      });
      expect(await db.select(db.trips).get(), hasLength(1));
    });

    test('the money, the ticks and the files stay as they are', () async {
      final tripId = await makeTrip(start: DateTime(2026, 5, 1));
      final entryId = await makeEntry(tripId, DateTime(2026, 5, 1));
      await db.costDao.addCost(
        CostsCompanion.insert(
          itemId: Value(entryId),
          amountMinor: 1200,
          currency: eurId,
          reason: 'Tickets',
          paid: const Value(true),
        ),
      );
      final listId = await db.checklistDao.addChecklist(
        ChecklistsCompanion.insert(tripId: tripId),
      );
      await db.checklistDao.addItem(
        ChecklistItemsCompanion.insert(
          checklistId: listId,
          label: 'Passport',
          done: const Value(true),
        ),
      );
      final pdf = Uint8List.fromList(utf8.encode('%PDF-1.4\n%booking\n'));
      await db.attachmentDao.addAttachment(
        prepareAttachment(
          pdf,
          name: 'ticket.pdf',
          kind: AttachmentKind.document,
        ),
        itemId: entryId,
      );

      await db.tripPlanDao.moveTrip(
        await withDates(tripId, DateTime(2026, 6, 1), DateTime(2026, 6, 1)),
        days: 31,
      );

      final entry = (await entriesOf(tripId)).single;
      expect(entry.id, entryId, reason: 'the same entry, moved');
      final costs = await db.costDao.watchCostsForTrip(tripId).first;
      expect(costs.single.itemId, entryId);
      expect(costs.single.paid, isTrue);
      expect(
        (await db.checklistDao.watchItems(listId).first).single.done,
        isTrue,
      );
      expect(
        await db.attachmentDao.watchAttachmentsForItem(entryId).first,
        hasLength(1),
      );
    });

    test('what the old day recorded is cleared, the plan is kept', () async {
      final tripId = await makeTrip(start: DateTime(2026, 5, 1));
      await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: DateTime(2026, 5, 1),
          kind: ItemKind.transport,
          startMinutes: const Value(600),
          endMinutes: const Value(700),
          actualStartMinutes: const Value(612),
          actualEndMinutes: const Value(715),
          sourceTripId: const Value('20260501_10:00_ic2021'),
          fromPlaceId: const Value('id:A'),
          toPlaceId: const Value('id:B'),
          stopovers: Value(
            encodeStopovers(const [
              Stopover(name: 'X', minutes: 630, delayMinutes: 12),
            ]),
          ),
        ),
      );
      expect((await db.tripPlanDao.moveFacts(tripId)).hasActualTimes, isTrue);

      await db.tripPlanDao.moveTrip(
        await withDates(tripId, DateTime(2026, 5, 8), DateTime(2026, 5, 8)),
        days: 7,
      );

      final leg = (await entriesOf(tripId)).single;
      expect(leg.date, DateTime(2026, 5, 8));
      expect(leg.startMinutes, 600);
      expect(leg.endMinutes, 700);
      expect(leg.fromPlaceId, 'id:A');
      expect(leg.toPlaceId, 'id:B');
      expect(leg.sourceTripId, isNull);
      expect(leg.actualStartMinutes, isNull);
      expect(leg.actualEndMinutes, isNull);
      expect(decodeStopovers(leg.stopovers), const [
        Stopover(name: 'X', minutes: 630),
      ]);
      expect((await db.tripPlanDao.moveFacts(tripId)).hasActualTimes, isFalse);
    });

    test('there and back again is where it started', () async {
      final tripId = await makeTrip(
        start: DateTime(2026, 5, 1),
        end: DateTime(2026, 5, 5),
      );
      await makeEntry(tripId, DateTime(2026, 5, 1), title: 'A');
      await makeEntry(tripId, DateTime(2026, 5, 4), title: 'B');

      await db.tripPlanDao.moveTrip(
        await withDates(tripId, DateTime(2026, 4, 21), DateTime(2026, 4, 25)),
        days: -10,
      );
      expect(
        {for (final e in await entriesOf(tripId)) e.title: e.date},
        {'A': DateTime(2026, 4, 21), 'B': DateTime(2026, 4, 24)},
      );
      await db.tripPlanDao.moveTrip(
        await withDates(tripId, DateTime(2026, 5, 1), DateTime(2026, 5, 5)),
        days: 10,
      );
      expect(
        {for (final e in await entriesOf(tripId)) e.title: e.date},
        {'A': DateTime(2026, 5, 1), 'B': DateTime(2026, 5, 4)},
      );
    });

    test(
      'a daylight-saving change in between costs no day',
      skip: skipWithoutEuropeanDst,
      () async {
        final tripId = await makeTrip(
          start: DateTime(2026, 3, 27),
          end: DateTime(2026, 3, 28),
        );
        await makeEntry(tripId, DateTime(2026, 3, 27), title: 'Fri');
        await makeEntry(tripId, DateTime(2026, 3, 28), title: 'Sat');

        // Across the spring change: the 29th is 23 hours long.
        await db.tripPlanDao.moveTrip(
          await withDates(tripId, DateTime(2026, 3, 29), DateTime(2026, 3, 30)),
          days: 2,
        );

        expect(
          {for (final e in await entriesOf(tripId)) e.title: e.date},
          {'Fri': DateTime(2026, 3, 29), 'Sat': DateTime(2026, 3, 30)},
        );
      },
    );

    test('a move of no days only writes the trip', () async {
      final tripId = await makeTrip(start: DateTime(2026, 5, 1));
      await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: DateTime(2026, 5, 1),
          kind: ItemKind.transport,
          actualStartMinutes: const Value(612),
          sourceTripId: const Value('run'),
        ),
      );
      final trip = (await db.tripDao.findTrip(tripId))!;
      await db.tripPlanDao.moveTrip(trip.copyWith(title: 'Renamed'), days: 0);

      expect((await db.tripDao.findTrip(tripId))!.title, 'Renamed');
      final leg = (await entriesOf(tripId)).single;
      expect(leg.actualStartMinutes, 612);
      expect(leg.sourceTripId, 'run');
    });

    test('moveFacts says whether there is anything to move', () async {
      final tripId = await makeTrip(start: DateTime(2026, 5, 1));
      expect(await db.tripPlanDao.moveFacts(tripId), (
        hasEntries: false,
        hasActualTimes: false,
      ));
      await makeEntry(tripId, DateTime(2026, 5, 1));
      expect(await db.tripPlanDao.moveFacts(tripId), (
        hasEntries: true,
        hasActualTimes: false,
      ));
    });
  });
}
