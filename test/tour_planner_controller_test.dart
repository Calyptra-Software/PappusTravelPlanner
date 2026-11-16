import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/route_planner/application/route_engine.dart';
import 'package:travelplanner/features/route_planner/application/route_planner_providers.dart';
import 'package:travelplanner/features/route_planner/application/tour_planner_controller.dart';
import 'package:travelplanner/features/route_planner/domain/route_profile.dart';
import 'package:travelplanner/features/route_planner/domain/routed_path.dart';
import 'package:travelplanner/features/route_planner/domain/tour.dart';
import 'package:travelplanner/features/route_planner/tour_entries.dart';

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
        databaseProvider.overrideWithValue(db),
      ],
    );
    // The screen's watch, which is what keeps an autoDispose tour alive.
    container.listen(tourPlannerProvider, (_, _) {});
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  TourPlannerController planner() =>
      container.read(tourPlannerProvider.notifier);
  TourPlannerState state() => container.read(tourPlannerProvider);

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

  test('a third waypoint in the same mode asks for the whole run', () async {
    planner()
      ..addWaypoint(_a)
      ..addWaypoint(_b);
    await engine.answer();
    planner().addWaypoint(_c);

    expect(engine.asked.last.$1, [_a, _b, _c]);
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

  test(
    'naming a waypoint inside a run asks only for the half that is new',
    () async {
      planner()
        ..addWaypoint(_a)
        ..addWaypoint(_b)
        ..addWaypoint(_c);
      await engine.answer();
      await engine.answer();
      final before = engine.asked.length;

      planner().updateWaypoint(1, const TourWaypoint(_b, name: 'Hut'));

      // From a to b was answered when b was the tour's end.
      expect(engine.asked.skip(before).map((request) => request.$1), [
        [_b, _c],
      ]);
      await engine.answer();
      expect(state().entries, hasLength(2));
    },
  );

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
    expect((item.startMinutes, item.endMinutes), (480, 500));
    expect((await db.select(db.tracks).getSingle()).source, TrackSource.routed);
  });
}
