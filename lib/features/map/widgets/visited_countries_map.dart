import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../application/visited_countries_providers.dart';
import '../finite_camera.dart';
import '../visited_countries.dart';

/// How wide one whole world is, in pixels, at zoom zero.
const double _worldPixels = 256;

/// Which countries a trip — or the whole record — has stood in.
///
/// A map with **no tiles at all**. Everything drawn is the bundled outline set,
/// so this costs nobody's donated server, works with no connection, and worked
/// on the web from its first day — none of which is true of the other maps. It
/// is also the honest picture: the question is which countries, not what the
/// ground looks like, and a street map underneath would answer a question
/// nobody asked while making the fills harder to read.
///
/// Under it, the tally per region and the list itself. The map says *how much*
/// at a glance; at world scale a country can be four pixels across, so only the
/// list can say *which*.
class VisitedCountriesMap extends ConsumerWidget {
  const VisitedCountriesMap({super.key, required this.tripId, this.accent});

  /// The trip to report on, or null for every trip.
  final int? tripId;
  final Color? accent;

  /// Marking a country by hand is a statement about a life, not about one
  /// journey, so it is offered only where the question is about all of them.
  bool get _canMark => tripId == null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final outlines = ref.watch(countryOutlinesProvider);
    final visited = ref.watch(allVisitedCountriesProvider(tripId));
    final marked = ref.watch(markedCountriesProvider).value ?? const <String>{};

    return outlines.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(l10n.genericError('$error'))),
      data: (countries) {
        final fill = accent ?? theme.colorScheme.primary;
        final tallies = regionTallies(countries, visited);
        final byRegion = <String, List<CountryOutline>>{};
        for (final country in countries) {
          byRegion.putIfAbsent(country.region, () => []).add(country);
        }

        return ListView(
          children: [
            // Twice as wide as it is tall. The zoom is fixed by the width —
            // any less and flutter_map starts drawing the next copy of the
            // world beside this one — so the *height* is what decides how much
            // of the world is on screen, and a fixed one cropped it to a band
            // on a wide window. At 2:1 the view reaches roughly the polar
            // circles, which is every latitude anybody travels to.
            // Twice as wide as it is tall, and never more than half the
            // screen. The zoom is fixed by the width — any less and flutter_map
            // draws the next copy of the world beside this one — so the height
            // is what decides how much of the world is on screen. Where the cap
            // bites, the map gives up *width* rather than latitude and sits
            // centred: a whole world with a margin reads better than a band
            // with the poles cut off, and stretching it edge to edge is what
            // cost Scandinavia and Patagonia.
            Builder(
              builder: (context) {
                final size = MediaQuery.sizeOf(context);
                final height = math.min(size.width / 2, size.height * 0.5);
                return Center(
                  child: SizedBox(
                    width: height * 2,
                    height: height,
                    child: _WorldMap(
                      countries: countries,
                      visited: visited,
                      fill: fill,
                    ),
                  ),
                );
              },
            ),
            _TallyRow(
              label: l10n.countriesWorld,
              visited: visited.length,
              total: countries.length,
              l10n: l10n,
              theme: theme,
              emphasis: true,
            ),
            if (_canMark)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  l10n.countriesMarkHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (final tally in tallies)
              _RegionSection(
                tally: tally,
                countries: (byRegion[tally.region] ?? const [])
                  ..sort(
                    (a, b) => a.name(language).compareTo(b.name(language)),
                  ),
                visited: visited,
                marked: marked,
                language: language,
                canMark: _canMark,
                l10n: l10n,
                theme: theme,
                onToggle: (code, value) =>
                    ref.read(repositoryProvider).setCountryMarked(code, value),
              ),
          ],
        );
      },
    );
  }
}

/// The outlines, with the visited ones filled.
class _WorldMap extends StatefulWidget {
  const _WorldMap({
    required this.countries,
    required this.visited,
    required this.fill,
  });

  final List<CountryOutline> countries;
  final Set<String> visited;
  final Color fill;

  @override
  State<_WorldMap> createState() => _WorldMapState();
}

