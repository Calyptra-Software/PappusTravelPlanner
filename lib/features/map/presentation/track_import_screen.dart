import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../basemap.dart';
import '../finite_camera.dart';
import '../track_import_plan.dart';
import '../track_split.dart';
import '../widgets/map_overlays.dart';

/// Colours for the stretches, chosen here rather than taken from the theme.
///
/// The theme's primary, secondary and tertiary are three shades of one hue in
/// this app, which is right for a coherent screen and wrong for the one job
/// this screen has: saying which stretch is which. These are far apart in hue
/// and dark enough to hold their own on pale raster tiles, which are themselves
/// full of thin red and orange lines — so no red, and nothing pastel.
const List<Color> kTrackPieceColors = [
  Color(0xFF1565C0), // blue
  Color(0xFFEF6C00), // orange
  Color(0xFF6A1B9A), // purple
  Color(0xFF2E7D32), // green
  Color(0xFFC2185B), // magenta
  Color(0xFF00838F), // teal
];

/// What the part of the line nobody has divided yet is drawn in: present, but
/// visibly not yet anybody's.
const Color kTrackUndividedColor = Color(0xFF9E9E9E);

/// Spreads one recording over the entries it covered, with the division on
/// screen before anything is written.
///
/// A full-screen route rather than a sheet, for the reason the map picker is
/// one: a sheet answers a vertical drag by closing, and that is the same gesture
/// as panning the map under it.
///
/// The screen exists because of what it refuses to do. The line has to be cut
/// where one entry handed over to the next, and for entries that were never
/// given coordinates nobody knows where that is. So it asks — every handover,
/// no exceptions — and because the division is drawn while it is being decided,
/// the answer is visible before it is a fact. There is deliberately no way to
/// skip: an estimated cut is invisible, and an invisible guess is the kind that
/// turns into a wrong answer months later. It also means nothing downstream
/// needs a rule for dividing a line nobody has said anything about.
///
/// There is one interaction and no modes: **a tap puts a handover where it
/// landed.** While one is still open it is that one; once they are all placed a
/// tap moves the nearest, which is what changing your mind looks like. An
/// earlier version made the marker itself tappable to "pick up" first — an
/// invisible state, and one that competed with the map for the same tap, so
/// often neither happened. The marks are inert on purpose, and the tap is the
/// map's own `onTap`: flutter_map's gesture handling wraps its children, so a
/// `GestureDetector` placed among them never wins the arena and no tap arrives
/// at all. Both of those were tried; neither is worth trying again.
Future<bool?> importTrackAcrossEntries(
  BuildContext context, {
  required List<List<LatLng>> lines,
  required String? name,
  required List<ItineraryItem> selection,
}) => Navigator.of(context).push<bool>(
  MaterialPageRoute(
    builder: (_) =>
        TrackImportScreen(lines: lines, name: name, selection: selection),
  ),
);

class TrackImportScreen extends ConsumerStatefulWidget {
  const TrackImportScreen({
    super.key,
    required this.lines,
    required this.name,
    required this.selection,
  });

  /// The recording, one list per `<trkseg>` — a pause is a hole that survives.
  final List<List<LatLng>> lines;
  final String? name;

  /// The contiguous run of entries the recording covers, in the order the day
  /// reads them.
  final List<ItineraryItem> selection;

  @override
  ConsumerState<TrackImportScreen> createState() => _TrackImportScreenState();
}

class _TrackImportScreenState extends ConsumerState<TrackImportScreen> {
  final MapController _controller = MapController();
  late TrackImportPlan _plan;
  late List<LatLng?> _boundaries;

  /// Every point of the recording in one sequence — what a tap is snapped
  /// against, and the same order the cutting walks.
  late List<LatLng> _flat;

  @override
  void initState() {
    super.initState();
    _plan = trackImportPlan(widget.selection);
    _boundaries = [..._plan.boundaries];
    _flat = [for (final line in widget.lines) ...line];
  }

