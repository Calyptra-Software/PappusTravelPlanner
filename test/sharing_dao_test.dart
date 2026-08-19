import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/stopovers.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/sharing/trip_bundle.dart';

import 'currency_fixture.dart';

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
        mode: const Value(6), // seeded 'train' mode (enum index 5 + 1)
        fromLocation: const Value('Florence'),
        toLocation: const Value('Rome'),
        spansNextDay: const Value(true),
        sourceTripId: const Value('trip-99'),
        stopovers: Value(
          encodeStopovers(const [
            Stopover(name: 'Innsbruck Hbf', minutes: 300),
          ]),
        ),
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
        currency: eurId,
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
        currency: eurId,
        reason: 'Train',
      ),
    );
    await db.costDao.addCost(
      CostsCompanion.insert(
        tripId: Value(tripId),
        amountMinor: -500,
        currency: usdId,
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
    expect(transport.mode, 'train');
    // A routed leg's plan travels: the overnight flag and the stops it calls
    // at. Its routing trip id does not — that is provenance, not plan.
    expect(transport.spansNextDay, isTrue);
    expect(decodeStopovers(transport.stopovers).map((s) => s.name), [
      'Innsbruck Hbf',
    ]);
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

  test('a settlement arrives as a settlement, with its receiver', () async {
    final source = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(source.close);

    final sourceId = await _seedTrip(source);
    final bytes = (await source.sharingDao.exportTrip(sourceId))!.encode();
    final newId = await db.sharingDao.importTrip(TripBundle.decode(bytes));

    final costs = await db.costDao.watchCostsForTrip(newId).first;
    final settlement = costs.singleWhere((c) => c.isTransfer);
    expect(settlement.amountMinor, 2000);
    expect(settlement.paidBy, 'Bob');
    final receivers = await db.costDao.watchBeneficiaries(settlement.id).first;
    expect(receivers.map((p) => p.name), ['Alice']);

    // And it still isn't spending on the recipient's device either.
    final totals = await db.costDao.watchTotalsByTrip().first;
    expect(totals[newId]!['EUR'], 1600 + 8000);
  });

  test('a bundle written before settlements existed reads as expenses', () {
    // The flag is simply absent in an older sender's JSON.
    final json = {
      'itemLocalId': null,
      'groupLocalId': null,
      'amountMinor': 1600,
      'currency': 'eur',
      'reason': 'Tickets',
      'paidBy': 'Alice',
      'paid': true,
      'createdAt': DateTime(2026, 5, 1).toIso8601String(),
      'beneficiaries': ['Alice'],
    };
    expect(BundleCost.fromJson(json).isTransfer, isFalse);
  });

  group('currencies', () {
    test('travel by code, with their definitions alongside', () async {
      final tripId = await _seedTrip(db);
      // The base carries a rate of 1 by definition; give USD one too.
      await db.currencyDao.setRate(usdId, 900000);

      final bundle = (await db.sharingDao.exportTrip(tripId))!;
      expect(
        bundle.costs.map((c) => c.currency),
        everyElement(isIn(['EUR', 'USD'])),
      );
      // Only the currencies the trip actually uses ride along — plus the base,
      // which is what the rates mean.
      expect(bundle.currencies.map((c) => c.code), ['EUR', 'USD']);
      final usd = bundle.currencies.firstWhere((c) => c.code == 'USD');
      expect(usd.symbol, r'US$');
      expect(usd.rateMicros, 900000);
      expect(
        bundle.currencies.firstWhere((c) => c.code == 'EUR').isBase,
        isTrue,
      );
    });

    test(
      'a trip in the old four currencies stays readable by an older app',
      () async {
        final tripId = await _seedTrip(db);
        final bundle = (await db.sharingDao.exportTrip(tripId))!;
        // No decisions and no currency the old enum lacked: still a v1 bundle,
        // whose costs name their currency the way that app expects.
        expect(bundle.formatVersion, 1);
        final json = bundle.costs.first.toJson();
        expect(json['currency'], 'eur');
      },
    );

    test('a trip using an added currency goes out as v3', () async {
      final tripId = await _seedTrip(db);
      final jpy = await db.currencyDao.addCurrency(code: 'JPY', symbol: '¥');
      await db.costDao.addCost(
        CostsCompanion.insert(
          tripId: Value(tripId),
          amountMinor: 300000,
          currency: jpy,
          reason: 'Ryokan',
        ),
      );

      final bundle = (await db.sharingDao.exportTrip(tripId))!;
      expect(bundle.formatVersion, 3);
      expect(
        bundle.costs
            .firstWhere((c) => c.reason == 'Ryokan')
            .toJson()['currency'],
        'JPY',
      );
    });

    test(
      'an unknown currency is created on import, keeping its symbol',
      () async {
        final source = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(source.close);
        final sourceId = await _seedTrip(source);
        final jpy = await source.currencyDao.addCurrency(
          code: 'JPY',
          symbol: '¥',
          rateMicros: 6000,
        );
        await source.costDao.addCost(
          CostsCompanion.insert(
            tripId: Value(sourceId),
            amountMinor: 300000,
            currency: jpy,
            reason: 'Ryokan',
          ),
        );
        // The recipient deleted CHF and has never heard of JPY.
        await db.currencyDao.deleteCurrency(chfId);

        final bytes = (await source.sharingDao.exportTrip(sourceId))!.encode();
        final newId = await db.sharingDao.importTrip(TripBundle.decode(bytes));

        final currencies = await db.currencyDao.watchCurrencies().first;
        final imported = currencies.firstWhere((c) => c.code == 'JPY');
        expect(imported.symbol, '¥');
        // Both databases have EUR as their base, so the rate means the same thing
        // here and is adopted.
        expect(imported.rateMicros, 6000);

        final totals = await db.costDao.watchTotalsByTrip().first;
        expect(totals[newId]!['JPY'], 300000);
      },
    );

    test('a rate measured against another base is not adopted', () async {
      final source = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(source.close);
      final sourceId = await _seedTrip(source);
      final jpy = await source.currencyDao.addCurrency(
        code: 'JPY',
        symbol: '¥',
        rateMicros: 6000,
      );
      await source.costDao.addCost(
        CostsCompanion.insert(
          tripId: Value(sourceId),
          amountMinor: 300000,
          currency: jpy,
          reason: 'Ryokan',
        ),
      );
      // The recipient prices everything in GBP instead, so "¥1 = €0.006" says
      // nothing here and must not be taken at face value.
      await db.currencyDao.setBase(gbpId);

      final bytes = (await source.sharingDao.exportTrip(sourceId))!.encode();
      await db.sharingDao.importTrip(TripBundle.decode(bytes));

      final currencies = await db.currencyDao.watchCurrencies().first;
      expect(currencies.firstWhere((c) => c.code == 'JPY').rateMicros, isNull);
    });

    test(
      'an existing currency keeps the importer\'s own symbol and rate',
      () async {
        final source = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(source.close);
        final sourceId = await _seedTrip(source);
        await source.currencyDao.setRate(usdId, 900000);
        await source.currencyDao.editCurrency(usdId, symbol: r'$');

        await db.currencyDao.setRate(usdId, 950000);
        final bytes = (await source.sharingDao.exportTrip(sourceId))!.encode();
        await db.sharingDao.importTrip(TripBundle.decode(bytes));

        final currencies = await db.currencyDao.watchCurrencies().first;
        final usd = currencies.firstWhere((c) => c.code == 'USD');
        expect(usd.symbol, r'US$');
        expect(usd.rateMicros, 950000);
      },
    );
  });

  test('importing merges rosters without duplicating or overriding', () async {
    // The recipient (db) already knows Bob — as "me" — and has its own icon (2)
    // for the "Tickets" reason.
    await db.costDao.upsertPerson('Bob');
    final bob = await (db.select(
      db.people,
    )..where((p) => p.name.equals('Bob'))).getSingle();
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
    final items = await (db.select(
      db.itineraryItems,
    )..where((i) => i.tripId.equals(newId))).get();
    expect(items, hasLength(2));
    final groups = await (db.select(
      db.itemGroups,
    )..where((g) => g.tripId.equals(newId))).get();
    expect(groups, hasLength(1));
    expect(items.every((i) => i.groupId == groups.single.id), isTrue);

    // The grouped ("Train") cost points at the *new* group, not the source's.
    final b = await db.sharingDao.exportTrip(newId);
    final trainCost = b!.costs.firstWhere((c) => c.reason == 'Train');
    expect(trainCost.groupLocalId, groups.single.id);
  });

  group('trip kind and tags', () {
    test('a routine or a tag forces v4; a plain trip stays v1', () async {
      // An older app reads a bundle with no kind as an ordinary trip — right
      // for a trip, wrong for a routine, whose entries would land on a 1970
      // anchor day.
      final plain = await db.tripDao.createTrip(
        TripsCompanion.insert(title: 'Rome'),
      );
      expect((await db.sharingDao.exportTrip(plain))!.formatVersion, 1);

      final routine = await db.tripDao.createTrip(
        TripsCompanion.insert(
          title: 'To work',
          kind: const Value(TripKind.routine),
        ),
      );
      expect((await db.sharingDao.exportTrip(routine))!.formatVersion, 4);

      final tagged = await db.tripDao.createTrip(
        TripsCompanion.insert(title: 'River walk'),
      );
      await db.tagDao.setTagsForTrip(tagged, {
        await db.tagDao.ensureTag('walks'),
      });
      expect((await db.sharingDao.exportTrip(tagged))!.formatVersion, 4);
    });

    test('a routine survives export and import as a routine', () async {
      final routineId = await db.tripDao.createTrip(
        TripsCompanion.insert(
          title: 'To work',
          kind: const Value(TripKind.routine),
        ),
      );
      final bundle = (await db.sharingDao.exportTrip(routineId))!;

      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);
      final importedId = await target.sharingDao.importTrip(bundle);

      expect(
        (await target.tripDao.findTrip(importedId))!.kind,
        TripKind.routine,
      );
    });

    test('tags travel by name, and are created on the recipient', () async {
      final tripId = await db.tripDao.createTrip(
        TripsCompanion.insert(title: 'River walk'),
      );
      await db.tagDao.setTagsForTrip(tripId, {
        await db.tagDao.ensureTag('walks'),
        await db.tagDao.ensureTag('weekend'),
      });
      final bundle = (await db.sharingDao.exportTrip(tripId))!;
      expect(bundle.tags, containsAll(['walks', 'weekend']));

      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);
      final importedId = await target.sharingDao.importTrip(bundle);

      final tags = await target.tagDao.watchTagsForTrip(importedId).first;
      expect(tags.map((t) => t.name), containsAll(['walks', 'weekend']));
    });

    test("an existing tag keeps the recipient's own colour", () async {
      final tripId = await db.tripDao.createTrip(
        TripsCompanion.insert(title: 'River walk'),
      );
      await db.tagDao.setTagsForTrip(tripId, {
        await db.tagDao.ensureTag('walks'),
      });
      final bundle = (await db.sharingDao.exportTrip(tripId))!;

      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);
      // The recipient already files walks, in their own colour. A tag is
      // matched by name; the sender's styling is not theirs to impose.
      final mine = await target.tagDao.createTag(
        TagsCompanion.insert(
          name: 'walks',
          colorValue: const Value(0xFF123456),
        ),
      );
      final importedId = await target.sharingDao.importTrip(bundle);

      final tags = await target.tagDao.watchTagsForTrip(importedId).first;
      expect(tags, hasLength(1));
      expect(tags.single.id, mine);
      expect(tags.single.colorValue, 0xFF123456);
    });

    test("a leg's place ids travel, its live trip id does not", () async {
      final tripId = await db.tripDao.createTrip(
        TripsCompanion.insert(title: 'Rome'),
      );
      await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: DateTime(2026, 5),
          kind: ItemKind.transport,
          fromPlaceId: const Value('stop:1'),
          toPlaceId: const Value('52.5,13.4'),
          sourceTripId: const Value('one-dated-run'),
        ),
      );

      final bundle = (await db.sharingDao.exportTrip(tripId))!;
      final leg = bundle.items.single;
      // Where, not when: the recipient can look this journey up for their own
      // dates, but must not inherit a service that ran on the sender's.
      expect(leg.fromPlaceId, 'stop:1');
      expect(leg.toPlaceId, '52.5,13.4');

      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);
      final importedId = await target.sharingDao.importTrip(bundle);
      final items = await target.itineraryDao
          .watchItemsForTrip(importedId)
          .first;
      expect(items.single.fromPlaceId, 'stop:1');
      expect(items.single.sourceTripId, isNull);
    });

    test(
      "an entry's map color travels, and an uncolored one stays so",
      () async {
        final tripId = await db.tripDao.createTrip(
          TripsCompanion.insert(title: 'Hamburg'),
        );
        await db.itineraryDao.addItem(
          ItineraryItemsCompanion.insert(
            tripId: tripId,
            date: DateTime(2026, 5),
            kind: ItemKind.transport,
            title: const Value('Commute'),
            colorValue: const Value(0xFF1B5E20),
          ),
        );
        await db.itineraryDao.addItem(
          ItineraryItemsCompanion.insert(
            tripId: tripId,
            date: DateTime(2026, 5),
            kind: ItemKind.place,
            title: const Value('Office'),
            sortOrder: const Value(1),
          ),
        );

        final bundle = (await db.sharingDao.exportTrip(tripId))!;
        expect(bundle.items.map((i) => i.colorValue), [0xFF1B5E20, null]);

        final target = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(target.close);
        final importedId = await target.sharingDao.importTrip(bundle);
        final items = await target.itineraryDao
            .watchItemsForTrip(importedId)
            .first;
        // The recipient's map draws the same trip, so the choice comes with it —
        // and the entry nobody colored keeps falling back to the trip's accent.
        expect(items.map((i) => i.colorValue), [0xFF1B5E20, null]);
      },
    );
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
      mode: const Value(6), // seeded 'train' mode (enum index 5 + 1)
      // An imported overnight leg: both are read back on the recipient's side,
      // so both have to travel.
      spansNextDay: const Value(true),
      stopovers: Value(
        encodeStopovers(const [
          Stopover(name: 'Firenze S.M.N.', minutes: 1320),
          Stopover(name: 'Roma Tiburtina', minutes: 75, dayOffset: 1),
        ]),
      ),
    ),
  );
  final groupId = await db.groupDao.groupItems(place, leg);
  await db.tripDao.addParticipant(tripId, 'Alice');
  await db.tripDao.addParticipant(tripId, 'Bob');
  final itemCost = await db.costDao.addCost(
    CostsCompanion.insert(
      itemId: Value(place),
      amountMinor: 1600,
      currency: eurId,
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
      currency: eurId,
      reason: 'Train',
    ),
  );
  await db.costDao.addCost(
    CostsCompanion.insert(
      tripId: Value(tripId),
      amountMinor: -500,
      currency: usdId,
      reason: 'Refund',
    ),
  );
  // A settlement: Bob hands Alice 20.00 back. Not an expense — it must travel
  // as what it is, or the recipient's balances would read as spending.
  final settlement = await db.costDao.addCost(
    CostsCompanion.insert(
      tripId: Value(tripId),
      amountMinor: 2000,
      currency: eurId,
      reason: '',
      paidBy: const Value('Bob'),
      paid: const Value(true),
      isTransfer: const Value(true),
    ),
  );
  await db.costDao.setBeneficiaries(settlement, ['Alice']);
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
