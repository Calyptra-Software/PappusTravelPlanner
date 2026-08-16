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
      expect(ends.first, (itemId: 1, isStart: true, at: first));
      expect(ends.last, (itemId: 1, isStart: false, at: last));
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
      expect(ends.map((e) => (e.itemId, e.isStart)), [(1, false), (2, true)]);
    });
  });
}
