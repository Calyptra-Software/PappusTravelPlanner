import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../l10n/app_localizations.dart';
import '../application/visited_countries_providers.dart';
import '../finite_camera.dart';
import '../visited_countries.dart';

/// The world as far as Web Mercator draws it. The poles are cut where the
/// projection stops being usable, which is also where the outline set stops
/// having anything to say.
final LatLngBounds _world = LatLngBounds(
  const LatLng(-85, -180),
  const LatLng(85, 180),
);

/// The world, with the countries a trip touched filled in.
///
/// A map with **no tiles at all**. Everything drawn is the bundled outline set,
/// so this costs nobody's donated server, works with no connection, and works
/// on the web from the first day — none of which is true of the other maps. It
/// is also the honest picture: the question is which countries, not what the
/// ground looks like, and a street map underneath would answer a question
/// nobody asked while making the fills harder to read.
class VisitedCountriesMap extends ConsumerWidget {
  const VisitedCountriesMap({super.key, required this.tripId, this.accent});

  /// The trip to report on, or null for every trip.
  final int? tripId;
  final Color? accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final outlines = ref.watch(countryOutlinesProvider);
    final visited = ref.watch(visitedCountriesProvider(tripId));

    return outlines.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(l10n.genericError('$error'))),
      data: (countries) {
        if (visited.isEmpty) return _NothingPlaced(l10n: l10n);
        final fill = accent ?? theme.colorScheme.primary;
        final names = [
          for (final country in countries)
            if (visited.contains(country.code)) country.name(language),
        ]..sort();

        return Column(
          children: [
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  // With nothing but outlines there is no detail to zoom into;
                  // the point is the shape of the record at a glance.
                  minZoom: 1,
                  maxZoom: 6,
                  initialCenter: const LatLng(25, 10),
                  // Fitted *inside* the world rather than around it, which is
                  // what keeps exactly one of it on screen: fitting around
                  // would leave room beside the edges, and flutter_map fills
                  // that room with the next copy. The constraint below cannot
                  // do this on its own — it is consulted on moves, and the
                  // camera a map opens with was never moved.
                  initialCameraFit: CameraFit.insideBounds(
                    bounds: _world,
                    padding: const EdgeInsets.all(8),
                  ),
                  // One world, once. Zoomed out far enough that the world is
                  // narrower than the screen, flutter_map repeats it sideways —
                  // which is right for a street map somebody is panning around
                  // the date line, and wrong here: three Germanies shaded on one
                  // screen read as three visits. `contain` refuses a camera that
                  // cannot fit inside the world's own bounds, which is exactly
                  // that case.
                  cameraConstraint: FiniteCamera(
                    then: CameraConstraint.contain(bounds: _world),
                  ),
                  // The sea. flutter_map's own default is a pale grey meant to
                  // sit under tiles, and there are no tiles here — left alone it
                  // is a white sheet in a dark app.
                  backgroundColor: theme.colorScheme.surfaceContainerLowest,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  PolygonLayer(
                    // Unvisited first, so a filled country is never hidden
                    // under the outline of the one it borders.
                    polygons: [
                      for (final country in countries)
                        if (!visited.contains(country.code))
                          ..._shapes(
                            country,
                            border: theme.colorScheme.outlineVariant,
                          ),
                      for (final country in countries)
                        if (visited.contains(country.code))
                          ..._shapes(
                            country,
                            border: fill,
                            fill: fill.withValues(alpha: 0.55),
                          ),
                    ],
                  ),
                ],
              ),
            ),
            _Legend(
              count: visited.length,
              names: names,
              l10n: l10n,
              theme: theme,
            ),
          ],
        );
      },
    );
  }

  /// One polygon per landmass, holes and all — so an enclave is drawn as the
  /// separate country it is rather than swallowed by the one around it.
  Iterable<Polygon> _shapes(
    CountryOutline country, {
    required Color border,
    Color? fill,
  }) sync* {
    for (final polygon in country.polygons) {
      yield Polygon(
        points: polygon.first,
        holePointsList: polygon.length > 1 ? polygon.skip(1).toList() : null,
        borderColor: border,
        borderStrokeWidth: 0.6,
        color: fill,
      );
    }
  }
}

/// The count, and which ones — because a shaded map says *how much* while a
/// list says *which*, and at this scale a small country is a few pixels.
class _Legend extends StatelessWidget {
  const _Legend({
    required this.count,
    required this.names,
    required this.l10n,
    required this.theme,
  });

  final int count;
  final List<String> names;
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.countriesVisited(count),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 96),
              child: SingleChildScrollView(
                child: Text(
                  names.join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when nothing carries coordinates.
///
/// A world map with nothing filled in would look like an answer — "you have
/// been nowhere" — when the truth is that nothing has been placed yet.
class _NothingPlaced extends StatelessWidget {
  const _NothingPlaced({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.public_off,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.countriesNothingPlaced,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.countriesNothingPlacedHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
