import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/features/route_planner/application/route_planner_providers.dart';
import 'package:travelplanner/features/route_planner/application/terrain_heights.dart';

/// [TerrainHeights] that never has any, as from a server out of reach.
class NoTerrainHeights implements TerrainHeights {
  const NoTerrainHeights();

  @override
  Future<List<double>?> at(List<LatLng> points) async => null;
}

/// The planner asks for the heights of every line drawn by hand; a test that
/// is not about them gets none, without a network or the preferences the
/// real provider reads.
final Override noTerrainHeights = terrainHeightsProvider.overrideWithValue(
  const NoTerrainHeights(),
);
