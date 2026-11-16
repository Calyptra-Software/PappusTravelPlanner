import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/route_plan.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/database/track_points.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/sharing/trip_bundle.dart';
import 'package:travelplanner/features/sharing/trip_gpx.dart';

/// A line's heights and an entry's route plan, through every way a line or an
/// entry is written, copied and carried out of the app.
void main() {
  late AppDatabase db;
  late TripRepository repo;

  const line = [LatLng(47, 11), LatLng(47.01, 11), LatLng(47.02, 11)];
  const heights = [500.0, 612.5, 580.0];
  final plan = encodeRoutePlan(
    const RoutePlan(
      tour: 't1',
      profile: 'foot',
      waypoints: [
        RoutePlanPoint(lat: 47, lon: 11, name: 'Car park'),
        RoutePlanPoint(lat: 47.02, lon: 11, name: 'Summit'),
      ],
    ),
  );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
  });
  tearDown(() => db.close());

  Future<int> makeTrip({TripKind kind = TripKind.trip}) => db.tripDao
      .createTrip(TripsCompanion.insert(title: 'Karwendel', kind: Value(kind)));

  Future<int> makeLeg(int tripId, {DateTime? date}) => db
      .into(db.itineraryItems)
      .insert(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: date ?? DateTime(2026, 5, 1),
          kind: ItemKind.transport,
          fromLocation: const Value('Car park'),
          toLocation: const Value('Summit'),
          fromLat: const Value(47),
          fromLon: const Value(11),
          toLat: const Value(47.02),
          toLon: const Value(11),
          routePlan: Value(plan),
        ),
      );

  Future<List<Track>> tracksOf(int itemId) =>
      (db.select(db.tracks)..where((t) => t.itemId.equals(itemId))).get();

  List<double>? heightsOf(Track track) => trackElevationsOrNull(
    track.elevations,
    decodeTrackPoints(track.points).length,
  );

  group('addTracks', () {
    test('stores a height for every point', () async {
      final legId = await makeLeg(await makeTrip());

      await db.trackDao.addTracks(
        legId,
        [(points: line, name: null)],
        source: TrackSource.routed,
        elevations: [heights],
      );

      expect(heightsOf((await tracksOf(legId)).single), heights);
    });

    test('a line given no heights has none', () async {
      final legId = await makeLeg(await makeTrip());

      await db.trackDao.addTracks(legId, [(points: line, name: null)]);

      expect((await tracksOf(legId)).single.elevations, isNull);
    });

    test('heights that do not number the points are left out', () async {
      final legId = await makeLeg(await makeTrip());

      await db.trackDao.addTracks(
        legId,
        [(points: line, name: null)],
        elevations: [
          const [500, 600],
        ],
      );

      expect((await tracksOf(legId)).single.elevations, isNull);
    });

    test('only the lines that came with heights get them', () async {
      final legId = await makeLeg(await makeTrip());

      await db.trackDao.addTracks(
        legId,
        [(points: line, name: 'a'), (points: line, name: 'b')],
        elevations: [null, heights],
      );

      final tracks = await tracksOf(legId);
      expect(tracks.map(heightsOf), [null, heights]);
    });
  });

  group('a routed shape', () {
    test('is written with the heights given beside it', () async {
      final tripId = await makeTrip();

      final ids = await repo.insertJourney(
        tripId,
        [
          ItineraryItemsCompanion.insert(
            tripId: tripId,
            date: DateTime(2026, 5, 1),
            kind: ItemKind.transport,
          ),
        ],
        shapes: [encodeTrackPoints(line, precision: kRoutedShapePrecision)],
        elevations: [heights],
      );

      final track = (await tracksOf(ids.single)).single;
      expect(track.source, TrackSource.routed);
      expect(heightsOf(track), heights);
    });
  });

  group('a copy', () {
    test('takes the heights and the route plan', () async {
      final legId = await makeLeg(await makeTrip());
      await db.trackDao.addTracks(
        legId,
        [(points: line, name: null)],
        elevations: [heights],
      );

      final copyId = await repo.duplicateItem(legId, day: DateTime(2026, 5, 2));

      expect(heightsOf((await tracksOf(copyId)).single), heights);
      final copy = await (db.select(
        db.itineraryItems,
      )..where((i) => i.id.equals(copyId))).getSingle();
      expect(copy.routePlan, plan);
    });

    test(
      'running the other way turns the heights and the plan round',
      () async {
        final routineId = await makeTrip(kind: TripKind.routine);
        final legId = await makeLeg(routineId, date: kRoutineAnchorDay);
        await db.trackDao.addTracks(
          legId,
          [(points: line, name: null)],
          elevations: [heights],
        );

        final backId = await db.routineDao.duplicateReversed(
          routineId,
          title: 'Back',
        );

        final back =
            (await db.itineraryDao.watchItemsForTrip(backId).first).single;
        final track = (await tracksOf(back.id)).single;
        expect(decodeTrackPoints(track.points).first, line.last);
        expect(heightsOf(track), heights.reversed.toList());
        expect(decodeRoutePlan(back.routePlan)!.waypoints.map((p) => p.name), [
          'Summit',
          'Car park',
        ]);
      },
    );
  });

  group('the bundle', () {
    test(
      'carries the heights and the route plan, and reads them back',
      () async {
        final tripId = await makeTrip();
        final legId = await makeLeg(tripId);
        await db.trackDao.addTracks(
          legId,
          [(points: line, name: null)],
          source: TrackSource.routed,
          elevations: [heights],
        );

        final bytes = (await repo.exportTrip(tripId))!;
        final importedId = await repo.importTrip(bytes);

        final imported =
            (await db.itineraryDao.watchItemsForTrip(importedId).first).single;
        expect(imported.routePlan, plan);
        expect(heightsOf((await tracksOf(imported.id)).single), heights);
      },
    );

    test('says nothing about heights or a plan that are not there', () async {
      final tripId = await makeTrip();
      final legId = await db
          .into(db.itineraryItems)
          .insert(
            ItineraryItemsCompanion.insert(
              tripId: tripId,
              date: DateTime(2026, 5, 1),
              kind: ItemKind.transport,
            ),
          );
      await db.trackDao.addTracks(legId, [(points: line, name: null)]);

      final bundle = (await repo.tripBundle(tripId))!;
      final item = bundle.items.single.toJson();

      expect(item.containsKey('routePlan'), isFalse);
      expect(
        (item['tracks'] as List).single as Map,
        isNot(contains('elevations')),
      );
    });

    test('reads a bundle written before either existed', () {
      final track = BundleTrack.fromJson(const {
        'points': '_p~iF~ps|U',
        'source': 'recorded',
      });

      expect(track.elevations, isNull);
    });
  });

  group('the GPX export', () {
    Future<String> export(List<double>? elevations) async {
      final tripId = await makeTrip();
      final legId = await makeLeg(tripId);
      await db.trackDao.addTracks(
        legId,
        [(points: line, name: null)],
        source: TrackSource.routed,
        elevations: [elevations],
      );
      return buildTripGpx(bundle: (await repo.tripBundle(tripId))!)!;
    }

    test('writes a height on every point of a line that has them', () async {
      final gpx = await export(heights);

      expect('<ele>'.allMatches(gpx), hasLength(3));
      expect(gpx, contains('<ele>500.0</ele>'));
      expect(gpx, contains('<ele>612.5</ele>'));
    });

    test('writes none on a line without', () async {
      expect(await export(null), isNot(contains('<ele>')));
    });
  });
}
