import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/sharing/trip_bundle.dart';

void main() {
  // Several tests open a second in-memory database to stand in for a recipient
  // device; each uses its own executor, so the multi-database warning is noise.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('exportTrip returns null for a missing trip', () async {
    expect(await db.sharingDao.exportTrip(999), isNull);
  });

  test('exportTrip captures a fully-populated trip', () async {
    final tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Rome',
        destination: const Value('Italy'),
        startDate: Value(DateTime(2026, 5, 1)),
        endDate: Value(DateTime(2026, 5, 7)),
        notes: const Value('Sunscreen'),
        colorValue: const Value(0xFF112233),
      ),
    );

    final place = await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: DateTime(2026, 5, 1),
        kind: ItemKind.place,
        title: const Value('Colosseum'),
        location: const Value('Piazza del Colosseo'),
        startMinutes: const Value(600),
        actualStartMinutes: const Value(615),
      ),
    );
    final leg = await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: DateTime(2026, 5, 1),
        kind: ItemKind.transport,
        mode: const Value(TransportMode.train),
        fromLocation: const Value('Florence'),
        toLocation: const Value('Rome'),
      ),
    );
    // Group the leg with the place so a shared cost can attach to the group.
    final groupId = await db.groupDao.groupItems(place, leg);

    // People must exist before they can be participants/beneficiaries.
    await db.tripDao.addParticipant(tripId, 'Alice');
    await db.tripDao.addParticipant(tripId, 'Bob');

    final itemCost = await db.costDao.addCost(
      CostsCompanion.insert(
        itemId: Value(place),
        amountMinor: 1600,
        currency: Currency.eur,
        reason: 'Tickets',
        paidBy: const Value('Alice'),
        paid: const Value(true),
      ),
    );
    await db.costDao.setBeneficiaries(itemCost, ['Alice', 'Bob']);
    await db.costDao.setReasonIcon('Tickets', 7);

    await db.costDao.addCost(
      CostsCompanion.insert(
        groupId: Value(groupId),
        amountMinor: 8000,
        currency: Currency.eur,
        reason: 'Train',
      ),
    );
    await db.costDao.addCost(
      CostsCompanion.insert(
        tripId: Value(tripId),
        amountMinor: -500,
        currency: Currency.usd,
        reason: 'Refund',
      ),
    );

    final checklistId = await db.checklistDao.addChecklist(
      ChecklistsCompanion.insert(title: const Value('Packing'), tripId: tripId),
    );
    await db.checklistDao.addItem(
      ChecklistItemsCompanion.insert(
        checklistId: checklistId,
        label: 'Passport',
        done: const Value(true),
      ),
    );

    await db.itineraryDao.setDayCollapsed(tripId, DateTime(2026, 5, 3), true);

    final bundle = await db.sharingDao.exportTrip(tripId);
    expect(bundle, isNotNull);

    // Round-trip through bytes to also exercise (de)serialization end to end.
    final b = TripBundle.decode(bundle!.encode());

    expect(b.schemaVersion, db.schemaVersion);
    expect(b.trip.title, 'Rome');
    expect(b.trip.destination, 'Italy');
    expect(b.trip.colorValue, 0xFF112233);
    expect(b.participants, ['Alice', 'Bob']);
    expect(b.reasonIcons, {'Tickets': 7});

    // Group + items, with the leg linked to the group by its local key.
    expect(b.groups, hasLength(1));
    final groupLocal = b.groups.single.localId;
    final transport = b.items.firstWhere((i) => i.kind == ItemKind.transport);
    expect(transport.groupLocalId, groupLocal);
    expect(transport.mode, TransportMode.train);
    final placeItem = b.items.firstWhere((i) => i.kind == ItemKind.place);
    expect(placeItem.groupLocalId, groupLocal);
    expect(placeItem.location, 'Piazza del Colosseo');
    // The plan and how it really went both travel with the trip.
    expect(placeItem.startMinutes, 600);
    expect(placeItem.actualStartMinutes, 615);
    expect(placeItem.actualEndMinutes, isNull);

    // Costs across all three attachment targets.
    final byReason = {for (final c in b.costs) c.reason: c};
    expect(byReason['Tickets']!.itemLocalId, placeItem.localId);
    expect(byReason['Tickets']!.paid, isTrue);
    expect(byReason['Tickets']!.paidBy, 'Alice');
    expect(byReason['Tickets']!.beneficiaries, ['Alice', 'Bob']);
    expect(byReason['Train']!.groupLocalId, groupLocal);
    expect(byReason['Refund']!.amountMinor, -500);
    expect(byReason['Refund']!.itemLocalId, isNull);
    expect(byReason['Refund']!.groupLocalId, isNull);

    // Checklist + item.
    expect(b.checklists, hasLength(1));
    expect(b.checklists.single.title, 'Packing');
    expect(b.checklists.single.items.single.label, 'Passport');
    expect(b.checklists.single.items.single.done, isTrue);

    expect(b.collapsedDays, [DateTime(2026, 5, 3)]);
  });

  test('importTrip rejects a bundle from a newer app version', () async {
    final bundle = TripBundle(
      formatVersion: TripBundle.currentFormatVersion + 1,
      schemaVersion: db.schemaVersion,
      trip: BundleTrip(
        title: 'X',
        destination: '',
        colorValue: 0,
        createdAt: DateTime(2026),
      ),
    );
    expect(
      () => db.sharingDao.importTrip(bundle),
      throwsA(isA<IncompatibleBundleException>()),
    );
  });

  test('export then import into a fresh database reproduces the trip', () async {
    // A separate database stands in for the recipient's device, so the global
    // rosters really are distinct (not the same shared rows).
    final source = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(source.close);

    final sourceId = await _seedTrip(source);
    final bytes = (await source.sharingDao.exportTrip(sourceId))!.encode();
    final original = await source.sharingDao.exportTrip(sourceId);

    final newId = await db.sharingDao.importTrip(TripBundle.decode(bytes));
    final imported = await db.sharingDao.exportTrip(newId);

    // Into an empty recipient, the re-exported bundle matches the original once
    // the volatile local keys (autoincrement row ids) are normalized away.
    expect(_canonical(imported!.toJson()), _canonical(original!.toJson()));
  });

  test('importing merges rosters without duplicating or overriding', () async {
    // The recipient (db) already knows Bob — as "me" — and has its own icon (2)
    // for the "Tickets" reason.
    await db.costDao.upsertPerson('Bob');
    final bob = await (db.select(db.people)..where((p) => p.name.equals('Bob')))
        .getSingle();
    await db.costDao.setMePerson(bob.id);
    await db.costDao.setReasonIcon('Tickets', 2);

    final source = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(source.close);
    final sourceId = await _seedTrip(source);
    final bytes = (await source.sharingDao.exportTrip(sourceId))!.encode();

    await db.sharingDao.importTrip(TripBundle.decode(bytes));

    // Bob is not duplicated and keeps his "me" flag; Alice arrives without the
    // sender's isMe.
    final people = await db.costDao.watchPeopleRows().first;
    expect(people.where((p) => p.name == 'Bob'), hasLength(1));
    expect(people.firstWhere((p) => p.name == 'Bob').isMe, isTrue);
    expect(people.firstWhere((p) => p.name == 'Alice').isMe, isFalse);

    // The importer's own reason icon (2) wins over the bundle's (7).
    final reasons = await db.costDao.watchReasonRows().first;
    expect(reasons.firstWhere((r) => r.label == 'Tickets').iconId, 2);
  });

  test('importTrip remaps foreign keys onto fresh rows', () async {
    final source = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(source.close);
    final sourceId = await _seedTrip(source);
    final bytes = (await source.sharingDao.exportTrip(sourceId))!.encode();
    final newId = await db.sharingDao.importTrip(TripBundle.decode(bytes));

    // Every itinerary item, cost, checklist, and collapsed day now belongs to
    // the new trip, and grouped items point at the new trip's group.
    final items =
        await (db.select(db.itineraryItems)..where((i) => i.tripId.equals(newId)))
            .get();
    expect(items, hasLength(2));
    final groups =
        await (db.select(db.itemGroups)..where((g) => g.tripId.equals(newId)))
            .get();
    expect(groups, hasLength(1));
    expect(items.every((i) => i.groupId == groups.single.id), isTrue);

    // The grouped ("Train") cost points at the *new* group, not the source's.
    final b = await db.sharingDao.exportTrip(newId);
    final trainCost = b!.costs.firstWhere((c) => c.reason == 'Train');
    expect(trainCost.groupLocalId, groups.single.id);
  });
}

