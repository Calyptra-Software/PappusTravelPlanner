import 'package:latlong2/latlong.dart';

import '../domain/route_profile.dart';
import '../domain/routed_path.dart';

/// A provider-agnostic router over the street and path network.
///
/// An interface for the reason `TransportSearch` is one: the planner depends on
/// the capability, and the server behind it (BRouter by default, see
/// `BrouterRouteEngine`) can be exchanged or pointed at a self-hosted instance
/// without touching the planner. It answers for walking, cycling and driving.
/// Timetabled services are the connection search's, which this never calls.
///
/// A network service: it sits beside the repository, never inside it, and
/// nothing in the offline core depends on it.
abstract interface class RouteEngine {
  /// The way from the first of [waypoints] to the last, through the others in
  /// order, as [profile] would travel it.
  ///
  /// Takes at least two waypoints. Throws [RouteEngineException] when no answer
  /// arrives or the router finds no way.
  Future<RoutedPath> route({
    required List<LatLng> waypoints,
    required RouteProfile profile,
  });
}

/// A failure reaching or reading from the router. The planner maps it to a
/// message beside the section that asked; it never reaches the offline app.
class RouteEngineException implements Exception {
  const RouteEngineException(
    this.message, {
    this.statusCode,
    this.serverMessage,
  });

  final String message;

  /// The HTTP status of a refusal; null when no answer arrived at all.
  final int? statusCode;

  /// What the router said about the refusal, when it said anything.
  final String? serverMessage;

  /// Which of the failures a user is told apart this one is.
  RouteEngineFailure get failure {
    if (statusCode == null) return RouteEngineFailure.unreachable;
    if (statusCode == 400) return RouteEngineFailure.noRoute;
    return RouteEngineFailure.failed;
  }

  @override
  String toString() => 'RouteEngineException: $message';
}

/// The failures of a routing request that call for different words.
enum RouteEngineFailure {
  /// No answer: no connection, or the server took too long.
  unreachable,

  /// The router answered that it has no way between these points: one of them
  /// lies where it has no data or no path within reach.
  noRoute,

  /// The router answered with an error that says nothing about the points.
  failed,
}
