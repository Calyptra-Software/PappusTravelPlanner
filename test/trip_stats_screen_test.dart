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

/// Covers how the balances section reports settlements: the figure no expense
/// explains is named, and a suggested payment can be booked as one.
void main() {
  final trip = Trip(
    id: 1,
    title: 'Rome',
    destination: '',
    kind: TripKind.trip,
    colorValue: 0xFF112233,
    photosCollapsed: false,
    createdAt: DateTime(2026),
  );

  Cost cost(
    int id,
    int minor, {
    String reason = 'Dinner',
    String? paidBy,
    bool isTransfer = false,
  }) => Cost(
    id: id,
    tripId: 1,
    amountMinor: minor,
    currency: eurId,
    reason: reason,
    paidBy: paidBy,
    paid: false,
    isTransfer: isTransfer,
    createdAt: DateTime(2026),
  );

  Person person(int id, String name) => Person(id: id, name: name, isMe: false);

  /// Pumps the statistics screen over a fixed set of costs. The rosters are
  /// plain streams — drift's `.watch()` never resolves under the fake-async
  /// clock — but the statistics themselves are the real `computeTripStats`.
  Future<void> pumpStats(
    WidgetTester tester, {
    required List<Cost> costs,
    required Map<int, List<Person>> beneficiaries,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...currencyOverrides,
          tripProvider(1).overrideWith((ref) => Stream.value(trip)),
          countedCostsProvider(1).overrideWith((ref) => Stream.value(costs)),
          tripBeneficiariesProvider(
            1,
          ).overrideWith((ref) => Stream.value(beneficiaries)),
          tripParticipantsProvider(
            1,
          ).overrideWith((ref) => Stream.value(const [])),
          itineraryProvider(1).overrideWith((ref) => Stream.value(const [])),
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
          home: const TripStatsScreen(tripId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a settled amount is named beside the person it belongs to', (
    tester,
  ) async {
    // Ann paid 60 for the three of them; Bo has since handed her his 20 back.
    final dinner = cost(1, 6000, paidBy: 'Ann');
    final repayment = cost(2, 2000, reason: '', paidBy: 'Bo', isTransfer: true);
    await pumpStats(
      tester,
      costs: [dinner, repayment],
      beneficiaries: {
        1: [person(1, 'Ann'), person(2, 'Bo'), person(3, 'Cy')],
        2: [person(1, 'Ann')],
      },
    );

    // The trip's spending is the dinner alone…
    expect(find.text('1 expense'), findsOneWidget);
    // …while the balances account for the repayment on both sides.
    expect(find.text('paid back €20.00'), findsOneWidget);
    expect(find.text('received €20.00'), findsOneWidget);
    // Bo is square, so only Cy is left to settle.
    expect(find.text('Cy pays Ann'), findsOneWidget);
    expect(find.text('Bo pays Ann'), findsNothing);
  });

  testWidgets('a suggested payment opens the settlement form, prefilled', (
    tester,
  ) async {
    final dinner = cost(1, 6000, paidBy: 'Ann');
    await pumpStats(
      tester,
      costs: [dinner],
      beneficiaries: {
        1: [person(1, 'Ann'), person(2, 'Bo')],
      },
    );

    expect(find.text('Bo pays Ann'), findsOneWidget);
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();

    // The sheet opens as a settlement carrying the suggestion's amount…
    expect(find.text('Record settlement'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '30.00'), findsOneWidget);
    // …and its two ends, which is what makes it one tap.
    expect(find.widgetWithText(TextFormField, 'Bo'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Ann'), findsOneWidget);
  });
}
