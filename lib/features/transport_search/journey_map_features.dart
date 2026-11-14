import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../data/database/app_database.dart';
import '../../data/database/stopovers.dart';

/// What the journey screen's map draws besides the legs' own lines: a dot for
/// every stop it knows the position of, and, for a leg whose run has been asked
/// for, the rest of its vehicle's run as a quiet line beyond the leg.
///
/// The legs themselves are drawn by `tripMapFeatures`, as on the trip's map, so
/// one leg cannot be drawn by two sets of rules: its routed shape dashed, a
/// recording solid, its color, and red while it is under way. What is added
/// here is what only a journey shows, its stops and the run around it.
///
/// Pure, so what lands where is testable without a map.
class JourneyMapFeatures {
  const JourneyMapFeatures({
    this.runLines = const [],
    this.stops = const [],
    this.frame = const [],
  });

  /// The vehicle's run outside each leg whose run is shown, along the route
  /// it takes. Never a straight line from stop to stop: that would draw a
  /// route nobody takes, so a run whose route is not to hand draws its stops
  /// and no line.
  final List<List<LatLng>> runLines;

  /// Every stop with a known position, each once: a leg's ends, the stops it
  /// passes through, and, where its run is shown, the stops outside it.
  final List<JourneyStop> stops;

  /// What the camera opens on: the journey itself, its ends and the stops in
  /// between. Not the run around it, which may reach across the country and
  /// is context to be scrolled to rather than what was asked about.
  final List<LatLng> frame;
}

/// One stop on the journey's map.
class JourneyStop {
  const JourneyStop({
    required this.point,
    required this.name,
    this.end = false,
    this.outside = false,
  });

  final LatLng point;
  final String name;

  /// Whether the traveler gets on or off here: a leg's end, drawn larger.
  final bool end;

  /// Whether the stop lies outside the traveler's legs, on the run before
  /// boarding or after getting off: drawn in the quiet color its line is.
  final bool outside;
}

/// The stops and the run around [legs], the journey's transport legs in the
/// order it travels them.
///
/// The run around a leg is drawn only for the legs in [shownRuns] (by item
/// id): it is asked for, leg by leg, and put away again, since a journey's own
/// route is often what someone wants to look at. Its line is the route in
/// [runShapes], the whole run's, which is cut where the leg boards and gets
/// off ([splitRunShape]).
///
/// A stop met twice is drawn once, as what it is to the traveler: the station
/// one leg arrives at and the next leaves from is one end, not two, and an end
/// that is also a stop of a run (a train going on past where it is left) is an
/// end. Positions compare exactly, since both come from the same router.
JourneyMapFeatures journeyMapFeatures(
  List<ItineraryItem> legs, {
  Set<int> shownRuns = const {},
  Map<int, List<LatLng>> runShapes = const {},
}) {
  final runLines = <List<LatLng>>[];
  final frame = <LatLng>[];
  final byPoint = <LatLng, JourneyStop>{};

  void add(JourneyStop stop) {
    final seen = byPoint[stop.point];
    // An end outranks a stop passed through, which outranks one outside.
    if (seen == null || _rank(stop) > _rank(seen)) byPoint[stop.point] = stop;
  }

  for (final leg in legs) {
    final from = _point(leg.fromLat, leg.fromLon);
    final to = _point(leg.toLat, leg.toLon);
    if (from != null) {
      add(JourneyStop(point: from, name: leg.fromLocation ?? '', end: true));
      frame.add(from);
    }
    for (final stop in decodeStopovers(leg.stopovers)) {
      final point = _point(stop.lat, stop.lon);
      if (point == null) continue;
      add(JourneyStop(point: point, name: stop.name));
      frame.add(point);
    }
    if (to != null) {
      add(JourneyStop(point: to, name: leg.toLocation ?? '', end: true));
      frame.add(to);
    }

    if (!shownRuns.contains(leg.id)) continue;
    final run = decodeRunStops(leg.runStops);
    if (run == null) continue;
    for (final (point, name) in [
      ..._located(run.before),
      ..._located(run.after),
    ]) {
      add(JourneyStop(point: point, name: name, outside: true));
    }
    final shape = runShapes[leg.id];
    if (shape == null) continue;
    final parts = splitRunShape(shape, board: from, alight: to);
    if (parts == null) continue;
    if (parts.before.length > 1) runLines.add(parts.before);
    if (parts.after.length > 1) runLines.add(parts.after);
  }

  return JourneyMapFeatures(
    runLines: runLines,
    stops: byPoint.values.toList(),
    frame: frame,
  );
}

int _rank(JourneyStop stop) => stop.end ? 2 : (stop.outside ? 0 : 1);

List<(LatLng, String)> _located(List<Stopover> stops) => [
  for (final stop in stops)
    if (_point(stop.lat, stop.lon) case final point?) (point, stop.name),
];

LatLng? _point(double? lat, double? lon) =>
    lat == null || lon == null ? null : LatLng(lat, lon);

/// The route of a whole run cut where a leg boards and gets off: the part
/// [before] boarding, ending at the point nearest [board], and the part [after]
/// getting off, starting at the point nearest [alight]. Null when the leg has
/// no ends to cut at or the route is no line.
///
/// The leg's own part in between is left out: the leg is drawn from its own
/// stored route already. The alighting point is looked for only after the
/// boarding one, so a route that passes the same place twice (a bus around a
/// loop) is cut in the order it is traveled; a boarding point that a loop
/// passes twice is taken where the route comes nearest, which is the one place
/// this can be wrong.
({List<LatLng> before, List<LatLng> after})? splitRunShape(
  List<LatLng> shape, {
  required LatLng? board,
  required LatLng? alight,
}) {
  if (shape.length < 2 || board == null || alight == null) return null;
  final boardAt = _nearest(shape, board, from: 0);
  final alightAt = _nearest(shape, alight, from: boardAt);
  return (
    before: shape.sublist(0, boardAt + 1),
    after: shape.sublist(alightAt),
  );
}

/// The index of the point in [points] from [from] on that lies nearest [to],
/// by an equirectangular distance: exact enough to tell a station from the
/// next, and cheap over the ten thousand points of a long-distance run.
int _nearest(List<LatLng> points, LatLng to, {required int from}) {
  final scale = math.cos(to.latitude * math.pi / 180);
  var best = from;
  var bestDistance = double.infinity;
  for (var i = from; i < points.length; i++) {
    final dLat = points[i].latitude - to.latitude;
    final dLon = (points[i].longitude - to.longitude) * scale;
    final distance = dLat * dLat + dLon * dLon;
    if (distance < bestDistance) {
      bestDistance = distance;
      best = i;
    }
  }
  return best;
}
