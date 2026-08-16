import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/map/map_features.dart';

/// The rules the trip map draws by, without a widget tree or a tile server.
void main() {
  var nextId = 0;

  ItineraryItem place({double? lat, double? lon, String? title}) =>
      ItineraryItem(
        id: ++nextId,
        tripId: 1,
        date: DateTime(2026, 5, 1),
        sortOrder: 0,
        kind: ItemKind.place,
        title: title,
        spansNextDay: false,
        lat: lat,
        lon: lon,
      );

  ItineraryItem leg({
    double? fromLat,
    double? fromLon,
    double? toLat,
    double? toLon,
    int? mode,
  }) => ItineraryItem(
    id: ++nextId,
    tripId: 1,
    date: DateTime(2026, 5, 1),
    sortOrder: 0,
    kind: ItemKind.transport,
    spansNextDay: false,
    fromLat: fromLat,
    fromLon: fromLon,
    toLat: toLat,
    toLon: toLon,
    mode: mode,
  );

  setUp(() => nextId = 0);

  group('what reaches the map', () {
    test('a place without a position is not drawn', () {
      final features = tripMapFeatures([
        place(title: 'Somewhere'),
        place(lat: 50.1, lon: 8.6, title: 'Städel'),
      ]);
      expect(features.pins.map((p) => p.label), ['Städel']);
    });

    test('a leg is drawn only when both ends are known', () {
      final features = tripMapFeatures([
        leg(fromLat: 53.5, fromLon: 10.0), // no destination
        leg(toLat: 50.1, toLon: 8.6), // no origin
        leg(fromLat: 53.5, fromLon: 10.0, toLat: 50.1, toLon: 8.6),
      ]);
      expect(features.paths, hasLength(1));
      expect(features.pins, isEmpty);
    });

    test('nothing is invented between two places', () {
      final features = tripMapFeatures([
        place(lat: 50.1, lon: 8.6),
        place(lat: 50.2, lon: 8.7),
      ]);
      expect(features.pins, hasLength(2));
      expect(features.paths, isEmpty);
    });

    test('a place falls back to its location when it has no title', () {
      final item = place(
        lat: 50.1,
        lon: 8.6,
      ).copyWith(location: const Value('Schaumainkai 63'));
      expect(tripMapFeatures([item]).pins.single.label, 'Schaumainkai 63');
    });

    test('only the entry under way is marked as happening', () {
      final here = place(lat: 50.1, lon: 8.6);
      final elsewhere = place(lat: 51.1, lon: 9.6);
      final features = tripMapFeatures([
        here,
        elsewhere,
      ], happeningItemId: here.id);
      expect(features.pins.first.happening, isTrue);
      expect(features.pins.last.happening, isFalse);
    });

    test('with nothing under way nothing is marked', () {
      final features = tripMapFeatures([place(lat: 50.1, lon: 8.6)]);
      expect(features.pins.single.happening, isFalse);
      expect(features.isEmpty, isFalse);
      expect(TripMapFeatures.empty.isEmpty, isTrue);
    });
  });

  group('great circles', () {
    test('a short hop stays the plain two-point line', () {
      final points = greatCircle(LatLng(53.55, 10.0), LatLng(53.86, 10.69));
      expect(points, hasLength(2));
    });

    test('a long leg bends, and its ends are exactly where they were', () {
      const hamburg = LatLng(53.5511, 9.9937);
      const newYork = LatLng(40.7128, -74.0060);
      final points = greatCircle(hamburg, newYork);

      expect(points.length, greaterThan(8));
      expect(points.first.latitude, closeTo(hamburg.latitude, 1e-6));
      expect(points.first.longitude, closeTo(hamburg.longitude, 1e-6));
      expect(points.last.latitude, closeTo(newYork.latitude, 1e-6));
      expect(points.last.longitude, closeTo(newYork.longitude, 1e-6));
    });

    test(
      'the arc runs north of the straight line, as the route really does',
      () {
        const hamburg = LatLng(53.5511, 9.9937);
        const newYork = LatLng(40.7128, -74.0060);
        final points = greatCircle(hamburg, newYork);
        final middle = points[points.length ~/ 2];

        // Halfway along the flat line would sit near 47°N; the great circle is
        // well north of that.
        final straightMidLat = (hamburg.latitude + newYork.latitude) / 2;
        expect(middle.latitude, greaterThan(straightMidLat + 3));
      },
    );

    test('two points in the same spot do not divide by zero', () {
      const point = LatLng(53.5511, 9.9937);
      expect(greatCircle(point, point), hasLength(2));
    });
  });

  group('the antimeridian', () {
    test('an ordinary line is one segment', () {
      final segments = splitAtAntimeridian([
        LatLng(53.5, 10.0),
        LatLng(50.1, 8.6),
      ]);
      expect(segments, hasLength(1));
    });

    test('a transpacific leg is split rather than drawn backwards', () {
      const tokyo = LatLng(35.6762, 139.6503);
      const losAngeles = LatLng(34.0522, -118.2437);
      final path = tripMapFeatures([
        leg(
          fromLat: tokyo.latitude,
          fromLon: tokyo.longitude,
          toLat: losAngeles.latitude,
          toLon: losAngeles.longitude,
        ),
      ]).paths.single;

      expect(path.segments, hasLength(2));
      // No segment may itself contain the wrap it was split to avoid.
      for (final segment in path.segments) {
        for (var i = 1; i < segment.length; i++) {
          expect(
            (segment[i].longitude - segment[i - 1].longitude).abs(),
            lessThan(180),
          );
        }
      }
    });

    test('the icon anchor lands inside the longer half of a split leg', () {
      final path = tripMapFeatures([
        leg(fromLat: 35.6, fromLon: 139.6, toLat: 34.0, toLon: -118.2),
      ]).paths.single;
      // The anchor is interpolated, so it need not be one of the vertices — but
      // it must lie within the longitude span of the piece it belongs to, and
      // never on the far side of the antimeridian.
      final lons = [
        for (final s in path.segments)
          for (final p in s) p.longitude,
      ];
      expect(
        path.anchor.longitude,
        inInclusiveRange(
          lons.reduce((a, b) => a < b ? a : b),
          lons.reduce((a, b) => a > b ? a : b),
        ),
      );
    });
  });

  group('where the mode icon hangs', () {
    test('a short leg wears it in the middle, not at its destination', () {
      // Two platforms a few hundred metres apart: below the great-circle
      // threshold, so the line is exactly its two ends. Counting vertices used
      // to put the icon on the second of them.
      const from = LatLng(53.552914, 10.007209);
      const to = LatLng(53.552810, 10.007921);
      final path = tripMapFeatures([
        leg(
          fromLat: from.latitude,
          fromLon: from.longitude,
          toLat: to.latitude,
          toLon: to.longitude,
        ),
      ]).paths.single;

      expect(
        path.anchor.latitude,
        closeTo((from.latitude + to.latitude) / 2, 1e-9),
      );
      expect(
        path.anchor.longitude,
        closeTo((from.longitude + to.longitude) / 2, 1e-9),
      );
      expect(path.anchor, isNot(to));
      expect(path.anchor, isNot(from));
    });

    test('a long leg wears it half way along, by distance', () {
      final path = tripMapFeatures([
        leg(fromLat: 53.5511, fromLon: 9.9937, toLat: 48.1372, toLon: 11.5756),
      ]).paths.single;
      final line = path.segments.single;

      const distance = Distance(calculator: Haversine());
      var toAnchor = 0.0;
      for (var i = 1; i < line.length; i++) {
        final a = line[i - 1];
        final b = line[i];
        final step = distance.as(LengthUnit.Meter, a, b);
        // Stop once the anchor is inside this step.
        if (distance.as(LengthUnit.Meter, a, path.anchor) <= step &&
            distance.as(LengthUnit.Meter, path.anchor, b) <= step) {
          toAnchor += distance.as(LengthUnit.Meter, a, path.anchor);
          break;
        }
        toAnchor += step;
      }
      var total = 0.0;
      for (var i = 1; i < line.length; i++) {
        total += distance.as(LengthUnit.Meter, line[i - 1], line[i]);
      }
      expect(toAnchor / total, closeTo(0.5, 0.01));
    });

    test('a leg that goes nowhere still has a place', () {
      final path = tripMapFeatures([
        leg(fromLat: 53.5511, fromLon: 9.9937, toLat: 53.5511, toLon: 9.9937),
      ]).paths.single;
      expect(path.anchor.latitude, closeTo(53.5511, 1e-9));
    });
  });

  test('framing includes the bulge, not just the endpoints', () {
    final features = tripMapFeatures([
      leg(fromLat: 53.5511, fromLon: 9.9937, toLat: 40.7128, toLon: -74.0060),
    ]);
    final northernmost = features.allPoints
        .map((p) => p.latitude)
        .reduce((a, b) => a > b ? a : b);
    expect(northernmost, greaterThan(53.5511));
  });

  group('a recorded line replaces the straight one', () {
    ItineraryItem leg(int id) => ItineraryItem(
      id: id,
      tripId: 1,
      date: DateTime(2026, 5, 1),
      sortOrder: 0,
      kind: ItemKind.transport,
      spansNextDay: false,
      fromLat: 53.5511,
      fromLon: 9.9937,
      toLat: 53.5600,
      toLon: 10.0100,
    );

    test('the track is drawn and the chord is not', () {
      // Two answers to the same question; drawing both would put a line across
      // the bay beside the line around it.
      final features = tripMapFeatures(
        [leg(1)],
        tracks: {
          1: [
            const TrackLine(
              points: [
                LatLng(53.5511, 9.9937),
                LatLng(53.5540, 9.9990),
                LatLng(53.5600, 10.0100),
              ],
              source: TrackSource.imported,
            ),
          ],
        },
      );

      expect(features.paths.single.segments.single, hasLength(3));
    });

    test('a gap in the recording stays a gap', () {
      final features = tripMapFeatures(
        [leg(1)],
        tracks: {
          1: [
            const TrackLine(
              points: [LatLng(53.5511, 9.9937), LatLng(53.5540, 9.9990)],
              source: TrackSource.imported,
            ),
            const TrackLine(
              points: [LatLng(53.5570, 10.0050), LatLng(53.5600, 10.0100)],
              source: TrackSource.imported,
            ),
          ],
        },
      );

      expect(features.paths.single.segments, hasLength(2));
    });

    test('an entry with no track still gets the great circle', () {
      final features = tripMapFeatures([leg(1)], tracks: const {2: []});
      expect(features.paths.single.segments.single, hasLength(2));
    });
  });

  group('what a line claims decides how it is drawn', () {
    ItineraryItem leg(int id) => ItineraryItem(
      id: id,
      tripId: 1,
      date: DateTime(2026, 5, 1),
      sortOrder: 0,
      kind: ItemKind.transport,
      spansNextDay: false,
      fromLat: 53.5511,
      fromLon: 9.9937,
      toLat: 53.5600,
      toLon: 10.0100,
    );

    const walked = [LatLng(53.5511, 9.9937), LatLng(53.5600, 10.0100)];
    const computed = [LatLng(53.5511, 9.9937), LatLng(53.5550, 10.0000)];

    test('a computed route is drawn broken', () {
      final features = tripMapFeatures(
        [leg(1)],
        tracks: {
          1: [const TrackLine(points: computed, source: TrackSource.routed)],
        },
      );
      expect(features.paths.single.dashed, isTrue);
    });

    test('a recorded one is drawn solid', () {
      final features = tripMapFeatures(
        [leg(1)],
        tracks: {
          1: [const TrackLine(points: walked, source: TrackSource.recorded)],
        },
      );
      expect(features.paths.single.dashed, isFalse);
    });

    test('what was followed supersedes what was proposed', () {
      // Both stay stored — the entry's form lists them — but the map draws the
      // record, not the router's guess beside it.
      final features = tripMapFeatures(
        [leg(1)],
        tracks: {
          1: [
            const TrackLine(points: computed, source: TrackSource.routed),
            const TrackLine(points: walked, source: TrackSource.imported),
          ],
        },
      );
      expect(features.paths.single.segments, hasLength(1));
      expect(features.paths.single.segments.single, walked);
      expect(features.paths.single.dashed, isFalse);
    });
  });
}
