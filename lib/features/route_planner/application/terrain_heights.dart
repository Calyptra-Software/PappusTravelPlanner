import 'package:latlong2/latlong.dart';

/// Where the heights of a line come from when its router has none: a ski run,
/// whose map data from Overpass carries no heights (`TerrainTileHeights`).
abstract interface class TerrainHeights {
  /// The height of each of [points] in meters, or null when they cannot be
  /// had: no connection, a server that refused, data that does not read.
  /// All or nothing, as `RoutedPath.elevations` is.
  Future<List<double>?> at(List<LatLng> points);
}
