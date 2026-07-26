import '../domain/journey.dart';
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

  /// Plans journeys between two geocoded places.
  ///
  /// [time] is anchored by [arriveBy]: a departure time when false (the
  /// default), an arrival deadline when true.
  Future<List<JourneyOption>> journeys({
    required String fromId,
    required String toId,
    required DateTime time,
    bool arriveBy = false,
  });

  /// The ordered stops of a vehicle trip, with planned and real-time times —
  /// used to refresh an imported leg's actual departure/arrival.
  Future<List<TripStop>> tripStops(String tripId);
}
