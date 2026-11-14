import '../domain/journey.dart';
import '../domain/journey_options.dart';
import '../domain/transport_place.dart';
import '../domain/via_stop.dart';

/// A provider-agnostic connection-search backend.
///
/// Kept as an interface so the app depends on the *capability*, not on MOTIS:
/// the current implementation ([MotisTransportSearch]) talks to a MOTIS server
/// (Transitous by default), but a different backend could be dropped in behind
/// this without touching the feature UI or the itinerary mapper. This is a
/// network service and sits beside the repository, never inside it — the
/// offline SQLite core has no dependency on it.
abstract interface class TransportSearch {
  /// Resolves a (possibly partial) query into candidate origins/destinations.
  Future<List<TransportPlace>> searchPlaces(String query);

  /// Plans journeys between two geocoded places, returning the options in one
  /// time window and the cursors for the windows either side.
  ///
  /// [time] is anchored by [arriveBy]: a departure time when false (the
  /// default), an arrival deadline when true. [options] narrows *how* the
  /// journey may be made; its default asks for no restriction at all.
  ///
  /// [via] adds up to [kMaxViaStops] stops the journey must pass through, in
  /// order, each with the least time to spend there. Unlike [options] it is part
  /// of *where* the journey goes, so it belongs to this one search rather than
  /// to the traveller's preferences.
  ///
  /// [pageCursor] asks for a neighbouring window instead of the one around
  /// [time]: pass a cursor from an earlier result and leave **every other
  /// argument exactly as it was**, since a cursor is only meaningful against
  /// the query that produced it.
  Future<JourneyResults> journeys({
    required String fromId,
    required String toId,
    required DateTime time,
    bool arriveBy = false,
    JourneySearchOptions options = const JourneySearchOptions(),
    ViaStops via = ViaStops.none,
    String? pageCursor,
  });

  /// The ordered stops of a vehicle trip, with planned and real-time times —
  /// used to refresh an imported leg's actual departure/arrival.
  Future<List<TripStop>> tripStops(String tripId);

  /// The same trip with the route the whole run takes, about eight times the
  /// answer [tripStops] gives (62 KB against 8 KB for an ICE across Germany),
  /// so asked only when somebody wants the run drawn.
  Future<TripRun> tripRun(String tripId);

  /// The services leaving the station at ([lat], [lon]) with a planned
  /// departure from [from] to [from] + [window]: its departure board. Used to
  /// find an imported leg's run again when its stored trip id has expired.
  Future<List<StopDeparture>> departures({
    required double lat,
    required double lon,
    required DateTime from,
    required Duration window,
  });
}
