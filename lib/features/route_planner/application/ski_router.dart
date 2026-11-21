import 'package:latlong2/latlong.dart';

import '../domain/piste_difficulty.dart';
import '../domain/routed_path.dart';

/// Finds a ski day's way over the pistes and lifts of an area.
///
/// Beside [RouteEngine] rather than one of its profiles, because no routing
/// server knows lifts: the way is found on the device, over map data loaded
/// for the area (`OverpassSkiRouter`). The answer has a [PathSegment] per
/// ride, descent and walk.
abstract interface class SkiRouter {
  /// The way from the first of [waypoints] to the last, through the others in
  /// order, skiing no piste harder than [maxDifficulty].
  ///
  /// Throws `RouteEngineException` when the map data cannot be loaded or holds
  /// no such way.
  Future<RoutedPath> route({
    required List<LatLng> waypoints,
    required PisteDifficulty maxDifficulty,
  });

  /// Forgets the map data loaded so far, so the next run is routed over data
  /// loaded afresh: for pistes that changed since, or an answer that was
  /// wrong.
  Future<void> forget();
}
