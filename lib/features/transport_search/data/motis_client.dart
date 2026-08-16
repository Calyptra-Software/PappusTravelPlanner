import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/app_info.dart';
import '../application/transport_search.dart';
import '../domain/journey.dart';
import '../domain/journey_options.dart';
import '../domain/transit_filter.dart';
import '../domain/transport_place.dart';
import '../domain/via_stop.dart';
import 'motis_parser.dart';

/// The default MOTIS server: the community-run Transitous instance. MOTIS is the
/// API contract (and the engine); Transitous is a server that implements it with
/// open GTFS data loaded. Swapping to a self-hosted instance later is only a
/// change of [baseUrl] — the request/response shape is identical.
final Uri kTransitousBaseUrl = Uri.parse('https://api.transitous.org');

/// A [TransportSearch] backed by the MOTIS API over HTTP.
///
/// The [baseUrl] is injected so it can point at Transitous (the default) or a
/// self-hosted MOTIS, and the [http.Client] is injected so tests can drive it
/// with recorded responses. The [userAgent] identifies the app to the (donated)
/// service, which its usage policy requires — see [buildUserAgent].
class MotisTransportSearch implements TransportSearch {
  MotisTransportSearch({
    http.Client? httpClient,
    Uri? baseUrl,
    String? userAgent,
    this.language = _defaultLanguage,
  }) : _http = httpClient ?? http.Client(),
       _baseUrl = baseUrl ?? kTransitousBaseUrl,
       userAgent = userAgent ?? _defaultUserAgent;

  /// Only a fallback for a client built without one (the smoke tool, tests) —
  /// the app always passes its real version, via `transportSearchProvider`.
  /// It still carries a name and a contact, so an unversioned request coming
  /// off a developer machine is not an anonymous one.
  static final String _defaultUserAgent = buildUserAgent('dev');

  /// Whether to ask for a leg's route shape and turn-by-turn instructions.
  ///
  /// Sent **per call**, because the two endpoints want opposite answers — the
  /// split this comment anticipated before there was a map to want it.
  ///
  /// The **search** asks for it (`true`): its answer is what an import writes
  /// into the plan, and the shape is what makes the map draw a train along its
  /// line instead of a chord across the country. Measured against Transitous, a
  /// five-itinerary plan costs 57 KB → 103 KB for that.
  ///
  /// The **live refresh** does not (`false`), and this is the one that matters:
  /// it is the button pressed again and again on a platform while a train runs
  /// late, and it costs 8 KB → 62 KB — eight times the data for a shape that a
  /// delay does not change. The geocoder has no legs at all.
  ///
  /// Nothing else read here changes either way: every parsed field, both paging
  /// cursors, the direct connections and a trip's `intermediateStops` come back
  /// identical.
  static const String _detailedLegs = 'detailedLegs';

  /// Only a fallback for a client built without one (the smoke tool, tests) —
  /// the app always passes the language it is showing, via
  /// `searchLanguageProvider`.
  static const String _defaultLanguage = 'en';

  final http.Client _http;
  final Uri _baseUrl;

  /// How this client names itself to the service: application, version, and a
  /// way of contact, which is exactly what the Transitous usage policy asks
  /// every request to carry.
  ///
  /// Sent on every call — except in a browser, where it cannot be: `User-Agent`
  /// is a forbidden header name, so the runtime drops it and the request goes
  /// out with the browser's own. The policy anticipates this and accepts the
  /// `Referer` instead, on condition that the page serving the app carries
  /// contact information; that is a duty of the web *deployment*, not of this
  /// class, and nothing here can discharge it.
  final String userAgent;

  /// The language names come back in, sent on **every** endpoint.
  ///
  /// Not per call: a leg imported with Dutch stop names and later refreshed
  /// with French ones would leave `refreshedActualTimes` comparing
  /// `Brussel-Zuid` with `Brux.-Midi/Brus.-Zuid` on its name fallback. One
  /// language per client keeps the plan and its live refresh talking about the
  /// same stops.
  final String language;

  @override
  Future<List<TransportPlace>> searchPlaces(String query) async {
    final body = await _get('/api/v1/geocode', {
      'text': query,
      'language': language,
    });
    return parseGeocodeResponse(body);
  }

