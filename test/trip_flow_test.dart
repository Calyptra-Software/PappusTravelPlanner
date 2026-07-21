import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/features/trips/application/trip_providers.dart';
import 'package:travelplanner/features/trips/presentation/trip_list_screen.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// Pumps the overview screen with [tripListProvider] overridden to emit [trips],
/// avoiding the real drift stream (which doesn't resolve under fake-async).
Future<void> pumpOverview(
  WidgetTester tester,
  List<Trip> trips, {
  Locale? locale,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [tripListProvider.overrideWith((ref) => Stream.value(trips))],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const TripListScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Trip _trip({required int id, required String title, String destination = ''}) {
  return Trip(
    id: id,
    title: title,
    destination: destination,
    startDate: null,
    endDate: null,
    notes: null,
    colorValue: 0xFF00695C,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  testWidgets('shows the empty state when there are no trips', (tester) async {
    await pumpOverview(tester, const []);

    expect(find.text('No trips yet'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('renders a card for each trip', (tester) async {
    await pumpOverview(tester, [
      _trip(id: 1, title: 'Summer in Italy', destination: 'Rome'),
      _trip(id: 2, title: 'Nordic road trip', destination: 'Oslo'),
    ]);

    expect(find.text('No trips yet'), findsNothing);
    expect(find.text('Summer in Italy'), findsOneWidget);
    expect(find.text('Rome'), findsOneWidget);
    expect(find.text('Nordic road trip'), findsOneWidget);
  });

  testWidgets('renders German strings when locale is de', (tester) async {
    await pumpOverview(tester, const [], locale: const Locale('de'));

    expect(find.text('Meine Reisen'), findsOneWidget);
    expect(find.text('Noch keine Reisen'), findsOneWidget);
    expect(find.text('Neue Reise'), findsOneWidget);
  });

  group('app bar actions adapt to the window width', () {
    /// Sizes the test surface in logical pixels for the next pump.
    void sizeSurface(WidgetTester tester, double width) {
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = Size(width, 800);
      addTearDown(tester.view.reset);
    }

    // The navigation actions, by the icon each shows when it has its own slot.
    const navigationIcons = [
      Icons.bar_chart,
      Icons.file_download_outlined,
      Icons.settings_outlined,
    ];

    // The menu is typed on a private enum, so match the raw widget type.
    final overflowMenu = find.byWidgetPredicate((w) => w is PopupMenuButton);

    testWidgets('collapses navigation actions into a menu on a phone', (
      tester,
    ) async {
      sizeSurface(tester, 400);
      await pumpOverview(tester, const []);

      expect(overflowMenu, findsOneWidget);
      for (final icon in navigationIcons) {
        expect(find.byIcon(icon), findsNothing);
      }
      // The actions the list itself uses stay directly reachable.
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
    });

    testWidgets('shows every action as an icon on a wide window', (
      tester,
    ) async {
      sizeSurface(tester, 900);
      await pumpOverview(tester, const []);

      expect(overflowMenu, findsNothing);
      for (final icon in navigationIcons) {
        expect(find.byIcon(icon), findsOneWidget);
      }
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('menu exposes the collapsed actions when opened', (
      tester,
    ) async {
      sizeSurface(tester, 400);
      await pumpOverview(tester, const []);

      await tester.tap(overflowMenu);
      await tester.pumpAndSettle();

      expect(find.text('Overall statistics'), findsOneWidget);
      expect(find.text('Import trip'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });
  });
}
