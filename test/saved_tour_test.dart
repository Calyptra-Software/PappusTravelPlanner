import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/route_plan.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/database/track_points.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/route_planner/application/route_engine.dart';
import 'package:travelplanner/features/route_planner/application/route_planner_providers.dart';
import 'package:travelplanner/features/route_planner/application/tour_planner_controller.dart';
import 'package:travelplanner/features/route_planner/data/saved_tour.dart';
import 'package:travelplanner/features/route_planner/data/tour_mapper.dart';
import 'package:travelplanner/features/route_planner/domain/route_profile.dart';
import 'package:travelplanner/features/route_planner/domain/routed_path.dart';
import 'package:travelplanner/features/route_planner/domain/tour.dart';
import 'package:travelplanner/features/route_planner/tour_entries.dart';

const _car = RoutedMode(RouteProfile.car);
const _foot = RoutedMode(RouteProfile.foot);
const _ski = StraightMode(TransportMode.ski);

const _home = LatLng(47, 11);
const _carPark = LatLng(47.1, 11);
const _bend = LatLng(47.15, 11.01);
const _summit = LatLng(47.2, 11);

final _day = DateTime(2026, 3, 14);

/// Home, by car to the car park, on foot over a bend to the summit (a place),
/// and on skis straight back down to the car park.
final _tour = Tour(
  waypoints: const [
    TourWaypoint(_home, name: 'Home'),
    TourWaypoint(_carPark, name: 'Car park'),
    TourWaypoint(_bend),
    TourWaypoint(_summit, name: 'Summit', isPlace: true),
    TourWaypoint(_carPark, name: 'Car park'),
  ],
  modes: const [_car, _foot, _foot, _ski],
);

/// A router's answer through [points], with a point between each pair so the
/// line is longer than its waypoints, and a height on every point.
RoutedPath _answer(List<LatLng> points, {required int minutes}) {
  final line = <LatLng>[points.first];
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1];
    final b = points[i];
    line
      ..add(
        LatLng(
          (a.latitude + b.latitude) / 2,
          (a.longitude + b.longitude) / 2 + 0.002,
        ),
      )
      ..add(b);
  }
  return RoutedPath.measured(
    points: line,
    elevations: [for (var i = 0; i < line.length; i++) 800.0 + i * 100],
    lengthMeters: 1000.0 * points.length,
    duration: Duration(minutes: minutes),
  );
}

/// A router that counts what it is asked and answers at once.
class _CountingEngine implements RouteEngine {
  final asked = <(List<LatLng>, RouteProfile)>[];

  @override
  Future<RoutedPath> route({
    required List<LatLng> waypoints,
    required RouteProfile profile,
  }) async {
    asked.add((waypoints, profile));
    return _answer(waypoints, minutes: 30);
  }
}

