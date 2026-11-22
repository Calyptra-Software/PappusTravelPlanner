import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/map/elevation.dart';
import 'package:travelplanner/features/map/map_features.dart' show lineLength;
import 'package:travelplanner/features/route_planner/application/route_engine.dart';
import 'package:travelplanner/features/route_planner/application/route_planner_providers.dart';
import 'package:travelplanner/features/route_planner/application/terrain_heights.dart';
import 'package:travelplanner/features/route_planner/application/tour_planner_controller.dart';
import 'package:travelplanner/features/route_planner/domain/route_profile.dart';
import 'package:travelplanner/features/route_planner/domain/routed_path.dart';
import 'package:travelplanner/features/route_planner/domain/tour.dart';
import 'package:travelplanner/features/route_planner/tour_entries.dart';
import 'support/terrain_overrides.dart';

/// A router that records what it was asked and answers when told to.
class _FakeEngine implements RouteEngine {
  final asked = <(List<LatLng>, RouteProfile)>[];
  final _pending = <Completer<RoutedPath>>[];

  @override
  Future<RoutedPath> route({
    required List<LatLng> waypoints,
    required RouteProfile profile,
  }) {
    asked.add((waypoints, profile));
    final completer = Completer<RoutedPath>();
    _pending.add(completer);
    return completer.future;
  }

  /// Answers the oldest open request with a line through its waypoints.
  Future<void> answer() async {
    final index = asked.length - _pending.length;
    _pending
        .removeAt(0)
        .complete(
          RoutedPath(
            points: asked[index].$1,
            lengthMeters: 1000,
            duration: const Duration(minutes: 20),
          ),
        );
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> refuse(RouteEngineException error) async {
    _pending.removeAt(0).completeError(error);
    await Future<void>.delayed(Duration.zero);
  }
}

/// Terrain heights that record what they were asked and answer when told
/// to.
class _FakeHeights implements TerrainHeights {
  final asked = <List<LatLng>>[];
  final _pending = <Completer<List<double>?>>[];

  @override
  Future<List<double>?> at(List<LatLng> points) {
    asked.add(points);
    final completer = Completer<List<double>?>();
    _pending.add(completer);
    return completer.future;
  }

