import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/clock.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/checklist/application/checklist_providers.dart';
import 'package:travelplanner/features/costs/application/cost_providers.dart';
import 'package:travelplanner/features/itinerary/application/itinerary_providers.dart';
import 'package:travelplanner/features/itinerary/application/transport_mode_providers.dart';
import 'package:travelplanner/features/route_planner/application/route_engine.dart';
import 'package:travelplanner/features/route_planner/application/route_planner_providers.dart';
import 'package:travelplanner/features/route_planner/data/tour_mapper.dart';
import 'package:travelplanner/features/route_planner/domain/route_profile.dart';
import 'package:travelplanner/features/route_planner/domain/routed_path.dart';
import 'package:travelplanner/features/route_planner/domain/tour.dart';
import 'package:travelplanner/features/route_planner/presentation/route_planner_screen.dart';
import 'package:travelplanner/features/route_planner/tour_entries.dart';
import 'package:travelplanner/features/trips/application/trip_providers.dart';
import 'package:travelplanner/features/trips/presentation/trip_detail_screen.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

import 'currency_fixture.dart';
import 'support/attachment_overrides.dart';

/// Where the trip screen offers the route planner: *Plan route* under a day and
/// under an option of a decision, and *Edit route* on a planned run's label or
/// on a planned leg standing alone, in a day or in an option.
void main() {
  late AppDatabase db;
  late TripRepository repo;
  late SharedPreferences prefs;
  late int tripId;
  final day = DateTime(2026, 5, 1);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Karwendel',
        startDate: Value(day),
        endDate: Value(day),
      ),
    );
  });
  tearDown(() => db.close());

  /// Saves a planned walk from [from] to [to], over a hut when [legs] is two
  /// (a run, so a group), as the planner does.
  Future<void> saveWalk({int legs = 1, int? alternativeId}) async {
    const start = LatLng(47.4, 11);
    const hut = LatLng(47.42, 11.02);
    const end = LatLng(47.45, 11.05);
    final tour = Tour(
      waypoints: [
        const TourWaypoint(start, name: 'Car park'),
        if (legs == 2) const TourWaypoint(hut, name: 'Hut'),
        const TourWaypoint(end, name: 'Summit'),
      ],
      modes: [
        for (var i = 0; i < legs; i++) const RoutedMode(RouteProfile.foot),
      ],
    );
    final entries = tourEntries(tour, {
      for (final (index, run) in tourRuns(tour).indexed)
        // Three points, so the line is stored and opening asks nothing.
        index: RoutedPath(
          points: [
            run.waypointsOf(tour).first.position,
            LatLng(
              run.waypointsOf(tour).first.position.latitude + 0.001,
              run.waypointsOf(tour).first.position.longitude,
            ),
            run.waypointsOf(tour).last.position,
          ],
          lengthMeters: 1000,
        ),
    })!;
    final mapped = tourToItems(
      entries,
      tripId: tripId,
      date: day,
      resolveMode: builtinModeResolver(await repo.transportModes()),
      tourId: 't$legs${alternativeId ?? ''}',
    );
    await repo.insertJourney(
      tripId,
      mapped.items,
      alternativeId: alternativeId,
      shapes: mapped.shapes,
    );
  }

  /// A decision on the day whose chosen option is empty, and its id.
  Future<int> decision() async {
    final seed = await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: day,
        kind: ItemKind.place,
        title: const Value('Museum'),
      ),
    );
    final setId = await db.alternativeDao.createSetFromItem(seed);
    final option = await db.alternativeDao.addAlternative(setId);
    await db.alternativeDao.chooseAlternative(option);
    return option;
  }

  /// Pumps the trip screen over what the database now holds.
  Future<void> pumpDetail(WidgetTester tester) async {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(900, 2400);
    addTearDown(tester.view.reset);
    final data = (await tester.runAsync(() async {
      return (
        trip: (await db.tripDao.findTrip(tripId))!,
        items: await repo.itemsFor(tripId),
        groups: await db.groupDao.watchGroupsForTrip(tripId).first,
        sets: await db.alternativeDao.setsForTrip(tripId),
        branches: await db.alternativeDao.branchesForTrip(tripId),
      );
    }))!;
    final router = GoRouter(
      initialLocation: '/trip/$tripId',
      routes: [
        GoRoute(
          path: '/trip/:id',
          builder: (_, state) =>
              TripDetailScreen(tripId: int.parse(state.pathParameters['id']!)),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...currencyOverrides,
          repositoryProvider.overrideWithValue(repo),
          databaseProvider.overrideWithValue(db),
          ...attachmentTestOverrides,
          sharedPreferencesProvider.overrideWithValue(prefs),
          appVersionProvider.overrideWithValue('0.0.0-test'),
          routeEngineProvider.overrideWithValue(_NoRouter()),
          tripProvider(tripId).overrideWith((ref) => Stream.value(data.trip)),
          itineraryProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(data.items)),
          alternativeSetsProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(data.sets)),
          alternativeBranchesProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(data.branches)),
          collapsedDaysProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const {})),
          groupsProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(data.groups)),
          costsForTripProvider(tripId).overrideWith(
            (ref) => Stream.value((
              byItem: const <int, List<Cost>>{},
              byGroup: const <int, List<Cost>>{},
              tripLevel: const <Cost>[],
            )),
          ),
          countedCostsProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const [])),
          tripParticipantsProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const [])),
          checklistsProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const [])),
          reasonRowsProvider.overrideWith((ref) => Stream.value(const [])),
          mePersonProvider.overrideWith((ref) => Stream.value(null)),
          transportModesProvider.overrideWith((ref) => Stream.value(const [])),
          nowProvider.overrideWith(
            (ref) => Stream.value(DateTime(2026, 4, 1, 9)),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Presses [finder] and waits for what it opens, which reads the database
  /// on the real event loop first when it is a saved route.
  Future<void> press(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
  }

  Finder addButton(String label) => find.widgetWithText(TextButton, label);

  testWidgets('Plan route under a day opens the planner for that day', (
    tester,
  ) async {
    await pumpDetail(tester);

    await press(tester, find.text('Plan route'));

    expect(find.byType(RoutePlannerScreen), findsOneWidget);
    expect(addButton('Add to day'), findsOneWidget);
  });

  testWidgets('a plan with no days yet offers it on its one section', (
    tester,
  ) async {
    await tester.runAsync(
      () => (db.update(db.trips)..where((t) => t.id.equals(tripId))).write(
        const TripsCompanion(startDate: Value(null), endDate: Value(null)),
      ),
    );
    await pumpDetail(tester);

    await press(tester, find.text('Plan route'));

    expect(find.byType(RoutePlannerScreen), findsOneWidget);
  });

  testWidgets('a morning a night train arrives in starts from its arrival', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await (db.update(db.trips)..where((t) => t.id.equals(tripId))).write(
        TripsCompanion(endDate: Value(day.add(const Duration(days: 1)))),
      );
      await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: day,
          kind: ItemKind.transport,
          startMinutes: const Value(22 * 60),
          endMinutes: const Value(7 * 60),
          endDayOffset: const Value(1),
        ),
      );
    });
    await pumpDetail(tester);

    // The second day's: the train arrives there at seven.
    await press(tester, find.text('Plan route').last);
    await tester.tap(find.text('Start time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Start 07:00'), findsOneWidget);
  });

  testWidgets('Edit route on a planned run\'s label opens it', (tester) async {
    await tester.runAsync(() => saveWalk(legs: 2));
    await pumpDetail(tester);

    await press(tester, find.byTooltip('Edit route'));

    expect(find.byType(RoutePlannerScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('waypoint-2')), findsOneWidget);
    expect(addButton('Save'), findsOneWidget);
  });

  testWidgets('Edit route on a planned leg standing alone opens it', (
    tester,
  ) async {
    await tester.runAsync(() => saveWalk());
    await pumpDetail(tester);

    await press(tester, find.byTooltip('Edit route'));

    expect(find.byType(RoutePlannerScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('waypoint-1')), findsOneWidget);
  });

  testWidgets('Plan route in an option opens the planner for it', (
    tester,
  ) async {
    await tester.runAsync(decision);
    await pumpDetail(tester);

    // The day's own and the option's: the option's is the first, above.
    expect(find.text('Plan route'), findsNWidgets(2));
    await press(tester, find.text('Plan route').first);

    expect(find.byType(RoutePlannerScreen), findsOneWidget);
  });

  testWidgets('Edit route works inside an option too', (tester) async {
    await tester.runAsync(() async {
      final option = await decision();
      await saveWalk(legs: 2, alternativeId: option);
      await saveWalk(alternativeId: option);
    });
    await pumpDetail(tester);

    // The run's label and the lone leg, both in the option.
    expect(find.byTooltip('Edit route'), findsNWidgets(2));
    await press(tester, find.byTooltip('Edit route').first);
    expect(find.byType(RoutePlannerScreen), findsOneWidget);
    // Closed again: the planner is a full-screen dialog.
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(RoutePlannerScreen), findsNothing);

    await press(tester, find.byTooltip('Edit route').last);
    expect(find.byType(RoutePlannerScreen), findsOneWidget);
  });
}

/// A router nobody may ask: opening the planner, or a saved route in it,
/// asks nothing.
class _NoRouter implements RouteEngine {
  @override
  Future<RoutedPath> route({
    required List<LatLng> waypoints,
    required RouteProfile profile,
  }) => fail('the router was asked');
}
