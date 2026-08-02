import '../../data/database/app_database.dart';
import '../../data/database/tables.dart';
import '../transport_search/domain/transport_place.dart';

/// A run of transport legs in a plan that can be **looked up again**: searched
/// afresh for the day it now sits on, so it becomes a real connection with live
/// times rather than a copy of one.
///
/// The unit is the group, because in this app a group already *is* a journey —
/// the legs bundled together are the ones that were imported together. Its
/// endpoints are the first member's origin and the last member's destination,
/// which is exactly how the search that produced it was issued.
///
/// Pure, so which journeys are refreshable can be tested without a database or
/// a network.
class PlannedJourney {
  const PlannedJourney({required this.groupId, required this.legs});

  /// The group these legs belong to, or null for a single imported leg standing
  /// on its own.
  final int? groupId;

  /// The legs in day order. Never empty.
  final List<ItineraryItem> legs;

  /// The day the run departs on.
  DateTime get date => legs.first.date;

  /// How the router addresses the ends of the whole run.
  ///
  /// The id the search was issued against when the leg still carries it, and
  /// the end's **coordinates** otherwise. The ids live only on the run's outer
  /// legs, so anything that changes an end — deleting a leading walk, replacing
  /// the last leg — takes one with it, and without the fallback the journey
  /// would simply stop being offered, silently and for good. Routing from a
  /// coordinate is slightly coarser at a station (it starts outside rather than
  /// on the platform), which is why the id is preferred where there is one, and
  /// no reason at all to give up on the journey where there is not.
  String? get fromPlaceId =>
      legs.first.fromPlaceId ??
      _coordinate(legs.first.fromLat, legs.first.fromLon);
  String? get toPlaceId =>
      legs.last.toPlaceId ?? _coordinate(legs.last.toLat, legs.last.toLon);

  static String? _coordinate(double? lat, double? lon) =>
      lat == null || lon == null ? null : coordinateQueryId(lat, lon);

  /// When the run is planned to depart, as minutes since midnight.
  int? get departMinutes => legs.first.startMinutes;

  String? get fromLocation => legs.first.fromLocation;
  String? get toLocation => legs.last.toLocation;

  List<int> get legIds => [for (final leg in legs) leg.id];

  /// Whether this run holds enough to be searched again: both endpoints as the
  /// router addresses them, and a departure time to search around.
  ///
  /// A hand-entered leg has neither ids nor coordinates, so it is left exactly
  /// as it is — copied as a plan. That is the honest outcome: there is nothing
  /// to re-issue a query with, and guessing one from the station's name would
  /// be a different journey wearing the same label.
  bool get canLookUp =>
      fromPlaceId != null && toPlaceId != null && departMinutes != null;
}

/// The journeys in [items] that could be looked up again, in day order.
///
/// A run qualifies when its ends can still be addressed to the router — by the
/// id the search used, or failing that by the coordinates the leg carries —
/// and it is grouped exactly as the import grouped it. Items in an option that was not chosen are skipped by the
/// caller, not here: this only answers what the plan *holds*.
List<PlannedJourney> plannedJourneys(List<ItineraryItem> items) {
  final transport =
      [
        for (final item in items)
          if (item.kind == ItemKind.transport) item,
      ]..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        if (byOrder != 0) return byOrder;
        return (a.startMinutes ?? 0).compareTo(b.startMinutes ?? 0);
      });

  final grouped = <int, List<ItineraryItem>>{};
  final standalone = <PlannedJourney>[];
  for (final leg in transport) {
    final groupId = leg.groupId;
    if (groupId == null) {
      standalone.add(PlannedJourney(groupId: null, legs: [leg]));
    } else {
      grouped.putIfAbsent(groupId, () => []).add(leg);
    }
  }

  final journeys =
      [
        ...standalone,
        for (final entry in grouped.entries)
          PlannedJourney(groupId: entry.key, legs: entry.value),
      ]..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return (a.departMinutes ?? 0).compareTo(b.departMinutes ?? 0);
      });
  return [
    for (final journey in journeys)
      if (journey.canLookUp) journey,
  ];
}
