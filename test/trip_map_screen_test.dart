import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/core/clock.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/itinerary/application/itinerary_providers.dart';
import 'package:travelplanner/features/itinerary/application/transport_mode_providers.dart';
import 'package:travelplanner/features/trips/application/trip_providers.dart';
import 'package:travelplanner/features/itinerary/widgets/transport_mode.dart';
import 'package:travelplanner/features/map/widgets/map_overlays.dart';
import 'package:travelplanner/features/map/presentation/trip_map_screen.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// The trip map screen. Drift's `.watch()` streams never resolve under
/// `flutter_test`'s fake-async clock, so every provider it reads is overridden
/// with a plain stream — including `nowProvider`, whose real implementation
/// schedules a timer onto the next minute boundary and would outlive the test.
void main() {
  const tripId = 7;

  /// The trip's accent. Deliberately not one of the theme's colors, so a test
  /// asserting on it cannot pass by coincidence.
  const accent = 0xFF112233;

  final trip = Trip(
    id: tripId,
    title: 'Frankfurt',
    destination: '',
    colorValue: accent,
    createdAt: DateTime(2026, 5, 1),
    kind: TripKind.trip,
  );

  ItineraryItem place({
    required int id,
    double? lat,
    double? lon,
    int? startMinutes,
    int? endMinutes,
  }) => ItineraryItem(
    id: id,
    tripId: tripId,
    date: DateTime(2026, 5, 1),
    sortOrder: id,
    kind: ItemKind.place,
    title: 'Place $id',
    spansNextDay: false,
    lat: lat,
    lon: lon,
    startMinutes: startMinutes,
    endMinutes: endMinutes,
  );

  Future<void> pumpMap(
    WidgetTester tester, {
    required List<ItineraryItem> items,
    DateTime? now,
    EdgeInsets systemInsets = EdgeInsets.zero,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The map's tiles carry the app's version in their User-Agent, which
          // `main` resolves from the package metadata; a test has no bundle to
          // read it from.
          appVersionProvider.overrideWithValue('0.0.0-test'),
          tripProvider(tripId).overrideWith((ref) => Stream.value(trip)),
          itineraryProvider(tripId).overrideWith((ref) => Stream.value(items)),
          alternativeBranchesProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const {})),
          transportModesByIdProvider.overrideWith((ref) => const {}),
          nowProvider.overrideWith(
            (ref) => Stream.value(now ?? DateTime(2026, 5, 1, 3)),
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
          home: MediaQuery(
            data: MediaQueryData(padding: systemInsets),
            child: const TripMapScreen(tripId: tripId),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a trip with no positions says so instead of drawing a map', (
    tester,
  ) async {
    await pumpMap(tester, items: [place(id: 1)]);

    expect(find.text('Nothing to place yet'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  testWidgets('a trip with positions draws them', (tester) async {
    await pumpMap(
      tester,
      items: [
        place(id: 1, lat: 50.1, lon: 8.6),
        place(id: 2, lat: 50.2, lon: 8.7),
      ],
    );

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Nothing to place yet'), findsNothing);
    // Attribution is a condition of use, so it is on screen without being asked
    // for.
    expect(find.textContaining('OpenStreetMap'), findsOneWidget);

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  testWidgets('a leg is drawn in the trip\'s own accent, not the theme\'s', (
    tester,
  ) async {
    await pumpMap(
      tester,
      items: [
        ItineraryItem(
          id: 3,
          tripId: tripId,
          date: DateTime(2026, 5, 1),
          sortOrder: 0,
          kind: ItemKind.transport,
          spansNextDay: false,
          fromLat: 53.5511,
          fromLon: 9.9937,
          toLat: 50.1109,
          toLon: 8.6821,
        ),
      ],
    );

    final layer = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
    final polyline = layer.polylines.single;
    expect(polyline.color, const Color(accent));
    // And a casing under it, so a user-chosen color stays legible over whatever
    // the tiles happen to show there.
    expect(polyline.borderStrokeWidth, greaterThan(0));

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  testWidgets('the attribution clears the system navigation bar', (
    tester,
  ) async {
    // A phone with three-button navigation: the map draws edge to edge, so the
    // bottom strip would otherwise sit underneath the bar and be unreadable.
    const navBar = 48.0;
    await pumpMap(
      tester,
      items: [
        place(id: 1, lat: 50.1, lon: 8.6),
        place(id: 2, lat: 50.2, lon: 8.7),
      ],
      systemInsets: const EdgeInsets.only(bottom: navBar),
    );

    final attribution = find.textContaining('OpenStreetMap');
    final bottom = tester.getBottomLeft(attribution).dy;
    final screenBottom = tester.getSize(find.byType(MaterialApp)).height;
    expect(bottom, lessThanOrEqualTo(screenBottom - navBar));

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  testWidgets('tapping a place marker says what it stands for', (tester) async {
    await pumpMap(
      tester,
      items: [
        place(
          id: 1,
          lat: 50.1109,
          lon: 8.6821,
          startMinutes: 600,
          endMinutes: 660,
        ),
        place(id: 2, lat: 50.2, lon: 8.7),
      ],
    );

    await tester.tap(find.byType(MapPlacePin).first);
    await tester.pumpAndSettle();

    // The name the map cannot draw, the times it has no axis for, and the
    // numbers behind the pin.
    expect(find.text('Place 1'), findsOneWidget);
    expect(find.textContaining('50.11090'), findsOneWidget);
    expect(find.text('Edit place'), findsOneWidget);

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  testWidgets('tapping a leg badge names the leg, not a place', (tester) async {
    await pumpMap(
      tester,
      items: [
        ItineraryItem(
          id: 3,
          tripId: tripId,
          date: DateTime(2026, 5, 1),
          sortOrder: 0,
          kind: ItemKind.transport,
          title: 'ICE 507',
          fromLocation: 'Hamburg Hbf',
          toLocation: 'Frankfurt(Main) Hbf',
          spansNextDay: false,
          fromLat: 53.5511,
          fromLon: 9.9937,
          toLat: 50.1109,
          toLon: 8.6821,
        ),
      ],
    );

    // The camera is fitted to the whole leg on the first layout pass; before
    // that the view sits on its first point and the badge — which hangs at the
    // leg's midpoint — is culled as off-screen.
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(kDefaultTransportModeIcon).first);
    await tester.pumpAndSettle();

    expect(find.text('ICE 507'), findsOneWidget);
    expect(find.text('Hamburg Hbf → Frankfurt(Main) Hbf'), findsOneWidget);
    // Both ends, labeled — two numbers under each other must not be mistakable.
    expect(find.textContaining('53.55110'), findsOneWidget);
    expect(find.textContaining('50.11090'), findsOneWidget);
    expect(find.text('Edit transport'), findsOneWidget);

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });
}
