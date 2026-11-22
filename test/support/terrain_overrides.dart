import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/features/route_planner/application/route_pace_provider.dart';
import 'package:travelplanner/features/route_planner/application/route_planner_providers.dart';
import 'package:travelplanner/features/route_planner/application/terrain_heights.dart';
import 'package:travelplanner/features/route_planner/domain/pace.dart';

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

/// No pace remembered from an earlier tour, without the preferences the real
/// provider reads: every way of travel starts at the average pace.
class _NoRememberedPaces extends RememberedPaces {
  @override
  Map<String, Pace> build() => const {};

  @override
  Future<void> remember(String key, Pace pace) async =>
      state = {...state, key: pace};
}

final Override noRememberedPaces = rememberedPacesProvider.overrideWith(
  _NoRememberedPaces.new,
);
