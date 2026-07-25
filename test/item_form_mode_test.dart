import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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
import 'package:travelplanner/features/itinerary/application/itinerary_providers.dart';
import 'package:travelplanner/features/itinerary/application/transport_mode_providers.dart';
import 'package:travelplanner/features/itinerary/presentation/item_form_sheet.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

import 'currency_fixture.dart';

/// Covers which mode the item form opens a transport leg on. Deleting a mode
/// leaves the legs that used it with no mode at all (the foreign key is set
/// null), and the timeline draws those as "Other" — so the form must show the
/// same thing rather than pre-selecting a real mode that saving would assign.
void main() {
  late AppDatabase db;
  late TripRepository repo;
  late SharedPreferences prefs;

  final day = DateTime(2026, 7, 5);

  // Deliberately no "other" built-in here, so the word "Other" on screen can
  // only have come from the "no mode" hint.
  final modes = [
    TransportModeRow(id: 1, builtinKey: 'walk', sortOrder: 0),
    TransportModeRow(id: 6, builtinKey: 'train', sortOrder: 1),
  ];

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  tearDown(() => db.close());

  Widget wrap(Widget sheet) => ProviderScope(
    overrides: [
      ...currencyOverrides,
      repositoryProvider.overrideWithValue(repo),
      sharedPreferencesProvider.overrideWithValue(prefs),
      // Every drift-backed stream the sheet touches is stubbed: the real
      // `.watch()` never resolves under fake-async, which hangs the test.
      transportModesProvider.overrideWith((ref) => Stream.value(modes)),
      itineraryProvider(1).overrideWith((ref) => Stream.value(const [])),
      groupsProvider(1).overrideWith((ref) => Stream.value(const {})),
      costsForTripProvider(1).overrideWith(
        (ref) => Stream.value((
          byItem: const <int, List<Cost>>{},
          byGroup: const <int, List<Cost>>{},
          tripLevel: const <Cost>[],
        )),
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
      home: Scaffold(body: SingleChildScrollView(child: sheet)),
    ),
  );

  ItineraryItem leg({int? mode}) => ItineraryItem(
    id: 1,
    tripId: 1,
    date: day,
    sortOrder: 0,
    kind: ItemKind.transport,
    fromLocation: 'Zurich',
    toLocation: 'Chur',
    mode: mode,
  );

  DropdownButtonFormField<int?> dropdownOf(WidgetTester tester) =>
      tester.widget<DropdownButtonFormField<int?>>(
        find.byType(DropdownButtonFormField<int?>),
      );

  testWidgets('a new leg opens on the train built-in', (tester) async {
    await tester.pumpWidget(
      wrap(const ItemFormSheet(tripId: 1, kind: ItemKind.transport)),
    );
    await tester.pump();

    expect(dropdownOf(tester).initialValue, 6);
  });

  testWidgets('an existing leg keeps the mode it has', (tester) async {
    await tester.pumpWidget(
      wrap(
        ItemFormSheet(
          tripId: 1,
          kind: ItemKind.transport,
          existing: leg(mode: 1),
        ),
      ),
    );
    await tester.pump();

    expect(dropdownOf(tester).initialValue, 1);
  });

  testWidgets(
    'a leg whose mode was deleted stays unassigned, shown as "Other"',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          ItemFormSheet(
            tripId: 1,
            kind: ItemKind.transport,
            existing: leg(mode: null),
          ),
        ),
      );
      await tester.pump();

      // Not silently pre-selected onto train (or any other row) ...
      expect(dropdownOf(tester).initialValue, isNull);
      // ... and labelled the way the timeline labels it.
      expect(find.text('Other'), findsOneWidget);
    },
  );

  testWidgets(
    'a stale mode id that no longer exists falls back to unassigned',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          ItemFormSheet(
            tripId: 1,
            kind: ItemKind.transport,
            existing: leg(mode: 999), // deleted while the sheet was open
          ),
        ),
      );
      await tester.pump();

      expect(dropdownOf(tester).initialValue, isNull);
    },
  );
}
