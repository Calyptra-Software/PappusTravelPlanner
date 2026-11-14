import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/stopovers.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/transport_search/data/run_shape_cache.dart';
import 'package:travelplanner/data/database/track_points.dart';
import 'package:travelplanner/features/itinerary/application/transport_mode_providers.dart';
import 'package:travelplanner/features/itinerary/widgets/timeline_tile.dart';
import 'package:travelplanner/features/transport_search/application/transport_search.dart';
import 'package:travelplanner/features/transport_search/application/transport_search_providers.dart';
import 'package:travelplanner/features/transport_search/data/motis_client.dart';
import 'package:travelplanner/features/transport_search/domain/journey.dart';
import 'package:travelplanner/features/transport_search/domain/journey_options.dart';
import 'package:travelplanner/features/transport_search/domain/transport_place.dart';
import 'package:travelplanner/features/transport_search/domain/via_stop.dart';
import 'package:travelplanner/features/map/map_features.dart';
import 'package:travelplanner/features/map/widgets/map_overlays.dart';
import 'package:travelplanner/features/transport_search/presentation/journey_map.dart';
import 'package:travelplanner/features/transport_search/presentation/journey_screen.dart';
import 'package:travelplanner/features/transport_search/presentation/journey_sheet.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

import 'support/journey_screen_overrides.dart';

/// Reading back a journey the trip already holds. Drift's `.watch()` streams do
/// not resolve under the fake-async clock, so the trip's items arrive as a plain
/// stream — the same arrangement the other widget tests use.
const _train = TransportModeRow(id: 6, builtinKey: 'train', sortOrder: 5);
const _walk = TransportModeRow(id: 1, builtinKey: 'walk', sortOrder: 0);

ItineraryItem _leg({
  required int id,
  String? title,
  required String from,
  required String to,
  required int start,
  required int end,
  int? mode = 6,
  int? groupId = 1,
  String? notes,
  String? stopovers,
  String? runStops,
  String? sourceTripId,
}) => ItineraryItem(
  id: id,
  tripId: 7,
  groupId: groupId,
  date: DateTime(2026, 7, 27),
  sortOrder: id,
  kind: ItemKind.transport,
  endDayOffset: 0,
  chordDisplay: TrackDisplay.auto,
  title: title,
  startMinutes: start,
  endMinutes: end,
  mode: mode,
  notes: notes,
  fromLocation: from,
  toLocation: to,
  stopovers: stopovers,
  runStops: runStops,
  sourceTripId: sourceTripId,
);

/// A router that counts what it is asked and answers nothing: for the tests
/// that must send no request at all.
class _CountingSearch implements TransportSearch {
  int requests = 0;

  @override
  Future<List<StopDeparture>> departures({
    required double lat,
    required double lon,
    required DateTime from,
    required Duration window,
  }) async {
    requests++;
    return const [];
  }

  @override
  Future<TripRun> tripRun(String tripId) async {
    requests++;
    return const TripRun(stops: []);
  }

  @override
  Future<List<TripStop>> tripStops(String tripId) async {
    requests++;
    return const [];
  }

  @override
  Future<List<TransportPlace>> searchPlaces(String query) =>
      throw UnimplementedError();
  @override
  Future<JourneyResults> journeys({
    required String fromId,
    required String toId,
    required DateTime time,
    bool arriveBy = false,
    JourneySearchOptions options = const JourneySearchOptions(),
    ViaStops via = ViaStops.none,
    String? pageCursor,
  }) => throw UnimplementedError();
}

/// A router that has reissued its trip ids since the leg was imported: every
/// trip it is asked about is gone.
class _ForgetfulSearch implements TransportSearch {
  @override
  Future<List<StopDeparture>> departures({
    required double lat,
    required double lon,
    required DateTime from,
    required Duration window,
  }) => throw UnimplementedError();

  @override
  Future<TripRun> tripRun(String tripId) async =>
      throw const TransportSearchException(
        'MOTIS request failed (404)',
        statusCode: 404,
      );

  @override
  Future<List<TripStop>> tripStops(String tripId) async =>
      throw const TransportSearchException(
        'MOTIS request failed (404)',
        statusCode: 404,
      );

