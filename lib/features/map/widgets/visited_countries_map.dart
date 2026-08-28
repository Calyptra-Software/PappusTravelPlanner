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

/// As far in as the outlines are worth drawing.
///
/// Two steps past what a world map needs, because Liechtenstein and Monaco are
/// a few pixels across at any zoom that shows a continent, and a country you
/// cannot see is one you cannot tap. Not further: the rings are stored to three
/// decimals (~110 m) and simplified on top of that, so past here the coastline
/// visibly turns to straight lines and the map would be promising a detail it
/// does not have.
const double kCountryMapMaxZoom = 10;

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
        final tallies = regionTallies(countries, visited.states);
        final states = sovereignStates(countries);
        final byRegion = <String, List<CountryOutline>>{};
        for (final state in states) {
          byRegion.putIfAbsent(state.region, () => []).add(state);
        }

        return ListView(
          children: [
            // Twice as wide as it is tall, and never more than half the
            // screen. The zoom is fixed by the width — any less and flutter_map
            // draws the next copy of the world beside this one — so the height
            // is what decides how much of the world is on screen. Where the cap
            // bites, the map gives up *width* rather than latitude and sits
            // centered: a whole world with a margin reads better than a band
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
                      visited: visited.areas,
                      fill: fill,
                      onTapCountry: _markOnTap(
                        ref,
                        canMark: _canMark,
                        visited: visited,
                        marked: marked,
                      ),
                      // The list is what the map cannot say, so it is never
                      // worth being in the map's way: the whole screen is one
                      // tap off, and the camera travels in both directions.
                      onFullscreen: (handover) => _showFullscreenMap(
                        context,
                        tripId: tripId,
                        accent: fill,
                        handover: handover,
                      ),
                    ),
                  ),
                );
              },
            ),
            _TallyRow(
              label: l10n.countriesWorld,
              visited: visited.states.length,
              total: states.length,
              l10n: l10n,
              theme: theme,
              emphasis: true,
            ),
            for (final tally in tallies)
              _RegionSection(
                tally: tally,
                countries: (byRegion[tally.region] ?? const [])
                  ..sort(
                    (a, b) => a.name(language).compareTo(b.name(language)),
                  ),
                visited: visited.states,
                fromTrips: visited.derivedStates,
                language: language,
                canMark: _canMark,
                l10n: l10n,
                theme: theme,
                onToggle: (code, value) {
                  final repository = ref.read(repositoryProvider);
                  if (value) {
                    repository.setCountryMarked(code, true);
                  } else {
                    // Everything that was making the row true, its territories
                    // included — see [markKeysFor].
                    repository.clearCountryMarks(markKeysFor(countries, code));
                  }
                },
              ),
          ],
        );
      },
    );
  }
}

/// What a tap on an area does, or null where marking is not offered.
///
/// Shared by the tab's map and the fullscreen one, because ticking a country
/// has to mean the same thing on both — and a rule written out twice is a rule
/// that drifts.
void Function(CountryOutline country)? _markOnTap(
  WidgetRef ref, {
  required bool canMark,
  required VisitedWorld visited,
  required Set<String> marked,
}) {
  if (!canMark) return null;
  return (country) {
    // A country a trip put here is not the user's to take back — the same rule
    // the greyed-out checkbox rows below state.
    if (visited.derivedAreas.contains(country.code)) return;
    ref
        .read(repositoryProvider)
        .setCountryMarked(country.markKey, !marked.contains(country.markKey));
  };
}

/// Where a map is looking, carried into the fullscreen route and back out.
///
/// Mutable and handed over by reference rather than returned by
/// `Navigator.pop`, because the fullscreen map can be left three ways — its own
/// button, the system back button, and the back gesture — and only the first of
/// them can carry a result. Somebody who pans to Patagonia and swipes back
/// should not find themselves where they were before they zoomed in.
class _CameraHandover {
  _CameraHandover({required this.center, required this.zoom});

  LatLng center;
  double zoom;
}

/// Opens the world map on the whole screen, and completes when it is closed.
///
/// A **full screen route**, for the reason `pickPointOnMap` is one: a map is
/// dragged, and everything that could give the list back — a sheet, a scroll —
/// answers a vertical drag as well. Growing the map inside the tab would also
/// leave the app bar and the tab bar standing, which is exactly the height the
/// map wants; and once it filled the viewport there would be nothing left to
/// drag the list back with, since the map swallows the gesture.
Future<void> _showFullscreenMap(
  BuildContext context, {
  required int? tripId,
  required Color accent,
  required _CameraHandover handover,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _FullscreenWorldMap(
        tripId: tripId,
        accent: accent,
        handover: handover,
      ),
    ),
  );
}