/// Normalizes a bundle's JSON for comparison across databases: the local keys
/// (groups', items', checklists' autoincrement row ids) are remapped to their
/// position, so two bundles describing the same trip compare equal even though
/// their absolute ids differ. Relationships (an item's group, a cost's
/// item/group) are rewritten through the same maps, so a broken link would
/// still show up. The database-specific `schemaVersion` is dropped.
Map<String, dynamic> _canonical(Map<String, dynamic> bundleJson) {
  final j = Map<String, dynamic>.from(bundleJson)..remove('schemaVersion');
  final groups = (j['groups'] as List).cast<Map<String, dynamic>>();
  final items = (j['items'] as List).cast<Map<String, dynamic>>();
  final costs = (j['costs'] as List).cast<Map<String, dynamic>>();
  final checklists = (j['checklists'] as List).cast<Map<String, dynamic>>();

  final groupMap = {
    for (var k = 0; k < groups.length; k++) groups[k]['localId'] as int: k,
  };
  final itemMap = {
    for (var k = 0; k < items.length; k++) items[k]['localId'] as int: k,
  };

  int? via(Map<int, int> m, Object? id) => id == null ? null : m[id as int];

  j['groups'] = [
    for (final g in groups) {...g, 'localId': groupMap[g['localId']]},
  ];
  j['items'] = [
    for (final i in items)
      {
        ...i,
        'localId': itemMap[i['localId']],
        'groupLocalId': via(groupMap, i['groupLocalId']),
      },
  ];
  j['costs'] = [
    for (final c in costs)
      {
        ...c,
        'itemLocalId': via(itemMap, c['itemLocalId']),
        'groupLocalId': via(groupMap, c['groupLocalId']),
      },
  ];
  j['checklists'] = [
    for (var k = 0; k < checklists.length; k++)
      {...checklists[k], 'localId': k},
  ];
  return j;
}

