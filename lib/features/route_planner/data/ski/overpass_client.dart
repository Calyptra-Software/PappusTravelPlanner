import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/app_info.dart';
import '../../application/route_engine.dart';

/// The public Overpass API instance the ski router loads pistes and lifts
/// from. Its guidance is about 10,000 queries and 1 GB a day for all of an
/// app's users together, which an area loaded once and kept for weeks stays
/// far below.
final Uri kOverpassUrl = Uri.parse('https://overpass-api.de/api/interpreter');

/// Sends Overpass QL queries to a server and returns its answers as text.
///
/// The text, not the parsed answer, since the text is what is cached on disk.
class OverpassClient {
  OverpassClient({
    http.Client? httpClient,
    Uri? url,
    String? userAgent,
    this.sendUserAgent = true,
  }) : _http = httpClient ?? http.Client(),
       url = url ?? kOverpassUrl,
       userAgent = userAgent ?? buildUserAgent('dev');

  final http.Client _http;
  final Uri url;
  final String userAgent;

  /// Whether [userAgent] goes out as a header: not from a browser, for the
  /// reason `BrouterRouteEngine.sendUserAgent` gives.
  final bool sendUserAgent;

  /// Runs [query] and returns the answer's body.
  ///
  /// Throws [RouteEngineException]: without a status when no answer came, with
  /// the server's status otherwise. Overpass answers 429 when one client asks
  /// too often and 504 when it is overloaded; both are
  /// [RouteEngineFailure.busy], and nothing here asks again by itself.
  Future<String> run(String query) async {
    final http.Response response;
    try {
      response = await _http
          .post(
            url,
            headers: {if (sendUserAgent) 'User-Agent': userAgent},
            // A form field, which a browser sends without asking the server
            // first.
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw const RouteEngineException('Overpass timed out');
    } on http.ClientException catch (e) {
      throw RouteEngineException('Overpass failed: ${e.message}');
    }
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (response.statusCode != 200) {
      throw RouteEngineException(
        'Overpass request failed (${response.statusCode})',
        statusCode: response.statusCode,
        serverMessage: body.trim().isEmpty ? null : body.trim(),
      );
    }
    return body;
  }

  /// Releases the underlying HTTP client.
  void close() => _http.close();
}
