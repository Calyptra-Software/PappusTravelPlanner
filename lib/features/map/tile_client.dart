import 'package:http/http.dart';
import 'package:http/retry.dart';

/// How long a host is left alone after a 429 that names no time of its own.
const Duration kTileRateLimitPause = Duration(minutes: 15);

/// Stops asking a host for tiles once it has answered 429.
///
/// A tile layer asks for every tile that comes into view, so without this a
/// server that has said *stop* goes on being asked for as long as someone pans.
/// While a host is paused the request is answered here, with the same status,
/// and never leaves the device.
class RateLimitRespectingClient extends BaseClient {
  RateLimitRespectingClient(this._inner, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Client _inner;
  final DateTime Function() _now;
  final _pausedUntil = <String, DateTime>{};

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final host = request.url.host;
    final until = _pausedUntil[host];
    if (until != null && _now().isBefore(until)) {
      return StreamedResponse(const Stream.empty(), 429, request: request);
    }
    final response = await _inner.send(request);
    if (response.statusCode == 429) {
      _pausedUntil[host] = _now().add(_pauseFor(response));
    }
    return response;
  }

  /// `Retry-After` in its seconds form. Its date form is rare enough here that
  /// the default serves.
  Duration _pauseFor(BaseResponse response) {
    final seconds = int.tryParse(response.headers['retry-after'] ?? '');
    return seconds == null || seconds <= 0
        ? kTileRateLimitPause
        : Duration(seconds: seconds);
  }

  @override
  void close() => _inner.close();
}

/// The client every tile layer shares.
///
/// Shared because the pause has to outlive a layer, which is rebuilt with each
/// change of style. The retry around it is what flutter_map uses by default.
final Client tileHttpClient = RetryClient(RateLimitRespectingClient(Client()));
