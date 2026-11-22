import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/route_plan.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/route_planner/application/route_planner_providers.dart';
import 'package:travelplanner/features/route_planner/application/ski_router.dart';
import 'package:travelplanner/features/route_planner/application/tour_planner_controller.dart';
import 'package:travelplanner/features/route_planner/data/saved_tour.dart';
import 'package:travelplanner/features/route_planner/data/tour_mapper.dart';
import 'package:travelplanner/features/route_planner/domain/piste_difficulty.dart';
import 'package:travelplanner/features/route_planner/domain/routed_path.dart';
import 'package:travelplanner/features/route_planner/domain/tour.dart';
import 'package:travelplanner/features/route_planner/presentation/route_planner_screen.dart';
import 'package:travelplanner/features/route_planner/tour_entries.dart';
import 'package:travelplanner/l10n/app_localizations.dart';
import 'support/terrain_overrides.dart';

const _ski = SkiMode(PisteDifficulty.intermediate);

String _english(PisteDifficulty difficulty) =>
    pisteColorName(lookupAppLocalizations(const Locale('en')), difficulty);

LatLng _p(int i) => LatLng(47 + i / 100, 11);

/// The valley, a point somebody set on the way, and the hut at the end.
Tour _tour({int bend = 3}) => Tour(
  waypoints: [
    TourWaypoint(_p(0), name: 'Valley'),
    TourWaypoint(_p(bend)),
    TourWaypoint(_p(6), name: 'Hut'),
  ],
  modes: const [_ski, _ski],
);

/// A ski day through seven points: a chairlift to the top station, a descent,
/// a drag lift of two points, and a last descent to the hut. [reached] says
/// where along it each of the three waypoints was passed.
RoutedPath _day({
  List<int> reached = const [0, 3, 6],
  String secondPiste = 'Piste 2',
  List<double>? elevations,
}) => RoutedPath(
  points: [for (var i = 0; i <= 6; i++) _p(i)],
  elevations: elevations,
  lengthMeters: 6000,
  duration: const Duration(minutes: 40),
  segments: [
    const PathSegment(
      start: 0,
      end: 2,
      kind: SegmentKind.lift,
      liftMode: TransportMode.chairLift,
      name: 'Sonnenbahn',
      fromName: 'Tal',
      toName: 'Berg',
      lengthMeters: 2000,
      duration: Duration(minutes: 10),
    ),
    const PathSegment(
      start: 2,
      end: 4,
      kind: SegmentKind.descent,
      name: 'Piste 1',
      fromName: 'Berg',
      lengthMeters: 2000,
      duration: Duration(minutes: 12),
      pistes: [
        PisteStretch(name: 'Piste 1', difficulty: PisteDifficulty.intermediate),
      ],
    ),
    const PathSegment(
      start: 4,
      end: 5,
      kind: SegmentKind.lift,
      liftMode: TransportMode.dragLift,
      name: 'Schlepper',
      lengthMeters: 1000,
      duration: Duration(minutes: 8),
    ),
    PathSegment(
      start: 5,
      end: 6,
      kind: SegmentKind.descent,
      name: secondPiste,
      lengthMeters: 1000,
      duration: const Duration(minutes: 10),
      pistes: [
        for (final name in secondPiste.split(', '))
          PisteStretch(name: name, difficulty: PisteDifficulty.easy),
      ],
    ),
  ],
  waypointIndices: reached,
);

/// Answers a section with its part of [_day]: up and down to the bend, or on
/// from the bend over the drag lift to wherever the section ends.
class _FakeSkiRouter implements SkiRouter {
  final asked = <List<LatLng>>[];
  String secondPiste = 'Piste 2';

  @override
  Future<RoutedPath> route({
    required List<LatLng> waypoints,
    required PisteDifficulty maxDifficulty,
  }) async {
    asked.add(waypoints);
    final day = _day(secondPiste: secondPiste);
    final [ride, descent, drag, last] = day.segments!;
    if (waypoints.first == _p(0)) {
      return RoutedPath(
        points: day.points.sublist(0, 4),
        lengthMeters: 3000,
        duration: const Duration(minutes: 16),
        segments: [ride, _cut(descent, end: 3, minutes: 6)],
        waypointIndices: const [0, 3],
      );
    }
    return RoutedPath(
      points: [...day.points.sublist(3, 6), waypoints.last],
      lengthMeters: 3000,
      duration: const Duration(minutes: 24),
      segments: [
        _cut(descent, start: 0, end: 1, minutes: 6),
        _cut(drag, start: 1, end: 2),
        _cut(last, start: 2, end: 3),
      ],
      waypointIndices: const [0, 3],
    );
  }

