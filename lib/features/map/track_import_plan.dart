import 'package:latlong2/latlong.dart';

import '../../data/database/app_database.dart';
import '../../data/database/tables.dart';

/// What an import has to do with a run of entries the user picked.
class TrackImportPlan {
  const TrackImportPlan({required this.legs, required this.boundaries});

  /// The entries that will each get a stretch of the recording — the transport
  /// legs of the selection, in order.
  ///
  /// **Only legs.** A place is a point and has no straight line for a recording
  /// to replace, so there would be nothing to give it and nothing to suppress.
  final List<ItineraryItem> legs;

  /// Where each leg hands over to the next, or null where nobody has said.
  /// One shorter than [legs].
  final List<LatLng?> boundaries;

  /// The handovers still to be pointed at, by index into [boundaries].
  List<int> get open => [
    for (var i = 0; i < boundaries.length; i++)
      if (boundaries[i] == null) i,
  ];
}

/// Reads a selected run of entries as an import.
///
/// A handover between two legs is one place on the ground, so it is looked for
/// in the three columns that can describe it, in this order: the first leg's
/// **end**, a **place** standing between them, and the second leg's **start**.
/// A place is used because it is exactly what a handover is — where one leg
/// stopped and the next began — and using it saves the user a tap.
///
/// A place *without* a position is left out of this entirely. Giving it one
/// because the user tapped a boundary near it would be the app deciding that
/// the café stands where the walking turned into a bus ride, which is plausible
/// and not the same thing.
TrackImportPlan trackImportPlan(List<ItineraryItem> selection) {
  final legs = [
    for (final item in selection)
      if (item.kind == ItemKind.transport) item,
  ];
  if (legs.length < 2) {
    return TrackImportPlan(legs: legs, boundaries: const []);
  }

  final boundaries = <LatLng?>[];
  for (var i = 0; i < legs.length - 1; i++) {
    boundaries.add(
      _at(legs[i].toLat, legs[i].toLon) ??
          _placeBetween(selection, legs[i], legs[i + 1]) ??
          _at(legs[i + 1].fromLat, legs[i + 1].fromLon),
    );
  }
  return TrackImportPlan(legs: legs, boundaries: boundaries);
}

/// The first positioned place standing between two legs of the selection.
LatLng? _placeBetween(
  List<ItineraryItem> selection,
  ItineraryItem before,
  ItineraryItem after,
) {
  final from = selection.indexOf(before);
  final to = selection.indexOf(after);
  if (from < 0 || to < 0) return null;
  for (var i = from + 1; i < to; i++) {
    final place = selection[i];
    if (place.kind != ItemKind.place) continue;
    final at = _at(place.lat, place.lon);
    if (at != null) return at;
  }
  return null;
}

LatLng? _at(double? lat, double? lon) =>
    lat == null || lon == null ? null : LatLng(lat, lon);

/// The coordinates an import should write back onto the entries.
///
/// The outer ends come from the **recording itself**: its first point is where
/// the first leg started and its last is where the last one finished, so nobody
/// needs to be asked. The handovers in between come from [boundaries], and only
/// the ends that had nothing are written — an end the user already gave is
/// their statement, and the file is only a witness to it.
List<({int itemId, bool isStart, LatLng at})> trackImportEnds(
  TrackImportPlan plan, {
  required LatLng first,
  required LatLng last,
}) {
  final legs = plan.legs;
  if (legs.isEmpty) return const [];
  final ends = <({int itemId, bool isStart, LatLng at})>[];

  if (legs.first.fromLat == null || legs.first.fromLon == null) {
    ends.add((itemId: legs.first.id, isStart: true, at: first));
  }
  if (legs.last.toLat == null || legs.last.toLon == null) {
    ends.add((itemId: legs.last.id, isStart: false, at: last));
  }
  for (var i = 0; i < plan.boundaries.length; i++) {
    final at = plan.boundaries[i];
    if (at == null) continue;
    if (legs[i].toLat == null || legs[i].toLon == null) {
      ends.add((itemId: legs[i].id, isStart: false, at: at));
    }
    if (legs[i + 1].fromLat == null || legs[i + 1].fromLon == null) {
      ends.add((itemId: legs[i + 1].id, isStart: true, at: at));
    }
  }
  return ends;
}
