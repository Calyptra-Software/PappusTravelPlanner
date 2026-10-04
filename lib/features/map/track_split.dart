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
/// there is one fewer of them than there are stretches. Every one of them is
/// known: the import will not proceed until each has been pointed at, so there
/// is no rule here for dividing a line nobody has said anything about — and
/// therefore no guess anywhere in this file.
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
List<List<LatLng>> splitTrack(List<LatLng> points, List<LatLng> boundaries) {
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
  List<LatLng> boundaries,
) {
  final flat = [for (final line in lines) ...line];
  if (flat.length < 2) return [for (var i = 0; i <= boundaries.length; i++) []];
  if (boundaries.isEmpty) return [lines];
  return splitTracksAt(lines, [
    for (final cut in trackCutIndices(flat, boundaries)) cut!,
  ]);
}

/// [splitTracks] with the handovers already located: [cuts] are indices into
/// the recording read as one sequence, strictly increasing.
///
/// What the import screen divides by, because a handover there is a *point of
/// the line* once it has been placed — and so the division drawn and the one
/// written are the same division, not two searches that happen to agree.
List<List<List<LatLng>>> splitTracksAt(
  List<List<LatLng>> lines,
  List<int> cuts,
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
  if (flat.length < 2) return [for (var i = 0; i <= cuts.length; i++) []];
  if (cuts.isEmpty) return [lines];

  return [
    for (var stretch = 0; stretch <= cuts.length; stretch++)
      _linesBetween(
        flat,
        owner,
        stretch == 0 ? 0 : cuts[stretch - 1],
        stretch == cuts.length ? flat.length - 1 : cuts[stretch],
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
List<int> _cutIndices(List<LatLng> points, List<LatLng> boundaries) => [
  for (final cut in trackCutIndices(points, boundaries)) cut!,
];

/// Where each handover falls along [points], by the rule [splitTrack] cuts by,
/// or null for a handover nobody has placed yet.
///
/// An open handover is skipped but still **keeps its room**: one point is left
/// for it on either side, so placing it later never has to move the ones that
/// were already resolved around it.
List<int?> trackCutIndices(List<LatLng> points, List<LatLng?> boundaries) {
  final cuts = <int?>[];
  var searchFrom = 1;
  for (var i = 0; i < boundaries.length; i++) {
    final boundary = boundaries[i];
    if (boundary == null) {
      cuts.add(null);
      searchFrom++;
      continue;
    }
    // Leave one point per remaining stretch, so a cut cannot swallow the ones
    // behind it on a line with barely more points than entries.
    final latest = points.length - 2 - (boundaries.length - 1 - i);
    final index = _nearestIndex(
      points,
      boundary,
      searchFrom.clamp(1, latest < 1 ? 1 : latest),
      latest < 1 ? 1 : latest,
    );
    cuts.add(index);
    searchFrom = index + 1;
  }
  return cuts;
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

/// Where a tap lands on the line: the nearest recorded point within
/// `[after, before]`.
///
/// Snapped, because a handover has to lie *on* the recording — a point beside it
/// would not divide anything — and because a fingertip is wider than a line.
///
/// The bounds are the same rule the cutting uses, so what the user points at and
/// what the split does cannot disagree. They also keep a handover **between its
/// neighbours** when one is moved after the fact: dragging the second boundary
/// back past the first would ask for a stretch that runs backwards, and the
/// honest answer is that the line does not go there.
LatLng? snapToTrack(
  List<LatLng> points,
  LatLng tap, {
  int after = 0,
  int? before,
}) {
  final index = snapIndexOnTrack(points, tap, after: after, before: before);
  return index == null ? null : points[index];
}

/// [snapToTrack], answering with the index rather than the point.
///
/// The index is what a handover *is* once placed. Its coordinate is not enough
/// to find it again: a handover taken from an entry's coordinates lies beside
/// the line rather than on it, and a route that passes one spot twice has the
/// same coordinate at two indices. Looking a neighbour back up by coordinate
/// once turned the first case into an index of -1, which snapped every tap to
/// the recording's first point.
int? snapIndexOnTrack(
  List<LatLng> points,
  LatLng tap, {
  int after = 0,
  int? before,
}) {
  if (points.length < 2) return null;
  final first = after.clamp(0, points.length - 1);
  final last = (before ?? points.length - 1).clamp(0, points.length - 1);
  if (first > last || after > last) return null;
  return _nearestIndex(points, tap, first, last);
}