  /// The first handover nobody has said anything about, or null once they are
  /// all placed.
  int? get _open {
    for (var i = 0; i < _boundaries.length; i++) {
      if (_boundaries[i] == null) return i;
    }
    return null;
  }

  /// The handovers placed so far, as a prefix — everything up to the first one
  /// still open. That prefix is what can be drawn as divided; the rest of the
  /// line belongs to nobody yet.
  List<LatLng> get _placedPrefix {
    final out = <LatLng>[];
    for (final at in _boundaries) {
      if (at == null) break;
      out.add(at);
    }
    return out;
  }

  bool get _complete => _boundaries.every((b) => b != null);

  /// A tap puts a handover where it landed. That is the whole interaction.
  ///
  /// While one is still open it is that one; once they are all placed a tap
  /// moves the **nearest**, which is what changing your mind looks like. There
  /// is deliberately no picking-up step: a mode you cannot see is a mode you
  /// cannot use, and nothing here is written until *Import* anyway — so a tap in
  /// the wrong place costs another tap and is visible the moment it happens,
  /// because the division is redrawn under it.
  void _place(LatLng tap) {
    final index = _open ?? _nearest(tap);
    if (index == null) return;

    // Between its neighbours, because a stretch cannot run backwards.
    final previous = index == 0 ? null : _boundaries[index - 1];
    final next = index + 1 < _boundaries.length ? _boundaries[index + 1] : null;
    final after = previous == null ? 0 : trackIndexOf(_flat, previous) + 1;
    final before = next == null ? null : trackIndexOf(_flat, next) - 1;
    final snapped = snapToTrack(_flat, tap, after: after, before: before);
    if (snapped == null) return;
    setState(() => _boundaries[index] = snapped);
  }

  /// The placed handover closest to [tap].
  int? _nearest(LatLng tap) {
    const distance = Distance(calculator: Haversine());
    var best = -1;
    var bestMetres = double.infinity;
    for (var i = 0; i < _boundaries.length; i++) {
      final at = _boundaries[i];
      if (at == null) continue;
      final metres = distance.as(LengthUnit.Meter, at, tap);
      if (metres < bestMetres) {
        bestMetres = metres;
        best = i;
      }
    }
    return best < 0 ? null : best;
  }

  Future<void> _confirm() async {
    final navigator = Navigator.of(context);
    final boundaries = [for (final at in _boundaries) at!];
    final stretches = splitTracks(widget.lines, boundaries);
    final ends = trackImportEnds(
      TrackImportPlan(
        legs: _plan.legs,
        boundaries: _boundaries,
        selection: widget.selection,
      ),
      first: _flat.first,
      last: _flat.last,
    );

    await ref
        .read(repositoryProvider)
        .importTrackAcross(
          name: widget.name,
          pieces: [
            for (var i = 0; i < _plan.legs.length; i++)
              for (final line in stretches[i])
                (itemId: _plan.legs[i].id, points: line),
          ],
          ends: ends,
        );
    navigator.pop(true);
  }

