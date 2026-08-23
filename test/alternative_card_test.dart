import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/costs/application/cost_providers.dart';
import 'package:travelplanner/features/itinerary/application/item_clipboard.dart';
import 'package:travelplanner/features/itinerary/application/transport_mode_providers.dart';
import 'package:travelplanner/features/itinerary/day_blocks.dart';
import 'package:travelplanner/features/itinerary/widgets/alternative_card.dart';
import 'package:travelplanner/features/itinerary/widgets/now_line.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

import 'currency_fixture.dart';
import 'support/attachment_overrides.dart';

/// Covers the swipeable decision card: only the option on screen is drawn,
/// swiping merely browses (it must never move the trip's money), and every
/// option's price stays visible in the indicator row so they can be compared.
void main() {
  late AppDatabase db;
  late TripRepository repo;
  late SharedPreferences prefs;

  final day = DateTime(2026, 7, 5);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  tearDown(() => db.close());

  /// Wraps [card] in the scope it needs. The cost chips on a tile read the
  /// reason-icon roster and the display preference, so both are stubbed: the
  /// drift stream behind the roster would never resolve under fake-async.
  Widget wrap(Widget card) => ProviderScope(
    overrides: [
      ...currencyOverrides,
      repositoryProvider.overrideWithValue(repo),
      ...attachmentTestOverrides,
      sharedPreferencesProvider.overrideWithValue(prefs),
      reasonRowsProvider.overrideWith((ref) => Stream.value(const [])),
      // The transport tile resolves its mode through this stream; like the
      // reason roster, the real drift stream would never resolve under
      // fake-async, so stub it with the one mode the card uses.
      transportModesProvider.overrideWith(
        (ref) => Stream.value([
          TransportModeRow(id: 6, builtinKey: 'train', sortOrder: 0),
        ]),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: card)),
    ),
  );

  ItineraryItem item(int id, String title, {required int alternativeId}) =>
      ItineraryItem(
        id: id,
        tripId: 1,
        date: day,
        sortOrder: 0,
        kind: ItemKind.place,
        spansNextDay: false,
        title: title,
        alternativeId: alternativeId,
      );

  Cost cost(int id, int itemId, int amountMinor) => Cost(
    id: id,
    itemId: itemId,
    amountMinor: amountMinor,
    currency: eurId,
    reason: 'Ticket',
    paid: false,
    isTransfer: false,
    createdAt: DateTime(2026),
  );

  /// A decision with a €15 museum (chosen) and a €50 boat trip.
  DecisionBlock block() => DecisionBlock(
    set: AlternativeSet(id: 5, tripId: 1, date: day, sortOrder: 0),
    branches: const [
      Alternative(id: 10, setId: 5, sortOrder: 0, chosen: true),
      Alternative(id: 11, setId: 5, sortOrder: 1, chosen: false),
    ],
    itemsByBranch: {
      // Option A holds two entries, so it is the taller of the two — which
      // the height test below depends on.
      10: [
        item(1, 'Museum', alternativeId: 10),
        item(3, 'Lunch', alternativeId: 10),
      ],
      11: [item(2, 'Boat trip', alternativeId: 11)],
    },
  );

  Future<void> pumpCard(WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        AlternativeCard(
          block: block(),
          accent: Colors.teal,
          groups: const {},
          costsByItem: {
            1: [cost(1, 1, 1500)],
            2: [cost(2, 2, 5000)],
          },
          costsByGroup: const {},
          localeName: 'en',
          onTapItem: (_) {},
          onTapCost: (_) {},
          onAddPlace: (_) {},
          onAddTransport: (_) {},
          onQuickAddPlace: (_, _) {},
          onReorderBranch: (_, _, _) {},
          onReorderRun: (_, _, _) {},
          held: null,
          onPutDown: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the chosen option and hides the other', (tester) async {
    await pumpCard(tester);

    expect(find.text('Museum'), findsOneWidget);
    expect(find.text('Boat trip'), findsNothing);
    // The chosen option says so; there is nothing to commit.
    expect(find.text('Chosen'), findsOneWidget);
    expect(find.text('Use this option'), findsNothing);
  });

  testWidgets('every option\'s price is visible without swiping', (
    tester,
  ) async {
    await pumpCard(tester);

    // The pager can only show one option, so the indicator row carries the
    // comparison — this is the whole point of planning alternatives.
    expect(find.textContaining('Option A · €15.00'), findsOneWidget);
    expect(find.textContaining('Option B · €50.00'), findsOneWidget);
  });

  testWidgets('swiping browses the next option without choosing it', (
    tester,
  ) async {
    await pumpCard(tester);

    await tester.fling(find.text('Museum'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Boat trip'), findsOneWidget);
    expect(find.text('Museum'), findsNothing);
    // Looking is not choosing: the option on screen offers to be chosen, and
    // nothing has been written. (Read with a plain query, not a .watch() stream
    // — those never resolve under fake-async.)
    expect(find.text('Use this option'), findsOneWidget);
    expect(await db.select(db.alternatives).get(), isEmpty);
  });

  testWidgets('the chevron steps to the next option', (tester) async {
    await pumpCard(tester);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('Boat trip'), findsOneWidget);
  });

  testWidgets('clicking the card lets the arrow keys step through the options', (
    tester,
  ) async {
    await pumpCard(tester);

    // Before the click the card has no focus, so the keys go nowhere — this is
    // what made the shortcuts unreachable: nothing gave the card the keyboard.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Museum'), findsOneWidget);

    // Clicking it anywhere hands it the keyboard (here: its title).
    await tester.tap(find.text('Choice'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Boat trip'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('Museum'), findsOneWidget);
  });

  testWidgets('"use this option" commits the choice', (tester) async {
    // The card writes through the repository, so give it a real decision to
    // choose in.
    final tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(title: 'T'),
    );
    final museum = await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: day,
        kind: ItemKind.place,
      ),
    );
    final setId = await db.alternativeDao.createSetFromItem(museum);
    final branches =
        await (db.select(db.alternatives)
              ..where((a) => a.setId.equals(setId))
              ..orderBy([(a) => OrderingTerm(expression: a.sortOrder)]))
            .get();

    await tester.pumpWidget(
      wrap(
        AlternativeCard(
          block: DecisionBlock(
            set: AlternativeSet(
              id: setId,
              tripId: tripId,
              date: day,
              sortOrder: 0,
            ),
            branches: branches,
            itemsByBranch: {
              for (final b in branches) b.id: const <ItineraryItem>[],
            },
          ),
          accent: Colors.teal,
          groups: const {},
          costsByItem: const {},
          costsByGroup: const {},
          localeName: 'en',
          onTapItem: (_) {},
          onTapCost: (_) {},
          onAddPlace: (_) {},
          onAddTransport: (_) {},
          onQuickAddPlace: (_, _) {},
          onReorderBranch: (_, _, _) {},
          onReorderRun: (_, _, _) {},
          held: null,
          onPutDown: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this option'));
    await tester.pumpAndSettle();

    final after = await db.select(db.alternatives).get();
    expect(after.where((b) => b.chosen).map((b) => b.id), [branches.last.id]);
  });

  testWidgets('an option comes back at its own full height after a swipe away', (
    tester,
  ) async {
    await pumpCard(tester);
    final tallHeight = tester.getSize(find.byType(AlternativeCard)).height;
    // The taller option's actions sit at the bottom of the card, so they are the
    // first thing a height that is too small cuts off.
    expect(find.text('Add place'), findsOneWidget);

    await tester.fling(find.text('Museum'), const Offset(-600, 0), 2000);
    await tester.pumpAndSettle();
    final shortHeight = tester.getSize(find.byType(AlternativeCard)).height;
    expect(
      shortHeight,
      lessThan(tallHeight),
      reason: 'the card shrinks to fit',
    );

    await tester.fling(find.text('Boat trip'), const Offset(600, 0), 2000);
    await tester.pumpAndSettle();

    // Regression: the height is interpolated from the pager's position, and
    // `onPageChanged` fires halfway through a swipe. Rebuilding only then froze
    // the card at that moment's height, so a swipe away and back left the taller
    // option clipped — its add actions gone.
    expect(tester.getSize(find.byType(AlternativeCard)).height, tallHeight);
    expect(find.text('Museum'), findsOneWidget);
    expect(find.text('Add place'), findsOneWidget);
    final addPlace = tester.getRect(find.text('Add place'));
    final card = tester.getRect(find.byType(AlternativeCard));
    expect(addPlace.bottom, lessThanOrEqualTo(card.bottom));
  });

  testWidgets('an option ending on a leg offers to add its destination', (
    tester,
  ) async {
    // The same "you just arrived here" shortcut the day itself offers: an option
    // that ends on a leg to Kronberg can add Kronberg as a place in one tap,
    // without typing the name again.
    (int, String)? quickAdded;
    await tester.pumpWidget(
      wrap(
        AlternativeCard(
          block: DecisionBlock(
            set: AlternativeSet(id: 5, tripId: 1, date: day, sortOrder: 0),
            branches: const [
              Alternative(id: 10, setId: 5, sortOrder: 0, chosen: true),
              Alternative(id: 11, setId: 5, sortOrder: 1, chosen: false),
            ],
            itemsByBranch: {
              10: [
                ItineraryItem(
                  id: 1,
                  tripId: 1,
                  date: day,
                  sortOrder: 0,
                  kind: ItemKind.transport,
                  spansNextDay: false,
                  mode: 6,
                  fromLocation: 'Hamburg',
                  toLocation: 'Kronberg',
                  alternativeId: 10,
                ),
              ],
              11: [item(2, 'Boat trip', alternativeId: 11)],
            },
          ),
          accent: Colors.teal,
          groups: const {},
          costsByItem: const {},
          costsByGroup: const {},
          localeName: 'en',
          onTapItem: (_) {},
          onTapCost: (_) {},
          onAddPlace: (_) {},
          onAddTransport: (_) {},
          onQuickAddPlace: (branchId, location) =>
              quickAdded = (branchId, location),
          onReorderBranch: (_, _, _) {},
          onReorderRun: (_, _, _) {},
          held: null,
          onPutDown: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Kronberg'));
    await tester.pumpAndSettle();

    // The place lands inside the option that was on screen, not on the day.
    expect(quickAdded, (10, 'Kronberg'));

    // The other option ends on a place, so there is nowhere to "arrive".
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.textContaining('Add Kronberg'), findsNothing);
  });

  /// A decision on today whose chosen option runs 11:00–12:00 and then
  /// 15:00–16:00 — so a time can fall *between* its entries, which is where a
  /// decision would otherwise swallow the "you are here" mark: the day sees the
  /// whole decision as under way and draws no line of its own.
  Future<void> pumpTimedCard(
    WidgetTester tester, {
    required int nowMinutes,
    bool isNow = true,
  }) async {
    ItineraryItem timed(int id, String title, int start, int end) => item(
      id,
      title,
      alternativeId: 10,
    ).copyWith(startMinutes: Value(start), endMinutes: Value(end));

    await tester.pumpWidget(
      wrap(
        AlternativeCard(
          block: DecisionBlock(
            set: AlternativeSet(id: 5, tripId: 1, date: day, sortOrder: 0),
            branches: const [
              Alternative(id: 10, setId: 5, sortOrder: 0, chosen: true),
              Alternative(id: 11, setId: 5, sortOrder: 1, chosen: false),
            ],
            itemsByBranch: {
              10: [
                timed(1, 'Museum', 11 * 60, 12 * 60),
                timed(3, 'Park', 15 * 60, 16 * 60),
              ],
              11: [timed(2, 'Boat trip', 11 * 60, 17 * 60)],
            },
          ),
          accent: Colors.teal,
          groups: const {},
          costsByItem: const {},
          costsByGroup: const {},
          localeName: 'en',
          isNow: isNow,
          nowMinutes: nowMinutes,
          onTapItem: (_) {},
          onTapCost: (_) {},
          onAddPlace: (_) {},
          onAddTransport: (_) {},
          onQuickAddPlace: (_, _) {},
          onReorderBranch: (_, _, _) {},
          onReorderRun: (_, _, _) {},
          held: null,
          onPutDown: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('between two entries of the option in progress, the now-line is '
      'drawn inside the card', (tester) async {
    await pumpTimedCard(tester, nowMinutes: 13 * 60 + 30);

    expect(find.byType(NowLine), findsOneWidget);
    // On the decision itself, saying which slot of the day we are in.
    expect(find.byType(NowBadge), findsOneWidget);
  });

  testWidgets('an entry under way takes the badge, and no line is drawn', (
    tester,
  ) async {
    await pumpTimedCard(tester, nowMinutes: 11 * 60 + 30);

    expect(find.byType(NowLine), findsNothing);
    // One on the decision, one on the entry itself.
    expect(find.byType(NowBadge), findsNWidgets(2));
  });

  testWidgets('a decision the day is not in carries no mark', (tester) async {
    // The option not taken would still be running at 16:30 — but the trip is not
    // following it, so the day has moved past this decision entirely.
    await pumpTimedCard(tester, nowMinutes: 16 * 60 + 30, isNow: false);

    expect(find.byType(NowLine), findsNothing);
    expect(find.byType(NowBadge), findsNothing);
  });

  testWidgets('a held entry can be put down in the option on screen', (
    tester,
  ) async {
    int? target;
    await tester.pumpWidget(
      wrap(
        AlternativeCard(
          block: block(),
          accent: Colors.teal,
          groups: const {},
          costsByItem: const {},
          costsByGroup: const {},
          localeName: 'en',
          onTapItem: (_) {},
          onTapCost: (_) {},
          onAddPlace: (_) {},
          onAddTransport: (_) {},
          onQuickAddPlace: (_, _) {},
          onReorderBranch: (_, _, _) {},
          onReorderRun: (_, _, _) {},
          held: const HeldItem(tripId: 1, itemId: 9, mode: HoldMode.move),
          onPutDown: (branchId) => target = branchId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The offer joins the option's own add-row, so the destination is the
    // option being looked at — not "the card", which names no option at all.
    await tester.tap(find.text('Move here'));
    expect(target, 10);

    // Swiping to the other option retargets it: same chip, the option on screen.
    await tester.fling(find.text('Museum'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move here'));
    expect(target, 11);
  });

  testWidgets('nothing held, nothing offered', (tester) async {
    await pumpCard(tester);

    expect(find.text('Move here'), findsNothing);
    expect(find.text('Copy here'), findsNothing);
  });
}