/// The same map, with nothing else on the screen.
///
/// It watches the providers itself rather than being handed the snapshot the
/// tab was drawing: a country ticked here has to fill here, not on the way
/// back.
class _FullscreenWorldMap extends ConsumerWidget {
  const _FullscreenWorldMap({
    required this.tripId,
    required this.accent,
    required this.handover,
  });

  final int? tripId;
  final Color accent;
  final _CameraHandover handover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final outlines = ref.watch(countryOutlinesProvider);
    final visited = ref.watch(allVisitedCountriesProvider(tripId));
    final marked = ref.watch(markedCountriesProvider).value ?? const <String>{};

    return Scaffold(
      body: outlines.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(l10n.genericError('$error'))),
        data: (countries) => _WorldMap(
          countries: countries,
          visited: visited.areas,
          fill: accent,
          onTapCountry: _markOnTap(
            ref,
            // The same rule as the tab's: a mark is a statement about a life,
            // so it is offered only where the question is about every trip.
            canMark: tripId == null,
            visited: visited,
            marked: marked,
          ),
          camera: handover,
          onExitFullscreen: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

/// The outlines, with the visited ones filled.
class _WorldMap extends StatefulWidget {
  const _WorldMap({
    required this.countries,
    required this.visited,
    required this.fill,
    this.onTapCountry,
    this.camera,
    this.onFullscreen,
    this.onExitFullscreen,
  });

  final List<CountryOutline> countries;

  /// Area codes, not state codes: what is drawn is where somebody stood.
  final Set<String> visited;
  final Color fill;

  /// What a tap on an area means, or null where marking is not offered.
  final void Function(CountryOutline country)? onTapCountry;

  /// The camera this map takes over: it opens on it and writes every move back
  /// into it. Set on the fullscreen map, null on the one in the tab, which
  /// keeps its own camera in its controller.
  final _CameraHandover? camera;

  /// Opens the fullscreen map on the camera it is handed, and completes when
  /// that map is closed. Null on the fullscreen map itself, which offers
  /// [onExitFullscreen] instead.
  final Future<void> Function(_CameraHandover handover)? onFullscreen;

  /// Closes the fullscreen map. Null on every other one.
  final VoidCallback? onExitFullscreen;

  @override
  State<_WorldMap> createState() => _WorldMapState();
}

class _WorldMapState extends State<_WorldMap> {
  final MapController _controller = MapController();

  /// What lay under the last tap, by area code. `PolygonLayer` fills this
  /// before the gesture arrives, which is the arrangement the all-trips map
  /// already uses for its lines.
  final LayerHitNotifier<String> _hits = ValueNotifier(null);

  @override
  void dispose() {
    _hits.dispose();
    super.dispose();
  }

  /// Hands the fullscreen map this camera, and picks up the one it ends on.
  Future<void> _openFullscreen() async {
    final camera = _controller.camera;
    final handover = _CameraHandover(center: camera.center, zoom: camera.zoom);
    await widget.onFullscreen!(handover);
    if (!mounted) return;
    // No clamping needed on the way back: `move` clamps to this map's own zoom
    // floor, and that floor is the lower of the two — a narrower map fits the
    // whole world at a smaller zoom.
    _controller.move(handover.center, handover.zoom);
  }

  void _onTap() {
    final hit = _hits.value;
    if (hit == null) return;
    // Innermost first: an enclave is drawn over the country around it, and a
    // tap on Lesotho means Lesotho. `hitValues` comes back in the order the
    // polygons were given, and the visited ones are drawn last.
    final codes = hit.hitValues.toSet();
    for (final country in widget.countries.reversed) {
      if (codes.contains(country.code)) {
        widget.onTapCountry?.call(country);
        return;
      }
    }
  }

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
                maxZoom: kCountryMapMaxZoom,
                // Taking over from another map means opening where it was —
                // but its zoom floor is its own, and a wider map needs more
                // zoom to fill itself with one world.
                initialZoom: math.max(widget.camera?.zoom ?? fit, fit),
                initialCenter: widget.camera?.center ?? const LatLng(20, 0),
                onPositionChanged: (position, _) {
                  final handover = widget.camera;
                  if (handover == null) return;
                  handover.center = position.center;
                  handover.zoom = position.zoom;
                },
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
                GestureDetector(
                  onTap: widget.onTapCountry == null ? null : _onTap,
                  child: PolygonLayer(
                    // Left off where a tap means nothing, so the layer does no
                    // hit-testing for an answer nobody reads.
                    hitNotifier: widget.onTapCountry == null ? null : _hits,
                    // Unvisited first, so a filled country is never hidden
                    // under the outline of the one it borders.
                    polygons: [
                      for (final country in widget.countries)
                        if (!widget.visited.contains(country.code))
                          ..._shapes(
                            country,
                            border: theme.colorScheme.outline,
                            // Land, filled — not merely outlined. A hairline of
                            // border color against the sea is a country nobody
                            // can make out at world scale, and the shape of the
                            // continents is what the eye reads first. So the
                            // unvisited world is drawn as land: grey against the
                            // sea, and the accent then reads as a fill on it
                            // rather than as the only thing on the map.
                            fill: theme.colorScheme.surfaceContainerHigh,
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
                ),
              ],
            ),
            // Aligned rather than inset by a fixed amount, and inside a
            // `SafeArea`: the fullscreen map has no app bar over it, so the top
            // of the screen is the status bar.
            Positioned.fill(
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: _ZoomButtons(
                      controller: _controller,
                      minZoom: fit,
                      onFullscreen: widget.onFullscreen == null
                          ? null
                          : _openFullscreen,
                      onExitFullscreen: widget.onExitFullscreen,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// One polygon per landmass, holes and all — so an enclave is drawn as the
  /// separate country it is rather than swallowed by the one around it.
  Iterable<Polygon<String>> _shapes(
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
        // What a tap here means: this area. A state's own ground and its
        // territories are separate answers, which is the whole reason
        // Greenland can be ticked without saying anything about Denmark.
        hitValue: country.code,
      );
    }
  }
}

/// `+` / `−` for a map with no wheel under it.
///
/// Its own rather than the shared `MapZoomButtons`, which clamps to the app's
/// tile zoom range; here the floor is whatever puts one world on screen.
class _ZoomButtons extends StatelessWidget {
  const _ZoomButtons({
    required this.controller,
    required this.minZoom,
    this.onFullscreen,
    this.onExitFullscreen,
  });

  final MapController controller;
  final double minZoom;

  /// Opens the fullscreen map, where that is a way out of here.
  final VoidCallback? onFullscreen;

  /// Closes it. Exactly one of the two is set, and neither is on a map that
  /// already fills what it can fill.
  final VoidCallback? onExitFullscreen;

  void _by(double delta) {
    final camera = controller.camera;
    controller.move(
      camera.center,
      (camera.zoom + delta).clamp(minZoom, kCountryMapMaxZoom),
    );
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
        // Under the zoom pair rather than beside it: it is the same question
        // asked at the coarsest end — how much of the world can be seen at
        // once — and the answer the two buttons cannot give, since the width is
        // what fixes the zoom floor.
        if (onFullscreen case final open?) ...[
          const SizedBox(height: 6),
          _ZoomButton(
            icon: Icons.fullscreen,
            tooltip: l10n.mapFullscreen,
            onPressed: open,
          ),
        ],
        if (onExitFullscreen case final close?) ...[
          const SizedBox(height: 6),
          _ZoomButton(
            icon: Icons.fullscreen_exit,
            tooltip: l10n.mapExitFullscreen,
            onPressed: close,
          ),
        ],
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
    required this.fromTrips,
    required this.language,
    required this.canMark,
    required this.l10n,
    required this.theme,
    required this.onToggle,
  });

  final RegionTally tally;
  final List<CountryOutline> countries;
  final Set<String> visited;

  /// The ones a trip put here, which are the ones nobody may untick.
  final Set<String> fromTrips;
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
        // Every row here is a sovereign state and therefore names one; the
        // pattern is what says so, rather than a `!` claiming it.
        for (final country in countries)
          if (country.stateCode case final code?)
            CheckboxListTile(
              dense: true,
              value: visited.contains(code),
              // A country a trip put here cannot be unticked: unticking is
              // taking back a *statement*, and the trips are not one — the way
              // to undo them is to change the trip. The greyed-out tick says
              // so by itself, which is why there is no line of text under it.
              onChanged: canMark && !fromTrips.contains(code)
                  ? (value) => onToggle(code, value ?? false)
                  : null,
              title: Text(country.name(language)),
            ),
      ],
    );
  }
}

/// The region's name in the app's language.
///
/// Translated here rather than carried in the asset: there are six of them, they
/// never change, and the asset's own `REGION_UN` is an English key rather than a
/// label — using it directly would put "North America" in a German list. The key
/// and the label are also allowed to differ: `Oceania` reads as "Australia and
/// Oceania", which is what an atlas calls it and what somebody looking for
/// Australia in a list of continents expects to find.
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