  @override
  Future<List<TransportPlace>> searchPlaces(String query) =>
      throw UnimplementedError();
  @override
  Future<JourneyResults> journeys({
    required String fromId,
    required String toId,
    required DateTime time,
    bool arriveBy = false,
    JourneySearchOptions options = const JourneySearchOptions(),
    ViaStops via = ViaStops.none,
    String? pageCursor,
  }) => throw UnimplementedError();
}

/// Hamburg → Basel as the import wrote it: an ICE calling at three places, a
/// walk across Frankfurt, then a second ICE — all in one group.
final _journey = [
  _leg(
    id: 1,
    title: 'ICE 507',
    from: 'Hamburg Hbf',
    to: 'Frankfurt(Main) Hbf',
    start: 480,
    end: 590,
    notes: 'to München Hbf · Pl. 14 → Pl. 7',
    sourceTripId: 'trip-507',
    stopovers: encodeStopovers(const [
      Stopover(name: 'Hannover Hbf', minutes: 520, delayMinutes: 5),
      Stopover(name: 'Göttingen', minutes: 545),
      Stopover(name: 'Kassel-Wilhelmshöhe', minutes: 565, cancelled: true),
    ]),
  ),
  // The walking transfer, as the import wrote it: no line to name, the walk
  // mode, and nothing to refresh.
  _leg(
    id: 2,
    from: 'Frankfurt(Main) Hbf',
    to: 'Frankfurt(Main) Hbf',
    start: 592,
    end: 600,
    mode: 1,
  ),
  // A service the feed listed no intermediate stops for — imported all the same.
  _leg(
    id: 3,
    title: 'ICE 71',
    from: 'Frankfurt(Main) Hbf',
    to: 'Basel SBB',
    start: 613,
    end: 780,
    sourceTripId: 'trip-71',
  ),
];

Future<void> _pumpSheet(
  WidgetTester tester,
  List<ItineraryItem> items, {
  TransportSearch? search,
  String? label = 'To Basel',
  DateTime? now,
  Map<int, List<TrackLine>> tracks = const {},
  RunShapeCache? runShapes,
}) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        transportModesByIdProvider.overrideWith(
          (ref) => {_train.id: _train, _walk.id: _walk},
        ),
        if (search != null) transportSearchProvider.overrideWithValue(search),
        ...journeyScreenOverrides(
          tripId: 7,
          items: items,
          prefs: await _prefs(),
          groups: {
            1: ItemGroup(id: 1, tripId: 7, label: label, collapsed: false),
          },
          now: now,
          tracks: tracks,
          runShapes: runShapes,
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
        home: const JourneyScreen(tripId: 7, groupId: 1),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await settleTiles(tester);
}

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