  /// A name for an entry in a question about it. The title is what the user
  /// wrote; failing that the route, which is what an imported leg carries.
  String _label(ItineraryItem leg, AppLocalizations l10n) {
    final title = leg.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    final from = leg.fromLocation?.trim();
    final to = leg.toLocation?.trim();
    if (from != null && to != null && from.isNotEmpty && to.isNotEmpty) {
      return '$from → $to';
    }
    return from ?? to ?? l10n.transportLabelOptional;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    const basemap = kDefaultBasemap;
    final open = _open;
    final placed = _placedPrefix;
    final stretches = splitTracks(widget.lines, placed);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trackImportTitle)),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    minZoom: kMinMapZoom,
                    maxZoom: maxZoomOf(basemap),
                    cameraConstraint: const FiniteCamera(),
                    initialCameraFit: _flat.length > 1
                        ? CameraFit.bounds(
                            bounds: LatLngBounds.fromPoints(_flat),
                            padding: const EdgeInsets.all(48),
                          )
                        : null,
                    initialCenter: _flat.first,
                    initialZoom: 13,
                    // The map's own tap, not a `GestureDetector` among its
                    // children: flutter_map's gesture handling wraps the
                    // children, so one placed there never wins the arena and no
                    // tap arrives at all. Nothing competes with it now — the
                    // handover marks are inert.
                    onTap: (_, point) => _place(point),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    basemapTileLayer(basemap, ref.watch(appVersionProvider)),
                    PolylineLayer(
                      polylines: [
                        for (var i = 0; i < stretches.length; i++)
                          for (final line in stretches[i])
                            Polyline(
                              points: line,
                              strokeWidth: 4,
                              // The last stretch is only *this* entry's once
                              // every handover after it has been placed.
                              color: i < placed.length || _complete
                                  ? kTrackPieceColors[i %
                                        kTrackPieceColors.length]
                                  : kTrackUndividedColor,
                              borderStrokeWidth: 2,
                              borderColor: theme.colorScheme.surface,
                            ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        for (var i = 0; i < _boundaries.length; i++)
                          if (_boundaries[i] case final at?)
                            Marker(
                              point: at,
                              width: 28,
                              height: 28,
                              // Ignoring pointers on purpose: the mark is a
                              // mark, not a control. Letting it take taps put it
                              // in competition with the layer that places
                              // handovers, and a tap that two widgets both want
                              // is a tap that does nothing.
                              child: const IgnorePointer(child: _Handover()),
                            ),
                      ],
                    ),
                  ],
                ),
                // Placing a handover means finding a spot precisely, which is
                // exactly when a trackpad or a shaky finger needs a button.
                Positioned(
                  top: 12,
                  right: 12 + MediaQuery.paddingOf(context).right,
                  child: MapZoomButtons(
                    controller: _controller,
                    basemap: basemap,
                    zoomInTooltip: l10n.mapZoomIn,
                    zoomOutTooltip: l10n.mapZoomOut,
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: MapAttributionBar(basemap: basemap),
                ),
              ],
            ),
          ),
          _Panel(
            l10n: l10n,
            theme: theme,
            question: open == null
                ? null
                : l10n.trackTapBoundary(
                    _label(_plan.legs[open], l10n),
                    _label(_plan.legs[open + 1], l10n),
                  ),
            hint: _complete ? l10n.trackBoundaryMove : null,
            legend: [
              for (var i = 0; i < _plan.legs.length; i++)
                (
                  _label(_plan.legs[i], l10n),
                  kTrackPieceColors[i % kTrackPieceColors.length],
                ),
            ],
            // Says what it will do, because this import changes entries and not
            // only the map.
            summary: l10n.trackImportSummary(
              _plan.legs.length,
              trackImportEnds(
                TrackImportPlan(
                  legs: _plan.legs,
                  boundaries: _boundaries,
                  selection: widget.selection,
                ),
                first: _flat.first,
                last: _flat.last,
              ).length,
            ),
            // Nothing is written until every handover has been pointed at.
            onConfirm: _plan.legs.isEmpty || !_complete ? null : _confirm,
          ),
        ],
      ),
    );
  }
}

/// The strip under the map: which colour is which entry, what is being asked,
/// and the one button.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.l10n,
    required this.theme,
    required this.question,
    required this.hint,
    required this.legend,
    required this.summary,
    required this.onConfirm,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final String? question;
  final String? hint;
  final List<(String, Color)> legend;
  final String summary;
  final VoidCallback? onConfirm;

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
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final (label, colour) in legend)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 14, height: 4, color: colour),
                      const SizedBox(width: 6),
                      Text(label, style: theme.textTheme.labelSmall),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              question ?? hint ?? summary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: question == null
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    summary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: onConfirm,
                  child: Text(l10n.trackImportConfirm),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A handover already placed.
///
/// Ink on a halo, in its own colours rather than the theme's — raster tiles are
/// pale in both themes and full of thin lines, so a mark tinted by the theme
/// reads as a road.
class _Handover extends StatelessWidget {
  const _Handover();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: const Color(0xFF212121),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
    ),
  );
}
