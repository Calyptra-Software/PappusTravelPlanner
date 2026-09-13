import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/core/widgets/app_sheet.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/trips/trip_filter.dart';
import 'package:travelplanner/features/trips/widgets/trip_filter_sheet.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// The filter sheet shared by the overview and the overall statistics: it edits
/// a copy of the query and hands it back only on OK.
void main() {
  const walks = Tag(id: 10, name: 'walks', colorValue: 0, sortOrder: 0);
  const ann = Person(id: 20, name: 'Ann', isMe: false);
  Trip routine(int id, String title) => Trip(
    id: id,
    title: title,
    destination: '',
    kind: TripKind.routine,
    colorValue: 0xFF112233,
    coverHidden: false,
    photosCollapsed: false,
    createdAt: DateTime(2026),
  );

  /// Opens the sheet over [query] and returns what it hands back — null when
  /// it was dismissed. [interact] runs while the sheet is open.
  Future<TripQuery?> openSheet(
    WidgetTester tester, {
    TripQuery query = const TripQuery(),
    bool showSort = true,
    required Future<void> Function() interact,
  }) async {
    // Tall enough that no section has to be scrolled to.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    TripQuery? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showAppSheet<TripQuery>(
                  context,
                  builder: (_) => TripFilterSheet(
                    query: query,
                    people: const [ann],
                    tags: const [walks],
                    routines: [routine(1, 'Commute'), routine(2, 'Ride')],
                    showSort: showSort,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await interact();
    return result;
  }

  Future<void> tapChip(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(FilterChip, label));
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();
  }

  testWidgets('every facet is written into the query it hands back', (
    tester,
  ) async {
    final result = await openSheet(
      tester,
      query: const TripQuery(text: 'rome'),
      interact: () async {
        await tapChip(tester, 'Past');
        await tapChip(tester, 'walks');
        await tapChip(tester, 'Commute');
        await tapChip(tester, 'Ann');
        await tester.tap(find.widgetWithText(ChoiceChip, 'Name (A–Z)'));
        await tester.pumpAndSettle();
        await confirm(tester);
      },
    );

    expect(result, isNotNull);
    expect(result!.statuses, {TripStatus.past});
    expect(result.tagIds, {10});
    expect(result.routineIds, {1});
    expect(result.participantIds, {20});
    expect(result.sort, TripSort.nameAsc);
    // The search is not the sheet's to touch.
    expect(result.text, 'rome');
  });

  testWidgets('a chip tapped twice is off again', (tester) async {
    final result = await openSheet(
      tester,
      interact: () async {
        for (final label in ['Past', 'walks', 'Commute', 'Ann']) {
          await tapChip(tester, label);
          await tapChip(tester, label);
        }
        await confirm(tester);
      },
    );

    expect(result!.hasActiveFilters, isFalse);
  });

  testWidgets('"any routine" selects them all, and clears them all', (
    tester,
  ) async {
    final result = await openSheet(
      tester,
      interact: () async {
        await tapChip(tester, 'Any routine');
        final any = tester.widget<FilterChip>(
          find.widgetWithText(FilterChip, 'Any routine'),
        );
        expect(any.selected, isTrue);
        expect(
          tester
              .widget<FilterChip>(find.widgetWithText(FilterChip, 'Ride'))
              .selected,
          isTrue,
        );
        await confirm(tester);
      },
    );
    expect(result!.routineIds, {1, 2});

    final cleared = await openSheet(
      tester,
      query: const TripQuery(routineIds: {1, 2}),
      interact: () async {
        await tapChip(tester, 'Any routine');
        await confirm(tester);
      },
    );
    expect(cleared!.routineIds, isEmpty);
  });

  testWidgets('a date range is picked, and can be cleared on its own', (
    tester,
  ) async {
    final result = await openSheet(
      tester,
      interact: () async {
        await tester.tap(find.text('Any'));
        await tester.pumpAndSettle();
        // Typed rather than tapped: the calendar opens on whatever month the
        // test happens to run in.
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();
        final fields = find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(fields.at(0), '09/10/2026');
        await tester.enterText(fields.at(1), '09/12/2026');
        await tester.tap(
          find.descendant(of: find.byType(Dialog), matching: find.text('OK')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Any'), findsNothing);
        await confirm(tester);
      },
    );
    expect(result!.from, DateTime(2026, 9, 10));
    expect(result.to, DateTime(2026, 9, 12));

    final cleared = await openSheet(
      tester,
      query: TripQuery(from: DateTime(2026, 9, 10), to: DateTime(2026, 9, 12)),
      interact: () async {
        await tester.tap(find.byIcon(Icons.clear));
        await tester.pumpAndSettle();
        expect(find.text('Any'), findsOneWidget);
        await confirm(tester);
      },
    );
    expect(cleared!.from, isNull);
    expect(cleared.to, isNull);
  });

  testWidgets('clear empties the facets but keeps the search and the sort', (
    tester,
  ) async {
    final result = await openSheet(
      tester,
      query: const TripQuery(
        text: 'rome',
        statuses: {TripStatus.past},
        tagIds: {10},
        sort: TripSort.nameAsc,
      ),
      interact: () async {
        await tester.tap(find.widgetWithText(TextButton, 'Clear'));
        await tester.pumpAndSettle();
        await confirm(tester);
      },
    );

    expect(result!.hasActiveFilters, isFalse);
    expect(result.text, 'rome');
    expect(result.sort, TripSort.nameAsc);
  });

  testWidgets('without a sort section the sort handed in is kept', (
    tester,
  ) async {
    final result = await openSheet(
      tester,
      query: const TripQuery(sort: TripSort.expenseDesc),
      showSort: false,
      interact: () async {
        expect(find.text('Filter'), findsOneWidget);
        expect(find.text('Sort'), findsNothing);
        expect(find.byType(ChoiceChip), findsNothing);
        await confirm(tester);
      },
    );

    expect(result!.sort, TripSort.expenseDesc);
  });
}
