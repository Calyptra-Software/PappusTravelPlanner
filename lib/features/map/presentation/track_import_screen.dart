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

/// Spreads one recording over the entries it covered, with the division on
/// screen before anything is written.
///
/// A full-screen route rather than a sheet, for the reason the map picker is
/// one: a sheet answers a vertical drag by closing, and that is the same gesture
/// as panning the map under it.
///
/// The screen exists because of what it refuses to do. The line has to be cut
/// where one entry handed over to the next, and for entries that were never
/// given coordinates nobody knows where that is. Guessing is possible —
/// `splitTrack` will divide the distance evenly — but this app's rule is that a
/// position is *pointed at, never derived*, and a cut nobody can see is exactly
/// the kind of guess that turns into a wrong answer months later. So the
/// handovers are asked for, one tap each, on the recording itself; and because
/// the division is drawn while it is being decided, the answer is visible before
/// it is a fact.
///
/// Skipping is allowed. Somebody who just wants the line on the map should get
/// it, and the estimate is then honest about being one.
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
  late TrackImportPlan _plan;
  late List<LatLng?> _boundaries;

  /// Every point of the recording in one sequence — what a tap is snapped
  /// against, and the same order the cutting walks.
  late List<LatLng> _flat;

  /// Which handover is being asked for, or null when none is left.
  int? get _asking {
    for (var i = 0; i < _boundaries.length; i++) {
      if (_boundaries[i] == null && !_skipped.contains(i)) return i;
    }
    return null;
  }

  final _skipped = <int>{};

  @override
  void initState() {
    super.initState();
    _plan = trackImportPlan(widget.selection);
    _boundaries = [..._plan.boundaries];
    _flat = [for (final line in widget.lines) ...line];
  }

  /// A tap lands on the line, never beside it, and never before the handover
  /// already placed — the rule `splitTrack` follows, so the preview and the
  /// result cannot disagree.
  void _place(LatLng tap) {
    final asking = _asking;
    if (asking == null) return;
    var after = 0;
    for (var i = 0; i < asking; i++) {
      final placed = _boundaries[i];
      if (placed == null) continue;
      after = _flat.indexOf(placed) + 1;
    }
    final snapped = snapToTrack(_flat, tap, after: after);
    if (snapped == null) return;
    setState(() => _boundaries[asking] = snapped);
  }

  Future<void> _confirm() async {
    final navigator = Navigator.of(context);
    final stretches = splitTracks(widget.lines, _boundaries);
    final ends = trackImportEnds(
      TrackImportPlan(legs: _plan.legs, boundaries: _boundaries),
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
    final asking = _asking;
    final stretches = splitTracks(widget.lines, _boundaries);

    // One colour per entry, cycled: the division is the whole point of this
    // screen, so it has to be visible at a glance rather than inferred from
    // where the markers sit.
    final palette = [
      theme.colorScheme.primary,
      theme.colorScheme.tertiary,
      theme.colorScheme.secondary,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trackImportTitle)),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                FlutterMap(
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
                              color: palette[i % palette.length],
                              borderStrokeWidth: 2,
                              borderColor: theme.colorScheme.surface,
                            ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        for (final at in _boundaries.nonNulls)
                          Marker(
                            point: at,
                            width: 22,
                            height: 22,
                            child: _Handover(
                              color: theme.colorScheme.onSurface,
                              ring: theme.colorScheme.surface,
                            ),
                          ),
                      ],
                    ),
                  ],
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
            // The question, or the summary once there is nothing left to ask.
            question: asking == null
                ? null
                : l10n.trackTapBoundary(
                    _label(_plan.legs[asking], l10n),
                    _label(_plan.legs[asking + 1], l10n),
                  ),
            legend: [
              for (var i = 0; i < _plan.legs.length; i++)
                (_label(_plan.legs[i], l10n), palette[i % palette.length]),
            ],
            // Says what it will do, because this import changes entries and not
            // only the map.
            summary: l10n.trackImportSummary(
              _plan.legs.length,
              trackImportEnds(
                TrackImportPlan(legs: _plan.legs, boundaries: _boundaries),
                first: _flat.first,
                last: _flat.last,
              ).length,
            ),
            onSkip: asking == null
                ? null
                : () => setState(() => _skipped.add(asking)),
            onConfirm: _plan.legs.isEmpty ? null : _confirm,
          ),
        ],
      ),
    );
  }
}

/// The strip under the map: what is being asked, which colour is which entry,
/// and the two buttons.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.l10n,
    required this.theme,
    required this.question,
    required this.legend,
    required this.summary,
    required this.onSkip,
    required this.onConfirm,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final String? question;
  final List<(String, Color)> legend;
  final String summary;
  final VoidCallback? onSkip;
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
                      Container(width: 12, height: 4, color: colour),
                      const SizedBox(width: 6),
                      Text(label, style: theme.textTheme.labelSmall),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              question ?? summary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: question == null
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (onSkip != null)
                  TextButton(
                    onPressed: onSkip,
                    child: Text(l10n.trackBoundarySkip),
                  ),
                const Spacer(),
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

/// A handover already placed. Ink on a halo, in map colours rather than theme
/// colours — raster tiles are pale in both themes and full of thin red lines,
/// so a mark tinted by the theme reads as a road.
class _Handover extends StatelessWidget {
  const _Handover({required this.color, required this.ring});

  final Color color;
  final Color ring;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: ring, width: 3),
    ),
  );
}
