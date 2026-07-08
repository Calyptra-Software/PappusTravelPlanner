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
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/trips/presentation/trip_detail_screen.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// Drives the real TripDetailScreen widgets against a real in-memory database.
/// Uses integration_test (live binding, real clock) so drift `.watch()` streams
/// actually resolve — unlike plain widget tests under fake-async.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('group two stops, add one shared expense, counted once',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(title: 'Italy'),
    );
    final day = DateTime(2026, 7, 5);
    await db.itineraryDao.addItem(ItineraryItemsCompanion.insert(
      tripId: tripId,
      date: day,
      kind: ItemKind.transport,
      sortOrder: const Value(0),
      mode: const Value(TransportMode.train),
      fromLocation: const Value('Milan'),
      toLocation: const Value('Florence'),
    ));
    await db.itineraryDao.addItem(ItineraryItemsCompanion.insert(
      tripId: tripId,
      date: day,
      kind: ItemKind.transport,
      sortOrder: const Value(1),
      mode: const Value(TransportMode.train),
      fromLocation: const Value('Florence'),
      toLocation: const Value('Rome'),
    ));

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

    // Both legs are shown, ungrouped.
    expect(find.text('Milan  →  Florence'), findsOneWidget);
    expect(find.text('Florence  →  Rome'), findsOneWidget);
    expect(find.text('Group with next item'), findsNothing);

    // Open the first leg's detail sheet and group it with the next.
    await tester.tap(find.text('Milan  →  Florence'));
    await tester.pumpAndSettle();
    expect(find.text('Grouping'), findsOneWidget);
    await tester.tap(find.text('Group with next item'));
    await tester.pumpAndSettle();

    // Sheet now reflects membership: the shared-expenses editor is shown.
    expect(find.text('Shared expenses'), findsOneWidget);

    // Saving the just-grouped item must NOT drop it from the group (regression:
    // the full-row update used to reset groupId to null, ejecting this member).
    // The Save button sits at the bottom of a scrollable sheet, so bring it into
    // view first — otherwise the tap misses and the save never fires.
    final saveBtn = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(saveBtn);
    await tester.pumpAndSettle();
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();
    final members =
        await (db.select(db.itineraryItems)..where((i) => i.groupId.isNotNull()))
            .get();
    expect(members.length, 2, reason: 'both stops stay grouped after save');

    // Reopen the first leg to continue adding the shared expense.
    await tester.tap(find.text('Milan  →  Florence'));
    await tester.pumpAndSettle();
    // A grouped item now offers BOTH its own expenses and the shared ones.
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Shared expenses'), findsOneWidget);

    // Add one *shared* expense: the "Add expense" chip under "Shared expenses"
    // is the second one (own-expenses editor is rendered first). Scroll it into
    // view first — the grouped sheet is tall enough to push it off-screen.
    final addShared = find.text('Add expense').last;
    await tester.ensureVisible(addShared);
    await tester.pumpAndSettle();
    await tester.tap(addShared);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '90');
    // Category is a free-text field ("Category name") when none are saved yet.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Category name'),
      'Train ticket',
    );
    await tester.pumpAndSettle();
    // Save the cost (the sheet's primary button reads "Add"), then close.
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    // Close the item sheet if still open.
    if (find.text('Grouping').evaluate().isNotEmpty) {
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
    }

    // Back on the timeline: exactly one group cost row exists in the DB…
    final costs = await db.costDao.watchCostsForTrip(tripId).first;
    expect(costs.length, 1);
    expect(costs.single.groupId, isNotNull);
    expect(costs.single.amountMinor, 9000);

    // …and the day/trip total counts it once: "€ 90.00" shows, and crucially
    // NOT "180.00" — which is what a per-member double-count would produce for
    // this 2-member group.
    expect(find.textContaining('90.00'), findsWidgets);
    expect(find.textContaining('180'), findsNothing);

    // The two legs now render inside a group band headed by the default label.
    expect(find.text('Grouped'), findsOneWidget);
    expect(find.text('Milan  →  Florence'), findsOneWidget);
    expect(find.text('Florence  →  Rome'), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