class _WorldMapState extends State<_WorldMap> {
  final MapController _controller = MapController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The zoom at which one whole world is exactly as wide as the map.
        //
        // Computed rather than fixed, because it is the answer to a question
        // about *this* screen: below it flutter_map starts drawing the next
        // copy of the world beside this one, and three shaded Germanies read as
        // three visits. Above it, on a narrow phone, the world would be cropped
        // to a band — which is what a constant looked like on a wide window and
        // wrong on every other.
        final fit = math.log(constraints.maxWidth / _worldPixels) / math.ln2;
        return Stack(
          fit: StackFit.expand,
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                minZoom: fit,
                maxZoom: 8,
                initialZoom: fit,
                initialCenter: const LatLng(20, 0),
                // Latitude only: the zoom floor above already rules out a
                // second world sideways, and constraining longitude as well
                // would refuse the very camera the map opens with.
                cameraConstraint: const FiniteCamera(
                  then: CameraConstraint.containLatitude(),
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
                  // Unvisited first, so a filled country is never hidden under
                  // the outline of the one it borders.
                  polygons: [
                    for (final country in widget.countries)
                      if (!widget.visited.contains(country.code))
                        ..._shapes(
                          country,
                          border: theme.colorScheme.outlineVariant,
                        ),
                    for (final country in widget.countries)
                      if (widget.visited.contains(country.code))
                        ..._shapes(
                          country,
                          border: widget.fill,
                          fill: widget.fill.withValues(alpha: 0.55),
                        ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: _ZoomButtons(controller: _controller, minZoom: fit),
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

/// `+` / `−` for a map with no wheel under it.
///
/// Its own rather than the shared `MapZoomButtons`, which clamps to the app's
/// tile zoom range; here the floor is whatever puts one world on screen.
class _ZoomButtons extends StatelessWidget {
  const _ZoomButtons({required this.controller, required this.minZoom});

  final MapController controller;
  final double minZoom;

  void _by(double delta) {
    final camera = controller.camera;
    controller.move(camera.center, (camera.zoom + delta).clamp(minZoom, 8));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ZoomButton(
          icon: Icons.add,
          tooltip: l10n.mapZoomIn,
          onPressed: () => _by(1),
        ),
        const SizedBox(height: 6),
        _ZoomButton(
          icon: Icons.remove,
          tooltip: l10n.mapZoomOut,
          onPressed: () => _by(-1),
        ),
      ],
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
    elevation: 2,
    shape: const CircleBorder(),
    child: IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    ),
  );
}

/// "12 of 50 · 24 %", with a bar under it.
class _TallyRow extends StatelessWidget {
  const _TallyRow({
    required this.label,
    required this.visited,
    required this.total,
    required this.l10n,
    required this.theme,
    this.emphasis = false,
  });

  final String label;
  final int visited;
  final int total;
  final AppLocalizations l10n;
  final ThemeData theme;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0 : (visited * 100 / total).round();
    return Padding(
      padding: EdgeInsets.fromLTRB(16, emphasis ? 16 : 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: emphasis
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.titleSmall,
                ),
              ),
              Text(
                l10n.countriesRatio(visited, total, percent),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : visited / total,
              minHeight: emphasis ? 6 : 4,
            ),
          ),
        ],
      ),
    );
  }
}

/// One region: its tally, and the countries in it.
class _RegionSection extends StatelessWidget {
  const _RegionSection({
    required this.tally,
    required this.countries,
    required this.visited,
    required this.marked,
    required this.language,
    required this.canMark,
    required this.l10n,
    required this.theme,
    required this.onToggle,
  });

  final RegionTally tally;
  final List<CountryOutline> countries;
  final Set<String> visited;
  final Set<String> marked;
  final String language;
  final bool canMark;
  final AppLocalizations l10n;
  final ThemeData theme;
  final void Function(String code, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: _TallyRow(
        label: regionLabel(tally.region, l10n),
        visited: tally.visited,
        total: tally.total,
        l10n: l10n,
        theme: theme,
      ),
      children: [
        for (final country in countries)
          CheckboxListTile(
            dense: true,
            value: visited.contains(country.code),
            // A country a trip put here cannot be unticked: unticking is taking
            // back a *statement*, and the trips are not one — the way to undo
            // them is to change the trip. Only what was marked by hand is the
            // user's to take back.
            onChanged:
                canMark &&
                    (marked.contains(country.code) ||
                        !visited.contains(country.code))
                ? (value) => onToggle(country.code, value ?? false)
                : null,
            title: Text(country.name(language)),
            subtitle:
                visited.contains(country.code) && !marked.contains(country.code)
                ? Text(
                    l10n.countriesFromTrips,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : null,
          ),
      ],
    );
  }
}

/// The region's name in the app's language.
///
/// Translated here rather than carried in the asset: there are seven of them,
/// they never change, and the asset's own `REGION_UN` is an English key rather
/// than a label — using it directly would put "North America" in a German list.
String regionLabel(String region, AppLocalizations l10n) => switch (region) {
  'Africa' => l10n.regionAfrica,
  'Asia' => l10n.regionAsia,
  'Europe' => l10n.regionEurope,
  'North America' => l10n.regionNorthAmerica,
  'South America' => l10n.regionSouthAmerica,
  'Oceania' => l10n.regionOceania,
  'Antarctica' => l10n.regionAntarctica,
  _ => region,
};
