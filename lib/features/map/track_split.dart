import 'package:latlong2/latlong.dart';

const Distance _distance = Distance(calculator: Haversine());

/// Cuts one recording into the stretches its entries covered.
///
/// A recording is made in one go and the plan it belongs to is not: a morning
/// walk crosses two footpaths and a bus, and the file knows nothing of that.
/// This is where the two are reconciled — the line is divided at the points
/// where one entry handed over to the next, so each ends up with the ground it
/// actually covered and none of the ground it did not.
///
/// [boundaries] are the handovers *between* consecutive entries, in order, and
/// there is one fewer of them than there are stretches. A boundary is null when
/// nobody could say where it falls: no coordinate on either side, and the user
/// declined to point at one. Those are placed by dividing the distance between
/// their known neighbours evenly, which is a guess — and the only one here.
///
/// Two properties matter more than the exact cut, because they are what a later
/// edit could otherwise break:
///
/// * **Every stretch gets points.** An entry left without a piece would go back
///   to drawing the straight line between its ends the moment somebody gave it
///   coordinates, which is the thing this whole feature exists to avoid — and it
///   would happen weeks later, with nothing having touched the track.
/// * **Neighbours share their boundary point**, so the pieces still read as one
///   line. Cutting between two points would leave a gap at every handover.
///
/// Boundaries are located **in order**, each searched only in the part of the
/// line left after the one before it. That is what makes a there-and-back route
/// work: the turning point is passed twice, so "nearest to this coordinate" is
/// ambiguous while "nearest *after* the last handover" is not.
List<List<LatLng>> splitTrack(List<LatLng> points, List<LatLng?> boundaries) {
  if (boundaries.isEmpty) return [points];
  if (points.length < 2) {
    return [for (var i = 0; i <= boundaries.length; i++) points];
  }

  final cuts = _cutIndices(points, boundaries);
  return [
    for (var i = 0; i <= boundaries.length; i++)
      points.sublist(
        i == 0 ? 0 : cuts[i - 1],
        (i == boundaries.length ? points.length - 1 : cuts[i]) + 1,
      ),
  ];
}

/// The same across a recording that stopped and started again.
///
/// A file's `<trkseg>`s are one outing with holes in it — a tunnel, a pause, a
/// lost fix — so the handovers are looked for along the whole sequence, while
/// the holes survive: a stretch spanning one keeps it, and comes back as *two*
/// lines for that entry rather than one drawn across ground nobody covered.
///
/// Returns one list of lines per stretch, in the order [lines] arrived in.
List<List<List<LatLng>>> splitTracks(
  List<List<LatLng>> lines,
  List<LatLng?> boundaries,
) {
  // Flattened, with each point remembering which line it came from, so a cut
  // can be looked for along the outing and rebuilt within its segments.
  final flat = <LatLng>[];
  final owner = <int>[];
  for (var i = 0; i < lines.length; i++) {
    for (final point in lines[i]) {
      flat.add(point);
      owner.add(i);
    }
  }
  if (flat.length < 2) return [for (var i = 0; i <= boundaries.length; i++) []];
  if (boundaries.isEmpty) return [lines];

  final cuts = _cutIndices(flat, boundaries);
  return [
    for (var stretch = 0; stretch <= boundaries.length; stretch++)
      _linesBetween(
        flat,
        owner,
        stretch == 0 ? 0 : cuts[stretch - 1],
        stretch == boundaries.length ? flat.length - 1 : cuts[stretch],
      ),
  ];
}

/// The flattened points from [from] to [to], cut back apart wherever the
/// recording had stopped.
List<List<LatLng>> _linesBetween(
  List<LatLng> flat,
  List<int> owner,
  int from,
  int to,
) {
  final out = <List<LatLng>>[];
  var start = from;
  for (var i = from + 1; i <= to; i++) {
    if (owner[i] != owner[i - 1]) {
      if (i - start >= 2) out.add(flat.sublist(start, i));
      start = i;
    }
  }
  if (to + 1 - start >= 2) out.add(flat.sublist(start, to + 1));
  return out;
}

/// The index each boundary falls on, strictly increasing, with room left for
/// every stretch to keep at least two points.
List<int> _cutIndices(List<LatLng> points, List<LatLng?> boundaries) {
  final cuts = List<int?>.filled(boundaries.length, null);

  // Pass one: everything anybody could say where it is.
  var searchFrom = 1;
  for (var i = 0; i < boundaries.length; i++) {
    final at = boundaries[i];
    if (at == null) continue;
    // Leave one point per remaining stretch, so a cut cannot swallow the ones
    // behind it on a line with barely more points than entries.
    final latest = points.length - 2 - (boundaries.length - 1 - i);
    if (searchFrom > latest) break;
    final index = _nearestIndex(points, at, searchFrom, latest);
    cuts[i] = index;
    searchFrom = index + 1;
  }

  // Pass two: the rest, spread by distance between the neighbours that are
  // placed — the guess, and the only one.
  var start = 0;
  while (start < cuts.length) {
    if (cuts[start] != null) {
      start++;
      continue;
    }
    var end = start;
    while (end < cuts.length && cuts[end] == null) {
      end++;
    }
    final fromIndex = start == 0 ? 0 : cuts[start - 1]!;
    final toIndex = end == cuts.length ? points.length - 1 : cuts[end]!;
    final placed = _spread(points, fromIndex, toIndex, end - start);
    for (var i = start; i < end; i++) {
      cuts[i] = placed[i - start];
    }
    start = end;
  }

  return [for (final cut in cuts) cut!];
}

/// [count] indices strictly between [from] and [to], at even distances along the
/// line rather than every so many points: a recording is dense where it was slow
/// and sparse where it was fast, so counting vertices would put every boundary
/// in the traffic jam.
List<int> _spread(List<LatLng> points, int from, int to, int count) {
  final lengths = <double>[0];
  for (var i = from + 1; i <= to; i++) {
    lengths.add(
      lengths.last + _distance.as(LengthUnit.Meter, points[i - 1], points[i]),
    );
  }
  final total = lengths.last;
  final out = <int>[];
  var cursor = from + 1;
  for (var k = 1; k <= count; k++) {
    if (total == 0) {
      // A stretch that stands still — the recorder left running. Nothing to
      // divide, so the boundaries fall one point apart.
      out.add(cursor.clamp(from + 1, to - 1));
      cursor++;
      continue;
    }
    final target = total * k / (count + 1);
    var index = from + 1;
    for (var i = 1; i < lengths.length; i++) {
      if (lengths[i] >= target) {
        index = from + i;
        break;
      }
    }
    out.add(index.clamp(cursor, to - 1));
    cursor = out.last + 1;
  }
  return out;
}

/// The point of [points] nearest to [target], looked for in `[from, to]`.
int _nearestIndex(List<LatLng> points, LatLng target, int from, int to) {
  var best = from;
  var bestDistance = double.infinity;
  for (var i = from; i <= to; i++) {
    final d = _distance.as(LengthUnit.Meter, points[i], target);
    if (d < bestDistance) {
      bestDistance = d;
      best = i;
    }
  }
  return best;
}

/// Where a tap lands on the line: the nearest recorded point at or after
/// [after].
///
/// Snapped, because a handover has to lie *on* the recording — a point beside it
/// would not divide anything — and because a fingertip is wider than a line. The
/// [after] bound is the same rule the cutting uses, so what the user points at
/// and what the split does cannot disagree.
LatLng? snapToTrack(List<LatLng> points, LatLng tap, {int after = 0}) {
  if (points.length < 2 || after >= points.length) return null;
  return points[_nearestIndex(points, tap, after, points.length - 1)];
}
