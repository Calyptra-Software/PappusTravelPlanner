import 'package:drift/drift.dart' show Value;
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
import 'package:travelplanner/features/itinerary/presentation/item_form_sheet.dart';
import 'package:travelplanner/features/map/presentation/map_picker_screen.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// Giving an entry a position by pointing at it on a map, and what that does —
/// and deliberately does not do — to the rest of the row.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Widget host(Widget child, {AppDatabase? database}) => ProviderScope(
    overrides: [
      appVersionProvider.overrideWithValue('0.0.0-test'),
      if (database != null) databaseProvider.overrideWithValue(database),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );

  group('the picker itself', () {
    testWidgets('an edit starts on the point it is editing', (tester) async {
      LatLng? picked;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  picked = await pickPointOnMap(
                    context,
                    title: 'Pick',
                    initial: const LatLng(53.5511, 9.9937),
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

      // It opens holding the point it was given, so confirming straight away
      // is a no-op rather than a trap.
      expect(find.textContaining('53.55110'), findsOneWidget);

      await tester.tap(find.text('Use this point'));
      await tester.pumpAndSettle();

      expect(picked, isNotNull);
      expect(picked!.latitude, closeTo(53.5511, 1e-6));
      expect(picked!.longitude, closeTo(9.9937, 1e-6));
    });

    testWidgets('nothing can be confirmed until the map is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => pickPointOnMap(context, title: 'Pick'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Tap the map to place a point'), findsOneWidget);
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Use this point'),
      );
      expect(button.onPressed, isNull, reason: 'nothing has been chosen yet');
    });

    testWidgets('tapping the map chooses that point', (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      LatLng? picked;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  picked = await pickPointOnMap(context, title: 'Pick');
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
      // flutter_map waits out a possible second tap before reporting one, and
      // that wait is a Timer — which `pumpAndSettle` does not advance.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Tap the map to place a point'), findsNothing);
      await tester.tap(find.text('Use this point'));
      await tester.pumpAndSettle();

      expect(picked, isNotNull);
    });

    testWidgets('backing out picks nothing', (tester) async {
      var called = false;
      LatLng? picked;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  picked = await pickPointOnMap(context, title: 'Pick');
                  called = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(called, isTrue);
      expect(picked, isNull);
    });
  });

  group('what the form writes', () {
    Future<int> seedTrip() => db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Hamburg',
        startDate: Value(DateTime(2026, 5, 1)),
        endDate: Value(DateTime(2026, 5, 1)),
      ),
    );

    testWidgets('a picked place is saved with its position', (tester) async {
      // The form sheet is taller than the default test window, so its Save
      // button would never be laid out — the same trick the connection-search
      // tests use.
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final tripId = await seedTrip();

      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showItemFormSheet(
                  context,
                  tripId: tripId,
                  kind: ItemKind.place,
                  day: DateTime(2026, 5, 1),
                ),
                child: const Text('add'),
              ),
            ),
          ),
          database: db,
        ),
      );

      await tester.tap(find.text('add'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Place'),
        'Rathausmarkt',
      );
      expect(find.text('Not set'), findsOneWidget);

      await tester.tap(find.byTooltip('Choose on map'));
      await tester.pumpAndSettle();
      // Nothing is chosen until the map is tapped, so the form cannot be handed
      // a position by simply opening the picker.
      await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use this point'));
      await tester.pumpAndSettle();

      expect(find.text('Not set'), findsNothing);

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // Read with a plain select, never `.watch()`: a drift stream does not
      // resolve under `flutter_test`'s fake-async clock, and awaiting one here
      // hangs the test instead of failing it.
      final items = await db.select(db.itineraryItems).get();
      expect(items.single.location, 'Rathausmarkt');
      expect(items.single.lat, isNotNull);
      expect(items.single.lon, isNotNull);
    });

    /// An imported leg: both ends positioned, and both carrying the id the
    /// router was asked with.
    Future<ItineraryItem> seedImportedLeg(int tripId) async {
      final id = await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: DateTime(2026, 5, 1),
          kind: ItemKind.transport,
          fromLocation: const Value('Hamburg Hbf'),
          toLocation: const Value('Harburg'),
          fromLat: const Value(53.552914),
          fromLon: const Value(10.007209),
          toLat: const Value(53.456960),
          toLon: const Value(9.991454),
          fromPlaceId: const Value('de-DELFI_de:02000:11003'),
          toPlaceId: const Value('de-DELFI_de:02000:80953'),
          sourceTripId: const Value('trip-42'),
          startMinutes: const Value(600),
        ),
      );
      return (await db.select(db.itineraryItems).get()).firstWhere(
        (i) => i.id == id,
      );
    }

    Future<void> openLegForm(WidgetTester tester, ItineraryItem leg) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showItemFormSheet(
                  context,
                  tripId: leg.tripId,
                  kind: ItemKind.transport,
                  existing: leg,
                ),
                child: const Text('edit'),
              ),
            ),
          ),
          database: db,
        ),
      );
      await tester.tap(find.text('edit'));
      await tester.pumpAndSettle();
    }

    testWidgets('moving an end drops the id the router addressed it by', (
      tester,
    ) async {
      final tripId = await seedTrip();
      final leg = await seedImportedLeg(tripId);
      await openLegForm(tester, leg);

      // Clearing counts as moving it: the end is no longer where the search
      // found it, so the id no longer describes it.
      await tester.tap(find.byTooltip('Remove position').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = (await db.select(db.itineraryItems).get()).single;
      expect(saved.fromLat, isNull);
      expect(saved.fromPlaceId, isNull, reason: 'the id described that end');
      // The other end was never touched, so it keeps both.
      expect(saved.toLat, closeTo(53.456960, 1e-9));
      expect(saved.toPlaceId, 'de-DELFI_de:02000:80953');
      // And the service is not the end: the live-times refresh still works.
      expect(saved.sourceTripId, 'trip-42');
    });

    testWidgets('saving without touching the map keeps what the search left', (
      tester,
    ) async {
      final tripId = await seedTrip();
      final leg = await seedImportedLeg(tripId);
      await openLegForm(tester, leg);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = (await db.select(db.itineraryItems).get()).single;
      expect(saved.fromPlaceId, 'de-DELFI_de:02000:11003');
      expect(saved.toPlaceId, 'de-DELFI_de:02000:80953');
      expect(saved.fromLat, closeTo(53.552914, 1e-9));
      expect(saved.toLon, closeTo(9.991454, 1e-9));
    });
  });
}
