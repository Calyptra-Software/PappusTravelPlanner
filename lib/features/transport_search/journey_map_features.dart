import 'package:latlong2/latlong.dart';

import '../../data/database/app_database.dart';
import '../../data/database/stopovers.dart';

/// What the journey screen's map draws besides the legs' own lines: a dot for
/// every stop it knows the position of, and the rest of each vehicle's run as a
/// quiet line beyond the leg.
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

  /// The vehicle's run outside each leg, as straight lines from stop to stop:
  /// the trip keeps no shape for it, only where its stops are.
  final List<List<LatLng>> runLines;

  /// Every stop with a known position, each once: a leg's ends, the stops it
  /// passes through, and the stops of its run outside it.
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
/// A stop met twice is drawn once, as what it is to the traveler: the station
/// one leg arrives at and the next leaves from is one end, not two, and an end
/// that is also a stop of a run (a train going on past where it is left) is an
/// end. Positions compare exactly, since both come from the same router.
JourneyMapFeatures journeyMapFeatures(List<ItineraryItem> legs) {
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

    final run = decodeRunStops(leg.runStops);
    if (run == null) continue;
    final before = _located(run.before);
    final after = _located(run.after);
    for (final (point, name) in [...before, ...after]) {
      add(JourneyStop(point: point, name: name, outside: true));
    }
    // Joined to the leg's own end, so the run reads as the line it is on.
    final beforeLine = [for (final (point, _) in before) point, ?from];
    final afterLine = [?to, for (final (point, _) in after) point];
    if (beforeLine.length > 1) runLines.add(beforeLine);
    if (afterLine.length > 1) runLines.add(afterLine);
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
