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
import 'package:travelplanner/features/costs/application/cost_providers.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// A routine's cost is the **fare** — what this ride costs — so it is copied
/// onto every trip stamped out of the routine, and the template's own copy must
/// therefore never be counted as money spent. Counting both would charge the
/// user twice for a journey they described once.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the fare counts once it is travelled, never on the template', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final routineId = await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'To work',
        kind: const Value(TripKind.routine),
      ),
    );
    await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: routineId,
        date: DateTime(1970, 1, 1),
        kind: ItemKind.transport,
        fromLocation: const Value('Home'),
        toLocation: const Value('Office'),
      ),
    );
    await db.costDao.addCost(
      CostsCompanion.insert(
        tripId: Value(routineId),
        amountMinor: 320,
        currency: 1,
        reason: 'Ticket',
      ),
    );

    late ProviderContainer container;
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
          home: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The routine alone: its fare is a price, not a payment.
    final sub = container.listen(allTripsStatsProvider, (_, _) {});
    addTearDown(sub.close);
    await tester.pumpAndSettle();
    expect(sub.read().byCurrency, isEmpty);

    // Travel it once, and the fare is now money that was spent.
    await db.routineDao.materializeRoutine(
      routineId,
      startDate: DateTime(2026, 8, 3),
    );
    await tester.pumpAndSettle();
    expect(sub.read().byCurrency.single.currency, 'EUR');
    expect(sub.read().byCurrency.single.totalMinor, 320);

    // Twice, and it counts twice — but the template still counts for nothing.
    await db.routineDao.materializeRoutine(
      routineId,
      startDate: DateTime(2026, 8, 4),
    );
    await tester.pumpAndSettle();
    expect(sub.read().byCurrency.single.totalMinor, 640);
  });
}
