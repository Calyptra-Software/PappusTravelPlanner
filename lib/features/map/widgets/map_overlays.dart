/// The furniture every map in this app carries: the source's attribution and a
/// way to zoom without a mouse wheel.
///
/// Shared rather than repeated, because both are rules and not decoration — the
/// attribution is a condition of using the tiles, and the buttons are what makes
/// the map usable on a laptop trackpad and a phone alike. A second copy is how
/// one of them quietly ends up missing on the screen nobody looked at.
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../core/widgets/external_link.dart';
import '../basemap.dart';

/// Zoomed out no further than the whole world in view; a map showing four copies
/// of the earth is not a smaller map, just a confusing one.
const double kMinMapZoom = 2;

double maxZoomOf(Basemap basemap) => switch (basemap) {
  RasterBasemap(:final maxZoom) => maxZoom,
};

/// The `+` / `−` pair. Positioned by the caller: the trip map floats it over the
/// map, and a picker may want it somewhere else entirely.
///
/// The gestures alone (wheel, double tap, pinch) are the whole story on a phone,
/// but on a desktop with a trackpad they are guesswork — and a map with no
/// visible way to zoom reads as a picture rather than a map.
class MapZoomButtons extends StatelessWidget {
  const MapZoomButtons({
    super.key,
    required this.controller,
    required this.basemap,
    required this.zoomInTooltip,
    required this.zoomOutTooltip,
  });

  final MapController controller;
  final Basemap basemap;
  final String zoomInTooltip;
  final String zoomOutTooltip;

  void _zoomBy(double delta) {
    final camera = controller.camera;
    controller.move(
      camera.center,
      (camera.zoom + delta).clamp(kMinMapZoom, maxZoomOf(basemap)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ZoomButton(
          icon: Icons.add,
          tooltip: zoomInTooltip,
          onPressed: () => _zoomBy(1),
        ),
        const SizedBox(height: 8),
        _ZoomButton(
          icon: Icons.remove,
          tooltip: zoomOutTooltip,
          onPressed: () => _zoomBy(-1),
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
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

/// The basemap's attribution, over the map where the data is being used.
///
/// A condition of use rather than a credit, so it is always on screen and every
/// entry is a real link — the same rule the connection search follows. "On
/// screen" has to mean *readable*, which is why the system insets are added to
/// the padding rather than left to chance: the map deliberately draws edge to
/// edge, so on a phone with a three-button navigation bar the bottom strip would
/// sit underneath it, and an attribution nobody can read is one the app is not
/// really showing. The band still reaches the screen edge — only the text is
/// lifted — so the map keeps a clean bottom edge instead of a floating bar with
/// a gap under it.
class MapAttributionBar extends StatelessWidget {
  const MapAttributionBar({super.key, required this.basemap});

  final Basemap basemap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insets = MediaQuery.paddingOf(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surface.withValues(alpha: 0.75),
      padding: EdgeInsets.only(
        // Landscape puts the navigation bar on a side, so those insets count
        // too — a bar on the right is exactly where this text ends up.
        left: 8 + insets.left,
        right: 8 + insets.right,
        top: 2,
        bottom: 2 + insets.bottom,
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 12,
        children: [
          for (final source in basemap.attributions)
            InkWell(
              onTap: () => openExternalLink(context, source.url),
              child: Text(
                '© ${source.label}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
