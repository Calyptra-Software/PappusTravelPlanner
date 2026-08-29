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

  Attachment photo({
    double? lat,
    double? lon,
    int? itemId,
    int? groupId,
    AttachmentKind kind = AttachmentKind.photo,
  }) => Attachment(
    id: ++nextId,
    itemId: itemId,
    groupId: groupId,
    kind: kind,
    mimeType: 'image/jpeg',
    byteSize: 1024,
    lat: lat,
    lon: lon,
    positionSource: lat == null ? null : AttachmentPositionSource.exif,
    sortOrder: 0,
    createdAt: DateTime(2026, 5, 1),
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
              id: 1,
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
              id: 2,
              points: [LatLng(53.5511, 9.9937), LatLng(53.5540, 9.9990)],
              source: TrackSource.imported,
            ),
            const TrackLine(
              id: 3,
              points: [LatLng(53.5570, 10.0050), LatLng(53.5600, 10.0100)],
              source: TrackSource.imported,
            ),
          ],
        },
      );

      // Two rows, so two paths: each is a line somebody can point at, and the
      // gap between them is not a line at all.
      expect(features.paths, hasLength(2));
      expect(features.paths.map((p) => p.segments.length), [1, 1]);
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
          1: [
            const TrackLine(
              id: 4,
              points: computed,
              source: TrackSource.routed,
            ),
          ],
        },
      );
      expect(features.paths.single.dashed, isTrue);
    });

    test('a recorded one is drawn solid', () {
      final features = tripMapFeatures(
        [leg(1)],
        tracks: {
          1: [
            const TrackLine(
              id: 5,
              points: walked,
              source: TrackSource.recorded,
            ),
          ],
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
            const TrackLine(
              id: 6,
              points: computed,
              source: TrackSource.routed,
            ),
            const TrackLine(
              id: 7,
              points: walked,
              source: TrackSource.imported,
            ),
          ],
        },
      );
      expect(features.paths.single.segments, hasLength(1));
      expect(features.paths.single.segments.single, walked);
      expect(features.paths.single.dashed, isFalse);
      // And it is the *recorded* row that is drawn, by its id.
      expect(features.paths.single.trackId, isNotNull);
    });
  });

  group('which of an entry\'s lines the map draws', () {
    ({int id, TrackSource source, TrackDisplay display}) line(
      int id,
      TrackSource source, [
      TrackDisplay display = TrackDisplay.auto,
    ]) => (id: id, source: source, display: display);

    test('what was followed supersedes what was proposed', () {
      // The default, unchanged: a recording is drawn and the router's guess
      // beside it is not.
      expect(
        drawnTrackIds([
          line(1, TrackSource.routed),
          line(2, TrackSource.imported),
        ]),
        {2},
      );
    });

    test('a routed line alone is drawn', () {
      expect(drawnTrackIds([line(1, TrackSource.routed)]), {1});
    });

    test('hiding the recording brings the computed route forward', () {
      // The case the override exists for: the trace is wrong in the tunnel, so
      // it is put away — and nothing has to be deleted to see the route.
      expect(
        drawnTrackIds([
          line(1, TrackSource.routed),
          line(2, TrackSource.imported, TrackDisplay.hidden),
        ]),
        {1},
      );
    });

    test('a routed line asked for is drawn beside the recording', () {
      // A trace broken in two by that tunnel plus the route that bridges it is
      // one picture of one journey, and only the user can say so.
      expect(
        drawnTrackIds([
          line(1, TrackSource.routed, TrackDisplay.shown),
          line(2, TrackSource.imported),
          line(3, TrackSource.imported),
        ]),
        {1, 2, 3},
      );
    });

    test('hidden outranks everything, including being asked for', () {
      expect(
        drawnTrackIds([line(1, TrackSource.imported, TrackDisplay.hidden)]),
        isEmpty,
      );
    });

    test('a followed line the user asked for still suppresses the route', () {
      // `shown` on a recording says nothing the default did not, so it must not
      // quietly stop counting as a recording.
      expect(
        drawnTrackIds([
          line(1, TrackSource.routed),
          line(2, TrackSource.recorded, TrackDisplay.shown),
        ]),
        {2},
      );
    });
  });

  group('an entry with every line hidden falls back to the chord', () {
    ItineraryItem leg() => ItineraryItem(
      id: 1,
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

    const walked = [LatLng(53.5511, 9.9937), LatLng(53.5540, 9.9990)];

    test('the straight segment comes back, as on an entry with no line', () {
      // What the plan itself says about the leg. A leg vanishing from the map
      // because of a decision about *how* to draw it would be the bigger
      // surprise.
      final features = tripMapFeatures(
        [leg()],
        tracks: {
          1: [
            const TrackLine(
              id: 11,
              points: walked,
              source: TrackSource.imported,
              display: TrackDisplay.hidden,
            ),
          ],
        },
      );

      expect(features.paths.single.trackId, isNull);
      expect(features.paths.single.segments.single, hasLength(2));
    });

    test('a hidden line is not drawn even when it is the only one', () {
      // And an entry with no ends to fall back on simply is not on the map.
      final features = tripMapFeatures(
        [leg().copyWith(fromLat: const Value(null))],
        tracks: {
          1: [
            const TrackLine(
              id: 11,
              points: walked,
              source: TrackSource.imported,
              display: TrackDisplay.hidden,
            ),
          ],
        },
      );

      expect(features.paths, isEmpty);
    });
  });

  group('a line is a thing that can be pointed at', () {
    ItineraryItem leg(int id) => ItineraryItem(
      id: id,
      tripId: 1,
      date: DateTime(2026, 5, 1),
      sortOrder: id,
      kind: ItemKind.transport,
      spansNextDay: false,
      fromLat: 53.5511,
      fromLon: 9.9937,
      toLat: 53.5600,
      toLon: 10.0100,
    );

    const short = [LatLng(53.5511, 9.9937), LatLng(53.5540, 9.9990)];
    const long = [LatLng(53.5511, 9.9937), LatLng(53.6200, 10.1000)];

    test('each stored line is a path of its own, named by its row', () {
      // Without the row id the map could say which entry was tapped but not
      // which of its lines, which is the half of the question the sheet
      // answers.
      final features = tripMapFeatures(
        [leg(1)],
        tracks: {
          1: [
            const TrackLine(
              id: 11,
              points: short,
              source: TrackSource.imported,
            ),
            const TrackLine(id: 12, points: long, source: TrackSource.imported),
          ],
        },
      );

      expect(features.paths.map((p) => p.trackId), [11, 12]);
    });

    test('the straight segment between the ends carries no track id', () {
      // It is a drawing of the plan, not a row anybody can point at.
      expect(tripMapFeatures([leg(1)]).paths.single.trackId, isNull);
    });

    test('one path of an entry wears the badge, and it is the longest', () {
      // A walk recorded in four segments still wears one mode icon, where the
      // single path used to wear it: half way along the longest piece.
      final features = tripMapFeatures(
        [leg(1)],
        tracks: {
          1: [
            const TrackLine(
              id: 11,
              points: short,
              source: TrackSource.imported,
            ),
            const TrackLine(id: 12, points: long, source: TrackSource.imported),
            const TrackLine(
              id: 13,
              points: short,
              source: TrackSource.imported,
            ),
          ],
        },
      );

      expect(features.paths.map((p) => p.badged), [false, true, false]);
      expect(
        features.paths.singleWhere((p) => p.badged).anchor,
        midpointOf(long),
      );
    });

    test('an entry drawn as one line still wears its badge', () {
      expect(tripMapFeatures([leg(1)]).paths.single.badged, isTrue);
    });

    group('what one tap answers for', () {
      test('two lines of one entry are one answer', () {
        // The sheet lists that entry's lines and marks the one tapped, so a
        // chooser would be asking a question it is about to answer itself.
        final features = tripMapFeatures(
          [leg(1)],
          tracks: {
            1: [
              const TrackLine(
                id: 11,
                points: short,
                source: TrackSource.imported,
              ),
              const TrackLine(
                id: 12,
                points: long,
                source: TrackSource.imported,
              ),
            ],
          },
        );

        final hit = pathsUnderTap(features.paths.reversed, features.paths);
        expect(hit, hasLength(1));
        // The first hit is the line the finger landed on.
        expect(hit.single.trackId, 12);
      });

      test('two entries are two, in the order the plan draws them', () {
        // Never in the order they were hit: a stable order is one the user can
        // learn, and which line was drawn last is not something they can see.
        final features = tripMapFeatures([leg(1), leg(2)]);

        expect(
          pathsUnderTap(
            features.paths.reversed,
            features.paths,
          ).map((p) => p.itemId),
          [1, 2],
        );
      });

      test('a tap that landed on nothing answers nothing', () {
        expect(
          pathsUnderTap(const [], tripMapFeatures([leg(1)]).paths),
          isEmpty,
        );
      });
    });
  });

  group('an entry may carry its own color', () {
    ItineraryItem colored(ItineraryItem item, int? colorValue) =>
        item.copyWith(colorValue: Value(colorValue));

    test('a place hands its color to its pin, and null stays null', () {
      final features = tripMapFeatures([
        colored(place(lat: 50.1, lon: 8.6, title: 'Städel'), 0xFFB71C1C),
        place(lat: 50.2, lon: 8.7, title: 'Palmengarten'),
      ]);
      expect(features.pins.map((p) => p.colorValue), [0xFFB71C1C, null]);
    });

    test('a leg hands its color to the line drawn between its ends', () {
      final features = tripMapFeatures([
        colored(
          leg(fromLat: 53.5, fromLon: 10.0, toLat: 50.1, toLon: 8.6),
          0xFF1B5E20,
        ),
      ]);
      expect(features.paths.single.colorValue, 0xFF1B5E20);
    });

    test('and to its recorded line, which is the same claim', () {
      // Whichever line the leg turned out to be drawn as wears the color: it
      // is a statement about the entry, not about which of its lines won.
      final item = colored(
        leg(fromLat: 53.5511, fromLon: 9.9937, toLat: 53.5600, toLon: 10.0100),
        0xFF1B5E20,
      );
      final features = tripMapFeatures(
        [item],
        tracks: {
          item.id: [
            const TrackLine(
              id: 8,
              points: [LatLng(53.5511, 9.9937), LatLng(53.5600, 10.0100)],
              source: TrackSource.imported,
            ),
          ],
        },
      );
      expect(features.paths.single.colorValue, 0xFF1B5E20);
    });
  });

  group('photos on the map', () {
    test('one with a position is drawn, one without is not', () {
      final entry = place(lat: 53.55, lon: 9.99, title: 'Landungsbrücken');
      final features = tripMapFeatures(
        [entry],
        photos: [
          photo(lat: 53.5460, lon: 9.9680, itemId: entry.id),
          photo(itemId: entry.id),
        ],
      );

      expect(features.photos, hasLength(1));
      expect(features.photos.single.position.latitude, closeTo(53.546, 1e-9));
      // Deliberately not fallen back to the entry's own pin: the app does not
      // claim to know where a picture was taken.
      expect(features.pins, hasLength(1));
    });

    test('a photo has no position of the entry it hangs on', () {
      final entry = place(lat: 53.55, lon: 9.99);
      final features = tripMapFeatures(
        [entry],
        photos: [photo(itemId: entry.id)],
      );

      expect(features.photos, isEmpty);
    });

    test('one on an entry no longer in the plan is not drawn', () {
      final entry = place(lat: 53.55, lon: 9.99);
      // The entry is gone from `items` — it sits in an option nobody chose, and
      // `liveItems` dropped it before the map ever saw it.
      final features = tripMapFeatures(
        [entry],
        photos: [photo(lat: 53.1, lon: 9.1, itemId: entry.id + 100)],
      );

      expect(features.photos, isEmpty);
    });

    test('one on a run is drawn while the run has a live member', () {
      final member = leg(
        fromLat: 53.5,
        fromLon: 10.0,
        toLat: 50.1,
        toLon: 8.6,
      ).copyWith(groupId: const Value(7));
      final features = tripMapFeatures(
        [member],
        photos: [photo(lat: 52.0, lon: 9.0, groupId: 7)],
      );

      expect(features.photos.single.groupId, 7);
      expect(features.photos.single.itemId, isNull);
    });

    test('one on a run with nothing live left is not drawn', () {
      final loose = place(lat: 53.55, lon: 9.99);
      final features = tripMapFeatures(
        [loose],
        photos: [photo(lat: 52.0, lon: 9.0, groupId: 7)],
      );

      expect(features.photos, isEmpty);
    });

    test("takes its entry's color, and a run's photo takes none", () {
      final entry = place(
        lat: 53.55,
        lon: 9.99,
      ).copyWith(colorValue: const Value(0xFF1B5E20));
      final member = leg(
        fromLat: 53.5,
        fromLon: 10.0,
        toLat: 50.1,
        toLon: 8.6,
      ).copyWith(groupId: const Value(7));
      final features = tripMapFeatures(
        [entry, member],
        photos: [
          photo(lat: 53.1, lon: 9.1, itemId: entry.id),
          photo(lat: 52.0, lon: 9.0, groupId: 7),
        ],
      );

      expect(features.photos.first.colorValue, 0xFF1B5E20);
      // A group carries no color, and picking one of its members' would be an
      // accident deciding what the run looks like.
      expect(features.photos.last.colorValue, isNull);
    });

    test("the trip's own photo is always drawn", () {
      final features = tripMapFeatures(
        [place(lat: 53.55, lon: 9.99)],
        photos: [photo(lat: 41.9, lon: 12.5)],
      );

      // It belongs to the journey rather than to a part of it: there is no
      // option it could sit in and nothing that could stop being chosen.
      expect(features.photos.single.itemId, isNull);
      expect(features.photos.single.groupId, isNull);
      expect(features.photos.single.colorValue, isNull);
    });

    test("the trip's own is drawn even when the plan is empty", () {
      final features = tripMapFeatures(
        const [],
        photos: [photo(lat: 41.9, lon: 12.5)],
      );

      expect(features.photos, hasLength(1));
      expect(features.isEmpty, isFalse);
    });

    test('a document is never a marker, position or no position', () {
      final entry = place(lat: 53.55, lon: 9.99);
      final features = tripMapFeatures(
        [entry],
        photos: [
          photo(
            lat: 53.1,
            lon: 9.1,
            itemId: entry.id,
            kind: AttachmentKind.document,
          ),
        ],
      );

      // Nothing here filters by kind — the query the map reads does, and this
      // says the pure layer draws whatever it is handed rather than second-
      // guessing it. The rule lives in `watchPositionedPhotosForTrip`.
      expect(features.photos, hasLength(1));
    });

    test('they are drawn in gallery order, not the order they were added', () {
      final first = place(lat: 53.55, lon: 9.99, title: 'Day one');
      final member = leg(
        fromLat: 53.5,
        fromLon: 10.0,
        toLat: 50.1,
        toLon: 8.6,
      ).copyWith(groupId: const Value(7));
      // Handed over the way the query returns them — by their own sort order
      // and id, which is the order they were attached.
      final onLeg = photo(lat: 1, lon: 1, itemId: member.id);
      final onRun = photo(lat: 2, lon: 2, groupId: 7);
      final onEntry = photo(lat: 3, lon: 3, itemId: first.id);
      final onTrip = photo(lat: 4, lon: 4);

      final features = tripMapFeatures(
        [first, member],
        photos: [onLeg, onRun, onEntry, onTrip],
      );

      // The trip's own first, then the plan's, and a run's before those of the
      // entry it begins at — the same order the gallery opens in, which is what
      // decides which picture a cluster shows.
      expect(features.photos.map((p) => p.attachmentId), [
        onTrip.id,
        onEntry.id,
        onRun.id,
        onLeg.id,
      ]);
    });

    test('a photo is framed with everything else', () {
      final entry = place(lat: 53.55, lon: 9.99);
      final features = tripMapFeatures(
        [entry],
        photos: [photo(lat: 40.0, lon: -3.0, itemId: entry.id)],
      );

      // A picture taken a valley over is exactly what a viewport fitted to the
      // plan alone would cut off.
      expect(features.allPoints, hasLength(2));
      expect(features.allPoints.any((p) => p.latitude == 40.0), isTrue);
    });

    test('a trip with only a positioned photo is not an empty map', () {
      final entry = place();
      final features = tripMapFeatures(
        [entry],
        photos: [photo(lat: 53.1, lon: 9.1, itemId: entry.id)],
      );

      expect(features.pins, isEmpty);
      expect(features.paths, isEmpty);
      expect(features.isEmpty, isFalse);
    });
  });
}
