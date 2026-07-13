import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/costs/trip_stats.dart';
import 'package:travelplanner/features/itinerary/live_items.dart';

/// The money rule for alternatives: a cost hanging off a branch that was not
/// chosen is still *shown* (so each branch can be priced and compared) but never
/// *counted* — not in the trip's total, not on the overview card, not in the
/// expense split.
void main() {
  late AppDatabase db;

  final day = DateTime(2026, 7, 5);

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> makeTrip() =>
      db.tripDao.createTrip(TripsCompanion.insert(title: 'T'));

  Future<int> makeItem(
    int tripId, {
    required String title,
    int sortOrder = 0,
    int? alternativeId,
  }) => db.itineraryDao.addItem(
    ItineraryItemsCompanion.insert(
      tripId: tripId,
      date: day,
      kind: ItemKind.place,
      title: Value(title),
      sortOrder: Value(sortOrder),
      alternativeId: Value(alternativeId),
    ),
  );

  Future<int> makeCost({
    int? itemId,
    int? groupId,
    int? tripId,
    required int amountMinor,
    String paidBy = 'Ada',
  }) => db.costDao.addCost(
    CostsCompanion.insert(
      itemId: Value(itemId),
      groupId: Value(groupId),
      tripId: Value(tripId),
      amountMinor: amountMinor,
      currency: Currency.eur,
      reason: 'Ticket',
      paidBy: Value(paidBy),
    ),
  );

  Future<List<Alternative>> branchesOf(int tripId, int setId) async =>
      (await db.alternativeDao.watchBranchesForTrip(tripId).first)[setId]!;

  /// The trip's counted total in EUR minor units.
  Future<int> countedTotal(int tripId) async {
    final counted = await db.costDao.watchCountedCostsForTrip(tripId).first;
    return counted.fold<int>(0, (sum, c) => sum + c.amountMinor);
  }

  /// The trip's total as the overview card computes it, in EUR minor units.
  Future<int> cardTotal(int tripId) async {
    final totals = await db.costDao.watchTotalsByTrip().first;
    return totals[tripId]?[Currency.eur] ?? 0;
  }

  /// A trip with one decision: the chosen branch holds a €15 museum, the other a
  /// €50 boat trip. Returns (tripId, setId, branches).
  Future<(int, int, List<Alternative>)> tripWithDecision() async {
    final tripId = await makeTrip();
    final museum = await makeItem(tripId, title: 'Museum');
    final setId = await db.alternativeDao.createSetFromItem(museum);
    final branches = await branchesOf(tripId, setId);
    await makeCost(itemId: museum, amountMinor: 1500);
    final boat = await makeItem(
      tripId,
      title: 'Boat trip',
      alternativeId: branches.last.id,
    );
    await makeCost(itemId: boat, amountMinor: 5000);
    return (tripId, setId, branches);
  }

  test('an unchosen branch\'s cost is shown but not counted', () async {
    final (tripId, _, _) = await tripWithDecision();

    // Shown: the timeline prices both options, so they can be compared.
    final all = await db.costDao.watchCostsForTrip(tripId).first;
    expect(all.map((c) => c.amountMinor), unorderedEquals([1500, 5000]));

    // Counted: only the plan as it stands.
    expect(await countedTotal(tripId), 1500);
    expect(await cardTotal(tripId), 1500);
  });

  test('choosing the other branch moves the total to it', () async {
    final (tripId, _, branches) = await tripWithDecision();

    await db.alternativeDao.chooseAlternative(branches.last.id);

    expect(await countedTotal(tripId), 5000);
    expect(await cardTotal(tripId), 5000);
  });

  test('a branch\'s costs never reach the expense split', () async {
    final (tripId, _, _) = await tripWithDecision();
    await db.tripDao.addParticipant(tripId, 'Ada');
    await db.tripDao.addParticipant(tripId, 'Bob');

    final counted = await db.costDao.watchCountedCostsForTrip(tripId).first;
    final beneficiaries = await db.costDao
        .watchBeneficiariesForTrip(tripId)
        .first;
    final participants = await db.tripDao.watchParticipants(tripId).first;
    final stats = computeTripStats(counted, beneficiaries, [
      for (final p in participants) p.name,
    ]);

    // Ada paid the €15 museum and owes half of it; the €50 boat trip they did
    // not take must not show up in anyone's balance.
    final eur = stats.byCurrency.single;
    expect(eur.totalMinor, 1500);
    final ada = eur.byPerson.firstWhere((p) => p.name == 'Ada');
    final bob = eur.byPerson.firstWhere((p) => p.name == 'Bob');
    expect(ada.paidMinor, 1500);
    expect(ada.netMinor, 750);
    expect(bob.netMinor, -750);
    expect(eur.settlements.single.amountMinor, 750);
  });

  test('a group\'s shared cost follows its branch', () async {
    final tripId = await makeTrip();
    final museum = await makeItem(tripId, title: 'Museum');
    final setId = await db.alternativeDao.createSetFromItem(museum);
    final branches = await branchesOf(tripId, setId);
    // The other branch is a two-leg train journey on one ticket.
    final leg1 = await makeItem(
      tripId,
      title: 'Leg 1',
      alternativeId: branches.last.id,
    );
    final leg2 = await makeItem(
      tripId,
      title: 'Leg 2',
      sortOrder: 1,
      alternativeId: branches.last.id,
    );
    final groupId = await db.groupDao.groupItems(leg1, leg2);
    await makeCost(groupId: groupId, amountMinor: 8000);

    // The ticket belongs to the branch not taken, so it is not counted...
    expect(await countedTotal(tripId), 0);
    expect(await cardTotal(tripId), 0);

    // ...until that branch becomes the plan. Counted once, not once per leg.
    await db.alternativeDao.chooseAlternative(branches.last.id);
    expect(await countedTotal(tripId), 8000);
    expect(await cardTotal(tripId), 8000);
    final counted = await db.costDao.watchCountedCostsForTrip(tripId).first;
    expect(counted, hasLength(1));
  });

  test('costs outside any decision are unaffected', () async {
    final tripId = await makeTrip();
    final breakfast = await makeItem(tripId, title: 'Breakfast');
    final leg1 = await makeItem(tripId, title: 'Leg 1', sortOrder: 1);
    final leg2 = await makeItem(tripId, title: 'Leg 2', sortOrder: 2);
    final groupId = await db.groupDao.groupItems(leg1, leg2);
    await makeCost(itemId: breakfast, amountMinor: 800);
    await makeCost(groupId: groupId, amountMinor: 4000);
    await makeCost(tripId: tripId, amountMinor: 20000);

    // A loose item's cost, a loose group's shared ticket and a trip-level cost
    // all count, each exactly once.
    expect(await countedTotal(tripId), 24800);
    expect(await cardTotal(tripId), 24800);
  });

  test('a trip-level cost counts even while a decision is open', () async {
    final (tripId, _, _) = await tripWithDecision();
    await makeCost(tripId: tripId, amountMinor: 10000);

    expect(await countedTotal(tripId), 11500);
    expect(await cardTotal(tripId), 11500);
  });

  test('liveItems keeps loose items and the chosen branch only', () async {
    final (tripId, _, branches) = await tripWithDecision();
    await makeItem(tripId, title: 'Dinner', sortOrder: 1);
    final items = await db.itineraryDao.watchItemsForTrip(tripId).first;

    final all = await db.alternativeDao.watchBranchesForTrip(tripId).first;
    final chosen = chosenBranchIds(all);
    expect(chosen, {branches.first.id});
    expect(liveItems(items, chosen).map((i) => i.title), ['Museum', 'Dinner']);

    await db.alternativeDao.chooseAlternative(branches.last.id);
    final after = chosenBranchIds(
      await db.alternativeDao.watchBranchesForTrip(tripId).first,
    );
    expect(liveItems(items, after).map((i) => i.title), [
      'Boat trip',
      'Dinner',
    ]);
  });
}
