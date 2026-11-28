import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// How far from a planned line a position may lie and still be on it, in
/// meters, before the position's own accuracy is added: a path drawn a little
/// off the one walked, a fix a little off the path.
const double kOnRouteMeters = 150;

/// One leg of a planned route, as progress against the plan reads it: its
/// line, how the leg's time spreads along it (`effortAlong`), and when it
/// starts and ends.
class PlannedStretch {
  PlannedStretch({
    required this.points,
    required this.effort,
    required this.start,
    required this.end,
  }) : assert(points.length == effort.length && points.length > 1);

  final List<LatLng> points;
  final List<double> effort;
  final DateTime start;
  final DateTime end;

  /// When the plan has its traveler at the point [fraction] of the way from
  /// point [index] to the next.
  DateTime timeAt(int index, double fraction) {
    final total = effort.last;
    final reached =
        effort[index] + fraction * (effort[index + 1] - effort[index]);
    final share = total <= 0 ? 0.0 : reached / total;
    final span = end.difference(start).inMilliseconds;
    return start.add(Duration(milliseconds: (share * span).round()));
  }
}

/// Where a traveler stands against the plan of their route.
sealed class PlanProgress {
  const PlanProgress();
}

/// On the planned line, [behind] the plan (ahead of it where negative), and
/// so arriving at the route's end at [arrival] if the rest goes as planned.
class OnRoute extends PlanProgress {
  const OnRoute({required this.behind, required this.arrival});

  final Duration behind;
  final DateTime arrival;
}

/// Farther from every planned line than [kOnRouteMeters] and the fix's
/// accuracy: lost, on a shortcut, or not on the route at all.
class OffRoute extends PlanProgress {
  const OffRoute();
}

/// Where [position], read at [now], stands against [stretches], the legs of a
/// planned route in order. Null without stretches, and before the first one
/// starts, when there is no plan to be behind yet.
///
/// The position is put on the nearest point of every stretch of line within
/// reach, and of those the one the plan reaches nearest to [now] is taken: a
/// path walked out and back passes each point twice, and the time tells the
/// way out from the way back. What the traveler is behind is the time from
/// when the plan had them there to [now]; the arrival is the route's planned
/// end moved by as much.
PlanProgress? progressAgainstPlan(
  List<PlannedStretch> stretches,
  LatLng position,
  DateTime now, {
  double accuracyMeters = 0,
}) {
  if (stretches.isEmpty || now.isBefore(stretches.first.start)) return null;
  final reach = kOnRouteMeters + math.max(0, accuracyMeters);
  final local = _LocalPlane(position);
  DateTime? best;
  for (final stretch in stretches) {
    final points = stretch.points;
    for (var i = 0; i + 1 < points.length; i++) {
      final a = local.of(points[i]);
      final b = local.of(points[i + 1]);
      final dx = b.x - a.x;
      final dy = b.y - a.y;
      final squared = dx * dx + dy * dy;
      final t = squared == 0
          ? 0.0
          : ((-a.x * dx - a.y * dy) / squared).clamp(0.0, 1.0);
      final x = a.x + t * dx;
      final y = a.y + t * dy;
      if (math.sqrt(x * x + y * y) > reach) continue;
      final planned = stretch.timeAt(i, t);
      if (best == null ||
          now.difference(planned).abs() < now.difference(best).abs()) {
        best = planned;
      }
    }
  }
  if (best == null) return const OffRoute();
  final behind = now.difference(best);
  return OnRoute(behind: behind, arrival: stretches.last.end.add(behind));
}

/// Meters east and north of an origin, flat: exact enough within the reach
/// of a planned line, and cheap enough to ask every second.
class _LocalPlane {
  _LocalPlane(this.origin)
    : _east = 111320 * math.cos(origin.latitude * math.pi / 180);

  final LatLng origin;
  final double _east;
  static const double _north = 110574;

  ({double x, double y}) of(LatLng point) => (
    x: (point.longitude - origin.longitude) * _east,
    y: (point.latitude - origin.latitude) * _north,
  );
}
