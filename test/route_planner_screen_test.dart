import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
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
import 'package:travelplanner/features/route_planner/application/ski_router.dart';
import 'package:travelplanner/features/map/widgets/elevation_profile_chart.dart';
import 'package:travelplanner/features/map/widgets/map_overlays.dart';
import 'package:travelplanner/features/route_planner/application/tour_planner_controller.dart';
import 'package:travelplanner/features/route_planner/data/saved_tour.dart';
import 'package:travelplanner/features/route_planner/domain/pace.dart';
import 'package:travelplanner/features/route_planner/domain/piste_difficulty.dart';
import 'package:travelplanner/features/route_planner/domain/tour.dart';
import 'package:travelplanner/features/route_planner/domain/route_profile.dart';
import 'package:travelplanner/features/route_planner/domain/routed_path.dart';
import 'package:travelplanner/features/route_planner/presentation/route_planner_screen.dart';
import 'package:travelplanner/features/route_planner/tour_entries.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

import 'location_fixture.dart';
import 'support/terrain_overrides.dart';

/// A router that answers at once, or refuses while [refusal] is set, and holds
/// its answers back while [hold] is.
class _FakeEngine implements RouteEngine {
  final asked = <(List<LatLng>, RouteProfile)>[];
  RouteEngineException? refusal;
  Completer<void>? hold;

  /// Whether the answers come with a height for every point.
  bool heights = false;

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
      elevations: heights
          ? [for (var i = 0; i < waypoints.length; i++) 900.0 + i * 300]
          : null,
      lengthMeters: 4200,
      ascentMeters: 300,
      descentMeters: 120,
      duration: const Duration(minutes: 95),
    );
  }
}

/// A ski router that answers each run with a ride up and a descent, and
/// holds its answers back while [hold] is set.
class _FakeSkiRouter implements SkiRouter {
  final asked = <(List<LatLng>, PisteDifficulty)>[];
  Completer<void>? hold;
  var forgotten = 0;

  @override
  Future<RoutedPath> route({
    required List<LatLng> waypoints,
    required PisteDifficulty maxDifficulty,
  }) async {
    asked.add((waypoints, maxDifficulty));
    await hold?.future;
    final first = waypoints.first;
    final last = waypoints.last;
    // On the straight line between the two, so a tap on it finds the run.
    final top = LatLng(
      (first.latitude + last.latitude) / 2,
      (first.longitude + last.longitude) / 2,
    );
    return RoutedPath(
      points: [first, top, last],
      lengthMeters: 3000,
      duration: const Duration(minutes: 20),
      segments: const [
        PathSegment(
          start: 0,
          end: 1,
          kind: SegmentKind.lift,
          liftMode: TransportMode.chairLift,
          name: 'Sonnenbahn',
          toName: 'Bergstation',
          lengthMeters: 1000,
          duration: Duration(minutes: 8),
        ),
        PathSegment(
          start: 1,
          end: 2,
          kind: SegmentKind.descent,
          name: 'Talabfahrt',
          fromName: 'Bergstation',
          lengthMeters: 2000,
          duration: Duration(minutes: 12),
          pistes: [
            PisteStretch(
              name: 'Talabfahrt',
              difficulty: PisteDifficulty.intermediate,
            ),
          ],
        ),
      ],
      waypointIndices: [0, 2],
    );
  }

