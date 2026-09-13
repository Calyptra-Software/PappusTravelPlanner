import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/costs/application/cost_providers.dart';
import 'package:travelplanner/features/costs/presentation/trip_stats_screen.dart';
import 'package:travelplanner/features/itinerary/application/itinerary_providers.dart';
import 'package:travelplanner/features/trips/application/trip_providers.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

import 'currency_fixture.dart';

/// The all-trips statistics read through a filter of their own: set on the
/// screen, said above the tabs, and cleared from there.
///
/// Every DB-backed provider the screen watches is a plain stream — drift's
/// `.watch()` never resolves under fake-async — while the statistics
/// themselves are the real computation.
void main() {
  Trip trip(int id) => Trip(
    id: id,
    title: 'Trip $id',
    destination: '',
    kind: TripKind.trip,
    colorValue: 0xFF112233,
    coverHidden: false,
    photosCollapsed: false,
    createdAt: DateTime(2026),
  );

  Cost cost(int id, int tripId, int minor) => Cost(
    id: id,
    tripId: tripId,
    amountMinor: minor,
    currency: eurId,
    reason: 'Dinner',
    paid: false,
    isTransfer: false,
    createdAt: DateTime(2026),
  );

  const walks = Tag(id: 10, name: 'walks', colorValue: 0, sortOrder: 0);

  Future<void> pumpAllTripsStats(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...currencyOverrides,
          tripListProvider.overrideWith(
            (ref) => Stream.value([trip(1), trip(2)]),
          ),
          routineListProvider.overrideWith((ref) => Stream.value(const [])),
          tagListProvider.overrideWith((ref) => Stream.value(const [walks])),
          tagsByTripProvider.overrideWith(
            (ref) => Stream.value(const {
              1: [walks],
            }),
          ),
          allParticipantsProvider.overrideWith((ref) => Stream.value(const {})),
          for (final id in [1, 2]) ...[
            // One dinner on the first trip, two on the second.
            countedCostsProvider(id).overrideWith(
              (ref) => Stream.value([
                for (var i = 0; i < id; i++) cost(id * 10 + i, id, 1000),
              ]),
            ),
            tripBeneficiariesProvider(
              id,
            ).overrideWith((ref) => Stream.value(const {})),
            tripParticipantsProvider(
              id,
            ).overrideWith((ref) => Stream.value(const [])),
            itineraryProvider(id).overrideWith((ref) => Stream.value(const [])),
            alternativeBranchesProvider(
              id,
            ).overrideWith((ref) => Stream.value(const {})),
          ],
          reasonRowsProvider.overrideWith((ref) => Stream.value(const [])),
          mePersonProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TripStatsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens on every trip, and says so', (tester) async {
    await pumpAllTripsStats(tester);

    expect(find.text('2 of 2 trips'), findsOneWidget);
    expect(find.text('3 expenses'), findsOneWidget);
    expect(find.text('Clear'), findsNothing);
  });

  testWidgets('a tag narrows the expenses, and the line clears it', (
    tester,
  ) async {
    await pumpAllTripsStats(tester);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    // The overview's sheet, less the sort a sum has no use for.
    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('Sort'), findsNothing);
    await tester.tap(find.widgetWithText(FilterChip, 'walks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('1 of 2 trips'), findsOneWidget);
    expect(find.text('1 expense'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('2 of 2 trips'), findsOneWidget);
    expect(find.text('3 expenses'), findsOneWidget);
  });
}