void main() {
  testWidgets('reads the stored journey as legs and changes', (tester) async {
    await _pumpSheet(tester, _journey);

    expect(find.text('To Basel'), findsOneWidget);
    expect(find.textContaining('ICE 507'), findsOneWidget);
    expect(find.textContaining('ICE 71'), findsOneWidget);
    // The walk between the two trains is the change, not a leg of its own.
    expect(find.text('23 min change in Frankfurt(Main) Hbf'), findsOneWidget);
    expect(find.text('8 min'), findsOneWidget);
    // 08:00 – 13:00, in the header and on the legs themselves.
    expect(find.textContaining('8:00 AM'), findsNWidgets(2));
    expect(find.textContaining('1:00 PM'), findsNWidgets(2));
    // What the import wrote into the leg is where the platforms survive.
    expect(find.textContaining('Pl. 14 → Pl. 7'), findsOneWidget);
  });

  testWidgets('the stops are folded away until asked for', (tester) async {
    await _pumpSheet(tester, _journey);

    expect(find.text('3 stops'), findsOneWidget);
    expect(find.text('Hannover Hbf'), findsNothing);

    await tester.tap(find.text('3 stops'));
    await tester.pumpAndSettle();

    expect(find.text('Hannover Hbf'), findsOneWidget);
    expect(find.text('Kassel-Wilhelmshöhe'), findsOneWidget);
    // Each stop says when the train leaves it — 08:40 for Hannover, running 5
    // late, the miss printed beside the plan as everywhere else.
    expect(find.textContaining('8:40 AM'), findsOneWidget);
    expect(find.textContaining('(+5)'), findsOneWidget);
    // A stop nothing is known about says nothing: 09:05 with no figure.
    expect(find.textContaining('9:05 AM'), findsOneWidget);
  });

  testWidgets('a stop the train skips is struck out, and said on the fold', (
    tester,
  ) async {
    await _pumpSheet(tester, _journey);

    // Folded away is where a cancellation would hide, so the count says it.
    expect(find.text('1 stop canceled'), findsOneWidget);

    await tester.tap(find.text('3 stops'));
    await tester.pumpAndSettle();

    expect(find.text('Canceled'), findsOneWidget);
    final name = tester.widget<Text>(find.text('Kassel-Wilhelmshöhe'));
    expect(name.style?.decoration, TextDecoration.lineThrough);
    // 09:25 with no figure beside it: the feed repeats the plan for a stop it
    // is dropping, and printing that as "(+0)" is what this must never do.
    expect(find.textContaining('9:25 AM'), findsOneWidget);
    expect(find.textContaining('(+0)'), findsNothing);
  });

  testWidgets('a leg with no stops recorded offers no toggle', (tester) async {
    await _pumpSheet(tester, [_journey.last]);

    expect(find.textContaining('stops'), findsNothing);
    expect(find.textContaining('ICE 71'), findsOneWidget);
  });

  testWidgets('only an imported leg offers to refresh its live times', (
    tester,
  ) async {
    await _pumpSheet(tester, _journey);

    // One per service; the walk transfer has no trip to ask about.
    expect(find.byIcon(Icons.sync), findsNWidgets(2));
  });

  group('the run around a leg', () {
    // ICE 507 as the import wrote it, with its run since loaded: it set out
    // from Kiel the evening before and goes on past Frankfurt to München.
    final withRun = _journey.first.copyWith(
      runStops: Value(
        encodeRunStops(
          const RunStops(
            before: [
              Stopover(name: 'Kiel Hbf', minutes: 1410, dayOffset: -1),
              Stopover(name: 'Neumünster', minutes: 1440 - 5, dayOffset: -1),
            ],
            after: [
              Stopover(name: 'Mannheim Hbf', minutes: 630, delayMinutes: 3),
              Stopover(name: 'München Hbf', minutes: 800),
            ],
          ),
        ),
      ),
    );

    /// A cache already holding the ICE's route: what a run shown before
    /// leaves behind, so showing it again asks nobody.
    RunShapeCache cachedRoute() {
      final cache = RunShapeCache(Future.value());
      cache.write(
        'trip-507',
        encodeTrackPoints(const [
          LatLng(54.31, 10.13),
          LatLng(53.553, 10.007),
          LatLng(50.107, 8.663),
          LatLng(48.14, 11.56),
        ], precision: kRoutedShapePrecision),
        lastDay: DateTime(2026, 7, 27),
      );
      return cache;
    }

    testWidgets('is put away until asked for, though it is stored', (
      tester,
    ) async {
      await _pumpSheet(tester, [withRun], runShapes: cachedRoute());

      expect(find.text('From Kiel Hbf · 2 earlier stops'), findsNothing);
      // Offered all the same: the stored run is shown by the same button.
      expect(find.text('Show the whole route'), findsOneWidget);
    });

    testWidgets('is folded on either side of the leg once asked for', (
      tester,
    ) async {
      final search = _CountingSearch();
      await _pumpSheet(
        tester,
        [withRun],
        search: search,
        runShapes: cachedRoute(),
      );

      await tester.tap(find.text('Show the whole route'));
      await tester.pumpAndSettle();

      // Stored stops and a kept route: nobody was asked.
      expect(search.requests, 0);
      expect(find.text('From Kiel Hbf · 2 earlier stops'), findsOneWidget);
      expect(find.text('To München Hbf · 2 more stops'), findsOneWidget);
      expect(find.text('Neumünster'), findsNothing);

      await tester.tap(find.text('From Kiel Hbf · 2 earlier stops'));
      await tester.pumpAndSettle();

      expect(find.text('Neumünster'), findsOneWidget);
      // The evening before the leg's own day is said, as the morning after is.
      expect(find.text(' -1'), findsNWidgets(2));
      await settleTiles(tester);
    });

    testWidgets('is put away again by the same button', (tester) async {
      await _pumpSheet(
        tester,
        [withRun],
        search: _CountingSearch(),
        runShapes: cachedRoute(),
      );

      await tester.tap(find.text('Show the whole route'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hide the whole route'));
      await tester.pumpAndSettle();

      expect(find.text('From Kiel Hbf · 2 earlier stops'), findsNothing);
      expect(find.text('Show the whole route'), findsOneWidget);
      await settleTiles(tester);
    });

    testWidgets('is offered on a service, never on a walk', (tester) async {
      await _pumpSheet(tester, _journey);

      // Both trains have a trip to ask; the walk between them does not.
      expect(find.text('Show the whole route'), findsNWidgets(2));
    });

    testWidgets('a service gone from the timetable is said beside the button', (
      tester,
    ) async {
      await _pumpSheet(tester, [_journey.last], search: _ForgetfulSearch());

      await tester.tap(find.text('Show the whole route'));
      await tester.pumpAndSettle();

      // Inside the panel, where it was asked.
      expect(
        find.text('This service is no longer in the current timetable'),
        findsOneWidget,
      );
      expect(find.text('Hide the whole route'), findsNothing);
    });

    testWidgets('stored stops without a route are shown, and say so', (
      tester,
    ) async {
      // Offline: the stops are in the trip, the route is nowhere.
      await _pumpSheet(tester, [withRun], search: _ForgetfulSearch());

      await tester.tap(find.text('Show the whole route'));
      await tester.pumpAndSettle();

      expect(find.text('From Kiel Hbf · 2 earlier stops'), findsOneWidget);
      expect(
        find.text("The route's path can't be loaded right now"),
        findsOneWidget,
      );
      await settleTiles(tester);
    });
  });

  group('the screen around it', () {
    testWidgets('opens on a map, its sources credited on screen', (
      tester,
    ) async {
      await _pumpSheet(tester, _journey);

      expect(find.byType(FlutterMap), findsOneWidget);
      // A condition of using the tiles, so it is never hidden by the panel.
      expect(find.textContaining('OpenStreetMap'), findsOneWidget);
    });

    testWidgets('the credit is one line high over a navigation bar', (
      tester,
    ) async {
      // A phone with gesture navigation: an inset at the foot of the screen,
      // where the panel is, not the credit.
      tester.view.padding = const FakeViewPadding(bottom: 48);
      addTearDown(tester.view.resetPadding);
      await _pumpSheet(tester, _journey);

      expect(
        tester.getSize(find.byType(MapAttributionBar)).height,
        lessThan(30),
      );
    });

    testWidgets('is titled by its run\'s label, or plainly without one', (
      tester,
    ) async {
      await _pumpSheet(tester, _journey, label: null);

      expect(find.widgetWithText(AppBar, 'Journey'), findsOneWidget);
    });

    testWidgets('draws a shown run along its route, in the quiet grey', (
      tester,
    ) async {
      final withRun = _journey.first.copyWith(
        fromLat: const Value(53.553),
        fromLon: const Value(10.007),
        toLat: const Value(50.107),
        toLon: const Value(8.663),
        runStops: Value(
          encodeRunStops(
            const RunStops(
              before: [
                Stopover(
                  name: 'Kiel Hbf',
                  minutes: 400,
                  lat: 54.31,
                  lon: 10.13,
                ),
              ],
            ),
          ),
        ),
      );
      final cache = RunShapeCache(Future.value());
      await cache.write(
        'trip-507',
        encodeTrackPoints(const [
          LatLng(54.31, 10.13),
          LatLng(54.0, 10.2),
          LatLng(53.553, 10.007),
          LatLng(50.107, 8.663),
        ], precision: kRoutedShapePrecision),
        lastDay: DateTime(2026, 7, 27),
      );
      await _pumpSheet(tester, [withRun], runShapes: cache);

      List<Polyline> runLines() => [
        for (final layer in tester.widgetList<PolylineLayer>(
          find.byWidgetPredicate((w) => w is PolylineLayer),
        ))
          for (final line in layer.polylines)
            if (line.color == kJourneyRunColor) line,
      ];
      // Nothing outside the leg until it is asked for, and never a straight
      // line from stop to stop.
      expect(runLines(), isEmpty);

      await tester.tap(find.text('Show the whole route'));
      await tester.pumpAndSettle();

      // Along the route, from Kiel to where the traveler boards.
      expect(runLines().single.points, const [
        LatLng(54.31, 10.13),
        LatLng(54.0, 10.2),
        LatLng(53.553, 10.007),
      ]);
      await settleTiles(tester);
    });

    testWidgets('frames a shown run in the strip a raised panel leaves', (
      tester,
    ) async {
      final withRun = _journey.first.copyWith(
        fromLat: const Value(53.553),
        fromLon: const Value(10.007),
        toLat: const Value(50.107),
        toLon: const Value(8.663),
        runStops: Value(
          encodeRunStops(
            const RunStops(
              before: [
                Stopover(
                  name: 'Kiel Hbf',
                  minutes: 400,
                  lat: 54.31,
                  lon: 10.13,
                ),
              ],
            ),
          ),
        ),
      );
      final cache = RunShapeCache(Future.value());
      await cache.write(
        'trip-507',
        encodeTrackPoints(const [
          LatLng(54.31, 10.13),
          LatLng(53.553, 10.007),
          LatLng(50.107, 8.663),
        ], precision: kRoutedShapePrecision),
        lastDay: DateTime(2026, 7, 27),
      );
      await _pumpSheet(tester, [withRun], runShapes: cache);
      // A phone's screen, where the strip is narrower than the margins a
      // framed view keeps on a larger one.
      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpAndSettle();

      // The panel pulled up to the top, leaving a strip of the map.
      await tester.drag(find.byType(JourneyHeader), const Offset(0, -700));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show the whole route'));
      await tester.pumpAndSettle();

      final map = find.byType(FlutterMap);
      final camera = MapCamera.of(
        tester.element(
          find.descendant(of: map, matching: find.byType(PolylineLayer)).first,
        ),
      );
      final strip = tester.getRect(map).height * 0.1;
      // Not the whole world: the run from Kiel fills the strip it is seen in.
      for (final point in const [LatLng(54.31, 10.13), LatLng(50.107, 8.663)]) {
        final y = camera.latLngToScreenOffset(point).dy;
        expect(y, inInclusiveRange(0, strip));
      }
      expect(camera.zoom, greaterThan(kMinMapZoom));
      await settleTiles(tester);
    });

    /// ICE 507 placed on the map, Hamburg to Frankfurt.
    final placed = _journey.first.copyWith(
      fromLat: const Value(53.553),
      fromLon: const Value(10.007),
      toLat: const Value(50.107),
      toLon: const Value(8.663),
    );

    /// The legs' own lines, as the screen draws them.
    List<Polyline> legLines(WidgetTester tester) => [
      for (final layer in tester.widgetList<PolylineLayer>(
        find.byWidgetPredicate((w) => w is PolylineLayer),
      ))
        for (final line in layer.polylines)
          if (line.color != kJourneyRunColor) line,
    ];

    testWidgets('the leg under way is drawn in the red reserved for it', (
      tester,
    ) async {
      // 08:30 on the day: ICE 507 runs 08:00 to 09:50.
      await _pumpSheet(tester, [placed], now: DateTime(2026, 7, 27, 8, 30));

      final red = Theme.of(
        tester.element(find.byType(JourneyMap)),
      ).colorScheme.error;
      expect(legLines(tester).single.color, red);
    });

    testWidgets('a routed shape is drawn dashed, as on the trip\'s map', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        [placed],
        tracks: {
          1: const [
            TrackLine(
              id: 1,
              points: [
                LatLng(53.553, 10.007),
                LatLng(52.0, 9.5),
                LatLng(50.107, 8.663),
              ],
              source: TrackSource.routed,
            ),
          ],
        },
      );

      final line = legLines(tester).single;
      expect(line.points, hasLength(3));
      expect(line.pattern, isNot(const StrokePattern.solid()));
    });

    testWidgets('the credit for the tiles follows the panel\'s edge', (
      tester,
    ) async {
      await _pumpSheet(tester, _journey);
      final before = tester.getRect(find.byType(MapAttributionBar)).bottom;

      // Pull the panel up by its top, far enough that it snaps to the top
      // rather than back to where it opened.
      await tester.drag(find.byType(JourneyHeader), const Offset(0, -900));
      await tester.pumpAndSettle();

      final after = tester.getRect(find.byType(MapAttributionBar)).bottom;
      expect(after, lessThan(before));
      await settleTiles(tester);
    });

    testWidgets('a journey arriving the next day says so in its header', (
      tester,
    ) async {
      final overnight = _journey.last.copyWith(endDayOffset: 1);
      await _pumpSheet(tester, [overnight]);

      // In the header, and on the leg's own arrival.
      expect(find.textContaining('+1'), findsNWidgets(2));
    });

    testWidgets('is reached by its run, or by a lone leg, as a route', (
      tester,
    ) async {
      final opened = <String>[];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () =>
                        openJourney(context, tripId: 7, groupId: 1),
                    child: const Text('run'),
                  ),
                  TextButton(
                    onPressed: () => openJourney(context, tripId: 7, itemId: 3),
                    child: const Text('leg'),
                  ),
                ],
              ),
            ),
            routes: [
              GoRoute(
                path: 'trip/:id/journey',
                builder: (context, state) {
                  opened.add(state.uri.toString());
                  return const Scaffold(body: Text('journey'));
                },
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.tap(find.text('run'));
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('leg'));
      await tester.pumpAndSettle();

      expect(opened, ['/trip/7/journey?group=1', '/trip/7/journey?item=3']);
    });

    testWidgets('a journey whose legs have gone says so', (tester) async {
      await _pumpSheet(tester, const []);

      expect(
        find.text('This journey is no longer in the trip.'),
        findsOneWidget,
      );
      expect(find.byType(FlutterMap), findsNothing);
    });
  });

  group('where the button is offered', () {
    test('a grouped run of legs is a journey; a run of places is not', () {
      expect(groupHasJourney(_journey, 1), isTrue);
      expect(
        groupHasJourney([
          ItineraryItem(
            id: 9,
            tripId: 7,
            groupId: 1,
            date: DateTime(2026, 7, 27),
            sortOrder: 0,
            kind: ItemKind.place,
            endDayOffset: 0,
            chordDisplay: TrackDisplay.auto,
            title: 'Museum',
          ),
        ], 1),
        isFalse,
      );
      // A group other than the one asked about is not this journey.
      expect(groupHasJourney(_journey, 2), isFalse);
    });

    test('every leg of an ungrouped journey keeps its way in', () {
      // What ungrouping an imported connection leaves behind: two services and
      // the walk between them, all loose. Each service opens its own journey —
      // including one the feed listed no intermediate stops for, which is how
      // the first leg of a real import lost its button.
      final loose = [
        for (final item in _journey) item.copyWith(groupId: const Value(null)),
      ];
      expect(hasStandaloneJourney(loose[0]), isTrue); // stops and a trip id
      expect(hasStandaloneJourney(loose[2]), isTrue); // a trip id, no stops
      // The walk transfer is nobody's service: a journey of one walk is nothing.
      expect(hasStandaloneJourney(loose[1]), isFalse);
      // Grouped: its run's header carries the button instead.
      expect(hasStandaloneJourney(_journey.first), isFalse);
      // Hand-entered: the tile already shows everything it knows.
      expect(
        hasStandaloneJourney(
          _leg(
            id: 5,
            title: 'Bus',
            from: 'A',
            to: 'B',
            start: 60,
            end: 120,
            groupId: null,
          ),
        ),
        isFalse,
      );
    });
  });

  testWidgets('a group run carries the way into its journey on its label', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transportModesByIdProvider.overrideWith((ref) => {_train.id: _train}),
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
            body: SizedBox(
              width: 400,
              child: GroupRunTile(
                groupId: 1,
                label: null,
                items: _journey,
                accent: Colors.teal,
                costsByItem: const {},
                groupCosts: const [],
                localeName: 'en',
                onTapItem: (_) {},
                onTapCost: (_) {},
                onReorder: (_, _, _) {},
                held: null,
                onShowJourney: () => opened++,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.route));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });
}
