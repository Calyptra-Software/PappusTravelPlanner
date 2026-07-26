import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../application/transport_search.dart';
import '../domain/journey.dart';
import '../domain/journey_options.dart';
import '../domain/transit_filter.dart';
import '../domain/transport_place.dart';
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
/// with recorded responses. A descriptive `User-Agent` identifies the app to
/// the (donated) service, as such services expect.
class MotisTransportSearch implements TransportSearch {
  MotisTransportSearch({
    http.Client? httpClient,
    Uri? baseUrl,
    this.userAgent = _defaultUserAgent,
  }) : _http = httpClient ?? http.Client(),
       _baseUrl = baseUrl ?? kTransitousBaseUrl;

  static const String _defaultUserAgent = 'TravelPlanner (connection search)';

  final http.Client _http;
  final Uri _baseUrl;
  final String userAgent;

  @override
  Future<List<TransportPlace>> searchPlaces(String query) async {
    final body = await _get('/api/v1/geocode', {
      'text': query,
      'language': 'de',
    });
    return parseGeocodeResponse(body);
  }

  @override
  Future<List<JourneyOption>> journeys({
    required String fromId,
    required String toId,
    required DateTime time,
    bool arriveBy = false,
    JourneySearchOptions options = const JourneySearchOptions(),
  }) async {
    // `transitModes` is sent only as a *restriction*: omitted, the server
    // applies its own `TRANSIT` default, which is the wider (and future-proof)
    // set. An unknown token is rejected outright (HTTP 500, "unknown value"),
    // so the list may only ever be built from `motisTransitModes`.
    final modes = motisTransitModes(options.modes);
    final body = await _get('/api/v1/plan', {
      'fromPlace': fromId,
      'toPlace': toId,
      'time': _rfc3339Seconds(time),
      'arriveBy': arriveBy.toString(),
      if (modes.isNotEmpty) 'transitModes': modes.join(','),
    });
    return parsePlanResponse(body);
  }

  @override
  Future<List<TripStop>> tripStops(String tripId) async {
    final body = await _get('/api/v1/trip', {'tripId': tripId});
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
