import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/itinerary/application/itinerary_providers.dart';
import 'package:travelplanner/features/map/widgets/map_overlays.dart';
import 'package:travelplanner/features/map/presentation/all_trips_map.dart';
import 'package:travelplanner/features/trips/application/trip_view_provider.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

import 'currency_fixture.dart';

/// The overview's map view: every visible trip on one map, each in its own
/// accent, filtered by being *handed* the trips rather than by filtering again.
void main() {
  // `PolylineLayer` is generic in its hit value, so `byType(PolylineLayer)` —
  // which means `PolylineLayer<dynamic>` — matches nothing once the lines carry
  // one. Match the widget itself instead of guessing its type argument.
  final polylineLayer = find.byWidgetPredicate((w) => w is PolylineLayer);

  Trip? opened;
  setUp(() => opened = null);

  const tealTrip = 0xFF00695C;
  const orangeTrip = 0xFFEF6C00;

  Trip trip(int id, int color) => Trip(
    id: id,
    title: 'Trip $id',
    destination: '',
    colorValue: color,
    coverHidden: false,
    photosCollapsed: false,
    createdAt: DateTime(2026, 5, 1),
    kind: TripKind.trip,
  );

  ItineraryItem leg(int id, int tripId, double lat) => ItineraryItem(
    id: id,
    tripId: tripId,
    date: DateTime(2026, 5, 1),
    sortOrder: 0,
    kind: ItemKind.transport,
    spansNextDay: false,
    fromLat: lat,
    fromLon: 9.9937,
    toLat: lat - 1,
    toLon: 10.5,
  );

  ItineraryItem place(int id, int tripId, double lat) => ItineraryItem(
    id: id,
    tripId: tripId,
    date: DateTime(2026, 5, 1),
    sortOrder: 1,
    kind: ItemKind.place,
    title: 'Place $id',
    spansNextDay: false,
    lat: lat,
    lon: 8.6821,
  );

  Future<void> pumpMap(
    WidgetTester tester, {
    required List<Trip> trips,
    required List<ItineraryItem> items,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWithValue('0.0.0-test'),
          positionedItemsProvider.overrideWith((ref) => Stream.value(items)),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AllTripsMap(
              trips: trips,
              book: seededBook,
              onOpenTrip: (t) => opened = t,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('each trip is drawn in its own accent', (tester) async {
    await pumpMap(
      tester,
      trips: [trip(1, tealTrip), trip(2, orangeTrip)],
      items: [leg(10, 1, 53.5), leg(11, 2, 50.1)],
    );

    final layer = tester.widget<PolylineLayer>(polylineLayer);
    expect(layer.polylines, hasLength(2));
    expect(layer.polylines.map((p) => p.color).toSet(), {
      const Color(tealTrip),
      const Color(orangeTrip),
    });

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  testWidgets('a trip the overview filtered out is not drawn', (tester) async {
    // The map is *handed* the visible trips, so the filter is inherited rather
    // than applied a second time — an entry whose trip is not in the list has
    // nothing to be drawn under.
    await pumpMap(
      tester,
      trips: [trip(1, tealTrip)],
      items: [leg(10, 1, 53.5), leg(11, 2, 50.1)],
    );

    final layer = tester.widget<PolylineLayer>(polylineLayer);
    expect(layer.polylines, hasLength(1));
    expect(layer.polylines.single.color, const Color(tealTrip));

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  testWidgets('narrowing the selection re-frames the map', (tester) async {
    // Tapping a tag chip is an explicit act with an expectation attached: the
    // trips that are left should be what you see, not a corner of the old view.
    late StateSetter setTrips;
    var trips = [trip(1, tealTrip), trip(2, orangeTrip)];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWithValue('0.0.0-test'),
          positionedItemsProvider.overrideWith(
            (ref) => Stream.value([leg(10, 1, 53.5), leg(11, 2, 20.0)]),
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
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setTrips = setState;
                return AllTripsMap(
                  trips: trips,
                  book: seededBook,
                  onOpenTrip: (t) => opened = t,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    final wide = controller.camera.zoom;

    // Drop the far-away trip; what is left is one short leg.
    setTrips(() => trips = [trip(1, tealTrip)]);
    await tester.pumpAndSettle();

    expect(
      controller.camera.zoom,
      greaterThan(wide),
      reason: 'the remaining trip should fill the view',
    );

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  testWidgets('trips without a position say so instead of drawing a map', (
    tester,
  ) async {
    await pumpMap(tester, trips: [trip(1, tealTrip)], items: const []);

    expect(find.text('Nothing to place yet'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  testWidgets('tapping a trip shows the trip, and opens it from there', (
    tester,
  ) async {
    // On this map the unit is the trip: a tangle of routes raises "which trip
    // is that", not "which leg". So the sheet is the card itself.
    await pumpMap(
      tester,
      trips: [trip(2, orangeTrip)],
      items: [place(12, 2, 50.1)],
    );

    await tester.tap(find.byType(MapPlacePin));
    await tester.pumpAndSettle();
    expect(find.text('Trip 2'), findsOneWidget);
    expect(opened, isNull, reason: 'looking is not opening');

    await tester.tap(find.text('Trip 2'));
    await tester.pumpAndSettle();
    expect(opened?.id, 2);

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  testWidgets('a tap where several trips run together lists them all', (
    tester,
  ) async {
    // Two trips over the same ground — the ordinary case on this map, not the
    // awkward one, since a commute is drawn once per day it was made. Answering
    // with whichever line was drawn last would be a coin toss, and re-tapping
    // does not reshuffle it.
    await pumpMap(
      tester,
      trips: [trip(1, tealTrip), trip(2, orangeTrip)],
      items: [leg(10, 1, 53.5), leg(11, 2, 53.5)],
    );

    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pumpAndSettle();

    expect(find.text('2 trips here'), findsOneWidget);
    expect(find.text('Trip 1'), findsOneWidget);
    expect(find.text('Trip 2'), findsOneWidget);
    expect(opened, isNull, reason: 'looking is not opening');

    // And the tap is finished from there, as it is from a card in the list.
    await tester.tap(find.text('Trip 2'));
    await tester.pumpAndSettle();
    expect(opened?.id, 2);

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  testWidgets('a lone line still answers with just its trip', (tester) async {
    // Nothing to choose between, so nothing to count: a heading reading "1 trip
    // here" over the single card on screen would be noise.
    await pumpMap(
      tester,
      trips: [trip(1, tealTrip)],
      items: [leg(10, 1, 53.5)],
    );

    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pumpAndSettle();

    expect(find.text('Trip 1'), findsOneWidget);
    expect(find.textContaining('trip here'), findsNothing);

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  testWidgets('places on one spot become one mark that says how many', (
    tester,
  ) async {
    // The ordinary case here, not the awkward one: a commute is drawn once per
    // day it was made, so the same platform carries twenty identical pins —
    // nineteen of them taps nobody can aim, since a marker wins the hit test
    // against everything under it.
    await pumpMap(
      tester,
      trips: [trip(1, tealTrip)],
      items: [place(12, 1, 50.1), place(13, 1, 50.1), place(14, 1, 50.1)],
    );

    final pin = tester.widget<MapPlacePin>(find.byType(MapPlacePin));
    expect(pin.count, 3);
    // Every place here is that trip's, so the mark still says which trip.
    expect(pin.color, const Color(tealTrip));

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  testWidgets('a mark of several trips wears none of their accents', (
    tester,
  ) async {
    // A colour on this map means "that is trip A's", so a mark holding B as
    // well may not wear A's — it would be saying something false about B.
    await pumpMap(
      tester,
      trips: [trip(1, tealTrip), trip(2, orangeTrip)],
      items: [place(12, 1, 50.1), place(13, 2, 50.1)],
    );

    final pin = tester.widget<MapPlacePin>(find.byType(MapPlacePin));
    expect(pin.count, 2);
    expect(pin.color, kMixedPinColor);

    // And the tap answers with both, as a tap on lines running together does.
    await tester.tap(find.byType(MapPlacePin));
    await tester.pumpAndSettle();
    expect(find.text('2 trips here'), findsOneWidget);
    expect(find.text('Trip 1'), findsOneWidget);
    expect(find.text('Trip 2'), findsOneWidget);

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  testWidgets('a mark keeps an accent two trips happen to share', (
    tester,
  ) async {
    // The neutral is for a mark that would otherwise have to *pick* one of
    // several colors. Where they agree there is nothing to pick, and drawing it
    // says nothing about either trip that was not already true.
    await pumpMap(
      tester,
      trips: [trip(1, tealTrip), trip(2, tealTrip)],
      items: [place(12, 1, 50.1), place(13, 2, 50.1)],
    );

    final pin = tester.widget<MapPlacePin>(find.byType(MapPlacePin));
    expect(pin.count, 2);
    expect(pin.color, const Color(tealTrip));

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  testWidgets('places far apart keep their own marks', (tester) async {
    await pumpMap(
      tester,
      trips: [trip(1, tealTrip)],
      items: [place(12, 1, 53.5), place(13, 1, 45.0)],
    );

    expect(find.byType(MapPlacePin), findsNWidgets(2));
    for (final pin in tester.widgetList<MapPlacePin>(
      find.byType(MapPlacePin),
    )) {
      expect(pin.count, 1, reason: 'nothing to count where nothing is hidden');
    }

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  group('the view is a setting', () {
    test('an unknown stored value falls back to the list', () async {
      SharedPreferences.setMockInitialValues({'flutter.trips_view': 99});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(tripViewProvider), TripView.list);
    });

    test('the chosen view survives a launch', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container.read(tripViewProvider.notifier).set(TripView.map);
      expect(prefs.getInt('trips_view'), TripView.map.index);

      // A second container stands in for the next launch.
      final relaunched = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(relaunched.dispose);
      expect(relaunched.read(tripViewProvider), TripView.map);
    });
  });
}
