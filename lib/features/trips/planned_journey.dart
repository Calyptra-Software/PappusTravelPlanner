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

  /// The two ends as the **search form** holds them, so a run can be looked up
  /// again with its endpoints already filled in and the query then adjusted —
  /// another day, a via stop, an hour later.
  ///
  /// Null on an end that cannot be addressed at all, exactly as [canLookUp]
  /// says. The kind is [PlaceKind.stop] whatever the end really is, because that
  /// is what makes [TransportPlace.queryId] hand [fromPlaceId] back verbatim:
  /// this is the very string the journey was searched by — a stop id, or a
  /// coordinate for an address — and re-deriving it from the coordinates could
  /// quietly search from somewhere else.
  TransportPlace? get fromPlace => _place(
    fromPlaceId,
    legs.first.fromLocation,
    legs.first.fromLat,
    legs.first.fromLon,
  );

  TransportPlace? get toPlace =>
      _place(toPlaceId, legs.last.toLocation, legs.last.toLat, legs.last.toLon);

  static TransportPlace? _place(
    String? queryId,
    String? name,
    double? lat,
    double? lon,
  ) => queryId == null
      ? null
      : TransportPlace(
          id: queryId,
          // The station's name as the trip has it: what the tile shows, so the
          // form reads as the journey it came from rather than as an id.
          name: name ?? queryId,
          kind: PlaceKind.stop,
          lat: lat,
          lon: lon,
        );

  /// When the run is planned to depart, as minutes since midnight.
  int? get departMinutes => legs.first.startMinutes;

  String? get fromLocation => legs.first.fromLocation;
  String? get toLocation => legs.last.toLocation;

  List<int> get legIds => [for (final leg in legs) leg.id];

  /// Whether this run holds enough to be searched **unattended**: both endpoints
  /// as the router addresses them, and a departure time to search around.
  ///
  /// A hand-entered leg has neither ids nor coordinates, so the routine flow
  /// leaves it exactly as it is — copied as a plan. That is the honest outcome
  /// for a query nobody is watching: there is nothing to re-issue it with, and
  /// guessing one from the station's name would be a different journey wearing
  /// the same label. With the user present it is not the end of the matter —
  /// see [plannedJourneyOf], which hands the same run to the search *form*, where
  /// naming the station is a question the user answers.
  bool get canLookUp =>
      fromPlaceId != null && toPlaceId != null && departMinutes != null;
}

/// When the traveller will really be standing at [leg]'s departure stop, in
/// minutes since midnight — the minute a search for *that leg alone* should start
/// from, or null when the plan is the best answer there is.
///
/// It is the **actual arrival of the leg before it**, when one has been recorded:
/// that is the case this exists for. The train in was twenty late, the connection
/// is gone, and the question is what runs from here now — asking that from the
/// planned departure would offer a train that has already left. An early arrival
/// counts the same way round: standing there sooner means an earlier connection is
/// catchable.
///
/// Null unless [run] holds the leg directly before it on the **same day**, ending
/// without crossing midnight: comparing minutes across a date boundary is how a
/// 23:58 arrival becomes an early morning, and a seed is not worth a wrong day.
/// It only seeds a form the user can see and change — nothing here decides
/// anything.
int? departureSeedMinutes(List<ItineraryItem> run, ItineraryItem leg) {
  final legs = _runLegs(run);
  final index = legs.indexWhere((item) => item.id == leg.id);
  if (index <= 0) return null;
  final before = legs[index - 1];
  if (before.spansNextDay || !_sameDay(before.date, leg.date)) return null;
  return before.actualEndMinutes;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The run [items] form as one journey, addressable or not — null when there is
/// no transport leg among them to make a journey of.
///
/// The difference from [plannedJourneys] is who is asking. That one answers "what
/// can be searched **without** anyone present", and so drops a run whose ends
/// cannot be handed to the router: the routine flow fires those queries by
/// itself, and a query it had to invent an endpoint for would silently be a
/// different journey. This one answers "what run is the user looking at", for
/// the search *form*, where an end with no id is simply an end the user is about
/// to pick — from the geocoder, seeing the candidates. A hand-entered leg has
/// only station names, and a name is not an address; the fix for that is a human
/// choosing, not the app guessing.
PlannedJourney? plannedJourneyOf(List<ItineraryItem> items) {
  final journeys = _runs(items);
  return journeys.length == 1 ? journeys.single : null;
}

/// The journeys in [items] that could be looked up again, in day order.
///
/// A run qualifies when its ends can still be addressed to the router — by the
/// id the search used, or failing that by the coordinates the leg carries —
/// and it is grouped exactly as the import grouped it. Items in an option that was not chosen are skipped by the
/// caller, not here: this only answers what the plan *holds*.
List<PlannedJourney> plannedJourneys(List<ItineraryItem> items) => [
  for (final journey in _runs(items))
    if (journey.canLookUp) journey,
];

/// The transport legs among [items], in the order a day is read: by date, then
/// the manual ordering, then the clock. The one place that order is written down.
List<ItineraryItem> _runLegs(List<ItineraryItem> items) =>
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

/// Every run in [items], in day order then by departure, whether or not it can be
/// looked up: a group is one run, a loose transport leg is one of its own.
List<PlannedJourney> _runs(List<ItineraryItem> items) {
  final transport = _runLegs(items);

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

  return [
    ...standalone,
    for (final entry in grouped.entries)
      PlannedJourney(groupId: entry.key, legs: entry.value),
  ]..sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    return (a.departMinutes ?? 0).compareTo(b.departMinutes ?? 0);
  });
}
