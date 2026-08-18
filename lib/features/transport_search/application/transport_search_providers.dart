import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_info.dart';
import '../../../core/providers.dart';
import '../data/motis_client.dart';
import '../domain/journey.dart';
import '../domain/journey_ends.dart';
import '../domain/journey_options.dart';
import '../domain/transport_place.dart';
import '../domain/via_stop.dart';
import 'search_language_provider.dart';
import 'transport_search.dart';

/// The connection-search backend (MOTIS via Transitous by default). It holds an
/// HTTP client, so it lives for the app session and is closed on dispose. A
/// network service, it sits *beside* the repository, never inside it — the
/// offline database has no dependency on it.
///
/// Watching [searchLanguageProvider] rebuilds it when the app's language
/// changes, so every endpoint keeps answering in one language (see
/// [MotisTransportSearch.language]).
///
/// This is where the app's real version reaches the wire: the service's usage
/// policy asks each request to name the client and its version, and only the
/// running app knows the latter.
final transportSearchProvider = Provider<TransportSearch>((ref) {
  final client = MotisTransportSearch(
    language: ref.watch(searchLanguageProvider),
    userAgent: buildUserAgent(ref.watch(appVersionProvider)),
  );
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
/// share one cached result. [JourneySearchOptions] and [ViaStops] compare by
/// value for the same reason.
///
/// [fromName] / [toName] name the two ends as the user picked them. They are not
/// sent anywhere: they are what `resolvedEnds` puts on an end the router could
/// only answer with a placeholder, which is why they ride here rather than being
/// applied by whoever reads the results — the paging windows are joined inside
/// the controller, and a window resolved differently from the one it is merged
/// onto would be two answers to one question. Being part of the key is harmless:
/// a name travels with the place it belongs to, so two searches that differ only
/// in it do not arise.
typedef JourneyQuery = ({
  String fromId,
  String toId,
  String fromName,
  String toName,
  ViaStops via,
  DateTime time,
  bool arriveBy,
  JourneySearchOptions options,
});

/// The journeys found for a [JourneyQuery], growing as further time windows are
/// loaded. Driven by an explicit search (not per keystroke), so unlike
/// [geocodeProvider] it isn't debounced.
///
/// A notifier rather than a `FutureProvider` because the results *accumulate*:
/// the service answers with one window around the requested time, and
/// "earlier"/"later" join the neighbouring windows onto the same list rather
/// than replacing it.
final journeyResultsProvider = AsyncNotifierProvider.autoDispose
    .family<JourneyResultsController, JourneyResults, JourneyQuery>(
      JourneyResultsController.new,
    );

class JourneyResultsController extends AsyncNotifier<JourneyResults> {
  JourneyResultsController(this.query);

  final JourneyQuery query;

  @override
  Future<JourneyResults> build() => _fetch();

  /// Loads the window before the ones on screen. See [_loadMore].
  Future<bool> loadEarlier() => _loadMore(earlier: true);

  /// Loads the window after the ones on screen. See [_loadMore].
  Future<bool> loadLater() => _loadMore(earlier: false);

  /// Fetches a neighbouring window and joins it on, answering whether it
  /// arrived.
  ///
  /// A failure here is deliberately **not** put into `state`: the journeys
  /// already found are what the user is reading, and replacing them with an
  /// error because one further window couldn't be fetched would throw away the
  /// results to report a failure of something else. The caller shows the
  /// failure instead, and the button is still there to tap again.
  Future<bool> _loadMore({required bool earlier}) async {
    final current = state.value;
    final cursor = earlier ? current?.earlierCursor : current?.laterCursor;
    if (current == null || cursor == null) return false;
    try {
      final page = await _fetch(pageCursor: cursor);
      // The sheet can be closed mid-flight; this provider is autoDispose.
      if (!ref.mounted) return false;
      state = AsyncData(current.merge(page, earlier: earlier));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<JourneyResults> _fetch({String? pageCursor}) async {
    final results = await ref
        .read(transportSearchProvider)
        .journeys(
          fromId: query.fromId,
          toId: query.toId,
          via: query.via,
          time: query.time,
          arriveBy: query.arriveBy,
          options: query.options,
          pageCursor: pageCursor,
        );
    // One of the two places a search's answer arrives, and so one of the two
    // that resolve the ends the router addressed by coordinate — before the
    // results are read, merged or imported. See `journey_ends.dart`.
    return resolvedEnds(
      results,
      fromName: query.fromName,
      toName: query.toName,
    );
  }
}
