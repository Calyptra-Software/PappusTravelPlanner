import 'package:latlong2/latlong.dart';

import '../../../core/format/civil_date.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/route_plan.dart';
import '../../../data/database/tables.dart';
import '../../../data/database/track_points.dart';
import '../../map/map_features.dart';
import '../domain/piste_difficulty.dart';
import '../domain/route_profile.dart';
import '../domain/routed_path.dart';
import '../domain/tour.dart';
import '../tour_entries.dart';
import 'tour_mapper.dart';

/// A tour the planner saved, read back from the entries it was saved as.
class SavedTour {
  const SavedTour({
    required this.tourId,
    required this.itemIds,
    required this.groupId,
    required this.tour,
    required this.paths,
    this.startMinutes,
    this.legItems = const {},
    this.placeItems = const {},
    this.runParts = const {},
  });

  /// The legs a ski run was laid out as, in order, by the keys of the run's
  /// two ends: what each leg is ([RoutePlan.part]), what it was called, and
  /// its entry. What saving the tour again keeps of a ski run.
  final Map<(int, int), List<({String? part, String? title, int id})>> runParts;

  /// The leg entry that runs between two of [tour]'s waypoints, by their
  /// `TourWaypoint.key`s, and the place entry that stands at one. What saving
  /// the tour again keeps (`keptEntryIds`).
  final Map<(int, int), int> legItems;
  final Map<int, int> placeItems;

  /// What marks the entries as one tour; kept when the tour is saved again.
  final String tourId;

  /// The entries the tour is saved as, in plan order: what saving it again
  /// takes out.
  final List<int> itemIds;

  /// The group the entries share, when they share one.
  final int? groupId;

  final Tour tour;

  /// The router's answers the entries still hold, by `runKey`: each leg's
  /// stored line with its heights. Opening a tour therefore asks the router
  /// nothing, except about a leg whose line was removed since. A line drawn by
  /// hand is here by `lineRunKey` where it was saved with heights.
  final Map<String, RoutedPath> paths;

  /// When the first entry starts, if it was given a time.
  final int? startMinutes;
}

