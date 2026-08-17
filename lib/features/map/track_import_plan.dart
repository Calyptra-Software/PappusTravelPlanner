import 'package:latlong2/latlong.dart';

import '../../data/database/app_database.dart';
import '../../data/database/tables.dart';

/// Which position of an entry an import is filling in.
enum TrackEnd {
  /// A leg's start.
  from,

  /// A leg's finish.
  to,

  /// A place's own position — it has one, not two.
  place,
}

class TrackImportPlan {
  const TrackImportPlan({
    required this.legs,
    required this.boundaries,
    this.selection = const [],
  });

  /// The entries that will each get a stretch of the recording — the transport
  /// legs of the selection, in order.
  ///
  /// **Only legs.** A place is a point and has no straight line for a recording
  /// to replace, so there would be nothing to give it and nothing to suppress.
  final List<ItineraryItem> legs;

  /// Where each leg hands over to the next, or null where nobody has said.
  /// One shorter than [legs].
  final List<LatLng?> boundaries;

  /// The run the user ticked, legs and places alike. Kept because the places in
  /// it are filled in too: a place standing at a handover is *at* that handover,
  /// so the position the two legs get is the position it gets.
  final List<ItineraryItem> selection;

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
/// A place *without* a position supplies nothing here — there is nothing to
/// read off it — but it is filled in afterwards from whatever the handover turns
/// out to be. See [trackImportEnds].
TrackImportPlan trackImportPlan(List<ItineraryItem> selection) {
  final legs = [
    for (final item in selection)
      if (item.kind == ItemKind.transport) item,
  ];
  if (legs.length < 2) {
    return TrackImportPlan(
      legs: legs,
      boundaries: const [],
      selection: selection,
    );
  }

  final boundaries = <LatLng?>[];
  for (var i = 0; i < legs.length - 1; i++) {
    boundaries.add(
      _at(legs[i].toLat, legs[i].toLon) ??
          _placeBetween(selection, legs[i], legs[i + 1]) ??
          _at(legs[i + 1].fromLat, legs[i + 1].fromLon),
    );
  }
  return TrackImportPlan(
    legs: legs,
    boundaries: boundaries,
    selection: selection,
  );
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
/// needs to be asked. The handovers in between come from [TrackImportPlan.boundaries].
///
/// **Places are filled in too.** A place standing between two legs *is* their
/// handover — that is what one is — so it gets the same position they do; one
/// at the front or back of the run gets the recording's own end. Where the
/// handover was already known from a leg's coordinates, that is the position the
/// place gets, which is the only reading that keeps the three of them agreeing.
///
/// Only what had nothing is written. An end or a place the user already gave is
/// their statement, and the file is a witness to it, not a correction.
List<({int itemId, TrackEnd end, LatLng at})> trackImportEnds(
  TrackImportPlan plan, {
  required LatLng first,
  required LatLng last,
}) {
  final legs = plan.legs;
  if (legs.isEmpty) return const [];
  final ends = <({int itemId, TrackEnd end, LatLng at})>[];

  void placeIfUnset(ItineraryItem place, LatLng at) {
    if (place.lat == null || place.lon == null) {
      ends.add((itemId: place.id, end: TrackEnd.place, at: at));
    }
  }

  if (legs.first.fromLat == null || legs.first.fromLon == null) {
    ends.add((itemId: legs.first.id, end: TrackEnd.from, at: first));
  }
  if (legs.last.toLat == null || legs.last.toLon == null) {
    ends.add((itemId: legs.last.id, end: TrackEnd.to, at: last));
  }
  for (var i = 0; i < plan.boundaries.length; i++) {
    final at = plan.boundaries[i];
    if (at == null) continue;
    if (legs[i].toLat == null || legs[i].toLon == null) {
      ends.add((itemId: legs[i].id, end: TrackEnd.to, at: at));
    }
    if (legs[i + 1].fromLat == null || legs[i + 1].fromLon == null) {
      ends.add((itemId: legs[i + 1].id, end: TrackEnd.from, at: at));
    }
    for (final place in _placesBetween(plan.selection, legs[i], legs[i + 1])) {
      placeIfUnset(place, at);
    }
  }

  // A place before the first leg or after the last one stands where the
  // recording does.
  for (final place in _placesOutside(
    plan.selection,
    legs.first,
    before: true,
  )) {
    placeIfUnset(place, first);
  }
  for (final place in _placesOutside(
    plan.selection,
    legs.last,
    before: false,
  )) {
    placeIfUnset(place, last);
  }
  return ends;
}

/// The places of [selection] standing between two of its legs.
Iterable<ItineraryItem> _placesBetween(
  List<ItineraryItem> selection,
  ItineraryItem before,
  ItineraryItem after,
) sync* {
  final from = selection.indexOf(before);
  final to = selection.indexOf(after);
  if (from < 0 || to < 0) return;
  for (var i = from + 1; i < to; i++) {
    if (selection[i].kind == ItemKind.place) yield selection[i];
  }
}

/// The places standing before the first leg, or after the last.
Iterable<ItineraryItem> _placesOutside(
  List<ItineraryItem> selection,
  ItineraryItem leg, {
  required bool before,
}) sync* {
  final at = selection.indexOf(leg);
  if (at < 0) return;
  final range = before
      ? Iterable<int>.generate(at)
      : Iterable<int>.generate(selection.length - at - 1, (i) => at + 1 + i);
  for (final i in range) {
    if (selection[i].kind == ItemKind.place) yield selection[i];
  }
}
