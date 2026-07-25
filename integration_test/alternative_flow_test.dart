import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart' show ItemKind;
import 'package:travelplanner/features/trips/presentation/trip_detail_screen.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// Drives the real TripDetailScreen against a real database: plan alternatives
/// for a day, swipe between the options, and commit one. Uses integration_test
/// (live binding, real clock) so drift `.watch()` streams actually resolve —
/// unlike plain widget tests under fake-async — and so the decision card is laid
/// out for real inside the day's reorderable list and the screen's scroll view.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plan alternatives for a day, swipe the options, choose one', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final day = DateTime(2026, 7, 5);
    final tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Italy',
        startDate: Value(day),
        endDate: Value(day),
      ),
    );
    Future<int> place(String title, int sortOrder) => db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: day,
        kind: ItemKind.place,
        sortOrder: Value(sortOrder),
        title: Value(title),
      ),
    );
    await place('Breakfast', 0);
    final museum = await place('Museum', 1);
    await place('Dinner', 2);
    await db.costDao.addCost(
      CostsCompanion.insert(
        itemId: Value(museum),
        amountMinor: 1500,
        // The built-in currencies are seeded in enum order, so EUR is row 1.
        currency: 1,
        reason: 'Ticket',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
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

    // The day reads as three plain entries, and the museum's €15 counts.
    expect(find.text('Museum'), findsOneWidget);
    expect(find.textContaining('15.00'), findsWidgets);

    // Turn the museum into a decision from its detail sheet.
    await tester.tap(find.text('Museum'));
    await tester.pumpAndSettle();
    final planButton = find.text('Plan alternatives');
    await tester.ensureVisible(planButton);
    await tester.pumpAndSettle();
    await tester.tap(planButton);
    await tester.pumpAndSettle();
    // The decision is written the moment the button is pressed, so the sheet can
    // simply be dismissed by tapping the scrim above it.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('Grouping'), findsNothing, reason: 'the sheet is closed');

    // The day now holds a decision card in the museum's old slot, opened on the
    // chosen option — the existing plan is untouched.
    expect(find.text('Choice'), findsOneWidget);
    expect(find.text('Option A'), findsWidgets);
    expect(find.text('Chosen'), findsOneWidget);
    expect(find.text('Museum'), findsOneWidget);
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);
    // Both options are priced in the indicator row, even though only one shows.
    expect(find.textContaining('Option A · €15.00'), findsOneWidget);
    await Future<void>.delayed(const Duration(milliseconds: 2500));

    // Swipe to the second option, dragging from the entry tile itself — what a
    // user actually grabs — not from some empty part of the card.
    await tester.fling(find.text('Museum'), const Offset(-500, 0), 2000);
    await tester.pumpAndSettle();
    expect(find.text('Museum'), findsNothing);
    expect(find.text('Nothing planned in this option yet.'), findsOneWidget);
    expect(find.text('Use this option'), findsOneWidget);
    var branches = await db.select(db.alternatives).get();
    expect(
      branches.where((b) => b.chosen).map((b) => b.sortOrder),
      [0],
      reason: 'swiping browses; it must not move the choice',
    );
    await Future<void>.delayed(const Duration(milliseconds: 2500));

    // Commit the empty option: the museum leaves the plan, and its €15 with it.
    await tester.tap(find.text('Use this option'));
    await tester.pumpAndSettle();
    branches = await db.select(db.alternatives).get();
    expect(branches.where((b) => b.chosen).map((b) => b.sortOrder), [1]);
    final counted = await db.costDao.watchCountedCostsForTrip(tripId).first;
    expect(counted, isEmpty, reason: 'the museum is no longer the plan');
    // The trip header no longer totals the museum's ticket, but the option's own
    // price stays on its pill, so the two can still be compared.
    expect(find.textContaining('Option A · €15.00'), findsOneWidget);
    await Future<void>.delayed(const Duration(milliseconds: 2500));

    // Swiping back shows the museum again, still priced. (The drag has to cover
    // a good part of the card: a PageView snaps back from a short one, and on a
    // wide desktop window a "short" drag is still a few hundred pixels.)
    await tester.fling(
      find.text('Nothing planned in this option yet.'),
      const Offset(500, 0),
      2000,
    );
    await tester.pumpAndSettle();
    expect(find.text('Museum'), findsOneWidget);
    expect(find.text('Use this option'), findsOneWidget);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
  });
}