  /// [segment] with other ends, and other minutes where given.
  static PathSegment _cut(
    PathSegment segment, {
    int? start,
    required int end,
    int? minutes,
  }) => PathSegment(
    start: start ?? segment.start,
    end: end,
    kind: segment.kind,
    liftMode: segment.liftMode,
    name: segment.name,
    fromName: segment.fromName,
    toName: segment.toName,
    lengthMeters: segment.lengthMeters,
    duration: minutes == null ? segment.duration : Duration(minutes: minutes),
    pistes: segment.pistes,
  );

  @override
  Future<void> forget() async {}
}

void main() {
  group('a ski run laid out', () {
    test('is a leg per ride and per descent, under its own mode', () {
      final legs = tourEntries(_tour(), {0: _day()})!.cast<TourLeg>();

      expect(legs.map((leg) => leg.title), [
        'Sonnenbahn',
        'Piste 1',
        'Schlepper',
        'Piste 2',
      ]);
      expect(legs.map((leg) => leg.transportMode), [
        TransportMode.chairLift,
        TransportMode.ski,
        TransportMode.dragLift,
        TransportMode.ski,
      ]);
      expect(legs.map((leg) => leg.part!.index), [0, 1, 2, 3]);
      expect(legs.map((leg) => leg.path.points.length), [3, 3, 2, 2]);
      expect(legs.map((leg) => leg.path.duration!.inMinutes), [10, 12, 8, 10]);
    });

    test('meets at points the router chose, named after the station', () {
      final legs = tourEntries(_tour(), {0: _day()})!.cast<TourLeg>();

      expect(legs.first.from.name, 'Valley');
      expect(legs.last.to.name, 'Hut');
      final top = legs[0].to;
      expect(identical(top, legs[1].from), isTrue);
      expect((top.byRouter, top.name, top.position), (true, 'Berg', _p(2)));
      expect(legs[2].from.byRouter, isTrue);
      expect(legs[2].from.name, isNull);
    });

    test('a walk is filed under walking, untitled', () {
      final walk = RoutedPath(
        points: [_p(0), _p(6)],
        lengthMeters: 300,
        segments: const [
          PathSegment(
            start: 0,
            end: 1,
            kind: SegmentKind.walk,
            lengthMeters: 300,
            duration: Duration(minutes: 6),
          ),
        ],
      );
      final tour = Tour(
        waypoints: [TourWaypoint(_p(0)), TourWaypoint(_p(6))],
        modes: const [_ski],
      );

      final leg = tourEntries(tour, {0: walk})!.single as TourLeg;

      expect(leg.transportMode, TransportMode.walk);
      expect(leg.title, isNull);
    });

    test('without the router\'s word a waypoint rides in the last leg', () {
      final legs = tourEntries(_tour(), {
        0: RoutedPath(
          points: _day().points,
          lengthMeters: 6000,
          segments: _day().segments,
        ),
      })!.cast<TourLeg>();

      expect(legs.last.waypoints.map((w) => w.position), [_p(5), _p(3), _p(6)]);
    });

    test('carries each of the user\'s waypoints in exactly one leg', () {
      // The bend is passed inside the first descent.
      final inside = tourEntries(_tour(), {0: _day()})!.cast<TourLeg>();
      expect(inside[1].waypoints.map((w) => w.position), [_p(2), _p(3), _p(4)]);

      // Passed where the drag lift starts, it is where those legs meet.
      final atStart = tourEntries(_tour(bend: 4), {
        0: _day(reached: [0, 4, 6]),
      })!.cast<TourLeg>();
      expect(atStart[1].to.byRouter, isFalse);
      expect(identical(atStart[1].to, atStart[2].from), isTrue);
      expect(atStart.map((leg) => leg.waypoints.length), [2, 2, 2, 2]);
    });
  });

  group('a ski run saved', () {
    late AppDatabase db;
    late TripRepository repo;
    late int tripId;
    final day = DateTime(2026, 2, 7);

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = TripRepository(db);
      tripId = await db.tripDao.createTrip(
        TripsCompanion.insert(title: 'Ski day'),
      );
    });
    tearDown(() => db.close());

    Future<List<int>> save({
      String secondPiste = 'Piste 2',
      List<double>? elevations,
    }) async {
      final mapped = tourToItems(
        tourEntries(_tour(), {
          0: _day(secondPiste: secondPiste, elevations: elevations),
        })!,
        tripId: tripId,
        date: day,
        resolveMode: builtinModeResolver(await repo.transportModes()),
        tourId: 't1',
        startMinutes: 9 * 60,
        pisteColor: _english,
      );
      return repo.insertJourney(
        tripId,
        mapped.items,
        shapes: mapped.shapes,
        elevations: mapped.elevations,
        sources: mapped.sources,
      );
    }

    Future<List<ItineraryItem>> items() => (db.select(
      db.itineraryItems,
    )..orderBy([(i) => OrderingTerm(expression: i.sortOrder)])).get();

    Future<SavedTour?> open() async {
      final all = await items();
      final tracks = await db.select(db.tracks).get();
      return savedTourOf(
        tourItemsAround(all, all.first),
        (itemId) => [
          for (final track in tracks)
            if (track.itemId == itemId) track,
        ],
      );
    }

    test('writes the legs with their names, modes and plans', () async {
      await save();
      final rows = await items();
      final modes = await repo.transportModes();
      String? keyOf(int? id) =>
          modes.where((m) => m.id == id).firstOrNull?.builtinKey;

      expect(rows.map((r) => r.title), [
        'Sonnenbahn',
        'Piste 1',
        'Schlepper',
        'Piste 2',
      ]);
      expect(rows.map((r) => keyOf(r.mode)), [
        'chairLift',
        'ski',
        'dragLift',
        'ski',
      ]);
      expect(rows.map((r) => (r.fromLocation, r.toLocation)), [
        ('Valley', 'Berg'),
        ('Berg', null),
        (null, null),
        (null, 'Hut'),
      ]);
      // Timed one after the other from nine.
      expect(rows.map((r) => r.startMinutes), [540, 550, 562, 570]);
      // A descent's notes say how hard it is.
      expect(rows.map((r) => r.notes), [null, 'Red', null, 'Blue']);
      final plans = [for (final r in rows) decodeRoutePlan(r.routePlan)!];
      expect(plans.map((p) => p.ski).toSet(), {'intermediate'});
      expect(plans.map((p) => p.part), [
        'chairLift',
        'descent',
        'dragLift',
        'descent',
      ]);
      expect(plans[1].waypoints.map((w) => w.byRouter), [true, false, true]);
      // The drag lift is two points, the chord its leg draws anyway.
      final tracks = await db.select(db.tracks).get();
      expect(tracks.map((t) => t.itemId), [rows[0].id, rows[1].id]);
    });

    test('reads back as the tour it was, with its legs', () async {
      await save();

      final saved = (await open())!;

      expect(saved.tour.modes, [_ski, _ski]);
      expect(saved.tour.waypoints.map((w) => (w.position, w.name)), [
        (_p(0), 'Valley'),
        (_p(3), null),
        (_p(6), 'Hut'),
      ]);
      final run = tourRuns(saved.tour).single;
      final path = saved.paths[runKey(saved.tour, run)]!;
      expect(path.points, [for (var i = 0; i <= 6; i++) _p(i)]);
      expect(path.waypointIndices, [0, 3, 6]);
      final legs = tourEntries(saved.tour, {0: path})!.cast<TourLeg>();
      expect(legs.map((leg) => leg.title), [
        'Sonnenbahn',
        'Piste 1',
        'Schlepper',
        'Piste 2',
      ]);
      expect(legs.map((leg) => leg.transportMode), [
        TransportMode.chairLift,
        TransportMode.ski,
        TransportMode.dragLift,
        TransportMode.ski,
      ]);
      expect(legs[1].from.name, 'Berg');
      expect(path.duration, const Duration(minutes: 40));
    });

    test('reads back with its heights, a lift of two points too', () async {
      const heights = [1000.0, 1300.0, 1600.0, 1400.0, 1200.0, 1500.0, 1100.0];
      await save(elevations: heights);

      // The drag lift is two points, kept for the heights of its ends.
      final tracks = await db.select(db.tracks).get();
      expect(tracks, hasLength(4));
      final saved = (await open())!;
      final path =
          saved.paths[runKey(saved.tour, tourRuns(saved.tour).single)]!;

      expect(path.elevations, heights);
      expect(path.ascentMeters, 900);
      expect(path.descentMeters, 800);
      final legs = tourEntries(saved.tour, {0: path})!.cast<TourLeg>();
      expect(legs[2].path.elevations, [1200, 1500]);
    });

    test('a grade this version does not know cannot be opened', () async {
      await save();
      final row = (await items()).first;
      final plan = decodeRoutePlan(row.routePlan)!;
      await (db.update(
        db.itineraryItems,
      )..where((i) => i.id.equals(row.id))).write(
        ItineraryItemsCompanion(
          routePlan: Value(
            encodeRoutePlan(
              RoutePlan(
                tour: plan.tour,
                ski: 'double-black',
                part: plan.part,
                waypoints: plan.waypoints,
              ),
            ),
          ),
        ),
      );

      expect(await open(), isNull);
    });

    group('in the planner', () {
      late _FakeSkiRouter router;
      late ProviderContainer container;

      Future<(SavedTour, TourPlannerController)> openInPlanner() async {
        final saved = (await open())!;
        router = _FakeSkiRouter();
        container = ProviderContainer(
          overrides: [
            skiRouterProvider.overrideWithValue(router),
            noRememberedPaces,
            databaseProvider.overrideWithValue(db),
          ],
        );
        addTearDown(container.dispose);
        container.listen(tourPlannerProvider(saved), (_, _) {});
        await Future<void>.delayed(Duration.zero);
        return (saved, container.read(tourPlannerProvider(saved).notifier));
      }

      test('opens complete, asks nothing, and saves onto its rows', () async {
        final ids = await save();
        final (saved, planner) = await openInPlanner();

        expect(router.asked, isEmpty);
        expect(
          container.read(tourPlannerProvider(saved)).entries,
          hasLength(4),
        );
        expect(await planner.save(tripId: tripId, date: day), ids);
        expect((await items()).map((r) => r.id), ids);
      });

      test('a descent down many pistes is titled with two of them', () async {
        final ids = await save(secondPiste: 'Piste 2, Piste 3, Piste 4');
        final last = (await items()).last;
        expect(last.title, 'Piste 2, Piste 3 +1');
        expect(last.notes, 'Piste 2, Piste 3, Piste 4: Blue');

        // Asked again, the router names all three: still the descent saved
        // under the shorter title.
        final (_, planner) = await openInPlanner();
        router.secondPiste = 'Piste 2, Piste 3, Piste 4';
        planner.moveWaypoint(2, const LatLng(47.0601, 11));
        await Future<void>.delayed(Duration.zero);
        expect(router.asked, isNotEmpty);
        expect(await planner.save(tripId: tripId, date: day), ids);
        expect((await items()).last.title, 'Piste 2, Piste 3 +1');
      });

      test('a section on foot keeps the tour\'s grade for the next', () async {
        await save();
        final (saved, planner) = await openInPlanner();

        planner.selectMode(const StraightMode());

        expect(
          container.read(tourPlannerProvider(saved)).skiDifficulty,
          PisteDifficulty.intermediate,
        );
      });

      test('a leg the new way changed is a new entry', () async {
        final ids = await save();
        final (saved, planner) = await openInPlanner();
        router.secondPiste = 'Umfahrung';

        // Moving the hut asks the router again.
        planner.moveWaypoint(2, _p(6));
        planner.moveWaypoint(2, const LatLng(47.0601, 11));
        await Future<void>.delayed(Duration.zero);
        final newIds = (await planner.save(tripId: tripId, date: day))!;

        // A saved run's line is the run's, not its sections': moving a
        // point asks about every section of the run.
        expect(router.asked, hasLength(2));
        expect(newIds.take(3), ids.take(3));
        expect(newIds.last, isNot(ids.last));
        expect((await items()).last.title, 'Umfahrung');
      });

      test(
        'a kept descent keeps its notes, a new one is told its grade',
        () async {
          await save();
          final second = (await items())[1];
          await (db.update(db.itineraryItems)
                ..where((i) => i.id.equals(second.id)))
              .write(const ItineraryItemsCompanion(notes: Value('Wax first')));
          final (_, planner) = await openInPlanner();
          router.secondPiste = 'Umfahrung';

          planner.moveWaypoint(2, const LatLng(47.0601, 11));
          await Future<void>.delayed(Duration.zero);
          await planner.save(tripId: tripId, date: day, pisteColor: _english);

          expect((await items()).map((r) => r.notes), [
            null,
            'Wax first',
            null,
            'Blue',
          ]);
        },
      );
    });
  });

  test('a route plan carries a ski run\'s grade, part and router points', () {
    final plan = decodeRoutePlan(
      encodeRoutePlan(
        const RoutePlan(
          tour: 't',
          ski: 'easy',
          part: 'gondola',
          waypoints: [
            RoutePlanPoint(lat: 47, lon: 11),
            RoutePlanPoint(lat: 47.1, lon: 11, byRouter: true),
          ],
        ),
      ),
    )!;

    expect((plan.ski, plan.part), ('easy', 'gondola'));
    expect(plan.waypoints.map((w) => w.byRouter), [false, true]);
    expect(plan.reversed.ski, 'easy');
    expect(plan.reversed.waypoints.first.byRouter, isTrue);
  });
}
