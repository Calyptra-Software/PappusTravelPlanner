import '../domain/journey.dart';
import '../domain/journey_options.dart';
import '../domain/transport_place.dart';

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
    String? pageCursor,
  });

  /// The ordered stops of a vehicle trip, with planned and real-time times —
  /// used to refresh an imported leg's actual departure/arrival.
  Future<List<TripStop>> tripStops(String tripId);
}
