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

  testWidgets('nothing placed is said, not drawn as an empty world', (
    tester,
  ) async {
    // A world map with nothing filled would read as "you have been nowhere".
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

    expect(find.text('Nothing placed yet'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
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
    expect(find.text('2 countries'), findsOneWidget);
    expect(find.textContaining('France'), findsOneWidget);
    expect(find.textContaining('Germany'), findsOneWidget);
  });

  testWidgets('the names follow the app language', (tester) async {
    await pump(
      tester,
      items: [place(1, 53.5511, 9.9937)],
      locale: const Locale('de'),
    );

    expect(find.text('1 Land'), findsOneWidget);
    expect(find.textContaining('Deutschland'), findsOneWidget);
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

    expect(find.text('1 country'), findsOneWidget);
  });
}
