import 'package:latlong2/latlong.dart';

import '../../../core/format/civil_date.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/route_plan.dart';
import '../../../data/database/tables.dart';
import '../../../data/database/track_points.dart';
import '../../map/map_features.dart';
import '../domain/route_profile.dart';
import '../domain/routed_path.dart';
import '../domain/tour.dart';

/// A tour the planner saved, read back from the entries it was saved as.
class SavedTour {
  const SavedTour({
    required this.tourId,
    required this.itemIds,
    required this.groupId,
    required this.tour,
    required this.paths,
    this.startMinutes,
  });

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
  /// nothing, except about a leg whose line was removed since.
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
  return chains.firstWhere(
    (chain) => chain.any((item) => item.id == opened.id),
    orElse: () => const [],
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
  // The waypoint indices each leg runs between, to find its run again.
  final spans = <({int first, int last})>[];
  for (final (item: _, :plan) in legs) {
    final mode = _modeOf(plan);
    if (mode == null) return null;
    final points = [for (final point in plan.waypoints) _waypoint(point)];
    final first = waypoints.isEmpty ? 0 : waypoints.length - 1;
    // The leg's first waypoint is the one the leg before it ended on.
    waypoints.addAll(waypoints.isEmpty ? points : points.skip(1));
    modes.addAll(List.filled(points.length - 1, mode));
    spans.add((first: first, last: waypoints.length - 1));
  }
  final tour = Tour(waypoints: waypoints, modes: modes);

  final paths = <String, RoutedPath>{};
  final runs = tourRuns(tour);
  for (final (index, (:item, :plan)) in legs.indexed) {
    final span = spans[index];
    final run = runs
        .where((run) => run.first == span.first && run.last == span.last)
        .firstOrNull;
    final key = run == null ? null : runKey(tour, run);
    if (key == null) continue;
    final path = _storedPath(tracksOf(item.id), plan);
    if (path != null) paths[key] = path;
  }

  final groups = {for (final item in members) item.groupId};
  return SavedTour(
    tourId: legs.first.plan.tour,
    itemIds: [for (final item in members) item.id],
    groupId: groups.length == 1 ? groups.single : null,
    tour: tour,
    paths: paths,
    startMinutes: members.first.startMinutes,
  );
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

TourWaypoint _waypoint(RoutePlanPoint point) => TourWaypoint(
  LatLng(point.lat, point.lon),
  name: point.name,
  isPlace: point.isPlace,
);

bool _same(RoutePlanPoint a, RoutePlanPoint b) => _at(a, b.lat, b.lon);

/// Within about a decimeter: the same waypoint, written twice.
bool _at(RoutePlanPoint point, double lat, double lon) =>
    (point.lat - lat).abs() < 1e-6 && (point.lon - lon).abs() < 1e-6;
