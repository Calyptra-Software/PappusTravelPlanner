import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/database/track_points.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/data/database/route_plan.dart';
import 'package:travelplanner/features/route_planner/data/tour_mapper.dart';
import 'package:travelplanner/features/route_planner/domain/pace.dart';
import 'package:travelplanner/features/route_planner/domain/route_profile.dart';
import 'package:travelplanner/features/route_planner/domain/routed_path.dart';
import 'package:travelplanner/features/route_planner/domain/tour.dart';
import 'package:travelplanner/features/route_planner/tour_entries.dart';

const _car = RoutedMode(RouteProfile.car);
const _foot = RoutedMode(RouteProfile.foot);
const _bike = RoutedMode(RouteProfile.bike);
const _ski = StraightMode(TransportMode.ski);

final _day = DateTime(2026, 3, 14);

TourWaypoint _at(double lat, {String? name, bool isPlace = false}) =>
    TourWaypoint(LatLng(lat, 11), name: name, isPlace: isPlace);

TourLeg _leg(
  SectionMode mode,
  List<double> lats, {
  Duration? duration,
  String? from,
  String? to,
}) => TourLeg(
  from: _at(lats.first, name: from),
  to: _at(lats.last, name: to),
  mode: mode,
  path: RoutedPath(
    points: [for (final lat in lats) LatLng(lat, 11)],
    lengthMeters: 1000,
    duration: duration,
  ),
);

int? _resolve(TransportMode mode) => mode.index + 100;

