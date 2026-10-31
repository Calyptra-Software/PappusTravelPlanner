import '../../trips/planned_journey.dart';
import '../domain/transport_place.dart';

/// What the search form opens holding, before anybody has touched it.
///
/// Each end is either a [TransportPlace] the router can be asked about as it
/// stands — the id a search was issued against before, or a position somebody
/// pointed at — or only a **name** ([fromHint] / [toHint]), which is all a
/// hand-entered leg knows. A name is not an address: the router takes stop ids
/// and coordinates, and turning one into the other is the geocoder's job, with
/// the user choosing between the answers. So the name is shown on the empty
/// field and handed to the place picker as its opening query, and which
/// Rahlstedt it means stays the user's call. Never both on one end.
///
/// Kept apart from `JourneyDestination` because it answers a different
/// question: that one says what becomes of a result, this one what the question
/// starts as — and one destination is opened from different starting points,
/// the run as it is stored or an entry form as it is currently filled in.
class SearchSeed {
  const SearchSeed({
    this.from,
    this.fromHint,
    this.to,
    this.toHint,
    this.departMinutes,
  }) : assert(from == null || fromHint == null),
       assert(to == null || toHint == null);

  /// The ends as [journey] holds them, and the minute it was planned to leave —
  /// unless [departMinutes] names a better one (`departureSeedMinutes`, where
  /// the traveller is standing on the platform at the time they really
  /// arrived).
  factory SearchSeed.ofJourney(PlannedJourney journey, {int? departMinutes}) {
    final from = journey.fromPlace;
    final to = journey.toPlace;
    return SearchSeed(
      from: from,
      fromHint: from == null ? journey.fromLocation : null,
      to: to,
      toHint: to == null ? journey.toLocation : null,
      departMinutes: departMinutes ?? journey.departMinutes,
    );
  }

  /// The ends of a leg as an entry form holds them **now**, saved or not.
  ///
  /// An end the form can address — an id still describing it, or a position —
  /// fills its field under the name the form gives it; one with only a name is a
  /// hint. A name the form changed beside a position it did not is still routed
  /// from the position: that is the part somebody pointed at, and the name is a
  /// label (the same rule as saving, which drops an id only when the position
  /// moved).
  factory SearchSeed.ofLeg({
    String? fromName,
    String? fromPlaceId,
    double? fromLat,
    double? fromLon,
    String? toName,
    String? toPlaceId,
    double? toLat,
    double? toLon,
    int? departMinutes,
  }) {
    final from = legEndPlace(
      placeId: fromPlaceId,
      name: fromName,
      lat: fromLat,
      lon: fromLon,
    );
    final to = legEndPlace(
      placeId: toPlaceId,
      name: toName,
      lat: toLat,
      lon: toLon,
    );
    return SearchSeed(
      from: from,
      fromHint: from == null ? fromName : null,
      to: to,
      toHint: to == null ? toName : null,
      departMinutes: departMinutes,
    );
  }

  final TransportPlace? from;
  final String? fromHint;
  final TransportPlace? to;
  final String? toHint;

  /// The minute to open the time field on, or null for "now".
  final int? departMinutes;
}
