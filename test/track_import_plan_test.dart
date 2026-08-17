import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/map/track_import_plan.dart';

/// Reading a selected run of entries as an import.
void main() {
  ItineraryItem leg(int id, {double? fromLat, double? toLat}) => ItineraryItem(
    id: id,
    tripId: 1,
    date: DateTime(2026, 5, 1),
    sortOrder: id,
    kind: ItemKind.transport,
    spansNextDay: false,
    fromLat: fromLat,
    fromLon: fromLat == null ? null : 9.0,
    toLat: toLat,
    toLon: toLat == null ? null : 9.0,
  );

  ItineraryItem place(int id, {double? lat}) => ItineraryItem(
    id: id,
    tripId: 1,
    date: DateTime(2026, 5, 1),
    sortOrder: id,
    kind: ItemKind.place,
    title: 'Café',
    spansNextDay: false,
    lat: lat,
    lon: lat == null ? null : 9.0,
  );

  test('only legs get a stretch; a place is a boundary, never a piece', () {
    final plan = trackImportPlan([
      leg(1, toLat: 53.1),
      place(2, lat: 53.1),
      leg(3, fromLat: 53.1),
    ]);

    expect(plan.legs.map((l) => l.id), [1, 3]);
    expect(plan.boundaries, hasLength(1));
  });

  test('a positioned place supplies a handover the legs left open', () {
    // Saves the user a tap: the café is exactly where one leg stopped and the
    // next began.
    final plan = trackImportPlan([leg(1), place(2, lat: 53.5), leg(3)]);

    expect(plan.boundaries.single, const LatLng(53.5, 9.0));
    expect(plan.open, isEmpty);
  });

  test('a place without a position supplies nothing and is left alone', () {
    final plan = trackImportPlan([leg(1), place(2), leg(3)]);

    expect(plan.boundaries.single, isNull);
    expect(plan.open, [0]);
  });

  test("the leg's own end wins over the place beside it", () {
    final plan = trackImportPlan([
      leg(1, toLat: 53.9),
      place(2, lat: 53.5),
      leg(3),
    ]);
    expect(plan.boundaries.single, const LatLng(53.9, 9.0));
  });

  group('what the import writes back', () {
    const first = LatLng(50.0, 8.0);
    const last = LatLng(51.0, 8.5);

    test("the outer ends come from the recording when nobody gave them", () {
      final plan = trackImportPlan([leg(1)]);
      final ends = trackImportEnds(plan, first: first, last: last);

      expect(ends, hasLength(2));
      expect(ends.first, (itemId: 1, end: TrackEnd.from, at: first));
      expect(ends.last, (itemId: 1, end: TrackEnd.to, at: last));
    });

    test('an end the user already gave is left as it is', () {
      // Their statement; the file is only a witness to it.
      final plan = trackImportPlan([leg(1, fromLat: 40.0, toLat: 41.0)]);
      expect(trackImportEnds(plan, first: first, last: last), isEmpty);
    });

    test('a handover fills both sides of itself', () {
      final plan = trackImportPlan([
        leg(1, fromLat: 40.0),
        leg(2, toLat: 41.0),
      ]);
      final withBoundary = TrackImportPlan(
        legs: plan.legs,
        boundaries: const [LatLng(53.3, 9.3)],
      );

      final ends = trackImportEnds(withBoundary, first: first, last: last);
      expect(ends.map((e) => (e.itemId, e.end)), [
        (1, TrackEnd.to),
        (2, TrackEnd.from),
      ]);
    });
  });

  group('nothing is left half-placed', () {
    // The failure this guards: after an import across two legs, one of them had
    // coordinates and the other did not. Every end of every leg the import
    // touched has to come out set — the outer two from the recording, the inner
    // ones from the handover, which the screen now insists on before it lets
    // the import run at all.
    ItineraryItem bare(int id) => ItineraryItem(
      id: id,
      tripId: 1,
      date: DateTime(2026, 5, 1),
      sortOrder: id,
      kind: ItemKind.transport,
      spansNextDay: false,
    );

    test('two bare legs come out fully placed', () {
      final plan = trackImportPlan([bare(1), bare(2)]);
      final placed = TrackImportPlan(
        legs: plan.legs,
        boundaries: const [LatLng(51.0, 8.2)],
      );

      final ends = trackImportEnds(
        placed,
        first: const LatLng(50.0, 8.0),
        last: const LatLng(52.0, 8.5),
      );

      expect(ends.map((e) => (e.itemId, e.end)).toSet(), {
        (1, TrackEnd.from),
        (1, TrackEnd.to),
        (2, TrackEnd.from),
        (2, TrackEnd.to),
      });
    });

    test('and so do four', () {
      final legs = [bare(1), bare(2), bare(3), bare(4)];
      final plan = trackImportPlan(legs);
      final placed = TrackImportPlan(
        legs: plan.legs,
        boundaries: const [
          LatLng(50.5, 8.1),
          LatLng(51.0, 8.2),
          LatLng(51.5, 8.3),
        ],
      );

      final ends = trackImportEnds(
        placed,
        first: const LatLng(50.0, 8.0),
        last: const LatLng(52.0, 8.5),
      );

      for (final leg in legs) {
        expect(
          ends.where((e) => e.itemId == leg.id).map((e) => e.end).toSet(),
          {TrackEnd.from, TrackEnd.to},
          reason: 'leg ${leg.id} was left half-placed',
        );
      }
    });
  });

  group('a place in the run is filled in too', () {
    const first = LatLng(50.0, 8.0);
    const last = LatLng(52.0, 8.5);
    const handover = LatLng(51.0, 8.2);

    LatLng? placedAt(
      List<ItineraryItem> selection,
      int id, {
      LatLng? boundary,
    }) {
      final plan = trackImportPlan(selection);
      final withBoundary = TrackImportPlan(
        legs: plan.legs,
        boundaries: boundary == null
            ? plan.boundaries
            : [for (final _ in plan.boundaries) boundary],
        selection: selection,
      );
      final ends = trackImportEnds(withBoundary, first: first, last: last);
      return ends
          .where((e) => e.itemId == id && e.end == TrackEnd.place)
          .map((e) => e.at)
          .firstOrNull;
    }

    test('a place between two legs gets the handover they get', () {
      // All three "B"s end up saying the same thing, which is the point: they
      // *are* the same spot.
      expect(
        placedAt([leg(1), place(2), leg(3)], 2, boundary: handover),
        handover,
      );
    });

    test('a place at the front gets where the recording started', () {
      expect(placedAt([place(9), leg(1), place(2), leg(3)], 9), first);
    });

    test('a place at the back gets where it finished', () {
      expect(placedAt([leg(1), place(2), leg(3), place(9)], 9), last);
    });

    test('a place that already has a position keeps it', () {
      // Their statement; the file is a witness to it, not a correction.
      expect(
        placedAt([leg(1), place(2, lat: 40.0), leg(3)], 2, boundary: handover),
        isNull,
      );
    });

    test("it follows the legs' own ends when those already say where", () {
      // The handover resolves to the first leg's end, so that is what the place
      // is given — the only reading that keeps the three agreeing.
      final selection = [leg(1, toLat: 53.9), place(2), leg(3, fromLat: 53.9)];
      expect(placedAt(selection, 2), const LatLng(53.9, 9.0));
    });
  });
}
