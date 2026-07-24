import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/costs/application/cost_providers.dart';
import 'package:travelplanner/features/costs/presentation/cost_form_sheet.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// Covers the expense form's two picked fields — category and payer. Neither is
/// typed into: both open the searchable picker, and what it yields is what the
/// saved expense carries.
void main() {
  late AppDatabase db;
  late TripRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
    await repo.createTrip(TripsCompanion.insert(title: 'Rome'));
  });
  tearDown(() => db.close());

  /// Pumps the form for a new trip-level cost. The rosters behind both pickers
  /// are stubbed with plain streams — drift's `.watch()` never resolves under
  /// the fake-async clock — while saving goes through the real repository.
  Future<void> pumpForm(
    WidgetTester tester, {
    List<String> reasons = const ['Hotel', 'Dinner'],
    List<String> people = const ['Alex', 'Sam'],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          reasonsProvider.overrideWith((ref) => Stream.value(reasons)),
          reasonRowsProvider.overrideWith((ref) => Stream.value(const [])),
          peopleProvider.overrideWith((ref) => Stream.value(people)),
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
          home: const Scaffold(body: CostFormSheet(tripId: 1)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Reads what was actually written. Drift's streams and futures need the real
  /// clock — under the widget test's fake-async one they never resolve — so
  /// every database read here goes through [WidgetTester.runAsync].
  Future<List<Cost>> savedCosts(WidgetTester tester) async =>
      (await tester.runAsync(() => repo.watchCostsForTrip(1).first))!;

  // The form's fields, in the order it lays them out.
  final amountField = find.byType(TextFormField).at(0);
  final categoryField = find.byType(TextFormField).at(1);
  final payerField = find.byType(TextFormField).at(2);

  /// The picker's search box: the only plain [TextField] on screen once the
  /// sheet is up (the form's own fields are [TextFormField]s).
  final searchBox = find.byType(TextField).last;

  testWidgets('category and payer are picked from the searchable list', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.enterText(amountField, '42.50');
    await tester.tap(categoryField);
    await tester.pumpAndSettle();
    await tester.enterText(searchBox, 'din');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dinner'));
    await tester.pumpAndSettle();

    await tester.tap(payerField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sam'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final cost = (await savedCosts(tester)).single;
    expect(cost.amountMinor, 4250);
    expect(cost.reason, 'Dinner');
    expect(cost.paidBy, 'Sam');
    // The payer pays at least for themselves, so they seed the split.
    final beneficiaries = await tester.runAsync(
      () => repo.watchBeneficiaries(cost.id).first,
    );
    expect([for (final p in beneficiaries!) p.name], ['Sam']);
  });

  testWidgets('a category nobody has is added from the search box', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.enterText(amountField, '9');
    await tester.tap(categoryField);
    await tester.pumpAndSettle();
    await tester.enterText(searchBox, 'Sushi');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add “Sushi”'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect((await savedCosts(tester)).single.reason, 'Sushi');
    // ...and it joins the roster for the next expense.
    final roster = await tester.runAsync(() => repo.watchReasons().first);
    expect(roster, contains('Sushi'));
  });

  testWidgets('saving without a category is refused', (tester) async {
    await pumpForm(tester);

    await tester.enterText(amountField, '9');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a category'), findsOneWidget);
    expect(await savedCosts(tester), isEmpty);
  });

  group('settlement', () {
    /// Pumps the same sheet as a settlement between two people.
    Future<void> pumpTransfer(
      WidgetTester tester, {
      List<String> people = const ['Alex', 'Sam'],
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            reasonsProvider.overrideWith((ref) => Stream.value(const [])),
            reasonRowsProvider.overrideWith((ref) => Stream.value(const [])),
            peopleProvider.overrideWith((ref) => Stream.value(people)),
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
            home: const Scaffold(
              body: CostFormSheet(tripId: 1, transfer: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // In settlement mode the category and the split are gone: the two people
    // are the whole form.
    final fromField = find.byType(TextFormField).at(1);
    final toField = find.byType(TextFormField).at(2);

    /// Opens [field]'s picker and chooses [name] from its list. The row is
    /// targeted inside the picker: once a field holds the name, a plain text
    /// finder would match the field behind the sheet too.
    Future<void> pick(WidgetTester tester, Finder field, String name) async {
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, name));
      await tester.pumpAndSettle();
    }

    testWidgets('records who paid whom, and is not an expense', (tester) async {
      await pumpTransfer(tester);

      await tester.enterText(amountField, '20');
      await pick(tester, fromField, 'Sam');
      await pick(tester, toField, 'Alex');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      final cost = (await savedCosts(tester)).single;
      expect(cost.isTransfer, isTrue);
      expect(cost.amountMinor, 2000);
      expect(cost.paidBy, 'Sam');
      // No category: a repayment isn't a kind of spending.
      expect(cost.reason, '');
      // The receiver rides along as the row's single beneficiary — that is
      // what moves their balance.
      final beneficiaries = await tester.runAsync(
        () => repo.watchBeneficiaries(cost.id).first,
      );
      expect([for (final p in beneficiaries!) p.name], ['Alex']);
    });

    testWidgets('refuses a settlement with itself', (tester) async {
      await pumpTransfer(tester);

      await tester.enterText(amountField, '20');
      await pick(tester, fromField, 'Sam');
      await pick(tester, toField, 'Sam');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Choose two different people'), findsOneWidget);
      expect(await savedCosts(tester), isEmpty);
    });

    testWidgets('refuses a settlement of nothing', (tester) async {
      await pumpTransfer(tester);

      await tester.enterText(amountField, '0');
      await pick(tester, fromField, 'Sam');
      await pick(tester, toField, 'Alex');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Enter an amount above zero'), findsOneWidget);
      expect(await savedCosts(tester), isEmpty);
    });
  });
}
