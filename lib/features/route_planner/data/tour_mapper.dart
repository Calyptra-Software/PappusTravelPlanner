import 'package:drift/drift.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../data/database/track_points.dart';
import '../domain/tour.dart';
import '../tour_entries.dart';

/// A tour as the rows it is saved as: [items] in plan order, and beside each
/// the line it draws along, packed the way `TripRepository.insertJourney`
/// takes a routed connection's shapes (null where an item has none).
class MappedTour {
  const MappedTour({required this.items, required this.shapes});

  final List<ItineraryItemsCompanion> items;
  final List<String?> shapes;
}

/// Maps a planned tour onto itinerary rows of [tripId] on [date].
///
/// A leg becomes a transport entry between its two waypoints, a place a place
/// entry at its own. [resolveMode] turns a built-in mode into the row the user
/// keeps for it, or null when they deleted it; the leg is then filed under no
/// mode, as an imported connection's would be.
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
  int? startMinutes,
}) {
  final items = <ItineraryItemsCompanion>[];
  final shapes = <String?>[];
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
          ),
        );
        shapes.add(null);
      case TourLeg(:final from, :final to, :final mode, :final path):
        final start = clock;
        final minutes = path.duration == null
            ? null
            : (path.duration!.inSeconds / 60).ceil();
        final end = start == null || minutes == null ? null : start + minutes;
        final builtin = mode.transportMode;
        items.add(
          ItineraryItemsCompanion.insert(
            tripId: tripId,
            date: date,
            kind: ItemKind.transport,
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
          ),
        );
        // Two points are the chord the leg draws anyway; a stored line would
        // only repeat it.
        shapes.add(
          path.points.length > 2
              ? encodeTrackPoints(path.points, precision: kRoutedShapePrecision)
              : null,
        );
        clock = end != null && end < _minutesPerDay ? end : null;
    }
  }
  return MappedTour(items: items, shapes: shapes);
}

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
