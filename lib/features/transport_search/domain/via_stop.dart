/// A stop the journey must be routed through, and the least time to spend there.
///
/// This is part of *where* a journey goes, not of how it is planned, which is
/// why it travels beside the origin and destination rather than in
/// [JourneySearchOptions]: a via stop belongs to one search — "Hamburg to
/// Munich, but with two hours in Nuremberg" — and is not a preference to carry
/// into the next one.
///
/// Only a **station** can be one. The routing service takes stop ids here and
/// no coordinates at all, so an address would be rejected outright rather than
/// routed to the nearest platform; that is what confines the picker behind this
/// to stops.
///
/// Equality is by value: it rides in the `journeyResultsProvider` family key, so
/// an equal-but-not-identical instance would otherwise re-run the search and
/// throw away the windows already loaded.
class ViaStop {
  const ViaStop({required this.id, this.minimumStayMinutes = 0});

  /// The routing service's own stop id — [TransportPlace.queryId] of a place of
  /// kind [PlaceKind.stop], which for a stop is its id.
  final String id;

  /// The least time to spend at [id] before travelling on.
  ///
  /// A floor, not a plan, and `0` is not merely "no wait": it tells the service
  /// the traveller need not get off at all, so the via may be passed through on
  /// the same vehicle. That often buys a connection with one change fewer,
  /// which is why it is the default rather than a token minimum.
  final int minimumStayMinutes;

  @override
  bool operator ==(Object other) =>
      other is ViaStop &&
      other.id == id &&
      other.minimumStayMinutes == minimumStayMinutes;

  @override
  int get hashCode => Object.hash(id, minimumStayMinutes);

  @override
  String toString() => 'ViaStop($id, ≥${minimumStayMinutes}min)';
}

/// The stays the search offers, in minutes.
///
/// `0` first, as "no minimum" — see [ViaStop.minimumStayMinutes] for why that is
/// a meaningful answer and not just the empty one. The list ends at four hours:
/// beyond that the via stop is not a break in a journey but a stop on the trip,
/// which the itinerary says better than a routing parameter can.
const List<int> kViaStayMinuteOptions = [0, 15, 30, 45, 60, 90, 120, 180, 240];

/// The most via stops a journey may be routed through: the routing service's own
/// limit, not a choice made here.
const int kMaxViaStops = 2;

/// The via stops of one search, **in the order the journey visits them**.
///
/// A type of its own rather than a bare list, because a list compares by
/// identity: this rides in the `journeyResultsProvider` family key, where that
/// would re-run a search whose parameters had not changed and throw away the
/// windows already loaded.
///
/// The [kMaxViaStops] cap is not enforced here — a const constructor cannot ask
/// a list its length — but where the request is built, which is the boundary the
/// limit actually belongs to.
class ViaStops {
  const ViaStops(this.stops);

  /// The ordinary journey: straight from A to B.
  static const ViaStops none = ViaStops([]);

  final List<ViaStop> stops;

  bool get isEmpty => stops.isEmpty;
  int get length => stops.length;

  @override
  bool operator ==(Object other) {
    if (other is! ViaStops || other.stops.length != stops.length) return false;
    for (var i = 0; i < stops.length; i++) {
      if (other.stops[i] != stops[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(stops);

  @override
  String toString() => 'ViaStops($stops)';
}
