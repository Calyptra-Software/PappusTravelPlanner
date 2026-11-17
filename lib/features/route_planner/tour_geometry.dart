import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'domain/tour.dart';

/// Where a tap on a run's line falls: which section of the tour, and the point
/// on the line nearest the tap.
typedef RunLocation = ({int section, LatLng point});

/// Reads a tap on the line a run is drawn as.
///
/// [line] is that line, the router's or the straight one through the run's
/// waypoints. A run holds several sections when waypoints inside it only shape
/// the line, and a tap means the one it landed in: the answer is the index of
/// that section in [Tour.modes], with the tap snapped onto the line, since a
/// point set into a section has to lie on it.
///
/// The run's inner waypoints are found on the line **in order**, each searched
/// only behind the one before it, so a run that passes one spot twice still
/// puts each waypoint where the line reaches it.
///
/// Null when [line] has fewer than two points.
RunLocation? locateOnRun(
  Tour tour,
  TourRun run,
  List<LatLng> line,
  LatLng tap,
) {
  if (line.length < 2) return null;
  final at = _nearest(line, tap, from: 0);
  var section = run.first;
  var behind = 0.0;
  for (var index = run.first + 1; index < run.last; index++) {
    final waypoint = _nearest(
      line,
      tour.waypoints[index].position,
      from: behind,
    );
    if (waypoint.along > at.along) break;
    behind = waypoint.along;
    section = index;
  }
  return (section: section, point: at.point);
}

/// The point of [line] nearest [target] at or behind [from], and how far along
/// the line it lies: the index of its segment plus the fraction of the segment
/// covered.
({double along, LatLng point}) _nearest(
  List<LatLng> line,
  LatLng target, {
  required double from,
}) {
  // Degrees of longitude are shorter than degrees of latitude by this factor;
  // at the scale of a tap that is all the projection a comparison needs.
  final shrink = math.cos(target.latitude * math.pi / 180);
  var best = (along: from, point: line[from.floor().clamp(0, line.length - 1)]);
  var bestDistance = double.infinity;
  for (var segment = from.floor(); segment < line.length - 1; segment++) {
    final a = line[segment];
    final b = line[segment + 1];
    final dx = (b.longitude - a.longitude) * shrink;
    final dy = b.latitude - a.latitude;
    final px = (target.longitude - a.longitude) * shrink;
    final py = target.latitude - a.latitude;
    final lengthSquared = dx * dx + dy * dy;
    var t = lengthSquared == 0 ? 0.0 : (px * dx + py * dy) / lengthSquared;
    t = t.clamp(segment == from.floor() ? from - segment : 0.0, 1.0);
    final ex = px - t * dx;
    final ey = py - t * dy;
    final distance = ex * ex + ey * ey;
    if (distance < bestDistance) {
      bestDistance = distance;
      best = (
        along: segment + t,
        point: LatLng(
          a.latitude + t * (b.latitude - a.latitude),
          a.longitude + t * (b.longitude - a.longitude),
        ),
      );
    }
  }
  return best;
}
