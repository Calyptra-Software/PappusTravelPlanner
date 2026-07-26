import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/motis_client.dart';
import '../domain/journey.dart';
import '../domain/journey_options.dart';
import '../domain/transport_place.dart';
import 'transport_search.dart';

/// The connection-search backend (MOTIS via Transitous by default). It holds an
/// HTTP client, so it lives for the app session and is closed on dispose. A
/// network service, it sits *beside* the repository, never inside it — the
/// offline database has no dependency on it.
final transportSearchProvider = Provider<TransportSearch>((ref) {
  final client = MotisTransportSearch();
  ref.onDispose(client.close);
  return client;
});

/// Station/place suggestions for a (partial) query, **debounced** so typing
/// doesn't fire a request per keystroke: a query is held briefly, and if it is
/// superseded (the field changed, disposing this entry) it is dropped before it
/// ever reaches the network. A query shorter than two characters resolves to
/// nothing without a call. `autoDispose.family` also caches per query string, so
/// re-typing a recent query is free.
final geocodeProvider = FutureProvider.autoDispose
    .family<List<TransportPlace>, String>((ref, query) async {
      final trimmed = query.trim();
      if (trimmed.length < 2) return const [];
      var superseded = false;
      ref.onDispose(() => superseded = true);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (superseded) return const [];
      return ref.watch(transportSearchProvider).searchPlaces(trimmed);
    });

/// The parameters of a journey search — a value type, so two identical searches
/// share one cached result. [JourneySearchOptions] compares by value for the
/// same reason.
typedef JourneyQuery = ({
  String fromId,
  String toId,
  DateTime time,
  bool arriveBy,
  JourneySearchOptions options,
});

/// Planned journeys for a [JourneyQuery]. Driven by an explicit search (not per
/// keystroke), so unlike [geocodeProvider] it isn't debounced.
final journeysProvider = FutureProvider.autoDispose
    .family<List<JourneyOption>, JourneyQuery>((ref, q) {
      return ref
          .watch(transportSearchProvider)
          .journeys(
            fromId: q.fromId,
            toId: q.toId,
            time: q.time,
            arriveBy: q.arriveBy,
            options: q.options,
          );
    });
