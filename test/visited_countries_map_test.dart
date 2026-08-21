import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
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

    final layer = tester.widget<PolygonLayer<String>>(
      find.byType(PolygonLayer<String>),
    );
    expect(layer.polygons.length, greaterThan(200));
    // Every landmass is filled — land against sea, not a hairline against
    // black — and the visited ones are filled in a second color.
    expect(layer.polygons.every((p) => p.color != null), isTrue);
    expect(layer.polygons.map((p) => p.color).toSet(), hasLength(2));
  });

  testWidgets('only sovereign states are listed and counted', (tester) async {
    await pump(tester, items: [place(1, 53.5511, 9.9937)]);

    // 200 of them, not the 242 areas the map draws.
    expect(find.textContaining('of 195'), findsOneWidget);
    await tester.tap(find.text('North America'));
    await tester.pumpAndSettle();
    expect(find.text('Denmark'), findsNothing);
    expect(find.text('Greenland'), findsNothing);
  });

  testWidgets('a dependency counts for its state', (tester) async {
    // Inland Greenland. Denmark is what moves, and it is in Europe.
    await pump(tester, items: [place(1, 72.0, -40.0)]);

    await tester.tap(find.text('Europe'));
    await tester.pumpAndSettle();
    final denmark = tester.widget<CheckboxListTile>(
      find.ancestor(
        of: find.text('Denmark'),
        matching: find.byType(CheckboxListTile),
      ),
    );
    expect(denmark.value, isTrue);
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
      AppDatabase? writingTo,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            countryOutlinesProvider.overrideWith((ref) async => outlines),
            markedCountriesProvider.overrideWith((ref) => Stream.value(marked)),
            positionedItemsProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
            // Only where a test wants to see what a tap writes: the marks the
            // screen *reads* are stubbed above, since a drift stream never
            // resolves under fake-async.
            if (writingTo case final db?)
              repositoryProvider.overrideWithValue(TripRepository(db)),
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
      await tester.tap(find.text('Europe'));
      await tester.pumpAndSettle();

      final germany = tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text('Germany'),
          matching: find.byType(CheckboxListTile),
        ),
      );
      expect(germany.onChanged, isNull);
      // And the map answers no taps either.
      final layer = tester.widget<PolygonLayer<String>>(
        find.byType(PolygonLayer<String>),
      );
      expect(layer.hitNotifier, isNull);
    });

    testWidgets('a country is ticked by tapping it on the map', (tester) async {
      // The only way a territory can be ticked at all: the list is of states,
      // so Greenland has no row — and it is right there on the map.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await pumpAllTrips(tester, writingTo: db);

      // Inland Greenland, projected by hand: the map is 600 x 300 at the zoom
      // that fits one world across it, centered on 20°N, and sits centered in an
      // 800-wide test surface.
      expect(
        outlines
            .firstWhere((c) => c.code == 'GRL')
            .contains(const LatLng(65, -45)),
        isTrue,
        reason: 'the tap has to land on Greenland to mean anything',
      );
      await tester.tapAt(const Offset(325, 40));
      await tester.pumpAndSettle();

      final rows = await db.select(db.visitedCountries).get();
      expect(rows.map((r) => r.code), ['GRL']);
    });
  });
}