  /// Answers the oldest open request with [height] at each point, or with
  /// none.
  Future<void> answer(double Function(LatLng point)? height) async {
    final points = asked[asked.length - _pending.length];
    _pending
        .removeAt(0)
        .complete(height == null ? null : [for (final p in points) height(p)]);
    await Future<void>.delayed(Duration.zero);
  }
}

const _a = LatLng(47, 11);
const _b = LatLng(47.1, 11);
const _c = LatLng(47.2, 11);

void main() {
  late _FakeEngine engine;
  late ProviderContainer container;
  late AppDatabase db;

  setUp(() {
    engine = _FakeEngine();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        routeEngineProvider.overrideWithValue(engine),
        noTerrainHeights,
        databaseProvider.overrideWithValue(db),
      ],
    );
    // The screen's watch, which is what keeps an autoDispose tour alive.
    container.listen(tourPlannerProvider(null), (_, _) {});
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  TourPlannerController planner() =>
      container.read(tourPlannerProvider(null).notifier);
  TourPlannerState state() => container.read(tourPlannerProvider(null));

  test('one waypoint asks nothing, the second asks for the run', () {
    planner().addWaypoint(_a);
    expect(engine.asked, isEmpty);
    expect(state().entries, isNull);

    planner().addWaypoint(_b);

    expect(engine.asked.single.$1, [_a, _b]);
    expect(engine.asked.single.$2, RouteProfile.foot);
    expect(state().routing, isTrue);
    expect(state().entries, isNull);
  });

  test('the answer completes the tour', () async {
    planner()
      ..addWaypoint(_a)
      ..addWaypoint(_b);
    await engine.answer();

    expect(state().routing, isFalse);
    final leg = state().entries!.single as TourLeg;
    expect(leg.path.points, [_a, _b]);
  });

  test('a third waypoint asks only for the section it adds', () async {
    planner()
      ..addWaypoint(_a)
      ..addWaypoint(_b);
    await engine.answer();
    planner().addWaypoint(_c);

    expect(engine.asked.last.$1, [_b, _c]);
    // The run's line up to the new point stays the router's while it waits.
    final lines = state().linesOf(state().runs.single);
    expect(lines.map((line) => line.known), [true, false]);
    expect(state().routing, isTrue);

    await engine.answer();
    expect(state().routing, isFalse);
    final leg = state().entries!.single as TourLeg;
    expect(leg.path.points, [_a, _b, _c]);
    expect(leg.path.lengthMeters, 2000);
    expect(leg.path.duration, const Duration(minutes: 40));
  });

  test('a change of mode asks only for the new run', () async {
    planner()
      ..selectMode(const RoutedMode(RouteProfile.car))
      ..addWaypoint(_a)
      ..addWaypoint(_b);
    await engine.answer();
    planner()
      ..selectMode(const RoutedMode(RouteProfile.foot))
      ..addWaypoint(_c);

    expect(engine.asked, hasLength(2));
    expect(engine.asked.last.$1, [_b, _c]);
    expect(engine.asked.last.$2, RouteProfile.foot);
  });

  test('a straight section asks nothing and is complete at once', () {
    planner()
      ..selectMode(const StraightMode(TransportMode.ski))
      ..addWaypoint(_a)
      ..addWaypoint(_b);

    expect(engine.asked, isEmpty);
    expect(state().entries, hasLength(1));
  });

  group('the heights of a straight line', () {
    late _FakeHeights heights;
    late ProviderContainer withHeights;

    setUp(() {
      heights = _FakeHeights();
      withHeights = ProviderContainer(
        overrides: [
          routeEngineProvider.overrideWithValue(engine),
          terrainHeightsProvider.overrideWithValue(heights),
          databaseProvider.overrideWithValue(db),
        ],
      );
      withHeights.listen(tourPlannerProvider(null), (_, _) {});
    });
    tearDown(() => withHeights.dispose());

    TourPlannerController planner() =>
        withHeights.read(tourPlannerProvider(null).notifier);
    TourPlannerState state() => withHeights.read(tourPlannerProvider(null));

    test('are asked for along the line, which waits for nothing', () async {
      planner()
        ..selectMode(const StraightMode())
        ..addWaypoint(_a)
        ..addWaypoint(_b);

      expect(state().routing, isFalse);
      expect(state().entries, hasLength(1));
      final asked = heights.asked.single;
      expect(asked.first, _a);
      expect(asked.last, _b);
      // 11 km in steps of no more than 20 m.
      expect(asked.length, greaterThan(500));

      await heights.answer((point) => 1000 + (point.latitude - 47) * 10000);

      final leg = state().entries!.single as TourLeg;
      expect(leg.path.points, asked);
      expect(leg.path.elevations!.first, closeTo(1000, 1e-6));
      expect(leg.path.elevations!.last, closeTo(2000, 1e-6));
      // Counted past the threshold, so the last few meters may not count.
      expect(leg.path.ascentMeters, closeTo(1000, kClimbThresholdMeters));
      expect(leg.path.lengthMeters, closeTo(lineLength([_a, _b]), 1e-6));
      expect(engine.asked, isEmpty);
    });

    test('each section on its own, joined into the run', () async {
      planner()
        ..selectMode(const StraightMode())
        ..addWaypoint(_a)
        ..addWaypoint(_b);
      await heights.answer((_) => 500);
      planner().addWaypoint(_c);

      expect(heights.asked, hasLength(2));
      expect(heights.asked.last.first, _b);
      expect(state().entries!.single, isA<TourLeg>());
      expect((state().entries!.single as TourLeg).path.elevations, isNull);

      await heights.answer((_) => 600);

      final leg = state().entries!.single as TourLeg;
      expect(leg.path.points.first, _a);
      expect(leg.path.points.last, _c);
      expect(leg.path.elevations!.first, 500);
      expect(leg.path.elevations!.last, 600);
    });

    test(
      'that do not come leave the line as it is, asked again on retry',
      () async {
        planner()
          ..selectMode(const StraightMode())
          ..addWaypoint(_a)
          ..addWaypoint(_b);

        await heights.answer(null);

        expect(state().failure, isNull, reason: 'nothing to tell the user');
        final leg = state().entries!.single as TourLeg;
        expect(leg.path.points, [_a, _b]);
        expect(leg.path.elevations, isNull);
        planner().selectMode(const RoutedMode(RouteProfile.foot));
        expect(heights.asked, hasLength(1));

        planner().retry();

        expect(heights.asked, hasLength(2));
      },
    );
  });

  test(
    'taking a waypoint back and setting it again asks nothing twice',
    () async {
      planner()
        ..addWaypoint(_a)
        ..addWaypoint(_b);
      await engine.answer();
      planner()
        ..removeWaypoint(1)
        ..addWaypoint(_b);

      expect(engine.asked, hasLength(1));
      expect(state().entries, isNotNull);
    },
  );

  test('a refusal is reported and asked again only on retry', () async {
    planner()
      ..addWaypoint(_a)
      ..addWaypoint(_b);
    await engine.refuse(const RouteEngineException('no', statusCode: 400));

    expect(state().failure, RouteEngineFailure.noRoute);
    expect(state().routing, isFalse);
    expect(state().entries, isNull);

    planner().updateWaypoint(0, const TourWaypoint(_a, isPlace: true));
    expect(engine.asked, hasLength(1));

    planner().retry();
    expect(engine.asked, hasLength(2));
    await engine.answer();
    expect(state().failure, isNull);
    expect(state().entries, isNotNull);
  });

  test('naming a waypoint inside a run asks nothing', () async {
    planner()
      ..addWaypoint(_a)
      ..addWaypoint(_b)
      ..addWaypoint(_c);
    await engine.answer();
    await engine.answer();
    final before = engine.asked.length;

    planner().updateWaypoint(1, const TourWaypoint(_b, name: 'Hut'));

    // Each half is a section answered on its own already.
    expect(engine.asked, hasLength(before));
    expect(state().entries, hasLength(2));
  });

  test('moving a waypoint asks for its run again and keeps its name', () async {
    planner()
      ..addWaypoint(_a)
      ..addWaypoint(_b);
    await engine.answer();
    planner().updateWaypoint(1, const TourWaypoint(_b, name: 'Hut'));

    planner().moveWaypoint(1, _c);

    expect(engine.asked.last.$1, [_a, _c]);
    expect(state().tour.waypoints.last.name, 'Hut');
    expect(state().entries, isNull);
  });

  test('changing a section to another mode asks for it in that mode', () async {
    planner()
      ..addWaypoint(_a)
      ..addWaypoint(_b)
      ..addWaypoint(_c);
    await engine.answer();
    await engine.answer();

    planner().setSectionMode(1, const RoutedMode(RouteProfile.car));

    // From a to b on foot was answered when b was the tour's end.
    expect(engine.asked.last.$1, [_b, _c]);
    expect(engine.asked.last.$2, RouteProfile.car);
    expect(engine.asked, hasLength(3));
  });

  test('changing a section to a straight line asks nothing', () async {
    planner()
      ..addWaypoint(_a)
      ..addWaypoint(_b);
    await engine.answer();

    planner().setSectionMode(0, const StraightMode(TransportMode.ski));

    expect(engine.asked, hasLength(1));
    expect(state().entries, hasLength(1));
  });

  test('a point set into an answered line keeps the answer', () async {
    planner()
      ..addWaypoint(_a)
      ..addWaypoint(_c);
    await engine.answer();

    planner().insertWaypoint(0, _b);

    expect(state().tour.waypoints.map((w) => w.position), [_a, _b, _c]);
    expect(engine.asked, hasLength(1), reason: 'the way has not changed');
    expect(state().entries, hasLength(1));
  });

  test('a point set into an unanswered line is asked about with it', () async {
    planner()
      ..addWaypoint(_a)
      ..addWaypoint(_c);

    planner().insertWaypoint(0, _b);

    expect(engine.asked.skip(1).map((request) => request.$1), [
      [_a, _b],
      [_b, _c],
    ]);
  });

  test('a new order asks only for the runs it made', () async {
    planner()
      ..selectMode(const RoutedMode(RouteProfile.car))
      ..addWaypoint(_a)
      ..addWaypoint(_b)
      ..selectMode(const RoutedMode(RouteProfile.foot))
      ..addWaypoint(_c);
    await engine.answer();
    await engine.answer();

    // a -car-> b -foot-> c becomes a -foot-> c -car-> b.
    planner().reorderWaypoint(2, 1);

    expect(state().tour.waypoints.map((w) => w.position), [_a, _c, _b]);
    final asked = engine.asked.skip(2).toList();
    expect(asked.map((request) => request.$1), [
      [_a, _c],
      [_c, _b],
    ]);
    expect(asked.map((request) => request.$2), [
      RouteProfile.foot,
      RouteProfile.car,
    ]);
  });

  test('save writes the tour into the trip', () async {
    final tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(title: 'Hike'),
    );
    planner()
      ..addWaypoint(_a)
      ..addWaypoint(_b)
      ..addWaypoint(_c);
    expect(
      await planner().save(tripId: tripId, date: DateTime(2026, 3, 14)),
      isNull,
      reason: 'a run is still unanswered',
    );
    await engine.answer();
    await engine.answer();

    final ids = await planner().save(
      tripId: tripId,
      date: DateTime(2026, 3, 14),
      startMinutes: 8 * 60,
    );

    expect(ids, hasLength(1));
    final item = await db.select(db.itineraryItems).getSingle();
    expect(item.kind, ItemKind.transport);
    // Two sections of twenty minutes each.
    expect((item.startMinutes, item.endMinutes), (480, 520));
    expect((await db.select(db.tracks).getSingle()).source, TrackSource.routed);
  });

  test('a tour planned from an option is saved into that option', () async {
    final tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(title: 'Hike'),
    );
    final day = DateTime(2026, 3, 14);
    // A decision made from an entry, and a second option beside it.
    final seed = await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: day,
        kind: ItemKind.place,
      ),
    );
    final setId = await db.alternativeDao.createSetFromItem(seed);
    final option = await db.alternativeDao.addAlternative(setId);
    planner()
      ..selectMode(const StraightMode(TransportMode.ski))
      ..addWaypoint(_a)
      ..addWaypoint(_b)
      ..selectMode(const StraightMode())
      ..addWaypoint(_c);

    final ids = await planner().save(
      tripId: tripId,
      date: day,
      alternativeId: option,
    );

    final rows = await (db.select(
      db.itineraryItems,
    )..where((i) => i.id.isIn(ids!))).get();
    expect(rows, hasLength(2));
    expect(rows.map((r) => r.alternativeId).toSet(), {option});
  });
}
