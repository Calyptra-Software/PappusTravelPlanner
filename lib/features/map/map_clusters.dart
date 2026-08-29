/// Gathering the marks that would otherwise sit on top of each other.
///
/// Pure, like the rest of what the map draws from: clustering is a rule about
/// distances on a screen, and a rule is worth testing without a tile server
/// under it.
///
/// The distance is measured in **pixels, not degrees**, which is the whole
/// point: two marks in the same square metre overlap at every zoom until the
/// map is scaled enough to separate them, and a threshold in metres would
/// either group them forever or never. Zoom in and the same marks come apart,
/// because the projection they are measured through has changed.
///
/// One definition, two callers — `photo_clusters.dart` and `pin_clusters.dart`.
/// What is gathered differs (a picture keeps its face, a pin keeps its trip's
/// accent); *which* marks fall together is one question, and two answers to it
/// would drift.
library;

import 'dart:math' as math;

/// Groups the [items] that land within [radius] pixels of each other.
///
/// [project] turns an item into screen coordinates — the camera's job, and the
/// reason this takes a function rather than a zoom level: what "close" means is
/// whatever the map is currently doing, including a rotation this app does not
/// allow and a projection it might change.
///
/// Greedy from the first item onwards, so the answer depends only on the order
/// it is given. A cluster therefore keeps the same face while the map moves,
/// instead of changing what it stands for every time the camera shifts by a
/// pixel — which is why the caller hands its items over in an order that means
/// something (gallery order for photographs, the overview's for trips).
///
/// Every item lands in exactly one group, and the group's first member is the
/// one that started it.
List<List<T>> clusterOnScreen<T>(
  List<T> items, {
  required math.Point<double> Function(T) project,
  required double radius,
}) {
  if (items.length < 2) {
    return [
      for (final item in items) [item],
    ];
  }
  final points = [for (final item in items) project(item)];
  final taken = List<bool>.filled(items.length, false);
  final clusters = <List<T>>[];
  final radiusSquared = radius * radius;

  for (var i = 0; i < items.length; i++) {
    if (taken[i]) continue;
    taken[i] = true;
    final members = <T>[items[i]];
    for (var j = i + 1; j < items.length; j++) {
      if (taken[j]) continue;
      final dx = points[j].x - points[i].x;
      final dy = points[j].y - points[i].y;
      // Measured against the one that started the cluster, not against whatever
      // joined it last: chaining would let a line of marks a screen wide
      // collapse into one, each within a thumb of its neighbour.
      if (dx * dx + dy * dy <= radiusSquared) {
        taken[j] = true;
        members.add(items[j]);
      }
    }
    clusters.add(members);
  }
  return clusters;
}
