import 'dart:math' as math;

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/map/map_features.dart';
import 'package:travelplanner/features/map/pin_clusters.dart';
import 'package:travelplanner/features/map/widgets/map_overlays.dart';

/// Gathering the place marks on the all-trips map, where a commute drawn once
/// per day it was made puts twenty pins on one spot.
void main() {
  Trip trip(int id) => Trip(
    id: id,
    title: 'Trip $id',
    destination: '',
    colorValue: 0xFF00695C + id,
    coverHidden: false,
    photosCollapsed: false,
    createdAt: DateTime(2026, 5, 1),
    kind: TripKind.trip,
  );

  var nextId = 0;
  TripPin pin(Trip owner, double lat, double lon) => TripPin(
    trip: owner,
    pin: MapPin(itemId: ++nextId, position: LatLng(lat, lon)),
  );

  setUp(() => nextId = 0);

  /// A projection where one degree is one hundred pixels, so distances in the
  /// tests read as pixels directly.
  math.Point<double> Function(TripPin) at(double scale) =>
      (p) => math.Point(
        p.pin.position.longitude * scale,
        p.pin.position.latitude * scale,
      );

  test('places far apart stay their own marks', () {
    final one = trip(1);
    final clusters = clusterPins([
      pin(one, 0, 0),
      pin(one, 0, 5),
    ], project: at(100));

    expect(clusters, hasLength(2));
    expect(clusters.every((c) => c.count == 1), isTrue);
  });

  test('two on one spot become one mark that says two', () {
    final one = trip(1);
    final clusters = clusterPins([
      pin(one, 0, 0),
      pin(one, 0, 0),
    ], project: at(100));

    expect(clusters.single.count, 2);
    // Its own position, not a middle where nothing is.
    expect(clusters.single.representative.pin.position, const LatLng(0, 0));
  });

  test('zooming in pulls them apart', () {
    final one = trip(1);
    final pins = [pin(one, 0, 0), pin(one, 0, 0.1)];

    expect(clusterPins(pins, project: at(100)), hasLength(1));
    // The same two places, the same radius — only the projection changed.
    expect(clusterPins(pins, project: at(1000)), hasLength(2));
  });

  test('a mark of one trip names just that trip, however many places', () {
    final one = trip(1);
    final clusters = clusterPins([
      pin(one, 0, 0),
      pin(one, 0, 0),
      pin(one, 0, 0),
    ], project: at(100));

    expect(clusters.single.count, 3);
    expect(clusters.single.trips.map((t) => t.id), [1]);
  });

  test('the trips under a mark are named once each, in the order given', () {
    // The overview's order, and the same fold the line hit test does: a stable
    // order is one the user can learn.
    final one = trip(1);
    final two = trip(2);
    final clusters = clusterPins([
      pin(one, 0, 0),
      pin(two, 0, 0),
      pin(one, 0, 0),
    ], project: at(100));

    expect(clusters.single.count, 3);
    expect(clusters.single.trips.map((t) => t.id), [1, 2]);
  });

  test('every place lands in exactly one mark', () {
    final one = trip(1);
    final pins = [
      for (var i = 0; i < 20; i++) pin(one, i % 3 * 0.05, i % 5 * 0.05),
    ];

    final clusters = clusterPins(pins, project: at(100));
    final seen = [
      for (final c in clusters)
        for (final p in c.members) p.pin.itemId,
    ];

    expect(seen.toSet(), pins.map((p) => p.pin.itemId).toSet());
    expect(seen.length, pins.length);
  });

  group('what a gathered mark is drawn in', () {
    const teal = Color(0xFF00695C);
    const orange = Color(0xFFEF6C00);

    test('the color they all agree on', () {
      expect(gatheredPinColor([teal, teal, teal]), teal);
    });

    test('agreement, not identity', () {
      // Two trips that happen to share an accent, or two entries given the same
      // color: drawing the mark in it says nothing that was not already true,
      // so the neutral would only be throwing information away.
      expect(gatheredPinColor([teal, teal]), teal);
    });

    test('the neutral once it would have to pick one of several', () {
      expect(gatheredPinColor([teal, orange]), kMixedPinColor);
    });

    test('one color is that color', () {
      expect(gatheredPinColor([orange]), orange);
    });
  });

  test('one place needs no projection at all', () {
    final clusters = clusterPins([
      pin(trip(1), 0, 0),
    ], project: (_) => throw StateError('should not project'));

    expect(clusters.single.count, 1);
  });
}
