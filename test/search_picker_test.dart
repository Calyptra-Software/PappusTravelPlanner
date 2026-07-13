import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/core/widgets/search_picker.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// Covers the searchable picker behind the category and person fields: typing
/// filters the list, a query nobody matches can be added straight from the
/// search box, and dismissing the sheet is not the same as picking "none".
void main() {
  const categories = [
    'Hotel',
    'Dinner',
    'Train ticket',
    'Museum',
    'Souvenirs',
  ];

  /// Opens the picker over a bare app and hands back the future it resolves.
  /// [result] receives the outcome — deliberately a two-level "not yet / picked
  /// what" so a dismissal (no result) is told apart from picking "none" (a
  /// result whose value is null).
  Future<void> open(
    WidgetTester tester, {
    required List<SearchPickerResult?> result,
    String? selected,
    String? noneLabel,
    bool allowCreate = true,
  }) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final picked = await showSearchPicker(
                  context,
                  title: 'Category',
                  options: [
                    for (final c in categories) SearchPickerOption(c),
                  ],
                  selected: selected,
                  noneLabel: noneLabel,
                  allowCreate: allowCreate,
                );
                result.add(picked);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('typing filters the list down to the matches', (tester) async {
    await open(tester, result: []);
    expect(find.text('Hotel'), findsOneWidget);
    expect(find.text('Museum'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'in');
    await tester.pumpAndSettle();

    // Matches anywhere in the label, not just at the start: "Dinner", "Train
    // ticket" — but not "Hotel".
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('Train ticket'), findsOneWidget);
    expect(find.text('Hotel'), findsNothing);
    expect(find.text('Museum'), findsNothing);
  });

  testWidgets('picking an option resolves to it', (tester) async {
    final result = <SearchPickerResult?>[];
    await open(tester, result: result);

    await tester.tap(find.text('Museum'));
    await tester.pumpAndSettle();

    expect(result.single?.value, 'Museum');
  });

  testWidgets('a query nobody matches offers to add it', (tester) async {
    final result = <SearchPickerResult?>[];
    await open(tester, result: result);

    await tester.enterText(find.byType(TextField), 'Sushi');
    await tester.pumpAndSettle();
    expect(find.text('Add “Sushi”'), findsOneWidget);

    await tester.tap(find.text('Add “Sushi”'));
    await tester.pumpAndSettle();
    expect(result.single?.value, 'Sushi');
  });

  testWidgets('an existing category is a hit, not a new entry', (tester) async {
    await open(tester, result: []);

    await tester.enterText(find.byType(TextField), 'hotel');
    await tester.pumpAndSettle();

    expect(find.text('Hotel'), findsOneWidget);
    expect(find.text('Add “hotel”'), findsNothing);
  });

  testWidgets('nothing matches and creating is off', (tester) async {
    await open(tester, result: [], allowCreate: false);

    await tester.enterText(find.byType(TextField), 'Sushi');
    await tester.pumpAndSettle();

    expect(find.text('Add “Sushi”'), findsNothing);
    expect(find.text('No matches'), findsOneWidget);
  });

  testWidgets('the none row resolves to a null value', (tester) async {
    final result = <SearchPickerResult?>[];
    await open(tester, result: result, selected: 'Hotel',
        noneLabel: 'Unassigned');

    await tester.tap(find.text('Unassigned'));
    await tester.pumpAndSettle();

    // A result, so the caller clears the field — unlike a dismissal below.
    expect(result, hasLength(1));
    expect(result.single?.value, isNull);
  });

  testWidgets('dismissing the sheet changes nothing', (tester) async {
    final result = <SearchPickerResult?>[];
    await open(tester, result: result, selected: 'Hotel',
        noneLabel: 'Unassigned');

    await tester.tapAt(const Offset(10, 10)); // the barrier above the sheet
    await tester.pumpAndSettle();

    expect(result.single, isNull);
  });
}
