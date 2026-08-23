import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/features/map/map_features.dart';
import 'package:travelplanner/features/map/photo_clusters.dart';

/// Gathering photographs that would otherwise sit on top of each other.
void main() {
  var nextId = 0;
  MapPhoto photo(double lat, double lon, {int? colorValue}) => MapPhoto(
    attachmentId: ++nextId,
    position: LatLng(lat, lon),
    colorValue: colorValue,
  );

  setUp(() => nextId = 0);

  /// A projection where one degree is one hundred pixels, so distances in the
  /// tests read as pixels directly.
  math.Point<double> Function(MapPhoto) at(double scale) =>
      (p) =>
          math.Point(p.position.longitude * scale, p.position.latitude * scale);

  test('nothing to gather leaves each on its own', () {
    final clusters = clusterPhotos([
      photo(0, 0),
      photo(0, 5),
    ], project: at(100));

    expect(clusters, hasLength(2));
    expect(clusters.every((c) => c.count == 1), isTrue);
  });

  test('two within the radius become one mark that says two', () {
    final clusters = clusterPhotos([
      photo(0, 0),
      photo(0, 0.1), // ten pixels away
    ], project: at(100));

    expect(clusters, hasLength(1));
    expect(clusters.single.count, 2);
  });

  test('the mark keeps the first one\'s face and its own position', () {
    final first = photo(0, 0);
    final second = photo(0, 0.1);
    final clusters = clusterPhotos([first, second], project: at(100));

    // Gallery order decides, so a cluster does not change which picture it
    // shows every time the camera shifts by a pixel — and the mark sits where
    // that picture is, not at a middle where nothing was taken.
    expect(clusters.single.representative.attachmentId, first.attachmentId);
    expect(clusters.single.representative.position, first.position);
  });

  test('zooming in pulls them apart', () {
    final photos = [photo(0, 0), photo(0, 0.1)];

    expect(clusterPhotos(photos, project: at(100)), hasLength(1));
    // The same two photographs, the same radius — only the projection changed.
    expect(clusterPhotos(photos, project: at(1000)), hasLength(2));
  });

  test('a line of pictures does not chain into one mark', () {
    // Each is within the radius of its neighbour, but the far ends are a
    // screen apart: measured from the one that starts the cluster, they cannot
    // all collapse together.
    final photos = [for (var i = 0; i < 8; i++) photo(0, i * 0.3)];

    final clusters = clusterPhotos(photos, project: at(100));

    expect(clusters.length, greaterThan(1));
    for (final cluster in clusters) {
      final anchor = cluster.representative.position.longitude * 100;
      for (final member in cluster.photos) {
        expect(
          (member.position.longitude * 100 - anchor).abs(),
          lessThanOrEqualTo(kPhotoClusterRadius),
        );
      }
    }
  });

  test('every photograph lands in exactly one mark', () {
    final photos = [
      for (var i = 0; i < 20; i++) photo(i % 3 * 0.05, i % 5 * 0.05),
    ];

    final clusters = clusterPhotos(photos, project: at(100));
    final seen = [
      for (final c in clusters)
        for (final p in c.photos) p.attachmentId,
    ];

    expect(seen.toSet(), photos.map((p) => p.attachmentId).toSet());
    expect(seen.length, photos.length);
  });

  test('one photograph needs no projection at all', () {
    // The short path, so a trip with a single picture does not pay for a
    // camera round trip on every frame.
    final clusters = clusterPhotos([
      photo(0, 0),
    ], project: (_) => throw StateError('should not project'));

    expect(clusters.single.count, 1);
  });
}
