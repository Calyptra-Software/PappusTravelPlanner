import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:drift/native.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/route_planner/application/route_engine.dart';
import 'package:travelplanner/features/route_planner/application/route_planner_providers.dart';
import 'package:travelplanner/features/route_planner/application/tour_planner_controller.dart';
import 'package:travelplanner/features/route_planner/domain/route_profile.dart';
import 'package:travelplanner/features/route_planner/domain/routed_path.dart';
import 'package:travelplanner/features/route_planner/presentation/route_planner_screen.dart';
import 'package:travelplanner/features/route_planner/tour_entries.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// A router that answers at once, or refuses while [refusal] is set, and holds
/// its answers back while [hold] is.
class _FakeEngine implements RouteEngine {
  final asked = <(List<LatLng>, RouteProfile)>[];
  RouteEngineException? refusal;
  Completer<void>? hold;

  @override
  Future<RoutedPath> route({
    required List<LatLng> waypoints,
    required RouteProfile profile,
  }) async {
    asked.add((waypoints, profile));
    await hold?.future;
    if (refusal case final refusal?) throw refusal;
    return RoutedPath(
      points: waypoints,
      lengthMeters: 4200,
      ascentMeters: 300,
      descentMeters: 120,
      duration: const Duration(minutes: 95),
    );
  }
}

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late _FakeEngine engine;
  final day = DateTime(2026, 3, 14);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    engine = _FakeEngine();
  });
  tearDown(() => db.close());

  /// Pumps a page with a button that opens the planner on [tripId], on a tall
  /// window so the panel below the map is laid out whole.
  Future<List<bool>> open(WidgetTester tester, {int tripId = 1}) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final results = <bool>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWithValue('0.0.0-test'),
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          routeEngineProvider.overrideWithValue(engine),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async => results.add(
                  await planRoute(
                    context,
                    tripId: tripId,
                    day: day,
                    color: const Color(0xFF00695C),
                    nearby: const [LatLng(47.4, 11.0), LatLng(47.5, 11.2)],
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  /// Taps the map [offset] from its center. flutter_map waits out a possible
  /// double tap before reporting a single one, and that wait is a timer.
  Future<void> tapMap(WidgetTester tester, Offset offset) async {
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)) + offset);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  /// Selects a mode. The chips scroll sideways, so the later ones start out
  /// beyond the window's edge.
  Future<void> choose(WidgetTester tester, String label) async {
    final chip = find.widgetWithText(ChoiceChip, label);
    await tester.ensureVisible(chip);
    await tester.pump();
    await tester.tap(chip);
    await tester.pump();
  }

  TextButton addButton(WidgetTester tester) =>
      tester.widget(find.widgetWithText(TextButton, 'Add to day'));

  testWidgets('opens asking for the start, with nothing to add', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Tap the map to set the start.'), findsOneWidget);
    expect(addButton(tester).onPressed, isNull);
    expect(engine.asked, isEmpty);
  });

  testWidgets('two taps ask the router once and show the totals', (
    tester,
  ) async {
    await open(tester);

    await tapMap(tester, const Offset(-150, -100));
    expect(find.text('Tap the map to set the next point.'), findsOneWidget);
    expect(engine.asked, isEmpty);

    await tapMap(tester, const Offset(150, 100));
    await tester.pumpAndSettle();

    expect(engine.asked.single.$2, RouteProfile.foot);
    expect(engine.asked.single.$1, hasLength(2));
    expect(find.text('4.2 km · ↑ 300 m · ↓ 120 m · 1h 35m'), findsOneWidget);
    expect(addButton(tester).onPressed, isNotNull);
  });

  testWidgets('says it is routing while the answer is out', (tester) async {
    engine.hold = Completer<void>();
    await open(tester);

    await tapMap(tester, const Offset(-150, -100));
    await tapMap(tester, const Offset(150, 100));

    expect(find.text('Finding the route…'), findsOneWidget);
    expect(addButton(tester).onPressed, isNull);

    engine.hold!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Finding the route…'), findsNothing);
    expect(addButton(tester).onPressed, isNotNull);
  });

  testWidgets('a ski section is a straight line and asks nobody', (
    tester,
  ) async {
    await open(tester);

    await choose(tester, 'Ski');
    expect(
      find.text('Drawn as a straight line between your points.'),
      findsOneWidget,
    );

    await tapMap(tester, const Offset(-150, -100));
    await tapMap(tester, const Offset(150, 100));
    await tester.pumpAndSettle();

    expect(engine.asked, isEmpty);
    expect(addButton(tester).onPressed, isNotNull);
  });

  testWidgets('the mode chosen before a tap is the one that section takes', (
    tester,
  ) async {
    await open(tester);

    await choose(tester, 'Car');
    await tapMap(tester, const Offset(-200, -100));
    await tapMap(tester, const Offset(0, 0));
    await choose(tester, 'On foot');
    await tapMap(tester, const Offset(200, 100));
    await tester.pumpAndSettle();

    expect(engine.asked.map((request) => request.$2), [
      RouteProfile.car,
      RouteProfile.foot,
    ]);
  });

  testWidgets('a refusal is said and asked again on Retry', (tester) async {
    engine.refusal = const RouteEngineException('no', statusCode: 400);
    await open(tester);

    await tapMap(tester, const Offset(-150, -100));
    await tapMap(tester, const Offset(150, 100));
    await tester.pumpAndSettle();

    expect(find.text('No route found between these points.'), findsOneWidget);
    expect(addButton(tester).onPressed, isNull);

    engine.refusal = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(engine.asked, hasLength(2));
    expect(find.text('No route found between these points.'), findsNothing);
    expect(addButton(tester).onPressed, isNotNull);
  });

  testWidgets('Remove last point takes the tour back a step', (tester) async {
    await open(tester);

    await tapMap(tester, const Offset(-150, -100));
    await tapMap(tester, const Offset(150, 100));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove last point'));
    await tester.pumpAndSettle();

    expect(find.text('Tap the map to set the next point.'), findsOneWidget);
    expect(find.byKey(const ValueKey('waypoint-1')), findsNothing);
    expect(find.byKey(const ValueKey('waypoint-0')), findsOneWidget);
  });

  testWidgets('a tap on a waypoint names it or removes it', (tester) async {
    await open(tester);
    await tapMap(tester, const Offset(-150, -100));
    await tapMap(tester, const Offset(150, 100));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('waypoint-1')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Waypoint'),
      ),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'Summit');
    await tester.tap(find.text('Add to the plan as a place'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(RoutePlannerScreen)),
    );
    // Read through the screen's own scope: the summit is now a place entry.
    expect(
      container
          .read(tourPlannerProvider)
          .entries
          ?.whereType<TourPlace>()
          .single
          .waypoint
          .name,
      'Summit',
    );
    // No waypoint was moved, so nothing new was asked.
    expect(engine.asked, hasLength(1));

    await tester.tap(find.byKey(const ValueKey('waypoint-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove point'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('waypoint-1')), findsNothing);
  });

  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(BottomSheet), matching: finder);

  int waypointCount(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(RoutePlannerScreen)),
  ).read(tourPlannerProvider).tour.waypoints.length;

  testWidgets('a tap on a waypoint is not also a tap on the map', (
    tester,
  ) async {
    await open(tester);
    await tapMap(tester, const Offset(-150, -100));
    await tapMap(tester, const Offset(150, 100));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('waypoint-0')));
    // Past the wait in which the map would report a tap of its own.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(inSheet(find.text('Waypoint')), findsOneWidget);
    expect(waypointCount(tester), 2);
  });

  testWidgets('Move point puts the waypoint where the next tap lands', (
    tester,
  ) async {
    await open(tester);
    await tapMap(tester, const Offset(-150, -100));
    await tapMap(tester, const Offset(150, 100));
    await tester.pumpAndSettle();
    final before = engine.asked.single.$1.last;

    await tester.tap(find.byKey(const ValueKey('waypoint-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move point'));
    await tester.pumpAndSettle();

    expect(find.text('Tap the map where the point should go.'), findsOneWidget);
    // The chips are at rest: a tap now means one thing.
    expect(
      tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .map((chip) => chip.onSelected),
      everyElement(isNull),
    );

    await tapMap(tester, const Offset(150, -200));
    await tester.pumpAndSettle();

    expect(waypointCount(tester), 2);
    expect(engine.asked, hasLength(2));
    expect(engine.asked.last.$1.last, isNot(before));
    expect(find.text('Tap the map where the point should go.'), findsNothing);
    expect(
      tester.widget<ChoiceChip>(find.byType(ChoiceChip).first).onSelected,
      isNotNull,
    );
  });

  testWidgets('a move can be called off', (tester) async {
    await open(tester);
    await tapMap(tester, const Offset(-150, -100));
    await tapMap(tester, const Offset(150, 100));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('waypoint-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move point'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // A tap adds a waypoint again.
    await tapMap(tester, const Offset(150, -200));
    await tester.pumpAndSettle();
    expect(waypointCount(tester), 3);
  });

  testWidgets('a tap on a line changes how that section is traveled', (
    tester,
  ) async {
    await open(tester);
    await choose(tester, 'Ski');
    await tapMap(tester, const Offset(-200, 0));
    await tapMap(tester, const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(engine.asked, isEmpty);

    // Half way along the straight line between the two.
    await tapMap(tester, Offset.zero);
    await tester.pumpAndSettle();

    expect(inSheet(find.text('Section')), findsOneWidget);
    expect(waypointCount(tester), 2, reason: 'a tap on the line adds nothing');
    expect(
      tester
          .widget<ChoiceChip>(inSheet(find.widgetWithText(ChoiceChip, 'Ski')))
          .selected,
      isTrue,
    );

    await tester.tap(inSheet(find.widgetWithText(ChoiceChip, 'On foot')));
    await tester.pumpAndSettle();

    expect(engine.asked.single.$2, RouteProfile.foot);
    expect(waypointCount(tester), 2);
  });

  testWidgets('a tap on a line sets a point into it', (tester) async {
    await open(tester);
    await tapMap(tester, const Offset(-200, 0));
    await tapMap(tester, const Offset(200, 0));
    await tester.pumpAndSettle();

    await tapMap(tester, Offset.zero);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a point here'));
    await tester.pumpAndSettle();

    expect(waypointCount(tester), 3);
    expect(find.byKey(const ValueKey('waypoint-2')), findsOneWidget);
    // The way through a point on it is the way already given.
    expect(engine.asked, hasLength(1));
    expect(addButton(tester).onPressed, isNotNull);
  });

  testWidgets('the map keeps its size whatever the panel says', (tester) async {
    await open(tester);
    Size map() => tester.getSize(find.byType(FlutterMap));
    final size = map();

    // The hint for the next point, then the totals.
    await tapMap(tester, const Offset(-150, -100));
    expect(map(), size);
    await tapMap(tester, const Offset(150, 100));
    await tester.pumpAndSettle();
    expect(map(), size);

    // The line under a straight mode.
    await choose(tester, 'Ski');
    expect(map(), size);

    // A point waiting to be put down.
    await tester.tap(find.byKey(const ValueKey('waypoint-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move point'));
    await tester.pumpAndSettle();
    expect(map(), size);
  });

  testWidgets('Add to day writes the tour and closes the planner', (
    tester,
  ) async {
    final tripId = await tester.runAsync(
      () => db.tripDao.createTrip(TripsCompanion.insert(title: 'Hike')),
    );
    final results = await open(tester, tripId: tripId!);
    await tapMap(tester, const Offset(-150, -100));
    await tapMap(tester, const Offset(0, 0));
    await tapMap(tester, const Offset(150, 100));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.text('Add to day'));
      // The write runs on the real event loop.
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(results, [true]);
    expect(find.byType(RoutePlannerScreen), findsNothing);
    final items = await tester.runAsync(
      () => db.select(db.itineraryItems).get(),
    );
    final item = items!.single;
    expect(item.kind, ItemKind.transport);
    expect(item.date, day);
    expect(item.fromLat, isNotNull);
    final tracks = await tester.runAsync(() => db.select(db.tracks).get());
    expect(tracks!.single.source, TrackSource.routed);
  });
}
