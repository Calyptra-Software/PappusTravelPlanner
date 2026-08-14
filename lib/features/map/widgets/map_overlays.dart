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

import '../../../core/app_info.dart';
import '../../../core/widgets/external_link.dart';
import '../basemap.dart';

/// Zoomed out no further than the whole world in view; a map showing four copies
/// of the earth is not a smaller map, just a confusing one.
const double kMinMapZoom = 2;

/// How near a tap has to land to count as hitting a line.
///
/// flutter_map measures a hit against the stroke itself, and a route is drawn
/// three pixels wide because that is what reads well under a dozen others — not
/// because anyone can put a fingertip within three pixels of it. This is the
/// usual touch slop instead, which also decides what "on this line" means when
/// several run alongside each other: a shared stretch of highway is one line to
/// the eye and should be one tap to the hand.
const double kLineHitbox = 20;

double maxZoomOf(Basemap basemap) => switch (basemap) {
  RasterBasemap(:final maxZoom) => maxZoom,
};

/// How long tile loading waits before reacting to a moved camera.
///
/// A pinch can cross a dozen zoom levels in half a second, and without this each
/// level in passing asks for a full screen of tiles that is discarded before it
/// arrives. Two reasons that is worth avoiding, and the first is not ours: those
/// requests go to donated servers, and a burst of screenfuls nobody will ever
/// look at is exactly the "heavy use" their policy asks clients not to make.
/// The second is the phone — every request is a connection, a cache write and a
/// decode, and enough of them at once starve the thread that is drawing.
///
/// Short enough that a deliberate zoom still feels immediate.
const Duration kTileUpdateThrottle = Duration(milliseconds: 150);

/// The basemap's tiles, built the same way wherever a map is drawn.
///
/// One place rather than three, because every line of it is a condition rather
/// than a preference: who we say we are, how often we ask, and that the answers
/// are cached.
TileLayer basemapTileLayer(Basemap basemap, String appVersion) =>
    switch (basemap) {
      RasterBasemap(:final urlTemplate, :final maxZoom) => TileLayer(
        urlTemplate: urlTemplate,
        maxZoom: maxZoom,
        // Who we are, as the OpenStreetMap policy requires of an app: this
        // application's name, its version, and a way to get in touch. Sent as a
        // real header rather than through `userAgentPackageName`, whose generic
        // format the policy names as a reason for blocking. The browser forbids
        // setting it at all, which is why a web deployment answers with its
        // Referer.
        tileProvider: NetworkTileProvider(
          headers: {'User-Agent': buildUserAgent(appVersion)},
        ),
        tileUpdateTransformer: TileUpdateTransformers.throttle(
          kTileUpdateThrottle,
        ),
        // Caching is left at flutter_map's default, which stores tiles for as
        // long as the server's own headers say — the conforming caching the
        // policy asks for, and the reason panning back over ground already seen
        // costs nobody anything.
      ),
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

/// A place, as a pin whose tip is the position.
///
/// Drawn as the pin's glyph twice: once **stroked** in white, once filled in the
/// entry's colour. Raster tiles are busy, so anything on them needs a
/// contrasting edge — the same reason the routes carry a casing and the picker's
/// mark is ink on halo.
///
/// A *keyline* rather than a bigger shape behind, which was the first attempt:
/// laying a larger white pin underneath fills the glyph's own hole and grows a
/// white wedge past the tip, so the mark reads as a white blob with a coloured
/// rim. Stroking the outline leaves the hole open — the map shows through it,
/// which is what a map pin has always looked like — and cannot shift the tip,
/// since both layers are the same glyph at the same size.
///
/// It also replaced a blurred `Shadow`, which is the kind of layer a GPU backend
/// caches and then fails to invalidate under a moving transform, leaving a grey
/// pin-shaped smudge behind while the real pin pans away. A hard edge cannot
/// smear.
class MapPlacePin extends StatelessWidget {
  const MapPlacePin({super.key, required this.color, this.size = 32});

  final Color color;
  final double size;

  Widget _glyph({Color? fill, Paint? outline}) => Text(
    String.fromCharCode(Icons.place.codePoint),
    style: TextStyle(
      fontFamily: Icons.place.fontFamily,
      package: Icons.place.fontPackage,
      fontSize: size,
      height: 1,
      color: fill,
      foreground: outline,
    ),
  );

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    // The glyph is a private-use code point: read aloud it is noise, and unlike
    // an `Icon` a `Text` does not hide itself from the semantics tree.
    child: Stack(
      alignment: Alignment.center,
      children: [
        _glyph(
          outline: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..strokeJoin = StrokeJoin.round
            ..color = const Color(0xFFFFFFFF),
        ),
        _glyph(fill: color),
      ],
    ),
  );
}