/// The entries of the tour [opened] belongs to, in plan order, or empty when
/// it does not belong to one.
///
/// A tour's entries carry one tour id, but an id alone is not a tour: a copy
/// of an entry carries it too. So the entries are also on [opened]'s day, in
/// its group and option, and **connected**: each leg starts where the one
/// before it ended. That is the stretch around [opened] the planner could have
/// written in one go, which is the only thing it can honestly open.
List<ItineraryItem> tourItemsAround(
  List<ItineraryItem> items,
  ItineraryItem opened,
) {
  final tourId = decodeRoutePlan(opened.routePlan)?.tour;
  if (tourId == null) return const [];
  final candidates = [
    for (final item in items)
      if (normalizeDay(item.date) == normalizeDay(opened.date) &&
          item.groupId == opened.groupId &&
          item.alternativeId == opened.alternativeId &&
          decodeRoutePlan(item.routePlan)?.tour == tourId)
        item,
  ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  final chains = <List<ItineraryItem>>[];
  RoutePlanPoint? end;
  for (final item in candidates) {
    final plan = decodeRoutePlan(item.routePlan)!;
    final bool connected;
    if (plan.isLeg) {
      connected = end != null && _same(end, plan.waypoints.first);
      end = plan.waypoints.last;
    } else {
      // A place stands at the end of the leg that reaches it; one standing
      // anywhere else opens the stretch that leaves it.
      connected =
          end != null &&
          item.lat != null &&
          item.lon != null &&
          _at(end, item.lat!, item.lon!);
      if (!connected && item.lat != null && item.lon != null) {
        end = RoutePlanPoint(lat: item.lat!, lon: item.lon!);
      }
    }
    if (connected) {
      chains.last.add(item);
    } else {
      chains.add([item]);
    }
  }
  // [opened] is among the candidates (it shares its own day, group, option
  // and tour), so one chain holds it.
  return chains.firstWhere(
    (chain) => chain.any((item) => item.id == opened.id),
  );
}

/// Reads [members], the entries of one tour in plan order, back into the tour
/// they were saved from. [tracksOf] gives an entry's stored lines.
///
/// Null when there is no leg among them, or a leg was planned with a profile
/// this version does not know: a tour opened with a section it cannot name
/// would be saved back as another tour.
SavedTour? savedTourOf(
  List<ItineraryItem> members,
  List<Track> Function(int itemId) tracksOf,
) {
  final legs = [
    for (final item in members)
      if (decodeRoutePlan(item.routePlan) case final plan? when plan.isLeg)
        (item: item, plan: plan),
  ];
  if (legs.isEmpty) return null;

  final waypoints = <TourWaypoint>[];
  final modes = <SectionMode>[];
  // The waypoint indices each leg runs between, to find its run again. A leg
  // of a ski run may start or end at a point the router chose, which is no
  // waypoint: it is placed at the waypoint before it, and on a ski run only
  // its start counts.
  final spans = <({int first, int last})>[];
  // Where each leg's ends stand in [waypoints], where they are waypoints.
  final ends = <({int? from, int? to})>[];
  for (final (item: _, :plan) in legs) {
    final mode = _modeOf(plan);
    if (mode == null) return null;
    final first = waypoints.isEmpty ? 0 : waypoints.length - 1;
    // The leg's first waypoint is the one the leg before it ended on.
    final points = waypoints.isEmpty ? plan.waypoints : plan.waypoints.skip(1);
    for (final point in points) {
      if (point.byRouter) continue;
      waypoints.add(_waypoint(point));
      if (waypoints.length > 1) modes.add(mode);
    }
    spans.add((first: first, last: waypoints.length - 1));
    ends.add((
      from: plan.waypoints.first.byRouter ? null : first,
      to: plan.waypoints.last.byRouter ? null : waypoints.length - 1,
    ));
  }
  if (waypoints.length < 2) return null;
  // Each waypoint is keyed by where it stands in the tour as saved, and named
  // as the entries now name it: an end renamed in the entry's form since, or
  // a place retitled, is what the planner shows and saves back, rather than
  // the name the plan was written with.
  final names = <int, String>{};
  final legItems = <(int, int), int>{};
  for (final (index, (:item, :plan)) in legs.indexed) {
    final span = spans[index];
    if (plan.ski == null) legItems[(span.first, span.last)] = item.id;
    if (ends[index].from case final from?) {
      if (_nonEmpty(item.fromLocation) case final name?) names[from] = name;
    }
    if (ends[index].to case final to?) {
      if (_nonEmpty(item.toLocation) case final name?) names[to] = name;
    }
  }
  // The places in plan order stand at the waypoints marked as places, in the
  // same order: both were written from one walk along the tour.
  final placeEntries = [
    for (final item in members)
      if (item.kind == ItemKind.place) item,
  ];
  final placeWaypoints = [
    for (final (index, waypoint) in waypoints.indexed)
      if (waypoint.isPlace) index,
  ];
  final placeItems = <int, int>{};
  if (placeEntries.length == placeWaypoints.length) {
    for (final (k, item) in placeEntries.indexed) {
      placeItems[placeWaypoints[k]] = item.id;
      if (_nonEmpty(item.title) case final title?) {
        names[placeWaypoints[k]] = title;
      }
    }
  }
  final keyed = [
    for (final (index, waypoint) in waypoints.indexed)
      TourWaypoint(
        waypoint.position,
        name: names[index] ?? waypoint.name,
        isPlace: waypoint.isPlace,
        key: index,
      ),
  ];

  final tour = Tour(waypoints: keyed, modes: modes);

  final paths = <String, RoutedPath>{};
  final runs = tourRuns(tour);
  // The legs of each ski run, in order, by the run's index.
  final skiLegs = <int, List<int>>{};
  for (final (index, (:item, :plan)) in legs.indexed) {
    final span = spans[index];
    if (plan.ski != null) {
      final run = runs.indexWhere(
        (run) => run.first <= span.first && span.first < run.last,
      );
      if (run < 0) return null;
      (skiLegs[run] ??= []).add(index);
      continue;
    }
    final run = runs
        .where((run) => run.first == span.first && run.last == span.last)
        .firstOrNull;
    final key = run == null ? null : runKey(tour, run) ?? lineRunKey(tour, run);
    if (key == null) continue;
    final path = _storedPath(tracksOf(item.id), plan);
    // A line drawn by hand is kept for its heights; without them the planner
    // draws it from its waypoints and asks for them.
    if (path != null && (!plan.straight || path.elevations != null)) {
      paths[key] = path;
    }
  }
  final runParts =
      <(int, int), List<({String? part, String? title, int id})>>{};
  for (final MapEntry(key: runIndex, value: legIndices) in skiLegs.entries) {
    final run = runs[runIndex];
    final parts = [for (final index in legIndices) legs[index]];
    final path = _storedSkiRun(
      parts,
      tracksOf,
      keyed.sublist(run.first, run.last + 1),
    );
    final key = runKey(tour, run);
    if (path != null && key != null) paths[key] = path;
    runParts[(run.first, run.last)] = [
      for (final (:item, :plan) in parts)
        (part: plan.part, title: _nonEmpty(item.title), id: item.id),
    ];
  }

  final groups = {for (final item in members) item.groupId};
  return SavedTour(
    tourId: legs.first.plan.tour,
    itemIds: [for (final item in members) item.id],
    groupId: groups.length == 1 ? groups.single : null,
    tour: tour,
    paths: paths,
    startMinutes: members.first.startMinutes,
    legItems: legItems,
    placeItems: placeItems,
    runParts: runParts,
  );
}

String? _nonEmpty(String? text) {
  final trimmed = text?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// Which of [entries], the tour about to be saved again, keep the entry they
/// were saved as: one id per entry, null where the entry is new.
///
/// An entry is the same entry for as long as the user can see it is: a place
/// while its waypoint stands, however moved, renamed or reordered; a leg while
/// it runs between the same two waypoints. A leg split at a point inside it
/// keeps its row for the first half, which starts where it did. Nothing is
/// matched by position or by order alone, which would hand one entry's notes
/// and photographs to another. Each row is kept at most once.
List<int?> keptEntryIds(List<TourEntry> entries, SavedTour saved) {
  final kept = List<int?>.filled(entries.length, null);
  final claimed = <int>{};
  int? claim(int? id) {
    if (id == null || !claimed.add(id)) return null;
    return id;
  }

  for (final (index, entry) in entries.indexed) {
    kept[index] = switch (entry) {
      TourPlace(:final waypoint) => claim(saved.placeItems[waypoint.key]),
      TourLeg(:final part?) => claim(_keptPart(part, saved)),
      TourLeg(:final from, :final to) when from.key != null && to.key != null =>
        claim(saved.legItems[(from.key!, to.key!)]),
      TourLeg() => null,
    };
  }
  // The first half of a split leg: it starts where an old leg started and
  // ends at a point that lay inside that leg (a key between its ends, the keys
  // being the saved order) or was set since. A leg that merely starts at the
  // same point after a reorder is not a half of anything.
  for (final (index, entry) in entries.indexed) {
    if (kept[index] != null || entry is! TourLeg || entry.part != null) {
      continue;
    }
    final from = entry.from.key;
    final to = entry.to.key;
    if (from == null) continue;
    for (final MapEntry(key: (first, last), value: id)
        in saved.legItems.entries) {
      final inside = to == null || (to > first && to < last);
      if (first == from && inside && !claimed.contains(id)) {
        kept[index] = claim(id);
        break;
      }
    }
  }
  return kept;
}

/// The entry a leg of a ski run was saved as, if it is the same entry: its
/// run runs between the same two waypoints, and the leg is the same ride or
/// descent at the same place in it, by what it is and what it is called.
int? _keptPart(TourLegPart part, SavedTour saved) {
  final from = part.runFrom.key;
  final to = part.runTo.key;
  if (from == null || to == null) return null;
  final old = saved.runParts[(from, to)];
  if (old == null || part.index >= old.length) return null;
  final same = old[part.index];
  return same.part == routePlanPartOf(part.segment) && same.title == part.title
      ? same.id
      : null;
}

/// The line the router gave for a leg, as the leg still holds it: its routed
/// track, with the totals the plan kept beside it.
RoutedPath? _storedPath(List<Track> tracks, RoutePlan plan) {
  for (final track in tracks) {
    if (track.source != TrackSource.routed) continue;
    final List<LatLng> points;
    try {
      points = decodeTrackPoints(track.points);
    } on FormatException {
      continue;
    }
    if (points.length < 2) continue;
    final seconds = plan.seconds;
    return RoutedPath.measured(
      points: points,
      elevations: trackElevationsOrNull(track.elevations, points.length),
      lengthMeters: plan.meters ?? lineLength(points),
      duration: seconds == null ? null : Duration(seconds: seconds),
    );
  }
  return null;
}

SectionMode? _modeOf(RoutePlan plan) {
  if (plan.ski case final ski?) {
    final difficulty = PisteDifficulty.byName(ski);
    return difficulty == null ? null : SkiMode(difficulty);
  }
  if (plan.straight) {
    return StraightMode(
      TransportMode.values
          .where((mode) => mode.name == plan.straightMode)
          .firstOrNull,
    );
  }
  final profile = RouteProfile.byName(plan.profile);
  return profile == null ? null : RoutedMode(profile);
}

/// The path of a ski run as its legs [parts] still hold it: their lines one
/// after the other, each a segment, with what each plan kept beside it. A leg
/// without a stored line was two points, its ends. [waypoints] are the run's,
/// placed where they lie along the path again.
RoutedPath? _storedSkiRun(
  List<({ItineraryItem item, RoutePlan plan})> parts,
  List<Track> Function(int itemId) tracksOf,
  List<TourWaypoint> waypoints,
) {
  final points = <LatLng>[];
  final segments = <PathSegment>[];
  for (final (:item, :plan) in parts) {
    final kind = switch (plan.part) {
      'descent' => SegmentKind.descent,
      'walk' => SegmentKind.walk,
      _ => SegmentKind.lift,
    };
    final liftMode = kind == SegmentKind.lift
        ? TransportMode.values.where((m) => m.name == plan.part).firstOrNull
        : null;
    if (kind == SegmentKind.lift && liftMode == null) return null;
    final line =
        _storedPath(tracksOf(item.id), plan)?.points ??
        [
          for (final point in [plan.waypoints.first, plan.waypoints.last])
            LatLng(point.lat, point.lon),
        ];
    final start = points.isEmpty ? 0 : points.length - 1;
    points.addAll(points.isEmpty ? line : line.skip(1));
    segments.add(
      PathSegment(
        start: start,
        end: points.length - 1,
        kind: kind,
        liftMode: liftMode,
        lengthMeters: plan.meters ?? lineLength(line),
        duration: Duration(seconds: plan.seconds ?? 0),
        name: _nonEmpty(item.title),
        fromName: _nonEmpty(item.fromLocation),
        toName: _nonEmpty(item.toLocation),
      ),
    );
  }
  if (points.length < 2) return null;
  // Each waypoint at the point nearest it, never before the one before it.
  final reached = <int>[];
  for (final (index, waypoint) in waypoints.indexed) {
    if (index == 0) {
      reached.add(0);
      continue;
    }
    if (index == waypoints.length - 1) {
      reached.add(points.length - 1);
      continue;
    }
    var best = reached.last;
    var bestMeters = double.infinity;
    for (var i = reached.last; i < points.length; i++) {
      final meters = lineLength([points[i], waypoint.position]);
      if (meters < bestMeters) {
        best = i;
        bestMeters = meters;
      }
    }
    reached.add(best);
  }
  return RoutedPath(
    points: points,
    lengthMeters: segments.fold(0, (sum, s) => sum + s.lengthMeters),
    duration: Duration(
      seconds: segments.fold(0, (sum, s) => sum + s.duration.inSeconds),
    ),
    segments: segments,
    waypointIndices: reached,
  );
}

TourWaypoint _waypoint(RoutePlanPoint point) => TourWaypoint(
  LatLng(point.lat, point.lon),
  name: point.name,
  isPlace: point.isPlace,
);

bool _same(RoutePlanPoint a, RoutePlanPoint b) => _at(a, b.lat, b.lon);

/// Within about a decimeter: the same waypoint, written twice.
bool _at(RoutePlanPoint point, double lat, double lon) =>
    (point.lat - lat).abs() < 1e-6 && (point.lon - lon).abs() < 1e-6;
