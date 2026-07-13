import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/sharing/trip_bundle.dart';

/// Sharing a trip that holds decisions: every option travels with the bundle —
/// including the ones not chosen, which are the point of having planned them —
/// and lands on the recipient's device as a decision again, not as a day with
/// every option's entries dumped into it.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  final day = DateTime(2026, 7, 5);

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// A trip whose Saturday is a decision: the chosen "Museum day" (€15) or a
  /// boat trip (€50). Returns the trip id.
  Future<int> seedDecision(AppDatabase target) async {
    final tripId = await target.tripDao.createTrip(
      TripsCompanion.insert(title: 'Rome'),
    );
    final museum = await target.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: day,
        kind: ItemKind.place,
        title: const Value('Museum'),
      ),
    );
    await target.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: day,
        kind: ItemKind.place,
        title: const Value('Dinner'),
        sortOrder: const Value(1),
      ),
    );
    final setId = await target.alternativeDao.createSetFromItem(museum);
    await target.alternativeDao.setSetLabel(setId, 'Saturday afternoon');
    final branches = (await target.alternativeDao
        .watchBranchesForTrip(tripId)
        .first)[setId]!;
    await target.alternativeDao.setAlternativeLabel(
      branches.first.id,
      'Museum day',
    );
    await target.costDao.addCost(
      CostsCompanion.insert(
        itemId: Value(museum),
        amountMinor: 1500,
        currency: Currency.eur,
        reason: 'Ticket',
      ),
    );
    final boat = await target.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: day,
        kind: ItemKind.place,
        title: const Value('Boat trip'),
        alternativeId: Value(branches.last.id),
      ),
    );
    await target.costDao.addCost(
      CostsCompanion.insert(
        itemId: Value(boat),
        amountMinor: 5000,
        currency: Currency.eur,
        reason: 'Boat',
      ),
    );
    return tripId;
  }

  test(
    'exportTrip captures the decision, its options and their items',
    () async {
      final tripId = await seedDecision(db);

      final bundle = (await db.sharingDao.exportTrip(tripId))!;

      final set = bundle.alternativeSets.single;
      expect(set.label, 'Saturday afternoon');
      expect(set.date, day);
      expect(set.alternatives, hasLength(2));
      expect(set.alternatives.first.label, 'Museum day');
      expect(set.alternatives.first.chosen, isTrue);
      expect(set.alternatives.last.chosen, isFalse);

      // Each item knows which option it belongs to; the day's own items don't.
      BundleItem item(String title) =>
          bundle.items.firstWhere((i) => i.title == title);
      expect(item('Museum').alternativeLocalId, set.alternatives.first.localId);
      expect(
        item('Boat trip').alternativeLocalId,
        set.alternatives.last.localId,
      );
      expect(item('Dinner').alternativeLocalId, isNull);

      // The option not taken travels with its price, or the recipient could not
      // compare the two.
      expect(
        bundle.costs.map((c) => c.amountMinor),
        unorderedEquals([1500, 5000]),
      );
    },
  );

  test(
    'a trip with decisions is stamped v2, an ordinary one stays v1',
    () async {
      // An older app would drop the decisions and flatten every option into the
      // day, so it must refuse this bundle — but it can still read plain trips.
      final withDecision = await seedDecision(db);
      expect(
        (await db.sharingDao.exportTrip(withDecision))!.formatVersion,
        TripBundle.currentFormatVersion,
      );

      final plain = await db.tripDao.createTrip(
        TripsCompanion.insert(title: 'X'),
      );
      expect((await db.sharingDao.exportTrip(plain))!.formatVersion, 1);
    },
  );

  test(
    'export then import reproduces the decision on the recipient\'s device',
    () async {
      final source = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(source.close);
      final sourceId = await seedDecision(source);
      final bytes = (await source.sharingDao.exportTrip(sourceId))!.encode();

      final newId = await db.sharingDao.importTrip(TripBundle.decode(bytes));

      // The decision came through as a decision — not as a day holding both plans.
      final sets = await db.alternativeDao.watchSetsForTrip(newId).first;
      final set = sets.values.single;
      expect(set.label, 'Saturday afternoon');
      final branches = (await db.alternativeDao
          .watchBranchesForTrip(newId)
          .first)[set.id]!;
      expect(branches, hasLength(2));
      expect(branches.where((b) => b.chosen).map((b) => b.label), [
        'Museum day',
      ]);

      // Items point at the *new* options, and the day still holds only its own.
      final items = await db.itineraryDao.watchItemsForTrip(newId).first;
      ItineraryItem item(String title) =>
          items.firstWhere((i) => i.title == title);
      expect(item('Museum').alternativeId, branches.first.id);
      expect(item('Boat trip').alternativeId, branches.last.id);
      expect(item('Dinner').alternativeId, isNull);

      // And the money rule survives the trip: both options are priced, but only
      // the chosen one counts.
      final all = await db.costDao.watchCostsForTrip(newId).first;
      expect(all.map((c) => c.amountMinor), unorderedEquals([1500, 5000]));
      final counted = await db.costDao.watchCountedCostsForTrip(newId).first;
      expect(counted.map((c) => c.amountMinor), [1500]);
    },
  );

  test(
    'the recipient can switch to the option the sender did not take',
    () async {
      final source = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(source.close);
      final bytes = (await source.sharingDao.exportTrip(
        await seedDecision(source),
      ))!.encode();
      final newId = await db.sharingDao.importTrip(TripBundle.decode(bytes));

      final sets = await db.alternativeDao.watchSetsForTrip(newId).first;
      final branches = (await db.alternativeDao
          .watchBranchesForTrip(newId)
          .first)[sets.values.single.id]!;
      await db.alternativeDao.chooseAlternative(branches.last.id);

      final counted = await db.costDao.watchCountedCostsForTrip(newId).first;
      expect(counted.map((c) => c.amountMinor), [5000]);
    },
  );

  test('a group inside an option survives with its shared cost', () async {
    final source = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(source.close);
    final tripId = await seedDecision(source);
    final sets = await source.alternativeDao.watchSetsForTrip(tripId).first;
    final branches = (await source.alternativeDao
        .watchBranchesForTrip(tripId)
        .first)[sets.values.single.id]!;
    // Two legs of one ticket, planned inside the option that was not chosen.
    final leg1 = await source.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: day,
        kind: ItemKind.transport,
        title: const Value('Leg 1'),
        sortOrder: const Value(1),
        alternativeId: Value(branches.last.id),
      ),
    );
    final leg2 = await source.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: day,
        kind: ItemKind.transport,
        title: const Value('Leg 2'),
        sortOrder: const Value(2),
        alternativeId: Value(branches.last.id),
      ),
    );
    final groupId = await source.groupDao.groupItems(leg1, leg2);
    await source.costDao.addCost(
      CostsCompanion.insert(
        groupId: Value(groupId),
        amountMinor: 8000,
        currency: Currency.eur,
        reason: 'Ticket',
      ),
    );

    final bytes = (await source.sharingDao.exportTrip(tripId))!.encode();
    final newId = await db.sharingDao.importTrip(TripBundle.decode(bytes));

    // Both legs came through in the same option and the same new group, and the
    // shared ticket still hangs off that group — uncounted, since the option was
    // not chosen.
    final items = await db.itineraryDao.watchItemsForTrip(newId).first;
    final legs = items.where((i) => i.title!.startsWith('Leg')).toList();
    expect(legs, hasLength(2));
    expect(legs.first.groupId, isNotNull);
    expect(legs.every((i) => i.groupId == legs.first.groupId), isTrue);
    expect(
      legs.every((i) => i.alternativeId == legs.first.alternativeId),
      isTrue,
    );

    final counted = await db.costDao.watchCountedCostsForTrip(newId).first;
    expect(counted.map((c) => c.amountMinor), [1500]);
  });
}
