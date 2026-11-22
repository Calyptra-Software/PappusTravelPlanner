import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../core/app_info.dart';
import '../application/route_engine.dart';
import '../domain/route_profile.dart';
import '../domain/routed_path.dart';
import 'brouter_parser.dart';

/// The default BRouter server, the instance behind brouter-web. A self-hosted
/// one answers the same requests, so swapping is a change of [baseUrl] only.
final Uri kBrouterBaseUrl = Uri.parse('https://brouter.de/brouter');

/// The stock profile each [RouteProfile] is routed with: the file names in
/// BRouter's `misc/profiles2`, which the public server serves.
String brouterProfileFor(RouteProfile profile) => switch (profile) {
  // A runner takes the same paths as a walker ([RouteProfile.routedAs]);
  // only the time differs.
  RouteProfile.foot || RouteProfile.run => 'hiking-mountain',
  RouteProfile.bike => 'trekking',
  RouteProfile.roadBike => 'fastbike',
  RouteProfile.gravelBike => 'gravel',
  RouteProfile.mountainBike => 'mtb',
  RouteProfile.car => 'car-vario',
};

/// A [RouteEngine] backed by a BRouter server over HTTP.
///
/// The [http.Client] is injected so tests can drive it with recorded answers,
/// and the [userAgent] names the app to a server somebody else runs (see
/// [buildUserAgent]).
class BrouterRouteEngine implements RouteEngine {
  BrouterRouteEngine({
    http.Client? httpClient,
    Uri? baseUrl,
    String? userAgent,
    this.sendUserAgent = true,
  }) : _http = httpClient ?? http.Client(),
       _baseUrl = baseUrl ?? kBrouterBaseUrl,
       userAgent = userAgent ?? buildUserAgent('dev');

  final http.Client _http;
  final Uri _baseUrl;
  final String userAgent;

  /// Whether [userAgent] goes out as a header. Not from a browser: setting it
  /// makes Firefox ask the server first (a CORS preflight), and brouter.de
  /// answers that without allowing the header, so every request would fail.
  /// The browser sends the page's `Referer` instead, as it does for the tiles
  /// (`basemapTileHeaders`). Chrome would drop the header anyway.
  final bool sendUserAgent;

  @override
  Future<RoutedPath> route({
    required List<LatLng> waypoints,
    required RouteProfile profile,
  }) async {
    if (waypoints.length < 2) {
      throw ArgumentError.value(waypoints, 'waypoints', 'needs two or more');
    }
    final uri = _baseUrl.replace(
      queryParameters: {
        ..._baseUrl.queryParameters,
        // Longitude first, which is this server's order and not the app's.
        'lonlats': [
          for (final point in waypoints)
            '${_degrees(point.longitude)},${_degrees(point.latitude)}',
        ].join('|'),
        'profile': brouterProfileFor(profile),
        'alternativeidx': '0',
        'format': 'geojson',
      },
    );
    final http.Response response;
    try {
      response = await _http
          .get(uri, headers: {if (sendUserAgent) 'User-Agent': userAgent})
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const RouteEngineException('Routing timed out');
    } on http.ClientException catch (e) {
      throw RouteEngineException('Routing failed: ${e.message}');
    }
    if (response.statusCode != 200) {
      // A refusal is plain text ("datafile W30_N45.rd5 not found"), or empty.
      final said = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
      throw RouteEngineException(
        'BRouter request failed (${response.statusCode})',
        statusCode: response.statusCode,
        serverMessage: said.isEmpty ? null : said,
      );
    }
    try {
      return parseBrouterResponse(jsonDecode(utf8.decode(response.bodyBytes)));
    } on FormatException catch (e) {
      throw RouteEngineException(
        'Unreadable BRouter answer: ${e.message}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Six decimals, about a decimeter: finer than a tap on a map, and never the
  /// exponent form a very small double prints as.
  static String _degrees(double value) => value.toStringAsFixed(6);

  /// Releases the underlying HTTP client.
  void close() => _http.close();
}
