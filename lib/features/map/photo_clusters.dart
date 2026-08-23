/// Gathering the photographs that would otherwise sit on top of each other.
///
/// Pure, like the rest of what the map draws from: clustering is a rule about
/// distances on a screen, and a rule is worth testing without a tile server
/// under it.
///
/// The distance is measured in **pixels, not degrees**, which is the whole
/// point: two pictures taken in the same square metre overlap at every zoom
/// until the map is scaled enough to separate them, and a threshold in metres
/// would either group them forever or never. Zoom in and the same photographs
/// come apart, because the projection they are measured through has changed.
library;

import 'dart:math' as math;

import 'map_features.dart';

/// How close two photographs must be on screen before one hides the other.
///
/// A little wider than a marker, so they are gathered before they overlap
/// rather than after: a picture half behind another is worse than a count.
const double kPhotoClusterRadius = 44;

/// One thumbnail on the map, standing for one or more photographs.
final class PhotoCluster {
  const PhotoCluster(this.photos);

  /// At least one, in the order the gallery lists them.
  final List<MapPhoto> photos;

  /// The one whose thumbnail is drawn, and whose position the mark sits on.
  ///
  /// The first in gallery order, and its *own* position rather than the middle
  /// of the group: this app does not put a mark where nothing is. The others
  /// are within [kPhotoClusterRadius] of it, so the difference is a thumb's
  /// width.
  MapPhoto get representative => photos.first;

  int get count => photos.length;
}

/// Groups [photos] that land within [radius] pixels of each other.
///
/// [project] turns a position into screen coordinates — the camera's job, and
/// the reason this takes a function rather than a zoom level: what "close"
/// means is whatever the map is currently doing, including a rotation this app
/// does not allow and a projection it might change.
///
/// Greedy from the first photograph onwards, so the answer depends only on the
/// order it is given — which is gallery order. A cluster therefore keeps the
/// same face while the map moves, instead of changing which picture it shows
/// every time the camera shifts by a pixel.
List<PhotoCluster> clusterPhotos(
  List<MapPhoto> photos, {
  required math.Point<double> Function(MapPhoto) project,
  double radius = kPhotoClusterRadius,
}) {
  if (photos.length < 2) {
    return [
      for (final photo in photos) PhotoCluster([photo]),
    ];
  }
  final points = [for (final photo in photos) project(photo)];
  final taken = List<bool>.filled(photos.length, false);
  final clusters = <PhotoCluster>[];
  final radiusSquared = radius * radius;

  for (var i = 0; i < photos.length; i++) {
    if (taken[i]) continue;
    taken[i] = true;
    final members = <MapPhoto>[photos[i]];
    for (var j = i + 1; j < photos.length; j++) {
      if (taken[j]) continue;
      final dx = points[j].x - points[i].x;
      final dy = points[j].y - points[i].y;
      // Measured against the one that started the cluster, not against whatever
      // joined it last: chaining would let a line of pictures a screen wide
      // collapse into one mark, each within a thumb of its neighbour.
      if (dx * dx + dy * dy <= radiusSquared) {
        taken[j] = true;
        members.add(photos[j]);
      }
    }
    clusters.add(PhotoCluster(members));
  }
  return clusters;
}