void main() {
  late AppDatabase db;
  late TripRepository repo;
  late int tripId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
    tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(title: 'Ski tour'),
    );
  });
  tearDown(() => db.close());

  /// Saves [_tour] the way the planner does and returns the new rows' ids.
  Future<List<int>> saveTour({String tourId = 't1', int? startMinutes}) async {
    final entries = tourEntries(_tour, {
      0: _answer(const [_home, _carPark], minutes: 45),
      1: _answer(const [_carPark, _bend, _summit], minutes: 120),
    })!;
    final mapped = tourToItems(
      entries,
      tripId: tripId,
      date: _day,
      resolveMode: builtinModeResolver(await repo.transportModes()),
      tourId: tourId,
      startMinutes: startMinutes,
    );
    return repo.insertJourney(
      tripId,
      mapped.items,
      shapes: mapped.shapes,
      elevations: mapped.elevations,
    );
  }

  Future<List<ItineraryItem>> items() =>
      (db.select(db.itineraryItems)..orderBy([
            (item) => OrderingTerm(expression: item.date),
            (item) => OrderingTerm(expression: item.sortOrder),
          ]))
          .get();

  Future<SavedTour?> open(ItineraryItem opened) async {
    final all = await items();
    final tracks = await db.select(db.tracks).get();
    return savedTourOf(
      tourItemsAround(all, opened),
      (itemId) => [
        for (final track in tracks)
          if (track.itemId == itemId) track,
      ],
    );
  }

  group('what a saved tour keeps', () {
    test(
      'each leg says how it was planned, each place which tour it is of',
      () async {
        await saveTour();

        final plans = [
          for (final item in await items()) decodeRoutePlan(item.routePlan)!,
        ];

        expect(plans.map((plan) => plan.tour).toSet(), {'t1'});
        expect(plans.map((plan) => plan.profile), ['car', 'foot', null, null]);
        expect(plans.map((plan) => plan.isLeg), [true, true, false, true]);
        expect(plans.last.straight, isTrue);
        expect(plans.last.straightMode, 'ski');
        // The walk keeps the bend it was led over, and what the router said.
        expect(plans[1].waypoints, hasLength(3));
        expect(plans[1].waypoints.last.isPlace, isTrue);
        expect(plans[1].seconds, 120 * 60);
        expect(plans[1].meters, 3000);
      },
    );

    test('a routed line is stored with its heights', () async {
      final ids = await saveTour();

      final tracks = await db.select(db.tracks).get();
      // The straight descent is its own chord and stores no line.
      expect(tracks.map((t) => t.itemId), [ids[0], ids[1]]);
      expect(tracks.every((t) => t.elevations != null), isTrue);
    });
  });

  group('reading a tour back', () {
    test('gives the tour that was saved, from any of its entries', () async {
      await saveTour(startMinutes: 8 * 60);

      for (final opened in await items()) {
        final saved = (await open(opened))!;

        expect(saved.tourId, 't1');
        expect(saved.itemIds, hasLength(4));
        expect(saved.startMinutes, 480);
        expect(saved.tour.modes, _tour.modes);
        expect(
          saved.tour.waypoints.map((w) => (w.position, w.name, w.isPlace)),
          _tour.waypoints.map((w) => (w.position, w.name, w.isPlace)),
        );
      }
    });

    test('keeps the router\'s answers, so opening asks nothing', () async {
      await saveTour();
      final saved = (await open((await items()).first))!;

      final entries = tourEntries(saved.tour, {
        for (final (index, run) in tourRuns(saved.tour).indexed)
          index: ?saved.paths[runKey(saved.tour, run)],
      });

      // Every routed run is answered: the tour is complete as it stands.
      expect(entries, isNotNull);
      final walk = entries!.whereType<TourLeg>().elementAt(1).path;
      expect(walk.duration, const Duration(minutes: 120));
      expect(walk.lengthMeters, 3000);
      expect(walk.elevations, hasLength(walk.points.length));
      expect(walk.ascentMeters, greaterThan(0));
    });

    test('an entry the planner did not make is no tour', () async {
      final id = await db
          .into(db.itineraryItems)
          .insert(
            ItineraryItemsCompanion.insert(
              tripId: tripId,
              date: _day,
              kind: ItemKind.transport,
            ),
          );
      final item = (await items()).firstWhere((item) => item.id == id);

      expect(tourItemsAround(await items(), item), isEmpty);
      expect(await open(item), isNull);
    });

    test('a copy of a leg on the same day is not part of the tour', () async {
      final ids = await saveTour();
      final copyId = await repo.duplicateItem(ids.first, day: _day);
      final all = await items();

      final saved = (await open(all.firstWhere((i) => i.id == ids.first)))!;
      expect(saved.itemIds, ids);

      // And the copy, opened, is a tour of its own leg only.
      final copy = (await open(all.firstWhere((i) => i.id == copyId)))!;
      expect(copy.itemIds, [copyId]);
      expect(copy.tour.waypoints, hasLength(2));
    });

    test('a leg moved to another day leaves the tour in two', () async {
      final ids = await saveTour();
      await repo.moveItem(ids.last, day: DateTime(2026, 3, 15));
      final all = await items();

      final first = (await open(all.firstWhere((i) => i.id == ids.first)))!;
      expect(first.itemIds, ids.take(3));

      final moved = (await open(all.firstWhere((i) => i.id == ids.last)))!;
      expect(moved.itemIds, [ids.last]);
    });

    test('a profile this version does not know cannot be opened', () async {
      final ids = await saveTour();
      final leg = (await items()).firstWhere((i) => i.id == ids.first);
      final plan = decodeRoutePlan(leg.routePlan)!;
      await (db.update(
        db.itineraryItems,
      )..where((i) => i.id.equals(leg.id))).write(
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
      );

      expect(await open((await items()).first), isNull);
    });

    test('a leg whose line was removed is asked about again', () async {
      final ids = await saveTour();
      await repo.deleteTracksForItem(ids.first);

      final saved = (await open((await items()).first))!;
      final runs = tourRuns(saved.tour);

      expect(saved.paths.containsKey(runKey(saved.tour, runs[0])), isFalse);
      expect(saved.paths.containsKey(runKey(saved.tour, runs[1])), isTrue);
    });
  });

  group('the planner opened on a saved tour', () {
    late _CountingEngine engine;
    late ProviderContainer container;

    Future<SavedTour> openInPlanner() async {
      final saved = (await open((await items()).first))!;
      engine = _CountingEngine();
      container = ProviderContainer(
        overrides: [
          routeEngineProvider.overrideWithValue(engine),
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);
      container.listen(tourPlannerProvider(saved), (_, _) {});
      // Past the look for runs that have no answer.
      await Future<void>.delayed(Duration.zero);
      return saved;
    }

    test('shows the tour complete and asks the router nothing', () async {
      await saveTour();
      final saved = await openInPlanner();

      final state = container.read(tourPlannerProvider(saved));

      expect(engine.asked, isEmpty);
      expect(state.entries, hasLength(4));
      expect(state.mode, _ski, reason: 'goes on as the tour ended');
    });

    test('asks only about a leg whose line is gone', () async {
      final ids = await saveTour();
      await repo.deleteTracksForItem(ids.first);
      final saved = await openInPlanner();
      await Future<void>.delayed(Duration.zero);

      expect(engine.asked.single.$2, RouteProfile.car);
      expect(container.read(tourPlannerProvider(saved)).entries, isNotNull);
    });

    test(
      'saving keeps the entries that stayed, in their slot and group',
      () async {
        final ids = await saveTour();
        // Something planned for after the tour, which must stay after it.
        final dinner = await repo.addItem(
          ItineraryItemsCompanion.insert(
            tripId: tripId,
            date: _day,
            kind: ItemKind.place,
            title: const Value('Dinner'),
            sortOrder: Value(await repo.nextSortOrder(tripId, _day)),
          ),
        );
        final group = (await items()).first.groupId;
        expect(group, isNotNull);
        final saved = await openInPlanner();
        final planner = container.read(tourPlannerProvider(saved).notifier);

        // Without the ski descent: the tour now ends on the summit.
        planner.removeWaypoint(4);
        final newIds = await planner.save(tripId: tripId, date: _day);

        // The drive, the walk and the summit are the rows they were; the
        // descent is gone.
        expect(newIds, ids.take(3));
        final after = await items();
        expect(after.map((i) => i.id), [...ids.take(3), dinner]);
        expect(after.take(3).map((i) => i.groupId).toSet(), {group});
        expect(
          after.take(3).map((i) => decodeRoutePlan(i.routePlan)!.tour).toSet(),
          {'t1'},
        );
        // Each routed leg holds one computed line again, with its heights.
        final tracks = await db.select(db.tracks).get();
        expect(tracks.map((t) => t.itemId), [ids[0], ids[1]]);
        expect(tracks.every((t) => t.elevations != null), isTrue);
        expect(engine.asked, isEmpty, reason: 'nothing new was routed');
      },
    );

    test('a kept entry keeps what was hung on it', () async {
      final ids = await saveTour(startMinutes: 8 * 60);
      // A note and an actual time on the walk, a recording beside its route,
      // a cost on it, and a note on the summit.
      await (db.update(
        db.itineraryItems,
      )..where((i) => i.id.equals(ids[1]))).write(
        const ItineraryItemsCompanion(
          notes: Value('Icy above the hut'),
          actualStartMinutes: Value(9 * 60),
        ),
      );
      await (db.update(db.itineraryItems)..where((i) => i.id.equals(ids[2])))
          .write(const ItineraryItemsCompanion(notes: Value('Cairn')));
      await db.trackDao.addTracks(ids[1], [
        (points: const [_carPark, _summit], name: 'walked'),
      ], source: TrackSource.recorded);
      await db
          .into(db.costs)
          .insert(
            CostsCompanion.insert(
              itemId: Value(ids[1]),
              amountMinor: 500,
              currency: (await db.select(db.currencies).get()).first.id,
              reason: 'Toll',
            ),
          );
      final saved = await openInPlanner();
      final planner = container.read(tourPlannerProvider(saved).notifier);

      // The bend is moved: the walk is still the walk.
      planner.moveWaypoint(2, const LatLng(47.16, 11.02));
      await Future<void>.delayed(Duration.zero);
      await planner.save(tripId: tripId, date: _day);

      final walk = (await items()).firstWhere((i) => i.id == ids[1]);
      expect(walk.notes, 'Icy above the hut');
      expect(walk.actualStartMinutes, 9 * 60);
      // No start time given: the planned times stay as they were.
      expect(walk.startMinutes, 8 * 60 + 45);
      // The new route through the moved bend replaced the old one; the
      // recording stays beside it.
      final waypoints = decodeRoutePlan(walk.routePlan)!.waypoints;
      expect(waypoints[1].lat, 47.16);
      final tracks = await (db.select(
        db.tracks,
      )..where((t) => t.itemId.equals(ids[1]))).get();
      expect(
        tracks.map((t) => t.source).toList()..sort((a, b) => a.index - b.index),
        [TrackSource.recorded, TrackSource.routed],
      );
      expect((await items()).firstWhere((i) => i.id == ids[2]).notes, 'Cairn');
      expect((await db.select(db.costs).getSingle()).itemId, ids[1]);
    });

    test(
      'a line drawn by hand is stored as drawn, and redrawn on save',
      () async {
        final ids = await saveTour();
        final saved = await openInPlanner();
        final planner = container.read(tourPlannerProvider(saved).notifier);

        // A bend in the ski descent: three points, so a line of its own.
        planner.insertWaypoint(3, const LatLng(47.15, 11.02));
        await planner.save(tripId: tripId, date: _day);

        final lines = await (db.select(
          db.tracks,
        )..where((t) => t.itemId.equals(ids[3]))).get();
        expect(lines.single.source, TrackSource.drawn);
        expect(decodeTrackPoints(lines.single.points), hasLength(3));

        // Saved again without the bend: the drawn line goes with it.
        final again = (await open((await items()).first))!;
        container.listen(tourPlannerProvider(again), (_, _) {});
        final second = container.read(tourPlannerProvider(again).notifier);
        second.removeWaypoint(4);
        await second.save(tripId: tripId, date: _day);
        expect(
          await (db.select(
            db.tracks,
          )..where((t) => t.itemId.equals(ids[3]))).get(),
          isEmpty,
        );
      },
    );

    test(
      'a start time given rewrites the planned times of kept entries',
      () async {
        final ids = await saveTour(startMinutes: 8 * 60);
        final saved = await openInPlanner();

        await container
            .read(tourPlannerProvider(saved).notifier)
            .save(tripId: tripId, date: _day, startMinutes: 6 * 60);

        final drive = (await items()).firstWhere((i) => i.id == ids[0]);
        expect((drive.startMinutes, drive.endMinutes), (360, 405));
      },
    );

    test(
      'a cost on an entry the tour no longer has moves to its group',
      () async {
        final ids = await saveTour();
        await db
            .into(db.costs)
            .insert(
              CostsCompanion.insert(
                itemId: Value(ids.last),
                amountMinor: 1200,
                currency: (await db.select(db.currencies).get()).first.id,
                reason: 'Lift pass',
              ),
            );
        final saved = await openInPlanner();
        final planner = container.read(tourPlannerProvider(saved).notifier);

        planner.removeWaypoint(4);
        await planner.save(tripId: tripId, date: _day);

        final cost = await db.select(db.costs).getSingle();
        expect(cost.amountMinor, 1200);
        expect(cost.itemId, isNull, reason: 'moved onto the group');
        expect(cost.groupId, (await items()).first.groupId);
      },
    );

    test(
      'a name changed in the entry form is what the planner shows',
      () async {
        final ids = await saveTour();
        await (db.update(db.itineraryItems)..where((i) => i.id.equals(ids[2])))
            .write(const ItineraryItemsCompanion(title: Value('Gipfelkreuz')));
        await (db.update(db.itineraryItems)..where((i) => i.id.equals(ids[0])))
            .write(const ItineraryItemsCompanion(fromLocation: Value('Hotel')));

        final saved = (await open((await items()).first))!;

        expect(saved.tour.waypoints.first.name, 'Hotel');
        expect(saved.tour.waypoints[3].name, 'Gipfelkreuz');
      },
    );

    test('the saved tour can be opened again afterwards', () async {
      await saveTour();
      final saved = await openInPlanner();
      await container
          .read(tourPlannerProvider(saved).notifier)
          .save(tripId: tripId, date: _day, startMinutes: 7 * 60);

      final again = (await open((await items()).last))!;

      expect(again.itemIds, hasLength(4));
      expect(again.startMinutes, 420);
      expect(again.tour.modes, _tour.modes);
    });
  });

  group('keptEntryIds', () {
    // A saved walk from 0 over the hut (1, a place) to 2: legs (0, 1) and
    // (1, 2) and the hut's place entry. A waypoint without a name or a place
    // mark only shapes a leg, so the cases below name what must end one.
    SavedTour saved() => SavedTour(
      tourId: 't1',
      itemIds: const [10, 11, 12],
      groupId: 5,
      tour: Tour(
        waypoints: const [
          TourWaypoint(_home, key: 0),
          TourWaypoint(_carPark, name: 'Hut', isPlace: true, key: 1),
          TourWaypoint(_summit, key: 2),
        ],
        modes: const [_foot, _foot],
      ),
      paths: const {},
      legItems: const {(0, 1): 10, (1, 2): 12},
      placeItems: const {1: 11},
    );

    List<int?> kept(List<TourWaypoint> waypoints, List<SectionMode> modes) =>
        keptEntryIds(
          tourEntries(Tour(waypoints: waypoints, modes: modes), const {})!,
          saved(),
        );

    // Straight sections, so the entries need no router.
    const walk = StraightMode(TransportMode.walk);

    test('an unchanged tour keeps every entry', () {
      expect(
        kept(
          const [
            TourWaypoint(_home, key: 0),
            TourWaypoint(_carPark, name: 'Hut', isPlace: true, key: 1),
            TourWaypoint(_summit, key: 2),
          ],
          const [walk, walk],
        ),
        [10, 11, 12],
      );
    });

    test('a moved and renamed place is the same place', () {
      expect(
        kept(
          const [
            TourWaypoint(_home, key: 0),
            TourWaypoint(_bend, name: 'Upper hut', isPlace: true, key: 1),
            TourWaypoint(_summit, key: 2),
          ],
          const [walk, walk],
        ),
        [10, 11, 12],
      );
    });

    test('a leg split at a new point keeps its row for the first half', () {
      expect(
        kept(
          const [
            TourWaypoint(_home, key: 0),
            TourWaypoint(_carPark, name: 'Hut', isPlace: true, key: 1),
            TourWaypoint(_bend, name: 'Spring'),
            TourWaypoint(_summit, key: 2),
          ],
          const [walk, walk, walk],
        ),
        [10, 11, 12, null],
      );
    });

    test('a reorder keeps the places but not the legs it rearranged', () {
      expect(
        kept(
          const [
            TourWaypoint(_home, key: 0),
            TourWaypoint(_summit, name: 'Summit', key: 2),
            TourWaypoint(_carPark, name: 'Hut', isPlace: true, key: 1),
          ],
          const [walk, walk],
        ),
        [null, null, 11],
      );
    });

    test('points set since are new, and a removed place is not kept', () {
      expect(
        kept(
          const [
            TourWaypoint(_home, key: 0),
            TourWaypoint(_carPark, name: 'Hut', key: 1),
            TourWaypoint(_summit, name: 'Summit', key: 2),
            TourWaypoint(_bend),
          ],
          const [walk, walk, walk],
        ),
        [10, 12, null],
      );
    });
  });
}