  @override
  Future<JourneyResults> journeys({
    required String fromId,
    required String toId,
    required DateTime time,
    bool arriveBy = false,
    JourneySearchOptions options = const JourneySearchOptions(),
    ViaStops via = ViaStops.none,
    String? pageCursor,
  }) async {
    // `transitModes` is sent only as a *restriction*: omitted, the server
    // applies its own `TRANSIT` default, which is the wider (and future-proof)
    // set. An unknown token is rejected outright (HTTP 500, "unknown value"),
    // so the list may only ever be built from `motisTransitModes`.
    final modes = motisTransitModes(options.modes);
    final body = await _get('/api/v6/plan', {
      'fromPlace': fromId,
      'toPlace': toId,
      'time': _rfc3339Seconds(time),
      'arriveBy': arriveBy.toString(),
      'language': language,
      _detailedLegs: 'true',
      if (modes.isNotEmpty) 'transitModes': modes.join(','),
      if (options.minTransferMinutes > 0)
        'minTransferTime': '${options.minTransferMinutes}',
      // `maxTransfers` counts interchanges only from v3 on — before that
      // `maxTransfers=1` means "direct only", the opposite of what the user
      // picked. This client talks v6 (see the paths above); do not move it back.
      if (options.maxTransfers != null)
        'maxTransfers': '${options.maxTransfers}',
      ..._walkingParams(options),
      ..._wheelchairParams(options),
      ..._bikeParams(options),
      ..._viaParams(via),
      // The cursor carries the window; the rest of the query must be repeated
      // unchanged beside it, which is why it is a parameter here and not a
      // separate call.
      'pageCursor': ?pageCursor,
    });
    return parsePlanResponse(body);
  }

  /// The stops the journey is asked to pass through, as the query writes them:
  /// one comma-joined list, in the order they are visited (the spec's
  /// `explode: false`).
  ///
  /// `via` takes **stop ids only** — the spec allows no coordinates here at all,
  /// which is what confines the picker behind it to stations; sending a
  /// `lat,lon` the way [TransportPlace.queryId] does for an address would be
  /// rejected rather than routed.
  ///
  /// `viaMinimumStay` is a **parallel array**, so it is all or nothing: a stay
  /// for the second stop can only be sent alongside one for the first, and
  /// naming just the stops that have a stay would silently attach them to the
  /// wrong ones. Sent, then, only when some stop asks for one, and then for
  /// every stop. Omitting it entirely is the service's own `0` for each, which
  /// does not merely mean "no wait": it says the traveller need not get off, so
  /// the via may be passed through on the same vehicle — often a connection
  /// with one change fewer.
  static Map<String, String> _viaParams(ViaStops via) {
    assert(
      via.length <= kMaxViaStops,
      'the service accepts at most $kMaxViaStops via stops',
    );
    if (via.isEmpty) return const {};
    final stays = [for (final stop in via.stops) stop.minimumStayMinutes];
    return {
      'via': [for (final stop in via.stops) stop.id].join(','),
      if (stays.any((minutes) => minutes > 0))
        'viaMinimumStay': stays.join(','),
    };
  }

  /// Everything "step-free only" turns into: **two** parameters, and the second
  /// is not optional decoration.
  ///
  /// `pedestrianProfile=WHEELCHAIR` alone routes the street legs for a
  /// wheelchair (verified live: the walk to the first stop grows from 5 to 12
  /// minutes) and does nothing else — the transfers inside stations keep their
  /// precomputed foot times, and the search still offers services the timetable
  /// marks `NOT_ACCESSIBLE`. Both of those only change with
  /// `useRoutedTransfers=true`, because the server passes the wheelchair
  /// profile down to the routing engine *only* when transfers are routed on OSM
  /// data, and it is that same profile flag which filters the trips. So one
  /// without the other is a half-answer wearing an accessibility label; they are
  /// sent together, exactly as the official MOTIS UI couples its two switches.
  ///
  /// Nothing at all when it is off: the service's own `FOOT` and precomputed
  /// transfers, which is what every other search here has always used.
  ///
  /// A caveat the UI has to carry, like bike carriage: GTFS `wheelchair_
  /// accessible` counts only an explicit "yes" (`1`), so a feed that simply
  /// says nothing reports `NOT_ACCESSIBLE` and is filtered out. Verified live —
  /// Hamburg→Lüneburg drops from 6 connections to 1 (and from 43 to 316
  /// minutes), Amsterdam→Utrecht from 5 to **none at all**.
  static Map<String, String> _wheelchairParams(JourneySearchOptions options) {
    if (!options.wheelchair) return const {};
    return {'pedestrianProfile': 'WHEELCHAIR', 'useRoutedTransfers': 'true'};
  }

  /// Everything travelling with a bike turns into.
  ///
  /// Nothing at all when there is no bike: the service then applies its own
  /// `WALK` defaults, and a `cyclingSpeed` for a bike nobody is riding would
  /// only be noise on the wire.
  ///
  /// The asymmetry between the two ends is deliberate. A bike ridden to the
  /// first stop and left there is not waiting at the far end, so only
  /// `preTransitModes` gets it; it is [JourneySearchOptions.bikeOnBoard] —
  /// which also restricts the search to services that carry bikes — that puts
  /// the bike back under the traveller for the last mile. Both ends apply to a
  /// *coordinate* endpoint only, which is why a picked address is queried by
  /// coordinate (see [TransportPlace.queryId]); from a station id the router
  /// has no first mile to route.
  static Map<String, String> _bikeParams(JourneySearchOptions options) {
    if (!options.byBike) return const {};
    const withBike = 'WALK,BIKE';
    return {
      'directModes': withBike,
      'preTransitModes': withBike,
      'postTransitModes': options.bikeOnBoard ? withBike : 'WALK',
      'cyclingSpeed': (options.cyclingSpeedKmh / 3.6).toStringAsFixed(3),
      if (options.bikeOnBoard) 'requireBikeTransport': 'true',
    };
  }

