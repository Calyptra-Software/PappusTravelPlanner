import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/stopovers.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/transport_search/journey_map_features.dart';

/// Harburg → Lüneburg on an ICE that started in Bergedorf and goes on to
/// Hannover, then a regional train on from Lüneburg to Uelzen.
ItineraryItem _leg({
  required int id,
  required String from,
  required LatLng fromPoint,
  required String to,
  required LatLng toPoint,
  List<Stopover> stops = const [],
  RunStops? run,
}) => ItineraryItem(
  id: id,
  tripId: 7,
  date: DateTime(2026, 11, 15),
  sortOrder: id,
  kind: ItemKind.transport,
  endDayOffset: 0,
  chordDisplay: TrackDisplay.auto,
  fromLocation: from,
  toLocation: to,
  fromLat: fromPoint.latitude,
  fromLon: fromPoint.longitude,
  toLat: toPoint.latitude,
  toLon: toPoint.longitude,
  stopovers: encodeStopovers(stops),
  runStops: run == null ? null : encodeRunStops(run),
);

const _bergedorf = LatLng(53.49, 10.21);
const _harburg = LatLng(53.456, 9.992);
const _meckelfeld = LatLng(53.424, 10.03);
const _lueneburg = LatLng(53.25, 10.42);
const _hannover = LatLng(52.377, 9.741);
const _uelzen = LatLng(52.966, 10.56);

final _ice = _leg(
  id: 1,
  from: 'Hamburg-Harburg',
  fromPoint: _harburg,
  to: 'Lüneburg',
  toPoint: _lueneburg,
  stops: [
    Stopover(
      name: 'Meckelfeld',
      minutes: 560,
      lat: _meckelfeld.latitude,
      lon: _meckelfeld.longitude,
    ),
    // Imported before positions were kept: nothing to draw.
    const Stopover(name: 'Winsen (Luhe)', minutes: 565),
  ],
  run: RunStops(
    before: [
      Stopover(
        name: 'Bergedorf',
        minutes: 528,
        lat: _bergedorf.latitude,
        lon: _bergedorf.longitude,
      ),
    ],
    after: [
      Stopover(
        name: 'Hannover Hbf',
        minutes: 627,
        lat: _hannover.latitude,
        lon: _hannover.longitude,
      ),
    ],
  ),
);

final _regional = _leg(
  id: 2,
  from: 'Lüneburg',
  fromPoint: _lueneburg,
  to: 'Uelzen',
  toPoint: _uelzen,
);

/// The ICE's whole route as the router would give it: out of Bergedorf,
/// through Harburg, Meckelfeld and Lüneburg, and on to Hannover.
const _shape = [
  _bergedorf,
  LatLng(53.47, 10.1),
  _harburg,
  _meckelfeld,
  _lueneburg,
  LatLng(52.8, 10.0),
  _hannover,
];

void main() {
  test('every stop with a position is drawn once', () {
    final features = journeyMapFeatures([_ice, _regional], shownRuns: {1});

    expect(
      features.stops.map((s) => s.name),
      unorderedEquals([
        'Hamburg-Harburg',
        'Meckelfeld',
        'Lüneburg',
        'Uelzen',
        'Bergedorf',
        'Hannover Hbf',
      ]),
    );
    // Lüneburg is where one leg ends and the next starts: one end, not two.
    final lueneburg = features.stops.where((s) => s.name == 'Lüneburg');
    expect(lueneburg.single.end, isTrue);
  });

  test('a run not asked for is not drawn, though it is stored', () {
    final features = journeyMapFeatures([_ice], runShapes: {1: _shape});

    expect(features.runLines, isEmpty);
    expect(features.stops.every((s) => !s.outside), isTrue);
  });

  test('a shown run follows its route outside the leg', () {
    final features = journeyMapFeatures(
      [_ice],
      shownRuns: {1},
      runShapes: {1: _shape},
    );

    // Cut where the leg boards and gets off; the leg's own part is the leg's.
    expect(features.runLines, [
      [_bergedorf, const LatLng(53.47, 10.1), _harburg],
      [_lueneburg, const LatLng(52.8, 10.0), _hannover],
    ]);
    final bergedorf = features.stops.singleWhere((s) => s.name == 'Bergedorf');
    expect(bergedorf.outside, isTrue);
    expect(bergedorf.end, isFalse);
    final meckelfeld = features.stops.singleWhere(
      (s) => s.name == 'Meckelfeld',
    );
    expect(meckelfeld.outside, isFalse);
  });

  test('a shown run without its route draws its stops and no line', () {
    // Never a straight line between stops: that is a route nobody takes.
    final features = journeyMapFeatures([_ice], shownRuns: {1});

    expect(features.runLines, isEmpty);
    expect(
      features.stops.where((s) => s.outside).map((s) => s.name),
      unorderedEquals(['Bergedorf', 'Hannover Hbf']),
    );
  });

  test('an end the run passes through stays an end', () {
    // The ICE goes on through Lüneburg, where the traveler changes: the run's
    // stop there is the traveler's end, and is drawn as one.
    final through = _leg(
      id: 3,
      from: 'Hamburg-Harburg',
      fromPoint: _harburg,
      to: 'Meckelfeld',
      toPoint: _meckelfeld,
      run: RunStops(
        after: [
          Stopover(
            name: 'Lüneburg',
            minutes: 568,
            lat: _lueneburg.latitude,
            lon: _lueneburg.longitude,
          ),
        ],
      ),
    );

    final features = journeyMapFeatures([through, _regional], shownRuns: {3});

    final lueneburg = features.stops.singleWhere((s) => s.name == 'Lüneburg');
    expect(lueneburg.end, isTrue);
    expect(lueneburg.outside, isFalse);
  });

  test('the camera frames the journey, not the run around it', () {
    final features = journeyMapFeatures(
      [_ice],
      shownRuns: {1},
      runShapes: {1: _shape},
    );

    expect(features.frame, [_harburg, _meckelfeld, _lueneburg]);
  });

  group('splitRunShape', () {
    test('a route passing the same place twice is cut in traveling order', () {
      // A bus around a loop: it passes the alighting stop (C) on its way out
      // too, before the boarding stop (B). The second pass is the one meant.
      const a = LatLng(50.0, 8.0);
      const c = LatLng(50.0, 8.1);
      const b = LatLng(50.0, 8.2);
      const d = LatLng(50.1, 8.1);
      final parts = splitRunShape([a, c, b, d, c, a], board: b, alight: c)!;

      expect(parts.before, [a, c, b]);
      expect(parts.after, [c, a]);
    });

    test('nothing to cut at, nothing cut', () {
      expect(splitRunShape(_shape, board: null, alight: _hannover), isNull);
      expect(
        splitRunShape(const [_harburg], board: _harburg, alight: _harburg),
        isNull,
      );
    });
  });
}