void main() {
  group('tourToItems', () {
    test('a leg is a transport entry between its waypoints', () {
      final mapped = tourToItems(
        [
          _leg(_foot, [47, 47.05, 47.1], from: ' Car park ', to: 'Summit'),
        ],
        tripId: 7,
        date: _day,
        resolveMode: _resolve,
        tourId: 't1',
      );

      final leg = mapped.items.single;
      expect(leg.tripId.value, 7);
      expect(leg.date.value, _day);
      expect(leg.kind.value, ItemKind.transport);
      expect(leg.mode.value, TransportMode.walk.index + 100);
      expect(leg.fromLocation.value, 'Car park');
      expect(leg.toLocation.value, 'Summit');
      expect(leg.fromLat.value, 47);
      expect(leg.toLat.value, 47.1);
      expect(leg.startMinutes.value, isNull);
      expect(leg.endMinutes.value, isNull);
    });

    test('the line is packed at the precision a routed shape is read at', () {
      final mapped = tourToItems(
        [
          _leg(_foot, [47, 47.05, 47.1]),
        ],
        tripId: 7,
        date: _day,
        resolveMode: _resolve,
        tourId: 't1',
      );

      expect(
        decodeTrackPoints(
          mapped.shapes.single!,
          precision: kRoutedShapePrecision,
        ),
        const [LatLng(47, 11), LatLng(47.05, 11), LatLng(47.1, 11)],
      );
    });

    test('a line drawn by hand says so, a routed one says it was routed', () {
      final mapped = tourToItems(
        [
          _leg(_foot, [47, 47.05, 47.1]),
          TourPlace(_at(47.1, name: 'Hut', isPlace: true)),
          _leg(_ski, [47.1, 47.05, 47]),
        ],
        tripId: 7,
        date: _day,
        resolveMode: _resolve,
        tourId: 't1',
      );

      expect(mapped.sources, [
        TrackSource.routed,
        TrackSource.routed,
        TrackSource.drawn,
      ]);
    });

    test('a line of two points is the chord and is not stored', () {
      final mapped = tourToItems(
        [
          _leg(_ski, [47.1, 47]),
        ],
        tripId: 7,
        date: _day,
        resolveMode: _resolve,
        tourId: 't1',
      );

      expect(mapped.shapes, [null]);
    });

    test('a mode the user deleted, or none, leaves the leg without one', () {
      final mapped = tourToItems(
        [
          _leg(_car, [47, 47.1]),
          _leg(const StraightMode(), [47.1, 47.2]),
        ],
        tripId: 7,
        date: _day,
        resolveMode: (_) => null,
        tourId: 't1',
      );

      expect(mapped.items.map((item) => item.mode.value), [null, null]);
    });

    test('times run on from the start, through a place', () {
      final mapped = tourToItems(
        [
          _leg(_car, [47, 47.1], duration: const Duration(minutes: 45)),
          // 30 s over the half hour: an arrival is not rounded early.
          _leg(_bike, [47.1, 47.2], duration: const Duration(seconds: 1830)),
          TourPlace(_at(47.2, name: 'Summit', isPlace: true)),
          _leg(_bike, [47.2, 47.1], duration: const Duration(minutes: 20)),
        ],
        tripId: 7,
        date: _day,
        resolveMode: _resolve,
        tourId: 't1',
        startMinutes: 8 * 60,
      );

      final [drive, up, summit, down] = mapped.items;
      expect((drive.startMinutes.value, drive.endMinutes.value), (480, 525));
      expect((up.startMinutes.value, up.endMinutes.value), (525, 556));
      expect(summit.kind.value, ItemKind.place);
      expect(summit.title.value, 'Summit');
      expect(summit.lat.value, 47.2);
      expect(summit.startMinutes.value, 556);
      expect((down.startMinutes.value, down.endMinutes.value), (556, 576));
      expect(mapped.shapes, hasLength(4));
    });

    test('nothing is timed behind a leg of unknown duration', () {
      final mapped = tourToItems(
        [
          _leg(_bike, [47, 47.1], duration: const Duration(minutes: 60)),
          _leg(_ski, [47.1, 47]),
          _leg(_car, [47, 46.9], duration: const Duration(minutes: 30)),
        ],
        tripId: 7,
        date: _day,
        resolveMode: _resolve,
        tourId: 't1',
        startMinutes: 9 * 60,
      );

      final [up, ski, drive] = mapped.items;
      expect((up.startMinutes.value, up.endMinutes.value), (540, 600));
      expect((ski.startMinutes.value, ski.endMinutes.value), (600, null));
      expect((drive.startMinutes.value, drive.endMinutes.value), (null, null));
    });

    test(
      'times a leg at its pace, and keeps the router\'s time in its plan',
      () {
        final mapped = tourToItems(
          [
            // 1 km on foot: 15 min by the hiking time, whatever the router said.
            _leg(_foot, [47, 47.1], duration: const Duration(minutes: 5)),
            _leg(_bike, [47.1, 47.2], duration: const Duration(minutes: 60)),
          ],
          tripId: 7,
          date: _day,
          resolveMode: _resolve,
          tourId: 't1',
          startMinutes: 9 * 60,
          paces: {'bike': Pace.brisk},
        );

        final [walk, ride] = mapped.items;
        expect((walk.startMinutes.value, walk.endMinutes.value), (540, 555));
        // An hour at 1.2 times the speed: 50 minutes.
        expect((ride.startMinutes.value, ride.endMinutes.value), (555, 605));
        final [walkPlan, ridePlan] = [
          for (final item in mapped.items)
            decodeRoutePlan(item.routePlan.value)!,
        ];
        expect((walkPlan.seconds, walkPlan.pace), (300, null));
        expect((ridePlan.seconds, ridePlan.pace), (3600, 'brisk'));
      },
    );

    test('a leg past midnight arrives a day on and ends the timing', () {
      final mapped = tourToItems(
        [
          _leg(_car, [47, 47.1], duration: const Duration(minutes: 90)),
          _leg(_foot, [47.1, 47.2], duration: const Duration(minutes: 10)),
        ],
        tripId: 7,
        date: _day,
        resolveMode: _resolve,
        tourId: 't1',
        startMinutes: 23 * 60,
      );

      final [drive, walk] = mapped.items;
      expect((drive.startMinutes.value, drive.endMinutes.value), (1380, 30));
      expect(drive.endDayOffset.value, 1);
      expect(walk.startMinutes.value, isNull);
      expect(walk.endDayOffset.value, 0);
    });
  });

  group('a mapped tour in the database', () {
    late AppDatabase db;
    late TripRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = TripRepository(db);
    });
    tearDown(() => db.close());

    test('is written as entries with dashed, routed lines', () async {
      final tripId = await db.tripDao.createTrip(
        TripsCompanion.insert(title: 'Ski tour'),
      );
      final modes = await db.select(db.transportModes).get();
      final mapped = tourToItems(
        [
          _leg(_foot, [47, 47.05, 47.1], to: 'Summit'),
          TourPlace(_at(47.1, name: 'Summit', isPlace: true)),
          _leg(_ski, [47.1, 47]),
        ],
        tripId: tripId,
        date: _day,
        resolveMode: builtinModeResolver(modes),
        tourId: 't1',
      );

      final ids = await repo.insertJourney(
        tripId,
        mapped.items,
        shapes: mapped.shapes,
      );

      final items = await (db.select(
        db.itineraryItems,
      )..orderBy([(item) => OrderingTerm(expression: item.sortOrder)])).get();
      expect(items.map((item) => item.kind), [
        ItemKind.transport,
        ItemKind.place,
        ItemKind.transport,
      ]);
      String? key(int? modeId) =>
          modes.where((mode) => mode.id == modeId).firstOrNull?.builtinKey;
      expect(key(items.first.mode), 'walk');
      expect(key(items.last.mode), 'ski');

      final tracks = await db.select(db.tracks).get();
      expect(tracks.single.itemId, ids.first);
      expect(tracks.single.source, TrackSource.routed);
    });
  });
}
