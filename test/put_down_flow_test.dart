import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/clock.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/checklist/application/checklist_providers.dart';
import 'package:travelplanner/features/costs/application/cost_providers.dart';
import 'package:travelplanner/features/itinerary/application/item_clipboard.dart';
import 'package:travelplanner/features/itinerary/application/itinerary_providers.dart';
import 'package:travelplanner/features/itinerary/application/transport_mode_providers.dart';
import 'package:travelplanner/features/itinerary/widgets/alternative_card.dart';
import 'package:travelplanner/features/trips/application/trip_providers.dart';
import 'package:travelplanner/features/trips/presentation/trip_detail_screen.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// Covers the *putting down* half of moving an entry, which only exists on the
/// trip screen: the chip in each day's and each option's add-row, the bar naming
/// what is being carried, and what the screen says about where it landed.
///
/// The picking-up half is one call into [ItemClipboard] from the item sheet, so
/// these tests hold the entry directly and drive what happens next.
///
/// The repository is a real in-memory database — the writes under test are the
/// DAO's — but every stream the screen watches is overridden with a plain
/// `Stream.value`, since drift's `.watch()` never resolves under fake-async.
/// That means the timeline does *not* re-render after a write, which is why the
/// assertions read the database back with plain queries rather than looking for
/// the moved tile.
void main() {
  late AppDatabase db;
  late TripRepository repo;
  late SharedPreferences prefs;
  late int tripId;

  final day1 = DateTime(2026, 7, 5);
  final day2 = DateTime(2026, 7, 6);
  // Well clear of both days, so no tile is "under way" and the now-marker stays
  // out of the way of what is being tested.
  final now = DateTime(2026, 7, 5, 9);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Rome',
        startDate: Value(day1),
        endDate: Value(day2),
      ),
    );
  });
  tearDown(() => db.close());

  Future<int> addItem(
    String title, {
    required DateTime date,
    int sortOrder = 0,
    int? alternativeId,
  }) => db.itineraryDao.addItem(
    ItineraryItemsCompanion.insert(
      tripId: tripId,
      date: date,
      kind: ItemKind.place,
      title: Value(title),
      sortOrder: Value(sortOrder),
      alternativeId: Value(alternativeId),
    ),
  );

  Future<List<ItineraryItem>> readItems() =>
      (db.select(db.itineraryItems)
            ..where((i) => i.tripId.equals(tripId))
            ..orderBy([
              (i) => OrderingTerm(expression: i.date),
              (i) => OrderingTerm(expression: i.sortOrder),
            ]))
          .get();

  Future<ItineraryItem> readItem(int id) =>
      (db.select(db.itineraryItems)..where((i) => i.id.equals(id))).getSingle();

  Future<Map<int, AlternativeSet>> readSets() async {
    final rows = await (db.select(
      db.alternativeSets,
    )..where((s) => s.tripId.equals(tripId))).get();
    return {for (final row in rows) row.id: row};
  }

  Future<Map<int, List<Alternative>>> readBranches() async {
    final branches = <int, List<Alternative>>{};
    for (final setId in (await readSets()).keys) {
      branches[setId] =
          await (db.select(db.alternatives)
                ..where((a) => a.setId.equals(setId))
                ..orderBy([(a) => OrderingTerm(expression: a.sortOrder)]))
              .get();
    }
    return branches;
  }

  /// Pumps the trip screen against whatever is currently in the database, with
  /// [held] already picked up (null for empty hands).
  ///
  /// The surface is made tall enough for both days' add-rows to be laid out and
  /// tappable: the chips under test sit at the bottom of each day.
  Future<void> pumpDetail(WidgetTester tester, {Held? held}) async {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(800, 2400);
    addTearDown(tester.view.reset);

    final trip = (await db.tripDao.findTrip(tripId))!;
    final items = await readItems();
    final sets = await readSets();
    final branches = await readBranches();
    // A one-shot query, not `watchGroupsForTrip().first`: a drift `.watch()`
    // stream never resolves under fake-async, and awaiting one here would hang
    // every test in the file (see the note at the top).
    final groupRows = await (db.select(
      db.itemGroups,
    )..where((g) => g.tripId.equals(tripId))).get();
    final groups = {for (final g in groupRows) g.id: g};

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          sharedPreferencesProvider.overrideWithValue(prefs),
          tripProvider(tripId).overrideWith((ref) => Stream.value(trip)),
          itineraryProvider(tripId).overrideWith((ref) => Stream.value(items)),
          alternativeSetsProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(sets)),
          alternativeBranchesProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(branches)),
          collapsedDaysProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const {})),
          groupsProvider(tripId).overrideWith((ref) => Stream.value(groups)),
          costsForTripProvider(tripId).overrideWith(
            (ref) => Stream.value((
              byItem: const <int, List<Cost>>{},
              byGroup: const <int, List<Cost>>{},
              tripLevel: const <Cost>[],
            )),
          ),
          countedCostsProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const [])),
          tripParticipantsProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const [])),
          checklistsProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const [])),
          reasonRowsProvider.overrideWith((ref) => Stream.value(const [])),
          mePersonProvider.overrideWith((ref) => Stream.value(null)),
          transportModesProvider.overrideWith((ref) => Stream.value(const [])),
          // A fixed clock: the real one schedules a timer to the next minute,
          // which would still be pending when the test ends.
          nowProvider.overrideWith((ref) => Stream.value(now)),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: TripDetailScreen(tripId: tripId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    if (held != null) {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TripDetailScreen)),
      );
      container.read(itemClipboardProvider.notifier).hold(held);
      await tester.pumpAndSettle();
    }
  }

  HeldItem holding(int itemId, HoldMode mode) =>
      HeldItem(tripId: tripId, itemId: itemId, mode: mode);

  /// The day sections render in order, so the last "put it here" chip belongs to
  /// the last day — the one nothing was picked up from.
  Finder putDownChips() => find.text('Move here');

  testWidgets('a held entry is dimmed, and every day offers to take it', (
    tester,
  ) async {
    final museum = await addItem('Museum', date: day1);
    await addItem('Market', date: day2);

    await pumpDetail(tester, held: holding(museum, HoldMode.move));

    // Named, so what is in hand is never a guess.
    expect(find.text('Moving: Museum'), findsOneWidget);
    // One offer per day: the day it came from included, which is a legal move
    // (to the end of that day) and not worth a special case.
    expect(putDownChips(), findsNWidgets(2));
    // Still in place, but faded: nothing has happened to it yet.
    expect(
      find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.4),
      findsOneWidget,
    );
  });

  testWidgets('nothing held, nothing offered', (tester) async {
    await addItem('Museum', date: day1);

    await pumpDetail(tester);

    expect(putDownChips(), findsNothing);
    expect(find.text('Copy here'), findsNothing);
    expect(find.textContaining('Moving:'), findsNothing);
  });

  testWidgets('putting an entry down on another day moves it there', (
    tester,
  ) async {
    final museum = await addItem('Museum', date: day1, sortOrder: 0);
    await addItem('Dinner', date: day1, sortOrder: 1);
    await addItem('Market', date: day2, sortOrder: 0);

    await pumpDetail(tester, held: holding(museum, HoldMode.move));
    await tester.tap(putDownChips().last);
    await tester.pumpAndSettle();

    final moved = await readItem(museum);
    expect(moved.date, day2);
    // Appended after what the day already had, rather than landing on its slot.
    expect(moved.sortOrder, 1);
    expect((await readItems()).length, 3);
    // Hands are empty again, so the bar and the offers go with it.
    expect(find.textContaining('Moving:'), findsNothing);
    expect(putDownChips(), findsNothing);
  });

  testWidgets('a copy lands and says the money stayed behind', (tester) async {
    final museum = await addItem('Museum', date: day1);

    await pumpDetail(tester, held: holding(museum, HoldMode.copy));
    expect(find.text('Copying: Museum'), findsOneWidget);
    await tester.tap(find.text('Copy here').last);
    await tester.pumpAndSettle();

    final items = await readItems();
    expect(items.map((i) => i.title), ['Museum', 'Museum']);
    // The original has not moved; the copy is the one on the other day.
    expect((await readItem(museum)).date, day1);
    expect(items.last.date, day2);
    // Said out loud rather than left to be discovered in the totals.
    expect(find.textContaining("Expenses aren't copied"), findsOneWidget);
  });

  testWidgets('landing in an option that is not chosen says so', (
    tester,
  ) async {
    final beach = await addItem('Beach', date: day1);
    await db.alternativeDao.createSetFromItem(beach);
    final museum = await addItem('Museum', date: day1, sortOrder: 1);

    await pumpDetail(tester, held: holding(museum, HoldMode.move));
    // The card opens on the chosen option; the second is the one that would
    // take the entry's money out of the trip.
    await tester.fling(find.text('Beach'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlternativeCard),
        matching: putDownChips(),
      ),
    );
    await tester.pumpAndSettle();

    final branches = (await readBranches()).values.single;
    expect((await readItem(museum)).alternativeId, branches.last.id);
    expect(branches.last.chosen, isFalse);
    // Named, and explicit about what it costs — this is the one thing a drag
    // into the card could never have said.
    expect(find.textContaining('Option B'), findsWidgets);
    expect(find.textContaining("won't count toward the trip"), findsOneWidget);
  });

  testWidgets('landing in the chosen option passes without a warning', (
    tester,
  ) async {
    final beach = await addItem('Beach', date: day1);
    await db.alternativeDao.createSetFromItem(beach);
    final museum = await addItem('Museum', date: day1, sortOrder: 1);

    await pumpDetail(tester, held: holding(museum, HoldMode.move));
    await tester.tap(
      find.descendant(
        of: find.byType(AlternativeCard),
        matching: putDownChips(),
      ),
    );
    await tester.pumpAndSettle();

    final branches = (await readBranches()).values.single;
    expect((await readItem(museum)).alternativeId, branches.first.id);
    // Nothing changed about the trip's money, so there is nothing to warn about.
    expect(find.textContaining("won't count toward the trip"), findsNothing);
  });

  testWidgets('cancelling leaves the entry exactly where it was', (
    tester,
  ) async {
    final museum = await addItem('Museum', date: day1, sortOrder: 3);
    await addItem('Market', date: day2);

    await pumpDetail(tester, held: holding(museum, HoldMode.move));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Moving:'), findsNothing);
    expect(putDownChips(), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.4),
      findsNothing,
    );
    final unmoved = await readItem(museum);
    expect(unmoved.date, day1);
    expect(unmoved.sortOrder, 3);
  });

  testWidgets('a held group dims all its members and moves them together', (
    tester,
  ) async {
    final leg1 = await addItem('Leg 1', date: day1, sortOrder: 0);
    final leg2 = await addItem('Leg 2', date: day1, sortOrder: 1);
    await addItem('Market', date: day2, sortOrder: 0);
    final groupId = await db.groupDao.groupItems(leg1, leg2);
    await db.groupDao.setGroupLabel(groupId, 'Rail pass');

    await pumpDetail(
      tester,
      held: HeldGroup(tripId: tripId, groupId: groupId, mode: HoldMode.move),
    );

    // The bar names the group, and both members are faded — the whole run is in
    // hand, not one entry.
    expect(find.text('Moving: Rail pass'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.4),
      findsNWidgets(2),
    );

    await tester.tap(putDownChips().last);
    await tester.pumpAndSettle();

    // Both legs crossed to the other day, still grouped; nothing left on day 1.
    expect((await readItem(leg1)).date, day2);
    expect((await readItem(leg2)).date, day2);
    expect((await readItem(leg1)).groupId, groupId);
    expect(find.textContaining('Moving:'), findsNothing);
  });
}
