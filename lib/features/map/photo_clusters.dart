/// Gathering the photographs that would otherwise sit on top of each other.
///
/// The gathering itself is `map_clusters.dart` — pixels on a screen, measured
/// through the camera's own projection. What is here is what a gathered
/// photograph *is*: the picture whose thumbnail is drawn, and how many others
/// it stands for.
library;

import 'dart:math' as math;

import 'map_clusters.dart';
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
/// Handed over in gallery order, so a cluster keeps the same face while the map
/// moves — and so the front of a cluster is the picture the gallery opens on.
/// See [clusterOnScreen] for the rest of the rule.
List<PhotoCluster> clusterPhotos(
  List<MapPhoto> photos, {
  required math.Point<double> Function(MapPhoto) project,
  double radius = kPhotoClusterRadius,
}) => [
  for (final members in clusterOnScreen(
    photos,
    project: project,
    radius: radius,
  ))
    PhotoCluster(members),
];
