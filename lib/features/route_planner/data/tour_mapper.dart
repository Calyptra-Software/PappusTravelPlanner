import 'package:drift/drift.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/route_plan.dart';
import '../../../data/database/tables.dart';
import '../../../data/database/track_points.dart';
import '../domain/routed_path.dart';
import '../domain/tour.dart';
import '../tour_entries.dart';

/// A tour as the rows it is saved as: [items] in plan order, and beside each
/// the line it draws along, packed the way `TripRepository.insertJourney`
/// takes a routed connection's shapes (null where an item has none), and the
/// heights of that line where the router gave them.
class MappedTour {
  const MappedTour({
    required this.items,
    required this.shapes,
    required this.elevations,
    required this.sources,
  });

  final List<ItineraryItemsCompanion> items;
  final List<String?> shapes;
  final List<List<double>?> elevations;

  /// What each line is: [TrackSource.routed] for a section the router found,
  /// [TrackSource.drawn] for one drawn by hand.
  final List<TrackSource> sources;
}

/// Maps a planned tour onto itinerary rows of [tripId] on [date].
///
/// A leg becomes a transport entry between its two waypoints, a place a place
/// entry at its own. [resolveMode] turns a built-in mode into the row the user
/// keeps for it, or null when they deleted it; the leg is then filed under no
/// mode, as an imported connection's would be.
///
/// Every entry is marked with [tourId] and, on a leg, with the waypoints and
/// the way of travel it was planned with (`RoutePlan`), which is what lets the
/// planner be opened on the saved tour again.
///
/// With [startMinutes] the entries are timed one after the other from the
/// router's durations. The chain stops at the first leg without one (a line
/// drawn by hand) and at midnight: what comes after is left untimed, since a
/// time behind an unknown stretch would be invented. A leg reaching past
/// midnight keeps its arrival through `endDayOffset`.
MappedTour tourToItems(
  List<TourEntry> entries, {
  required int tripId,
  required DateTime date,
  required int? Function(TransportMode mode) resolveMode,
  required String tourId,
  int? startMinutes,
}) {
  final items = <ItineraryItemsCompanion>[];
  final shapes = <String?>[];
  final elevations = <List<double>?>[];
  final sources = <TrackSource>[];
  // Minutes since midnight of [date] at which the next entry starts; null once
  // nothing is known about it any more.
  var clock = startMinutes;

  for (final entry in entries) {
    switch (entry) {
      case TourPlace(:final waypoint):
        items.add(
          ItineraryItemsCompanion.insert(
            tripId: tripId,
            date: date,
            kind: ItemKind.place,
            title: Value(_name(waypoint)),
            lat: Value(waypoint.position.latitude),
            lon: Value(waypoint.position.longitude),
            startMinutes: Value(clock),
            routePlan: Value(encodeRoutePlan(RoutePlan(tour: tourId))),
          ),
        );
        shapes.add(null);
        elevations.add(null);
        sources.add(TrackSource.routed);
      case TourLeg(
        :final from,
        :final to,
        :final mode,
        :final path,
        :final title,
      ):
        final start = clock;
        final minutes = path.duration == null
            ? null
            : (path.duration!.inSeconds / 60).ceil();
        final end = start == null || minutes == null ? null : start + minutes;
        final builtin = entry.transportMode;
        items.add(
          ItineraryItemsCompanion.insert(
            tripId: tripId,
            date: date,
            kind: ItemKind.transport,
            // Absent rather than null: a leg saved again keeps the title
            // somebody gave it.
            title: title == null ? const Value.absent() : Value(title),
            mode: Value(builtin == null ? null : resolveMode(builtin)),
            fromLocation: Value(_name(from)),
            toLocation: Value(_name(to)),
            fromLat: Value(from.position.latitude),
            fromLon: Value(from.position.longitude),
            toLat: Value(to.position.latitude),
            toLon: Value(to.position.longitude),
            startMinutes: Value(start),
            endMinutes: Value(end == null ? null : end % _minutesPerDay),
            endDayOffset: Value(end == null ? 0 : end ~/ _minutesPerDay),
            routePlan: Value(encodeRoutePlan(_planOf(entry, tourId))),
          ),
        );
        // Two points are the chord the leg draws anyway; a stored line would
        // only repeat it.
        final stored = path.points.length > 2;
        shapes.add(
          stored
              ? encodeTrackPoints(path.points, precision: kRoutedShapePrecision)
              : null,
        );
        elevations.add(stored ? path.elevations : null);
        sources.add(
          mode is StraightMode ? TrackSource.drawn : TrackSource.routed,
        );
        clock = end != null && end < _minutesPerDay ? end : null;
    }
  }
  return MappedTour(
    items: items,
    shapes: shapes,
    elevations: elevations,
    sources: sources,
  );
}

/// What a leg was planned with, as its row keeps it.
RoutePlan _planOf(TourLeg leg, String tourId) {
  final mode = leg.mode;
  final waypoints = leg.waypoints.isEmpty ? [leg.from, leg.to] : leg.waypoints;
  return RoutePlan(
    tour: tourId,
    profile: mode is RoutedMode ? mode.profile.name : null,
    straight: mode is StraightMode,
    straightMode: mode is StraightMode ? mode.transportMode?.name : null,
    ski: mode is SkiMode ? mode.maxDifficulty.name : null,
    part: switch (leg.part) {
      final part? => routePlanPartOf(part.segment),
      null => null,
    },
    waypoints: [
      for (final waypoint in waypoints)
        RoutePlanPoint(
          lat: waypoint.position.latitude,
          lon: waypoint.position.longitude,
          name: _name(waypoint),
          isPlace: waypoint.isPlace,
          byRouter: waypoint.byRouter,
        ),
    ],
    seconds: leg.path.duration?.inSeconds,
    meters: leg.path.lengthMeters,
  );
}

/// What [RoutePlan.part] calls a leg made of [segment]: the lift's transport
/// mode for a ride, else the kind of segment.
String routePlanPartOf(PathSegment segment) => switch (segment) {
  PathSegment(kind: SegmentKind.lift, :final liftMode) => liftMode!.name,
  PathSegment(:final kind) => kind.name,
};

/// Resolves a built-in mode to the user's row for it by `builtinKey`, as
/// `modeResolver` does for a connection: a renamed built-in still resolves, a
/// deleted one is null and never resurrected.
int? Function(TransportMode) builtinModeResolver(List<TransportModeRow> modes) {
  final idByBuiltinKey = {
    for (final mode in modes)
      if (mode.builtinKey != null) mode.builtinKey!: mode.id,
  };
  return (mode) => idByBuiltinKey[mode.name];
}

const int _minutesPerDay = 24 * 60;

String? _name(TourWaypoint waypoint) =>
    waypoint.isNamed ? waypoint.name!.trim() : null;