  /// The service's own defaults, in seconds, for the walking budgets scaled
  /// below. Nothing reads them back — they are only the base a slow walker's
  /// allowance is grown from.
  static const int _defaultPrePostTransitSeconds = 900;
  static const int _defaultDirectSeconds = 1800;

  /// Everything one "how fast do you walk" setting turns into.
  ///
  /// Three parameters, because the service scales the two halves of a journey's
  /// walking separately (both verified against Transitous):
  ///
  /// - `pedestrianSpeed` (m/s) governs the street legs — to the first stop,
  ///   from the last, and any direct walk.
  /// - `transferTimeFactor` governs the footpaths *inside* stations, which are
  ///   precomputed and which `pedestrianSpeed` does not touch at all. Sent only
  ///   when it would **lengthen** them: the spec declares factors below 1.0
  ///   unsupported, and buying tighter changes than the timetable's own minimum
  ///   is not a trade worth making on undefined behaviour.
  /// - the three time budgets, which are either what the traveller asked for or
  ///   — left automatic — the service's own, grown by the same ratio, because a
  ///   slow walker otherwise falls off a cliff: at 0.6 m/s the walk to the
  ///   first stop no longer fits in the default 900 s and the search returns
  ///   **nothing**, an empty screen that blames the route rather than the
  ///   setting. Oversized values are safe; the server clamps them to its own
  ///   configuration.
  static Map<String, String> _walkingParams(JourneySearchOptions options) {
    final kmh = options.walkingSpeedKmh;
    final slowdown = kNormalWalkingSpeedKmh / kmh;
    return {
      'pedestrianSpeed': (kmh / 3.6).toStringAsFixed(3),
      if (slowdown > 1.0) 'transferTimeFactor': slowdown.toStringAsFixed(2),
      'maxPreTransitTime': ?_budget(
        options.maxPreTransitMinutes,
        _defaultPrePostTransitSeconds,
        slowdown,
      ),
      'maxPostTransitTime': ?_budget(
        options.maxPostTransitMinutes,
        _defaultPrePostTransitSeconds,
        slowdown,
      ),
      'maxDirectTime': ?_budget(
        options.maxDirectMinutes,
        _defaultDirectSeconds,
        slowdown,
      ),
    };
  }

  /// One walking budget in seconds: what was **chosen**, used exactly as
  /// chosen — a number someone picked is never quietly multiplied because they
  /// also said they walk slowly — else the stretched default for a slow walker,
  /// else nothing at all, leaving the service on its own default.
  static String? _budget(int? minutes, int defaultSeconds, double slowdown) {
    if (minutes != null) return '${minutes * 60}';
    return slowdown > 1.0 ? '${(defaultSeconds * slowdown).round()}' : null;
  }

  @override
  Future<List<TripStop>> tripStops(String tripId) async {
    final body = await _get('/api/v6/trip', {
      'tripId': tripId,
      'language': language,
      _detailedLegs: 'false',
    });
    return parseTripResponse(body);
  }

  Future<dynamic> _get(String path, Map<String, String> query) async {
    final uri = _baseUrl.replace(
      path: path,
      queryParameters: {..._baseUrl.queryParameters, ...query},
    );
    final http.Response response;
    try {
      response = await _http
          .get(uri, headers: {'User-Agent': userAgent})
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const TransportSearchException('Connection search timed out');
    } on http.ClientException catch (e) {
      // No connectivity, DNS failure, TLS error, etc. — surface it so the UI
      // shows a retry instead of spinning forever.
      throw TransportSearchException('Connection search failed: ${e.message}');
    }
    if (response.statusCode != 200) {
      throw TransportSearchException(
        'MOTIS request failed (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  /// Formats [time] as UTC RFC 3339 with **seconds** precision (`...:00Z`).
  ///
  /// `DateTime.toIso8601String()` appends fractional seconds when present
  /// (`...:25.664866Z`); the MOTIS server rejects that and silently falls back
  /// to "now", so a query for a future day quietly returns today's departures.
  /// Truncating to whole seconds keeps the requested time honoured.
  static String _rfc3339Seconds(DateTime time) {
    final t = time.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}'
        'T${two(t.hour)}:${two(t.minute)}:${two(t.second)}Z';
  }

  /// Releases the underlying HTTP client. Call when the owning provider is
  /// disposed.
  void close() => _http.close();
}

/// A failure reaching or reading from the connection-search service. The UI maps
/// this to a friendly, retryable state; it never propagates to the rest of the
/// (offline) app.
class TransportSearchException implements Exception {
  const TransportSearchException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'TransportSearchException: $message';
}