/// Seeds a source trip covering every table with two grouped items, costs
/// across all three attachment targets, a checklist, participants, and a
/// collapsed day. Returns the trip id.
Future<int> _seedTrip(AppDatabase db) async {
  final tripId = await db.tripDao.createTrip(
    TripsCompanion.insert(
      title: 'Rome',
      destination: const Value('Italy'),
      startDate: Value(DateTime(2026, 5, 1)),
      endDate: Value(DateTime(2026, 5, 7)),
    ),
  );
  final place = await db.itineraryDao.addItem(
    ItineraryItemsCompanion.insert(
      tripId: tripId,
      date: DateTime(2026, 5, 1),
      kind: ItemKind.place,
      location: const Value('Colosseum'),
    ),
  );
  final leg = await db.itineraryDao.addItem(
    ItineraryItemsCompanion.insert(
      tripId: tripId,
      date: DateTime(2026, 5, 1),
      kind: ItemKind.transport,
      mode: const Value(TransportMode.train),
    ),
  );
  final groupId = await db.groupDao.groupItems(place, leg);
  await db.tripDao.addParticipant(tripId, 'Alice');
  await db.tripDao.addParticipant(tripId, 'Bob');
  final itemCost = await db.costDao.addCost(
    CostsCompanion.insert(
      itemId: Value(place),
      amountMinor: 1600,
      currency: Currency.eur,
      reason: 'Tickets',
      paidBy: const Value('Alice'),
    ),
  );
  await db.costDao.setBeneficiaries(itemCost, ['Alice', 'Bob']);
  await db.costDao.setReasonIcon('Tickets', 7);
  await db.costDao.addCost(
    CostsCompanion.insert(
      groupId: Value(groupId),
      amountMinor: 8000,
      currency: Currency.eur,
      reason: 'Train',
    ),
  );
  await db.costDao.addCost(
    CostsCompanion.insert(
      tripId: Value(tripId),
      amountMinor: -500,
      currency: Currency.usd,
      reason: 'Refund',
    ),
  );
  final checklistId = await db.checklistDao.addChecklist(
    ChecklistsCompanion.insert(title: const Value('Packing'), tripId: tripId),
  );
  await db.checklistDao.addItem(
    ChecklistItemsCompanion.insert(
      checklistId: checklistId,
      label: 'Passport',
      done: const Value(true),
    ),
  );
  await db.itineraryDao.setDayCollapsed(tripId, DateTime(2026, 5, 3), true);
  return tripId;
}