  @override
  Future<void> forget() async => forgotten++;
}

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late _FakeEngine engine;
  late _FakeSkiRouter skiRouter;
  final day = DateTime(2026, 3, 14);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    engine = _FakeEngine();
    skiRouter = _FakeSkiRouter();
  });
  tearDown(() => db.close());

  /// Pumps a page with a button that opens the planner on [tripId], on a tall
  /// window so the panel below the map is laid out whole.
  Future<List<bool>> open(
    WidgetTester tester, {
    int tripId = 1,
    Size size = const Size(1000, 2000),
    Locale? locale,
    SavedTour? editing,
    int? latestTime,
  }) async {
    tester.view.physicalSize = size;
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
          noTerrainHeights,
          noRememberedPaces,
          skiRouterProvider.overrideWithValue(skiRouter),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
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
                    editing: editing,
                    latestTime: latestTime,
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
    // The duration behind a clock and in "min", not a third figure in "m".
    expect(
      find.textContaining('4.2 km · ↑ 300 m · ↓ 120 m · '),
      findsOneWidget,
    );
    // The hiking time for 4.2 km, 300 m up and 120 m down, not the router's
    // 95 minutes.
    expect(find.textContaining('1 h 46 min'), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsNWidgets(2));
    expect(addButton(tester).onPressed, isNotNull);
  });

  testWidgets('the pace of the way of travel times the tour at once', (
    tester,
  ) async {
    await open(tester);
    await tapMap(tester, const Offset(-150, -100));
    await tapMap(tester, const Offset(150, 100));
    await tester.pumpAndSettle();
    expect(find.text('Pace:'), findsOneWidget);
    expect(find.textContaining('1 h 46 min'), findsOneWidget);

    await tester.tap(find.text('average'));
    await tester.pumpAndSettle();
    // Each pace says what it means on foot.
    expect(find.text('4.8 km/h, 360 m up an hour'), findsOneWidget);
    await tester.tap(find.text('brisk').last);
    await tester.pumpAndSettle();

    expect(find.text('brisk'), findsOneWidget);
    expect(find.textContaining('1 h 29 min'), findsOneWidget);
    expect(engine.asked, hasLength(1));
  });

  testWidgets('a pace of one\'s own is typed as a speed, and checked', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.text('average'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Own pace…'));
    await tester.pumpAndSettle();
    // Under the field, where it wraps, with the unit behind the figure.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration!.helperText, 'Walking speed on the flat');
    expect(field.decoration!.helperMaxLines, greaterThan(1));
    expect(field.decoration!.labelText, isNull);
    expect(field.decoration!.suffixText, 'km/h');
    await tester.enterText(find.byType(TextField), '6,2');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('6.2 km/h'), findsOneWidget);

    await tester.tap(find.text('6.2 km/h'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Own pace…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '20');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Choose a pace between 2.0 km/h and 8.0 km/h.'),
      findsOneWidget,
    );
    expect(find.text('6.2 km/h'), findsOneWidget);
  });

  testWidgets('running is timed by the minute a kilometer', (tester) async {
    await open(tester);
    await choose(tester, 'Run');

    await tester.tap(find.text('average'));
    await tester.pumpAndSettle();
    expect(find.text('6:00 min/km'), findsOneWidget);
    await tester.tap(find.text('Own pace…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '5:30');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('5:30 min/km'), findsOneWidget);
  });

  group('paceFromInput', () {
    const foot = RoutedMode(RouteProfile.foot);
    const run = RoutedMode(RouteProfile.run);
    const bike = RoutedMode(RouteProfile.bike);

    test('reads km/h on foot and on skis, a comma as the point', () {
      expect(paceFromInput(foot, '6'), const Pace(1.5));
      expect(paceFromInput(foot, ' 4,8 '), Pace.brisk);
      expect(paceFromInput(const SkiMode(), '27'), const Pace(1.5));
    });

    test('reads min/km running, as m:ss or in minutes', () {
      expect(paceFromInput(run, '6:00'), Pace.average);
      expect(paceFromInput(run, '5'), Pace.brisk);
      expect(paceFromInput(run, '7:30'), const Pace(0.8));
      expect(paceFromInput(run, '5:5'), isNull);
      expect(paceFromInput(run, '5:75'), isNull);
      expect(paceFromInput(run, '0'), isNull);
    });

    test('reads percent by bike', () {
      expect(paceFromInput(bike, '120'), Pace.brisk);
    });

    test('refuses what is no figure, or out of range', () {
      expect(paceFromInput(foot, 'fast'), isNull);
      expect(paceFromInput(foot, '1'), isNull);
      expect(paceFromInput(bike, '250'), isNull);
    });

    test('shows a pace the way it is typed back', () {
      for (final mode in [foot, run, bike, const SkiMode()]) {
        expect(
          paceFromInput(mode, paceInput(mode, const Pace(1.3))),
          const Pace(1.3),
          reason: '$mode',
        );
      }
    });
  });

  testWidgets('a drive has no pace, a ski run its grade and its pace', (
    tester,
  ) async {
    await open(tester);

    await choose(tester, 'Car');
    expect(find.text('Pace:'), findsNothing);

    await choose(tester, 'Ski');
    expect(find.text('Pistes:'), findsOneWidget);
    expect(find.text('Pace:'), findsOneWidget);
    await tester.tap(find.text('average'));
    await tester.pumpAndSettle();
    expect(find.text('descents at 18.0 km/h'), findsOneWidget);
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

  testWidgets('a straight line asks nobody', (tester) async {
    await open(tester);

    await choose(tester, 'Straight line');
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

  testWidgets('a ski run is routed over the pistes, to the grade chosen', (
    tester,
  ) async {
    await open(tester);
    await choose(tester, 'Ski');
    expect(find.text('Pistes:'), findsOneWidget);
    expect(find.text('all'), findsOneWidget);

    skiRouter.hold = Completer();
    await tapMap(tester, const Offset(-150, -100));
    await tapMap(tester, const Offset(150, 100));
    await tester.pump();
    expect(find.text('Loading pistes and lifts…'), findsOneWidget);
    skiRouter.hold!.complete();
    skiRouter.hold = null;
    await tester.pumpAndSettle();

    expect(engine.asked, isEmpty);
    expect(skiRouter.asked.single.$2, PisteDifficulty.standard);
    expect(addButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('up to intermediate').last);
    await tester.pumpAndSettle();

    // The run already planned is asked about again, held to the new grade.
    expect(skiRouter.asked.last.$2, PisteDifficulty.intermediate);
    expect(find.text('up to intermediate'), findsOneWidget);
  });

  testWidgets('a ski run is saved as a leg per ride and per descent', (
    tester,
  ) async {
    final tripId = await tester.runAsync(
      () => db.tripDao.createTrip(TripsCompanion.insert(title: 'Ski day')),
    );
    await open(tester, tripId: tripId!);
    await choose(tester, 'Ski');
    await tapMap(tester, const Offset(-150, -100));
    await tapMap(tester, const Offset(150, 100));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.text('Add to day'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    final items = await tester.runAsync(
      () => (db.select(
        db.itineraryItems,
      )..orderBy([(i) => OrderingTerm(expression: i.sortOrder)])).get(),
    );
    final modes = await tester.runAsync(() => db.transportModeDao.modes());
    String? modeOf(ItineraryItem item) =>
        modes!.where((m) => m.id == item.mode).firstOrNull?.builtinKey;
    expect(items!.map((i) => i.title), ['Sonnenbahn', 'Talabfahrt']);
    expect(items.map(modeOf), ['chairLift', 'ski']);
    expect(items.first.toLocation, 'Bergstation');
    expect(items.last.fromLocation, 'Bergstation');
    expect(items.map((i) => i.notes), [null, 'Red']);
    expect(items.map((i) => i.groupId).toSet(), hasLength(1));
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
          .read(tourPlannerProvider(null))
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
  ).read(tourPlannerProvider(null)).tour.waypoints.length;

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
    await choose(tester, 'Straight line');
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
          .widget<ChoiceChip>(
            inSheet(find.widgetWithText(ChoiceChip, 'Straight line')),
          )
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

  /// Drags [handle] by [dy] the way a finger does: a reorderable's handle
  /// starts the drag at once, and the list has to see it cross each row.
  Future<void> dragBy(WidgetTester tester, Finder handle, double dy) async {
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 50));
    for (var moved = 0.0; moved.abs() < dy.abs(); moved += dy / 8) {
      await gesture.moveBy(Offset(0, dy / 8));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('the points are numbered on the map in their order', (
    tester,
  ) async {
    await open(tester);
    await tapMap(tester, const Offset(-150, -100));
    await tapMap(tester, const Offset(150, 100));
    await tester.pumpAndSettle();

    for (final (index, number) in ['1', '2'].indexed) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('waypoint-$index')),
          matching: find.text(number),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('Points is offered from the first point on', (tester) async {
    await open(tester);
    IconButton points() => tester.widget(
      find.widgetWithIcon(IconButton, Icons.format_list_numbered),
    );
    expect(points().onPressed, isNull);

    await tapMap(tester, const Offset(-150, -100));
    expect(points().onPressed, isNotNull);
  });

  testWidgets('the bin on a point in the list removes that point', (
    tester,
  ) async {
    await open(tester);
    await tapMap(tester, const Offset(-200, -100));
    await tapMap(tester, const Offset(0, 0));
    await tapMap(tester, const Offset(200, 100));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RoutePlannerScreen)),
    );
    List<LatLng> positions() => [
      for (final w in container.read(tourPlannerProvider(null)).tour.waypoints)
        w.position,
    ];
    final before = positions();

    await tester.tap(find.byTooltip('Points'));
    await tester.pumpAndSettle();
    expect(inSheet(find.byIcon(Icons.delete_outline)), findsNWidgets(3));

    // The middle one, not the last.
    await tester.tap(find.byKey(const ValueKey('point-remove-1')));
    await tester.pumpAndSettle();

    expect(positions(), [before[0], before[2]]);
    // The list stays open on what is left, and the map follows.
    expect(inSheet(find.byType(ListTile)), findsNWidgets(2));
    expect(find.byKey(const ValueKey('waypoint-2')), findsNothing);
    // From the first to what was the third, in one run.
    expect(engine.asked.last.$1, [before[0], before[2]]);
  });

  testWidgets('removing the only point closes the list', (tester) async {
    await open(tester);
    await tapMap(tester, const Offset(-150, -100));

    await tester.tap(find.byTooltip('Points'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('point-remove-0')));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(waypointCount(tester), 0);
    expect(find.text('Tap the map to set the start.'), findsOneWidget);
  });

  testWidgets('dragging a point in the list changes the order of the tour', (
    tester,
  ) async {
    await open(tester);
    await choose(tester, 'Car');
    await tapMap(tester, const Offset(-200, -100));
    await tapMap(tester, const Offset(0, 0));
    await choose(tester, 'On foot');
    await tapMap(tester, const Offset(200, 100));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RoutePlannerScreen)),
    );
    List<LatLng> positions() => [
      for (final w in container.read(tourPlannerProvider(null)).tour.waypoints)
        w.position,
    ];
    final before = positions();

    await tester.tap(find.byTooltip('Points'));
    await tester.pumpAndSettle();
    // Each row says how its point is reached.
    expect(inSheet(find.text('Start')), findsOneWidget);
    expect(inSheet(find.text('Car')), findsOneWidget);
    expect(inSheet(find.text('On foot')), findsOneWidget);

    // The last point, up past the one before it.
    final row = tester.getSize(find.byKey(const ValueKey('point-2'))).height;
    await dragBy(
      tester,
      find.byKey(const ValueKey('point-handle-2')),
      -row * 1.2,
    );

    expect(positions(), [before[0], before[2], before[1]]);
    // It is still reached on foot, and the list says so in its new place.
    final tiles = tester
        .widgetList<ListTile>(inSheet(find.byType(ListTile)))
        .map((tile) => (tile.subtitle! as Text).data)
        .toList();
    expect(tiles, ['Start', 'On foot', 'Car']);
    expect(engine.asked.skip(2).map((request) => request.$2), [
      RouteProfile.foot,
      RouteProfile.car,
    ]);
  });

  testWidgets('nothing overflows on a narrow phone in German', (tester) async {
    // An overflow fails a test by itself. The German texts are the long ones,
    // and the test font is about twice as wide as a real one, so this is the
    // strict end of what a phone shows.
    engine.hold = Completer<void>();
    await open(tester, size: const Size(360, 800), locale: const Locale('de'));
    await tapMap(tester, const Offset(-60, -60));
    await tapMap(tester, const Offset(60, 60));
    expect(find.text('Route wird berechnet …'), findsOneWidget);

    engine.hold!.complete();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Punkte'), findsOneWidget);

    await tester.tap(find.byTooltip('Punkte'));
    await tester.pumpAndSettle();
    expect(inSheet(find.text('Zu Fuß')), findsOneWidget);
    await tester.tapAt(const Offset(180, 20));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('waypoint-1')));
    await tester.pumpAndSettle();
    expect(find.text('Punkt entfernen'), findsOneWidget);
    await tester.tap(find.text('Punkt verschieben'));
    await tester.pumpAndSettle();
    expect(find.text('Abbrechen'), findsOneWidget);
  });

  group('the elevation profile', () {
    // By its tooltip: shown, it wears its filled icon.
    IconButton button(WidgetTester tester) => tester.widget(
      find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'Elevation profile',
      ),
    );

    /// A tour of three points whose route came with heights, its profile
    /// shown over the map.
    Future<void> showProfile(WidgetTester tester) async {
      engine.heights = true;
      await open(tester);
      expect(button(tester).onPressed, isNull);

      await tapMap(tester, const Offset(-200, -100));
      await tapMap(tester, const Offset(200, 100));
      await tester.pumpAndSettle();
      expect(button(tester).onPressed, isNotNull);

      await tester.tap(find.byTooltip('Elevation profile'));
      await tester.pumpAndSettle();
    }

    Finder plot() => find.descendant(
      of: find.byType(ElevationProfileChart),
      matching: find.byType(GestureDetector),
    );

    testWidgets('is shown over the map once a line came with heights', (
      tester,
    ) async {
      Size mapSize() => tester.getSize(find.byType(FlutterMap));
      await showProfile(tester);
      final size = mapSize();

      expect(find.byKey(const ValueKey('profile-overlay')), findsOneWidget);
      expect(button(tester).isSelected, isTrue);
      // The lowest and the highest point, as the chart's scale.
      expect(find.text('900 m'), findsOneWidget);
      expect(find.text('1200 m'), findsOneWidget);
      // Over the map, not in a sheet: no scrim, and the map keeps its size.
      expect(find.byType(BottomSheet), findsNothing);
      expect(mapSize(), size);

      await tester.tap(find.byTooltip('Elevation profile'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-overlay')), findsNothing);
    });

    testWidgets('a finger drawn across it shows the point on the map', (
      tester,
    ) async {
      await showProfile(tester);
      final rect = tester.getRect(plot());

      final gesture = await tester.startGesture(
        rect.centerLeft + const Offset(10, 0),
      );
      await tester.pump();
      await gesture.moveTo(rect.center);
      await tester.pump();

      // The cursor's distance and height, and its point on the map.
      final cursor = tester.widget<Text>(
        find.byKey(const ValueKey('profile-cursor')),
      );
      expect(cursor.data, contains(' m'));
      expect(cursor.data, contains(' · '));
      expect(find.byKey(const ValueKey('profile-scrub-mark')), findsOneWidget);
      // Half way along the line from the first point to the second: between
      // them on the map too.
      final mark = tester.getCenter(
        find.byKey(const ValueKey('profile-scrub-mark')),
      );
      final from = tester.getCenter(find.byKey(const ValueKey('waypoint-0')));
      final to = tester.getCenter(find.byKey(const ValueKey('waypoint-1')));
      expect(mark.dx, inExclusiveRange(from.dx, to.dx));
      expect(mark.dy, inExclusiveRange(from.dy, to.dy));

      await gesture.up();
      await tester.pump();
      expect(find.byKey(const ValueKey('profile-scrub-mark')), findsNothing);
      expect(find.byKey(const ValueKey('profile-cursor')), findsNothing);
    });

    testWidgets('a pointer hovering over it does the same', (tester) async {
      await showProfile(tester);
      final rect = tester.getRect(plot());

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(rect.center);
      await tester.pump();
      expect(find.byKey(const ValueKey('profile-scrub-mark')), findsOneWidget);

      // Leaving the chart takes it away.
      await mouse.moveTo(rect.topCenter - const Offset(0, 40));
      await tester.pump();
      expect(find.byKey(const ValueKey('profile-scrub-mark')), findsNothing);
    });

    testWidgets('a drag across it does not pan the map', (tester) async {
      await showProfile(tester);
      final before = tester.getCenter(find.byKey(const ValueKey('waypoint-0')));
      final rect = tester.getRect(plot());

      await tester.dragFrom(
        rect.centerLeft + const Offset(10, 0),
        const Offset(200, 0),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getCenter(find.byKey(const ValueKey('waypoint-0'))),
        before,
      );
    });

    testWidgets('is not offered for a tour without heights', (tester) async {
      await open(tester);
      await choose(tester, 'Straight line');
      await tapMap(tester, const Offset(-150, -100));
      await tapMap(tester, const Offset(150, 100));
      await tester.pumpAndSettle();

      expect(button(tester).onPressed, isNull);
    });
  });

  group('opened on a saved tour', () {
    const start = LatLng(47.4, 11.0);
    const end = LatLng(47.5, 11.2);
    final tour = Tour(
      waypoints: const [
        TourWaypoint(start, name: 'Car park'),
        TourWaypoint(end, name: 'Summit'),
      ],
      modes: const [RoutedMode(RouteProfile.foot)],
    );
    SavedTour saved() => SavedTour(
      tourId: 't1',
      itemIds: const [],
      groupId: null,
      tour: tour,
      startMinutes: 7 * 60 + 30,
      paths: {
        runKey(tour, tourRuns(tour).single)!: const RoutedPath(
          points: [start, end],
          lengthMeters: 5000,
          duration: Duration(minutes: 80),
        ),
      },
    );

    testWidgets('shows the tour complete and asks the router nothing', (
      tester,
    ) async {
      await open(tester, editing: saved());

      expect(engine.asked, isEmpty);
      expect(find.byKey(const ValueKey('waypoint-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('waypoint-1')), findsOneWidget);
      expect(find.textContaining('5 km'), findsOneWidget);
      // 5 km on foot by the hiking time; the plan's 80 minutes are the
      // router's.
      expect(find.textContaining('1 h 15 min'), findsOneWidget);
      // The time its first entry has.
      expect(find.text('Start 07:30'), findsOneWidget);
    });

    testWidgets('saves over what is there, and says so', (tester) async {
      await open(tester, editing: saved());

      expect(find.widgetWithText(TextButton, 'Add to day'), findsNothing);
      final save = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Save'),
      );
      expect(save.onPressed, isNotNull);
    });
  });

  testWidgets(
    'the attribution sits on the panel, not a navigation bar higher',
    (tester) async {
      // A phone with a gesture or button bar along its foot.
      tester.view.padding = const FakeViewPadding(bottom: 48);
      addTearDown(tester.view.resetPadding);
      await open(tester);

      final bar = tester.getRect(find.byType(MapAttributionBar));
      final map = tester.getRect(find.byType(FlutterMap));
      // At the map's foot, and only as tall as its line of text: the inset is
      // the panel's to take, below it.
      expect(bar.bottom, map.bottom);
      expect(bar.height, lessThan(30));

      // The same with the profile shown over it.
      engine.heights = true;
      await tapMap(tester, const Offset(-150, -100));
      await tapMap(tester, const Offset(150, 100));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Elevation profile'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(MapAttributionBar)).height,
        lessThan(30),
      );
    },
  );

  testWidgets('the start time is picked from where the day leaves off', (
    tester,
  ) async {
    await open(tester, latestTime: 10 * 60 + 30);

    await tester.tap(find.text('Start time'));
    await tester.pumpAndSettle();

    // The dial opens on half past ten.
    expect(find.text('10'), findsWidgets);
    expect(find.text('30'), findsWidgets);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Start 10:30'), findsOneWidget);
  });

  group('the sheets keep clear of the navigation bar', () {
    const bar = 48.0;

    Future<void> withBar(WidgetTester tester) async {
      tester.view.padding = const FakeViewPadding(bottom: bar);
      addTearDown(tester.view.resetPadding);
      await open(tester);
      await tapMap(tester, const Offset(-200, 0));
      await tapMap(tester, const Offset(200, 0));
      await tester.pumpAndSettle();
    }

    double screenBottom(WidgetTester tester) =>
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    testWidgets('the waypoint sheet', (tester) async {
      await withBar(tester);
      await tester.tap(find.byKey(const ValueKey('waypoint-1')));
      await tester.pumpAndSettle();

      for (final label in ['Remove point', 'Save']) {
        expect(
          tester.getRect(inSheet(find.text(label))).bottom,
          lessThanOrEqualTo(screenBottom(tester) - bar),
          reason: label,
        );
      }
    });

    testWidgets('the section sheet', (tester) async {
      await withBar(tester);
      await tapMap(tester, Offset.zero);
      await tester.pumpAndSettle();

      expect(
        tester.getRect(inSheet(find.text('Add a point here'))).bottom,
        lessThanOrEqualTo(screenBottom(tester) - bar),
      );
    });

    testWidgets('the list of points', (tester) async {
      await withBar(tester);
      await tester.tap(find.byTooltip('Points'));
      await tester.pumpAndSettle();

      expect(
        tester.getRect(inSheet(find.byType(ListTile)).last).bottom,
        lessThanOrEqualTo(screenBottom(tester) - bar),
      );
    });
  });

  testWidgets('the attribution names the router and the map data', (
    tester,
  ) async {
    await open(tester);
    final bar = find.byType(MapAttributionBar);

    expect(
      find.descendant(of: bar, matching: find.text('Routes by BRouter')),
      findsOneWidget,
    );
    // Named once, though both the map and the routes are OpenStreetMap's.
    expect(
      find.descendant(of: bar, matching: find.text('© OpenStreetMap')),
      findsOneWidget,
    );
    // A wrong way is often wrong data; overpass-api.de's terms ask for this.
    expect(
      find.descendant(of: bar, matching: find.text('Report a map error')),
      findsOneWidget,
    );
  });

  group('my position', () {
    late FakeGeolocator platform;

    setUp(() {
      platform = FakeGeolocator()..permission = LocationPermission.whileInUse;
      GeolocatorPlatform.instance = platform;
    });

    int count(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(RoutePlannerScreen)),
    ).read(tourPlannerProvider(null)).tour.waypoints.length;

    List<LatLng> points(WidgetTester tester) => [
      for (final w in ProviderScope.containerOf(
        tester.element(find.byType(RoutePlannerScreen)),
      ).read(tourPlannerProvider(null)).tour.waypoints)
        w.position,
    ];

    testWidgets('the reading the press waited for is the next point', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byTooltip('Next point at my position'));
      await tester.pump();

      platform.emit(latitude: 47.42, longitude: 11.08, accuracy: 8);
      await tester.pumpAndSettle();
      expect(points(tester), [const LatLng(47.42, 11.08)]);

      // Walking on moves the blue mark, not the tour.
      platform.emit(latitude: 47.43, longitude: 11.09, accuracy: 8);
      await tester.pumpAndSettle();
      expect(count(tester), 1);

      // A second press takes the reading there is now.
      await tester.tap(find.byTooltip('Next point at my position'));
      await tester.pumpAndSettle();
      expect(points(tester).last, const LatLng(47.43, 11.09));
    });

    testWidgets('a tap made while waiting wins', (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('Next point at my position'));
      await tester.pump();

      await tapMap(tester, const Offset(-100, 0));
      platform.emit(latitude: 47.42, longitude: 11.08, accuracy: 8);
      await tester.pumpAndSettle();

      expect(count(tester), 1);
      expect(points(tester).single, isNot(const LatLng(47.42, 11.08)));
    });

    testWidgets('while a point is being moved, it moves there', (tester) async {
      await open(tester);
      await tapMap(tester, const Offset(-150, -100));
      await tapMap(tester, const Offset(150, 100));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('waypoint-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move point'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Use my position'));
      await tester.pump();
      platform.emit(latitude: 47.42, longitude: 11.08, accuracy: 8);
      await tester.pumpAndSettle();

      expect(count(tester), 2);
      expect(points(tester).last, const LatLng(47.42, 11.08));
    });
  });

  testWidgets('a point being moved can be put down on a line', (tester) async {
    await open(tester);
    await tapMap(tester, const Offset(-200, 0));
    await tapMap(tester, const Offset(200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('waypoint-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move point'));
    await tester.pumpAndSettle();

    // On the line between the two: the point goes there, no sheet opens.
    await tapMap(tester, Offset.zero);
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RoutePlannerScreen)),
    );
    final tour = container.read(tourPlannerProvider(null)).tour;
    expect(tour.waypoints, hasLength(2));
    expect(
      tester.getCenter(find.byKey(const ValueKey('waypoint-0'))).dx,
      closeTo(tester.getCenter(find.byType(FlutterMap)).dx, 25),
    );
  });

  testWidgets('without a time of the day, the start time opens on now', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.text('Start time'));
    await tester.pumpAndSettle();
    expect(find.text('OK'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Start time'), findsOneWidget);
  });

  testWidgets('an error from the router is said as one', (tester) async {
    engine.refusal = const RouteEngineException('boom', statusCode: 500);
    await open(tester);

    await tapMap(tester, const Offset(-150, -100));
    await tapMap(tester, const Offset(150, 100));
    await tester.pumpAndSettle();

    expect(
      find.text('The routing service answered with an error.'),
      findsOneWidget,
    );
  });

  testWidgets('a named point is listed by its name', (tester) async {
    await open(tester);
    await tapMap(tester, const Offset(-150, -100));
    await tapMap(tester, const Offset(150, 100));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('waypoint-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Summit ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Points'));
    await tester.pumpAndSettle();

    expect(inSheet(find.text('Summit')), findsOneWidget);
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
    await choose(tester, 'Straight line');
    expect(map(), size);

    // A point waiting to be put down.
    await tester.tap(find.byKey(const ValueKey('waypoint-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move point'));
    await tester.pumpAndSettle();
    expect(map(), size);
  });

  testWidgets('a ski section can have its pistes and lifts loaded again', (
    tester,
  ) async {
    await open(tester);
    await choose(tester, 'Ski');
    await tapMap(tester, const Offset(-200, 0));
    await tapMap(tester, const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(skiRouter.asked, hasLength(1));

    // The descent's half of the line.
    await tapMap(tester, const Offset(100, 0));
    await tester.pumpAndSettle();
    await tester.tap(inSheet(find.text('Reload pistes and lifts')));
    await tester.pumpAndSettle();

    expect(skiRouter.forgotten, 1);
    expect(skiRouter.asked, hasLength(2));
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
