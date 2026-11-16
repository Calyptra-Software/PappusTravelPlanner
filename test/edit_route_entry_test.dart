import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/route_plan.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/itinerary/application/transport_mode_providers.dart';
import 'package:travelplanner/features/itinerary/widgets/timeline_tile.dart';
import 'package:travelplanner/features/route_planner/application/route_engine.dart';
import 'package:travelplanner/features/route_planner/application/route_planner_providers.dart';
import 'package:travelplanner/features/route_planner/data/tour_mapper.dart';
import 'package:travelplanner/features/route_planner/domain/route_profile.dart';
import 'package:travelplanner/features/route_planner/domain/routed_path.dart';
import 'package:travelplanner/features/route_planner/domain/tour.dart';
import 'package:travelplanner/features/route_planner/presentation/route_planner_screen.dart';
import 'package:travelplanner/features/route_planner/presentation/saved_route.dart';
import 'package:travelplanner/features/route_planner/tour_entries.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

import 'support/attachment_overrides.dart';

/// *Edit route* is offered on the run's label, beside *Show journey*, and on a
/// planned leg standing alone: a route is the whole run, not one of its legs.
void main() {
  late AppDatabase db;
  late TripRepository repo;
  late SharedPreferences prefs;
  late int tripId;

  final day = DateTime(2026, 3, 14);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(title: 'Karwendel'),
    );
  });
  tearDown(() => db.close());

  Widget host(Widget child) => ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(repo),
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      appVersionProvider.overrideWithValue('0.0.0-test'),
      routeEngineProvider.overrideWithValue(_NoRouter()),
      transportModesProvider.overrideWith((ref) => Stream.value(const [])),
      ...attachmentTestOverrides,
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  ItineraryItem item({
    int id = 1,
    ItemKind kind = ItemKind.transport,
    String? routePlan,
    int? groupId,
  }) => ItineraryItem(
    id: id,
    tripId: 1,
    date: day,
    sortOrder: id,
    kind: kind,
    groupId: groupId,
    endDayOffset: 0,
    chordDisplay: TrackDisplay.auto,
    routePlan: routePlan,
  );

  final legPlan = encodeRoutePlan(
    const RoutePlan(
      tour: 't1',
      profile: 'foot',
      waypoints: [
        RoutePlanPoint(lat: 47.4, lon: 11),
        RoutePlanPoint(lat: 47.45, lon: 11.05),
      ],
    ),
  );

  group('isPlannedLeg', () {
    test('is a leg the planner made, and nothing else', () {
      expect(isPlannedLeg(item(routePlan: legPlan)), isTrue);
      // A place of a tour opens nothing of its own.
      expect(
        isPlannedLeg(
          item(
            kind: ItemKind.place,
            routePlan: encodeRoutePlan(const RoutePlan(tour: 't1')),
          ),
        ),
        isFalse,
      );
      expect(isPlannedLeg(item()), isFalse);
      expect(isPlannedLeg(item(routePlan: 'not a plan')), isFalse);
    });
  });

  group('the button', () {
    testWidgets('sits on the run\'s label when given', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 400,
            child: GroupRunTile(
              groupId: 9,
              label: 'Hike',
              items: [
                item(id: 1, kind: ItemKind.place, groupId: 9),
                item(id: 2, kind: ItemKind.place, groupId: 9),
              ],
              accent: Colors.teal,
              costsByItem: const {},
              groupCosts: const [],
              localeName: 'en',
              onTapItem: (_) {},
              onTapCost: (_) {},
              onReorder: (_, _, _) {},
              held: null,
              onEditRoute: () => opened++,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Edit route'));
      expect(opened, 1);
    });

    testWidgets('is not on a label without it', (tester) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 400,
            child: GroupRunTile(
              groupId: 9,
              label: 'Museums',
              items: [
                item(id: 1, kind: ItemKind.place, groupId: 9),
                item(id: 2, kind: ItemKind.place, groupId: 9),
              ],
              accent: Colors.teal,
              costsByItem: const {},
              groupCosts: const [],
              localeName: 'en',
              onTapItem: (_) {},
              onTapCost: (_) {},
              onReorder: (_, _, _) {},
              held: null,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byTooltip('Edit route'), findsNothing);
    });

    testWidgets('sits on a planned leg standing alone', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        host(
          TimelineTile(
            item: item(routePlan: legPlan),
            accent: Colors.teal,
            onTap: () {},
            costs: const [],
            localeName: 'en',
            onTapCost: (_) {},
            onEditRoute: () => opened++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Edit route'));
      expect(opened, 1);
    });
  });

  group('editSavedRoute', () {
    /// Saves a walk of two legs split at a named hut, as the planner does,
    /// and returns the rows.
    Future<List<ItineraryItem>> saveWalk() async {
      final tour = Tour(
        waypoints: const [
          TourWaypoint(LatLng(47.4, 11), name: 'Car park'),
          TourWaypoint(LatLng(47.42, 11.02), name: 'Hut'),
          TourWaypoint(LatLng(47.45, 11.05), name: 'Summit'),
        ],
        modes: const [
          RoutedMode(RouteProfile.foot),
          RoutedMode(RouteProfile.foot),
        ],
      );
      RoutedPath path(LatLng a, LatLng b) => RoutedPath(
        points: [a, LatLng((a.latitude + b.latitude) / 2, a.longitude), b],
        lengthMeters: 2000,
        duration: const Duration(minutes: 40),
      );
      final entries = tourEntries(tour, {
        0: path(const LatLng(47.4, 11), const LatLng(47.42, 11.02)),
        1: path(const LatLng(47.42, 11.02), const LatLng(47.45, 11.05)),
      })!;
      final mapped = tourToItems(
        entries,
        tripId: tripId,
        date: day,
        resolveMode: builtinModeResolver(await repo.transportModes()),
        tourId: 't1',
      );
      await repo.insertJourney(tripId, mapped.items, shapes: mapped.shapes);
      return repo.itemsFor(tripId);
    }

    Future<void> press(WidgetTester tester, ItineraryItem leg) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        host(
          Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => editSavedRoute(context, ref, leg),
              child: const Text('edit'),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('edit'));
        // The route is read off the database on the real event loop.
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
    }

    testWidgets('opens the planner on the whole route, asking nobody', (
      tester,
    ) async {
      final legs = (await tester.runAsync(saveWalk))!;

      // Pressed for the run's second leg: the route is still the whole run.
      await press(tester, legs.last);

      expect(find.byType(RoutePlannerScreen), findsOneWidget);
      for (final index in [0, 1, 2]) {
        expect(find.byKey(ValueKey('waypoint-$index')), findsOneWidget);
      }
      expect(find.textContaining('4 km'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Save'), findsOneWidget);
    });

    testWidgets('says so when the route cannot be read back', (tester) async {
      final legs = (await tester.runAsync(saveWalk))!;
      final plan = decodeRoutePlan(legs.first.routePlan)!;
      await tester.runAsync(
        () =>
            (db.update(
              db.itineraryItems,
            )..where((i) => i.id.equals(legs.first.id))).write(
              ItineraryItemsCompanion(
                routePlan: Value(
                  encodeRoutePlan(
                    RoutePlan(
                      tour: plan.tour,
                      profile: 'hovercraft',
                      waypoints: plan.waypoints,
                    ),
                  ),
                ),
              ),
            ),
      );
      final leg = (await tester.runAsync(() => repo.itemsFor(tripId)))!.first;

      await press(tester, leg);

      expect(find.byType(RoutePlannerScreen), findsNothing);
      expect(
        find.textContaining("can't be opened in the planner"),
        findsOneWidget,
      );
    });
  });
}

/// A router nobody may ask: opening a saved route reads its lines from the
/// trip, so a request here is the bug.
class _NoRouter implements RouteEngine {
  @override
  Future<RoutedPath> route({
    required List<LatLng> waypoints,
    required RouteProfile profile,
  }) => fail('the router was asked');
}
