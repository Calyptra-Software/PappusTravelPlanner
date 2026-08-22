import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/attachments/attachment_import.dart';

/// Storing a file on part of a plan: where it may hang, what happens to it when
/// that part goes away, and what the timeline is told about it.
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

  Future<int> makeLeg(int tripId, {int? groupId}) => db
      .into(db.itineraryItems)
      .insert(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: DateTime(2026, 5, 1),
          kind: ItemKind.transport,
          groupId: Value(groupId),
        ),
      );

  Future<int> makeGroup(int tripId) =>
      db.into(db.itemGroups).insert(ItemGroupsCompanion.insert(tripId: tripId));

  PreparedAttachment ticket({String? name = 'ticket.pdf', LatLng? at}) =>
      PreparedAttachment(
        kind: at == null ? AttachmentKind.document : AttachmentKind.photo,
        mimeType: at == null ? 'application/pdf' : 'image/jpeg',
        bytes: Uint8List.fromList(List.filled(64, 7)),
        name: name,
        thumbnail: at == null ? null : Uint8List.fromList([1, 2, 3]),
        position: at,
        positionSource: at == null ? null : AttachmentPositionSource.exif,
      );

  test('a file hangs on an entry and its bytes come back', () async {
    final trip = await makeTrip();
    final leg = await makeLeg(trip);

    final id = await db.attachmentDao.addAttachment(ticket(), itemId: leg);

    final rows = await db.attachmentDao.watchAttachmentsForItem(leg).first;
    expect(rows, hasLength(1));
    expect(rows.single.name, 'ticket.pdf');
    expect(rows.single.byteSize, 64);
    expect(rows.single.kind, AttachmentKind.document);
    expect(await db.attachmentDao.readAttachmentBytes(id), hasLength(64));
  });

  test('a file hangs on a run, where its shared ticket does', () async {
    final trip = await makeTrip();
    final group = await makeGroup(trip);
    await makeLeg(trip, groupId: group);

    await db.attachmentDao.addAttachment(ticket(), groupId: group);

    expect(
      await db.attachmentDao.watchAttachmentsForGroup(group).first,
      hasLength(1),
    );
  });

  test('it belongs to exactly one of the two, never both or neither', () async {
    final trip = await makeTrip();
    final leg = await makeLeg(trip);
    final group = await makeGroup(trip);

    expect(() => db.attachmentDao.addAttachment(ticket()), throwsArgumentError);
    expect(
      () =>
          db.attachmentDao.addAttachment(ticket(), itemId: leg, groupId: group),
      throwsArgumentError,
    );
  });

  test('a photo keeps where it was taken, and where that came from', () async {
    final trip = await makeTrip();
    final leg = await makeLeg(trip);

    final id = await db.attachmentDao.addAttachment(
      ticket(name: 'view.jpg', at: const LatLng(53.55, 9.99)),
      itemId: leg,
    );

    final row = (await db.attachmentDao.attachment(id))!;
    expect(row.lat, closeTo(53.55, 1e-9));
    expect(row.lon, closeTo(9.99, 1e-9));
    expect(row.positionSource, AttachmentPositionSource.exif);
  });

  test('a position pointed at replaces one read from the file', () async {
    final trip = await makeTrip();
    final leg = await makeLeg(trip);
    final id = await db.attachmentDao.addAttachment(
      ticket(name: 'view.jpg', at: const LatLng(53.55, 9.99)),
      itemId: leg,
    );

    await db.attachmentDao.setAttachmentPosition(id, const LatLng(48.0, 11.0));

    final row = (await db.attachmentDao.attachment(id))!;
    expect(row.lat, closeTo(48.0, 1e-9));
    expect(row.positionSource, AttachmentPositionSource.picked);
  });

  test('clearing a position clears where it came from with it', () async {
    final trip = await makeTrip();
    final leg = await makeLeg(trip);
    final id = await db.attachmentDao.addAttachment(
      ticket(name: 'view.jpg', at: const LatLng(53.55, 9.99)),
      itemId: leg,
    );

    await db.attachmentDao.setAttachmentPosition(id, null);

    final row = (await db.attachmentDao.attachment(id))!;
    expect(row.lat, isNull);
    expect(row.lon, isNull);
    // A source with nothing to describe would go on claiming the reading came
    // from somewhere.
    expect(row.positionSource, isNull);
  });

  test('deleting the entry takes the file and its bytes with it', () async {
    final trip = await makeTrip();
    final leg = await makeLeg(trip);
    final id = await db.attachmentDao.addAttachment(ticket(), itemId: leg);

    await (db.delete(db.itineraryItems)..where((i) => i.id.equals(leg))).go();

    expect(await db.attachmentDao.attachment(id), isNull);
    expect(await db.attachmentDao.readAttachmentBytes(id), isNull);
  });

  test('dissolving a group rescues its files onto the first member', () async {
    final trip = await makeTrip();
    final group = await makeGroup(trip);
    final first = await makeLeg(trip, groupId: group);
    final second = await makeLeg(trip, groupId: group);
    final onRun = await db.attachmentDao.addAttachment(
      ticket(),
      groupId: group,
    );
    final onLeg = await db.attachmentDao.addAttachment(
      ticket(name: 'seat.jpg'),
      itemId: second,
    );

    await db.groupDao.dissolveGroup(group);

    // Ungrouping is advertised as the harmless half of deleting: the entries
    // stay, so what they paid for stays with them. The fare has always been
    // rescued this way and the ticket now travels with it — the two are the
    // same thing said twice.
    expect((await db.attachmentDao.attachment(onRun))!.itemId, first);
    expect((await db.attachmentDao.attachment(onLeg))!.itemId, second);
  });

  test('a run picked apart leg by leg keeps its ticket', () async {
    final trip = await makeTrip();
    final group = await makeGroup(trip);
    final first = await makeLeg(trip, groupId: group);
    final second = await makeLeg(trip, groupId: group);
    final onRun = await db.attachmentDao.addAttachment(
      ticket(),
      groupId: group,
    );

    // Down to one member the group is dissolved as degenerate, which is the
    // other door into the same rescue.
    await db.groupDao.deleteItem(second);

    final rescued = (await db.attachmentDao.attachment(onRun))!;
    expect(rescued.itemId, first);
    expect(rescued.groupId, isNull);
  });

  test('deleting a whole run takes its files with it', () async {
    final trip = await makeTrip();
    final group = await makeGroup(trip);
    final leg = await makeLeg(trip, groupId: group);
    final onRun = await db.attachmentDao.addAttachment(
      ticket(),
      groupId: group,
    );
    final onLeg = await db.attachmentDao.addAttachment(
      ticket(name: 'seat.jpg'),
      itemId: leg,
    );

    await db.groupDao.deleteGroup(group);

    // Nothing survives to carry them: a ticket is not worth keeping a
    // photograph of once every leg it covered has been deleted.
    expect(await db.attachmentDao.attachment(onRun), isNull);
    expect(await db.attachmentDao.attachment(onLeg), isNull);
  });

  test('the trip-wide count answers per entry and per run', () async {
    final trip = await makeTrip();
    final group = await makeGroup(trip);
    final leg = await makeLeg(trip, groupId: group);
    final other = await makeLeg(trip);
    await db.attachmentDao.addAttachment(ticket(), groupId: group);
    await db.attachmentDao.addAttachment(ticket(), itemId: leg);
    await db.attachmentDao.addAttachment(ticket(name: 'a'), itemId: other);
    await db.attachmentDao.addAttachment(ticket(name: 'b'), itemId: other);

    final counts = await db.attachmentDao
        .watchAttachmentCountsForTrip(trip)
        .first;

    expect(counts.byGroup, {group: 1});
    expect(counts.byItem, {leg: 1, other: 2});
  });

  test('the count is of this trip only', () async {
    final trip = await makeTrip();
    final elsewhere = await makeTrip();
    await db.attachmentDao.addAttachment(
      ticket(),
      itemId: await makeLeg(elsewhere),
    );

    final counts = await db.attachmentDao
        .watchAttachmentCountsForTrip(trip)
        .first;

    expect(counts.byItem, isEmpty);
    expect(counts.byGroup, isEmpty);
  });

  group('what the map may ask for', () {
    test('only photos, and only ones carrying a position', () async {
      final trip = await makeTrip();
      final leg = await makeLeg(trip);
      await db.attachmentDao.addAttachment(
        ticket(name: 'placed.jpg', at: const LatLng(53.55, 9.99)),
        itemId: leg,
      );
      await db.attachmentDao.addAttachment(
        ticket(name: 'unplaced.jpg'),
        itemId: leg,
      );
      // A document with a position would still only be a dot with a paperclip
      // on it, and the reason to be on a map is to be seen.
      final document = await db.attachmentDao.addAttachment(
        ticket(name: 'ticket.pdf'),
        itemId: leg,
      );
      await db.attachmentDao.setAttachmentPosition(
        document,
        const LatLng(53.5, 10.0),
      );

      final drawn = await db.attachmentDao
          .watchPositionedPhotosForTrip(trip)
          .first;

      expect(drawn.map((a) => a.name), ['placed.jpg']);
    });

    test('a run\'s photo comes through its group', () async {
      final trip = await makeTrip();
      final group = await makeGroup(trip);
      await makeLeg(trip, groupId: group);
      await db.attachmentDao.addAttachment(
        ticket(name: 'platform.jpg', at: const LatLng(53.55, 9.99)),
        groupId: group,
      );

      final drawn = await db.attachmentDao
          .watchPositionedPhotosForTrip(trip)
          .first;

      expect(drawn.single.groupId, group);
    });

    test('another trip\'s photos stay off this map', () async {
      final trip = await makeTrip();
      final elsewhere = await makeTrip();
      await db.attachmentDao.addAttachment(
        ticket(name: 'far.jpg', at: const LatLng(1, 1)),
        itemId: await makeLeg(elsewhere),
      );

      expect(
        await db.attachmentDao.watchPositionedPhotosForTrip(trip).first,
        isEmpty,
      );
    });

    test('an option nobody chose is not filtered out here', () async {
      // Deliberately: whether a picture belongs to the plan as it stands is
      // decided against the live entries the screen already holds, so this
      // query has no second copy of that definition. See `_photoMarkers`.
      final trip = await makeTrip();
      final set = await db
          .into(db.alternativeSets)
          .insert(
            AlternativeSetsCompanion.insert(
              tripId: trip,
              date: DateTime(2026, 5, 1),
            ),
          );
      final branch = await db
          .into(db.alternatives)
          .insert(AlternativesCompanion.insert(setId: set));
      final legInBranch = await db
          .into(db.itineraryItems)
          .insert(
            ItineraryItemsCompanion.insert(
              tripId: trip,
              date: DateTime(2026, 5, 1),
              kind: ItemKind.transport,
              alternativeId: Value(branch),
            ),
          );
      await db.attachmentDao.addAttachment(
        ticket(name: 'maybe.jpg', at: const LatLng(53.55, 9.99)),
        itemId: legInBranch,
      );

      expect(
        await db.attachmentDao.watchPositionedPhotosForTrip(trip).first,
        hasLength(1),
      );
    });
  });

  group('a run looked up again', () {
    test('keeps the files that hung on its legs', () async {
      final trip = await makeTrip();
      final group = await makeGroup(trip);
      final leg = await makeLeg(trip, groupId: group);
      final id = await db.attachmentDao.addAttachment(ticket(), itemId: leg);

      final ids = await db.routineDao.replaceJourneyLegs(
        trip,
        oldLegIds: [leg],
        groupId: group,
        legs: [
          ItineraryItemsCompanion.insert(
            tripId: trip,
            date: DateTime(2026, 5, 1),
            kind: ItemKind.transport,
          ),
        ],
      );

      // Rescued onto the surviving bundle, exactly as the fare is: the photo of
      // the ticket is not about the 07:32 in particular.
      final row = (await db.attachmentDao.attachment(id))!;
      expect(row.groupId, group);
      expect(row.itemId, isNull);
      expect(ids, hasLength(1));
    });

    test('lands them on the first new leg when there is no run', () async {
      final trip = await makeTrip();
      final leg = await makeLeg(trip);
      final id = await db.attachmentDao.addAttachment(ticket(), itemId: leg);

      final ids = await db.routineDao.replaceJourneyLegs(
        trip,
        oldLegIds: [leg],
        legs: [
          ItineraryItemsCompanion.insert(
            tripId: trip,
            date: DateTime(2026, 5, 1),
            kind: ItemKind.transport,
          ),
        ],
      );

      final row = (await db.attachmentDao.attachment(id))!;
      expect(row.itemId, ids.single);
      expect(row.groupId, isNull);
    });

    test('leaves nothing parked when there is no replacement', () async {
      final trip = await makeTrip();
      final leg = await makeLeg(trip);
      final id = await db.attachmentDao.addAttachment(ticket(), itemId: leg);

      await db.routineDao.replaceJourneyLegs(
        trip,
        oldLegIds: [leg],
        legs: const [],
      );

      // Nothing to hang it on and nothing claiming to hold it: the entry was
      // removed outright, and an owner-less row would be invisible for good.
      expect(await db.attachmentDao.attachment(id), isNull);
    });
  });
}
