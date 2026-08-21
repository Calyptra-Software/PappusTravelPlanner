import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/itinerary/application/itinerary_providers.dart';
import 'package:travelplanner/features/map/application/visited_countries_providers.dart';
import 'package:travelplanner/features/map/visited_countries.dart';
import 'package:travelplanner/features/map/widgets/visited_countries_map.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// The world with the countries a trip touched filled in.
///
/// Drift's `.watch()` never resolves under fake-async, so the entries are
/// stubbed; the outlines come from the bundled asset, read off disk here rather
/// than through `rootBundle`.
void main() {
  const tripId = 4;
  late List<CountryOutline> outlines;

  setUpAll(() {
    outlines = parseCountryOutlines(
      File('assets/geo/countries.json').readAsStringSync(),
    );
  });

  ItineraryItem place(int id, double lat, double lon) => ItineraryItem(
    id: id,
    tripId: tripId,
    date: DateTime(2026, 5, 1),
    sortOrder: id,
    kind: ItemKind.place,
    spansNextDay: false,
    lat: lat,
    lon: lon,
  );

  Future<void> pump(
    WidgetTester tester, {
    required List<ItineraryItem> items,
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          countryOutlinesProvider.overrideWith((ref) async => outlines),
          markedCountriesProvider.overrideWith((ref) => Stream.value(const {})),
          itineraryProvider(tripId).overrideWith((ref) => Stream.value(items)),
          alternativeBranchesProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const {})),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: VisitedCountriesMap(tripId: tripId)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('with nothing placed the world is still drawn, at zero', (
    tester,
  ) async {
    // Not an empty screen: a country can still be ticked by hand from here,
    // which is the whole point of the list underneath.
    await pump(
      tester,
      items: [
        ItineraryItem(
          id: 1,
          tripId: tripId,
          date: DateTime(2026, 5, 1),
          sortOrder: 0,
          kind: ItemKind.place,
          spansNextDay: false,
        ),
      ],
    );

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.textContaining('0 of'), findsWidgets);
  });

  testWidgets('the countries stood in are counted and named', (tester) async {
    await pump(
      tester,
      items: [
        place(1, 53.5511, 9.9937), // Hamburg
        place(2, 48.8566, 2.3522), // Paris
      ],
    );

    expect(find.byType(FlutterMap), findsOneWidget);
    // The world's own tally, and the two regions' — Europe holds both.
    expect(find.textContaining('2 of'), findsWidgets);
    expect(find.text('Worldwide'), findsOneWidget);
    expect(find.text('Europe'), findsOneWidget);
  });

  testWidgets('the names follow the app language', (tester) async {
    await pump(
      tester,
      items: [place(1, 53.5511, 9.9937)],
      locale: const Locale('de'),
    );

    expect(find.text('Weltweit'), findsOneWidget);
    expect(find.text('Europa'), findsOneWidget);
  });

  testWidgets('the whole world is drawn, visited or not', (tester) async {
    // The unvisited ones are what make the visited ones mean something.
    await pump(tester, items: [place(1, 53.5511, 9.9937)]);

    final layer = tester.widget<PolygonLayer>(find.byType(PolygonLayer));
    expect(layer.polygons.length, greaterThan(200));
    // Exactly the visited country's landmasses carry a fill.
    expect(layer.polygons.where((p) => p.color != null), isNotEmpty);
  });

  testWidgets('an entry counts once, however many entries stand there', (
    tester,
  ) async {
    await pump(
      tester,
      items: [
        place(1, 53.5511, 9.9937),
        place(2, 52.5200, 13.4050),
        place(3, 48.1351, 11.5820),
      ],
    );

    expect(find.textContaining('1 of'), findsWidgets);
  });

  group('marking a country by hand', () {
    Future<void> pumpAllTrips(
      WidgetTester tester, {
      Set<String> marked = const {},
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            countryOutlinesProvider.overrideWith((ref) async => outlines),
            markedCountriesProvider.overrideWith((ref) => Stream.value(marked)),
            positionedItemsProvider.overrideWith(
              (ref) => Stream.value(const []),
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
            home: const Scaffold(body: VisitedCountriesMap(tripId: null)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a mark counts exactly like a visit derived from a trip', (
      tester,
    ) async {
      // The map is never told which is which: a life has journeys in it that
      // were never planned here.
      await pumpAllTrips(tester, marked: {'JP', 'NZ'});

      expect(find.textContaining('2 of'), findsWidgets);
    });

    testWidgets('the list says a mark can be taken back and a trip cannot', (
      tester,
    ) async {
      await pumpAllTrips(tester, marked: {'JP'});
      await tester.tap(find.text('Asia'));
      await tester.pumpAndSettle();

      final japan = tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text('Japan'),
          matching: find.byType(CheckboxListTile),
        ),
      );
      expect(japan.value, isTrue);
      expect(
        japan.onChanged,
        isNotNull,
        reason: 'a mark is the user\'s to undo',
      );
    });

    testWidgets('marking is not offered on a single trip\'s own tab', (
      tester,
    ) async {
      // A mark is a statement about a life, not about one journey.
      await pump(tester, items: const []);

      expect(
        find.textContaining('Tick a country you have been to'),
        findsNothing,
      );
    });
  });
}
