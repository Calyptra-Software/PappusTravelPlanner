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

void main() {
  test('every stop with a position is drawn once', () {
    final features = journeyMapFeatures([_ice, _regional]);

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

  test('the run lies outside the legs and joins them at their ends', () {
    final features = journeyMapFeatures([_ice]);

    expect(features.runLines, [
      [_bergedorf, _harburg],
      [_lueneburg, _hannover],
    ]);
    final bergedorf = features.stops.singleWhere((s) => s.name == 'Bergedorf');
    expect(bergedorf.outside, isTrue);
    expect(bergedorf.end, isFalse);
    final meckelfeld = features.stops.singleWhere(
      (s) => s.name == 'Meckelfeld',
    );
    expect(meckelfeld.outside, isFalse);
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

    final features = journeyMapFeatures([through, _regional]);

    final lueneburg = features.stops.singleWhere((s) => s.name == 'Lüneburg');
    expect(lueneburg.end, isTrue);
    expect(lueneburg.outside, isFalse);
  });

  test('the camera frames the journey, not the run around it', () {
    final features = journeyMapFeatures([_ice]);

    expect(features.frame, [_harburg, _meckelfeld, _lueneburg]);
  });

  test('a run never loaded draws nothing beyond the leg', () {
    final features = journeyMapFeatures([_regional]);

    expect(features.runLines, isEmpty);
    expect(features.stops.every((s) => !s.outside), isTrue);
  });
}
