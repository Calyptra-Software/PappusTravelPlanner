import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/database/track_points.dart';
import 'package:travelplanner/features/map/track_import_plan.dart';
import 'package:travelplanner/features/sharing/trip_bundle.dart';

/// Storing the line an entry followed, and keeping it through every copy.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> makeTrip({TripKind kind = TripKind.trip}) => db
      .into(db.trips)
      .insert(
        TripsCompanion.insert(
          title: 'Trip',
          destination: const Value(''),
          kind: Value(kind),
          startDate: Value(kind == TripKind.trip ? DateTime(2026, 5, 1) : null),
          endDate: Value(kind == TripKind.trip ? DateTime(2026, 5, 2) : null),
        ),
      );

  Future<int> makeLeg(int tripId, {int? alternativeId, DateTime? date}) => db
      .into(db.itineraryItems)
      .insert(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: date ?? DateTime(2026, 5, 1),
          kind: ItemKind.transport,
          alternativeId: Value(alternativeId),
          fromLat: const Value(53.55),
          fromLon: const Value(9.99),
          toLat: const Value(53.56),
          toLon: const Value(10.0),
        ),
      );

  const line = [LatLng(53.5511, 9.9937), LatLng(53.5513, 9.9940)];

  test('a line is stored, read back, and belongs to its entry', () async {
    final trip = await makeTrip();
    final leg = await makeLeg(trip);

    await db.trackDao.addTracks(leg, [(points: line, name: 'To the station')]);

    final stored = await db.trackDao.watchTracksForItem(leg).first;
    expect(stored, hasLength(1));
    expect(stored.single.name, 'To the station');
    expect(stored.single.source, TrackSource.imported);
    expect(decodeTrackPoints(stored.single.points), hasLength(2));
  });

  test('several segments arrive as several lines, in order', () async {
    final trip = await makeTrip();
    final leg = await makeLeg(trip);

    await db.trackDao.addTracks(leg, [
      (points: line, name: 'Walk'),
      (points: line, name: 'Walk'),
    ]);
    // A second import appends rather than replacing: a leg may carry the walk
    // out of one station and into the next.
    await db.trackDao.addTracks(leg, [(points: line, name: 'Walk back')]);

    final stored = await db.trackDao.watchTracksForItem(leg).first;
    expect(stored.map((t) => t.sortOrder), [0, 1, 2]);
    expect(stored.last.name, 'Walk back');
  });

  test('the road not taken is not drawn', () async {
    // The same rule the items and the costs follow, in the same place: SQL.
    final trip = await makeTrip();
    final set = await db
        .into(db.alternativeSets)
        .insert(
          AlternativeSetsCompanion.insert(
            tripId: trip,
            date: DateTime(2026, 5, 1),
          ),
        );
    final chosen = await db
        .into(db.alternatives)
        .insert(
          AlternativesCompanion.insert(setId: set, chosen: const Value(true)),
        );
    final other = await db
        .into(db.alternatives)
        .insert(
          AlternativesCompanion.insert(setId: set, chosen: const Value(false)),
        );

    final taken = await makeLeg(trip, alternativeId: chosen);
    final notTaken = await makeLeg(trip, alternativeId: other);
    await db.trackDao.addTracks(taken, [(points: line, name: 'Ferry')]);
    await db.trackDao.addTracks(notTaken, [(points: line, name: 'Bridge')]);

    final drawn = await db.trackDao.watchTracksForTrip(trip).first;
    expect(drawn.map((t) => t.name), ['Ferry']);

    // The form still sees it: the question there is what is on this entry, not
    // what the map should draw.
    expect(await db.trackDao.watchTracksForItem(notTaken).first, hasLength(1));
  });

  group('a line travels with a copy', () {
    test('duplicating an entry brings it', () async {
      final trip = await makeTrip();
      final leg = await makeLeg(trip);
      await db.trackDao.addTracks(leg, [(points: line, name: 'Walk')]);

      final copy = await db.itineraryDao.duplicateItem(
        leg,
        day: DateTime(2026, 5, 2),
      );

      final stored = await db.trackDao.watchTracksForItem(copy).first;
      expect(stored.single.name, 'Walk');
      expect(stored.single.source, TrackSource.imported);
    });

    test('stamping a routine out brings it', () async {
      // The walk to the station is part of the plan; one the user has to redraw
      // every morning is missing by Thursday.
      final routine = await makeTrip(kind: TripKind.routine);
      final leg = await makeLeg(routine, date: kRoutineAnchorDay);
      await db.trackDao.addTracks(leg, [(points: line, name: 'To the S-Bahn')]);

      final trip = await db.routineDao.materializeRoutine(
        routine,
        startDate: DateTime(2026, 6, 1),
      );

      final drawn = await db.trackDao.watchTracksForTrip(trip).first;
      expect(drawn.map((t) => t.name), ['To the S-Bahn']);
    });

    test('a copy of the line, not a second reference to it', () async {
      // Deleting the original must not take the copy's line with it.
      final trip = await makeTrip();
      final leg = await makeLeg(trip);
      await db.trackDao.addTracks(leg, [(points: line, name: 'Walk')]);
      final copy = await db.itineraryDao.duplicateItem(
        leg,
        day: DateTime(2026, 5, 2),
      );

      await db.trackDao.deleteTracksForItem(leg);

      expect(await db.trackDao.watchTracksForItem(copy).first, hasLength(1));
    });
  });

  test('a line leaves and re-enters the app unchanged', () async {
    // `.tpt` is the one lossless way out, so a track has to make the round trip.
    final trip = await makeTrip();
    final leg = await makeLeg(trip);
    await db.trackDao.addTracks(leg, [(points: line, name: 'Walk')]);

    final bundle = (await db.sharingDao.exportTrip(trip))!;
    expect(bundle.items.single.tracks.single.name, 'Walk');
    expect(bundle.items.single.tracks.single.source, TrackSource.imported);

    final imported = await db.sharingDao.importTrip(
      TripBundle.decode(bundle.encode()),
    );
    final drawn = await db.trackDao.watchTracksForTrip(imported).first;
    expect(drawn, hasLength(1));
    expect(drawn.single.name, 'Walk');
    expect(
      decodeTrackPoints(drawn.single.points).first.latitude,
      closeTo(53.5511, 1e-5),
    );
  });

  test('deleting the entry takes its line with it', () async {
    final trip = await makeTrip();
    final leg = await makeLeg(trip);
    await db.trackDao.addTracks(leg, [(points: line, name: 'Walk')]);

    await (db.delete(db.itineraryItems)..where((i) => i.id.equals(leg))).go();

    expect(await db.select(db.tracks).get(), isEmpty);
  });

  group('one recording across several entries', () {
    test('writes the pieces and the coordinates it learned, together', () async {
      final trip = await makeTrip();
      final a = await db
          .into(db.itineraryItems)
          .insert(
            ItineraryItemsCompanion.insert(
              tripId: trip,
              date: DateTime(2026, 5, 1),
              kind: ItemKind.transport,
              // An end that came from a search: placing it by hand has to drop the
              // id, which no longer describes where the end is.
              toPlaceId: const Value('de:02000:11'),
            ),
          );
      final b = await db
          .into(db.itineraryItems)
          .insert(
            ItineraryItemsCompanion.insert(
              tripId: trip,
              date: DateTime(2026, 5, 1),
              kind: ItemKind.transport,
            ),
          );
      final stop = await db
          .into(db.itineraryItems)
          .insert(
            ItineraryItemsCompanion.insert(
              tripId: trip,
              date: DateTime(2026, 5, 1),
              kind: ItemKind.place,
              title: const Value('B'),
            ),
          );

      await db.trackDao.importTrackAcross(
        name: 'Walk',
        pieces: [
          (itemId: a, points: const [LatLng(50, 8), LatLng(51, 8.2)]),
          (itemId: b, points: const [LatLng(51, 8.2), LatLng(52, 8.5)]),
        ],
        ends: [
          (itemId: a, end: TrackEnd.from, at: const LatLng(50, 8)),
          (itemId: a, end: TrackEnd.to, at: const LatLng(51, 8.2)),
          (itemId: b, end: TrackEnd.from, at: const LatLng(51, 8.2)),
          (itemId: b, end: TrackEnd.to, at: const LatLng(52, 8.5)),
          // A place has one position, not two.
          (itemId: stop, end: TrackEnd.place, at: const LatLng(51, 8.2)),
        ],
      );

      final rows = {
        for (final i in await db.select(db.itineraryItems).get()) i.id: i,
      };
      expect(rows[a]!.fromLat, 50);
      expect(rows[a]!.toLat, 51);
      expect(rows[b]!.fromLat, 51);
      expect(rows[b]!.toLat, 52);
      expect(rows[stop]!.lat, 51);
      expect(rows[stop]!.lon, 8.2);
      // The id no longer describes the end, so it goes.
      expect(rows[a]!.toPlaceId, null);

      expect(await db.trackDao.watchTracksForItem(a).first, hasLength(1));
      expect(await db.trackDao.watchTracksForItem(b).first, hasLength(1));
      // A place carries no line: it is a point, with no straight segment to
      // replace.
      expect(await db.trackDao.watchTracksForItem(stop).first, isEmpty);
    });

    test('a piece too short to be a line is not written', () async {
      final trip = await makeTrip();
      final leg = await makeLeg(trip);

      await db.trackDao.importTrackAcross(
        name: null,
        pieces: [
          (itemId: leg, points: const [LatLng(50, 8)]),
        ],
        ends: const [],
      );

      expect(await db.trackDao.watchTracksForItem(leg).first, isEmpty);
    });
  });

  test('every trip\'s lines come back in one query', () async {
    // The all-trips map's reading — the only query here not about one trip.
    final one = await makeTrip();
    final two = await makeTrip();
    await db.trackDao.addTracks(await makeLeg(one), [
      (points: line, name: 'One'),
    ]);
    await db.trackDao.addTracks(await makeLeg(two), [
      (points: line, name: 'Two'),
    ]);

    expect(
      (await db.trackDao.watchAllTracks().first).map((t) => t.name),
      containsAll(['One', 'Two']),
    );
  });

  test('one line of several can be removed on its own', () async {
    final trip = await makeTrip();
    final leg = await makeLeg(trip);
    await db.trackDao.addTracks(leg, [
      (points: line, name: 'First'),
      (points: line, name: 'Second'),
    ]);

    final stored = await db.trackDao.watchTracksForItem(leg).first;
    await db.trackDao.deleteTrack(stored.first.id);

    expect(
      (await db.trackDao.watchTracksForItem(leg).first).map((t) => t.name),
      ['Second'],
    );
  });

  test('the way home covers the ground the way out covered, reversed', () async {
    // A path from A to B *is* the path from B to A — unlike the times beside it,
    // which the reversed routine drops rather than turn into a fiction.
    final trip = await makeTrip();
    final out = await makeLeg(trip);
    final back = await makeLeg(trip);
    await db.trackDao.addTracks(out, [
      (
        points: const [LatLng(53.1, 9.1), LatLng(53.2, 9.2), LatLng(53.3, 9.3)],
        name: 'Out',
      ),
    ]);

    await db.trackDao.copyItemTracks(out, back, reversed: true);

    final copied = await db.trackDao.watchTracksForItem(back).first;
    final points = decodeTrackPoints(copied.single.points);
    expect(points.first.latitude, closeTo(53.3, 1e-4));
    expect(points.last.latitude, closeTo(53.1, 1e-4));
  });
}
