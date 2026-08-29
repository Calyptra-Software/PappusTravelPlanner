/// The furniture every map in this app carries: the source's attribution and a
/// way to zoom without a mouse wheel.
///
/// Shared rather than repeated, because both are rules and not decoration — the
/// attribution is a condition of using the tiles, and the buttons are what makes
/// the map usable on a laptop trackpad and a phone alike. A second copy is how
/// one of them quietly ends up missing on the screen nobody looked at.
library;

import 'dart:typed_data';

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
        MapRoundButton(
          icon: Icons.add,
          tooltip: zoomInTooltip,
          onPressed: () => _zoomBy(1),
        ),
        const SizedBox(height: 8),
        MapRoundButton(
          icon: Icons.remove,
          tooltip: zoomOutTooltip,
          onPressed: () => _zoomBy(-1),
        ),
      ],
    );
  }
}

/// One of the round buttons floating over a map.
///
/// Public and shared rather than private to the zoom pair, because the controls
/// that sit over a map are a *set*: they are read as one column, and a locate
/// button half a shade off or two pixels wider than the `+` above it looks like
/// something that wandered in from another screen. Anything new belongs here
/// too.
class MapRoundButton extends StatelessWidget {
  const MapRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.foreground,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// The icon's color, or null for the theme's own. Used to say that a button
  /// is *on* — a state the zoom pair does not have and the locate button does.
  final Color? foreground;

  /// Whether to draw a spinner around the icon: something was started that has
  /// not answered yet. The button stays pressable throughout, since the way out
  /// of a fix that is taking too long is to switch it off again.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      shape: const CircleBorder(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (busy)
            SizedBox.square(
              dimension: 36,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            ),
          IconButton(
            icon: Icon(icon),
            color: foreground,
            tooltip: tooltip,
            onPressed: onPressed,
          ),
        ],
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
  const MapPlacePin({
    super.key,
    required this.color,
    this.size = 32,
    this.count = 1,
  });

  final Color color;
  final double size;

  /// How many places this one pin stands for. One draws no badge: a "1" beside
  /// a mark answers a question nobody asked.
  ///
  /// A count widens the box by [kPinBadgeOverhang] on **both** sides and raises
  /// it by [kPinBadgeRise], so the glyph stays centered in it and the tip goes
  /// on landing where the marker says it does. See [pinBoxFor], which is what
  /// the layer sizes its markers with.
  final int count;

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
  Widget build(BuildContext context) {
    final pin = ExcludeSemantics(
      // The glyph is a private-use code point: read aloud it is noise, and
      // unlike an `Icon` a `Text` does not hide itself from the semantics tree.
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
    if (count < 2) return pin;

    final box = pinBoxFor(size);
    return SizedBox(
      width: box.width,
      height: box.height,
      child: Stack(
        children: [
          // Bottom-*center* of the widened box, which is where the marker's
          // alignment puts the position: the badge may not move the tip, since
          // the tip is the pin's whole claim.
          Align(alignment: Alignment.bottomCenter, child: pin),
          Positioned(
            top: 0,
            right: 0,
            child: _CountBadge(count: count, color: color),
          ),
        ],
      ),
    );
  }
}

/// How far a count badge reaches past the pin's glyph, sideways and upwards.
///
/// Room made *inside* the marker's own box rather than an overhang: a marker is
/// laid out by `MarkerLayer` in a `Stack` that clips, so a badge hanging off the
/// side would be cut in half on some frames and not others.
const double kPinBadgeOverhang = 11;
const double kPinBadgeRise = 7;

/// The box a [MapPlacePin] of [size] with a count needs.
///
/// Symmetric in width so the glyph — and with it the tip — stays on the
/// position; taller only upwards, away from it.
Size pinBoxFor(double size) =>
    Size(size + 2 * kPinBadgeOverhang, size + kPinBadgeRise);

/// How many of something one mark stands for.
///
/// The same badge on a gathered photograph and on a gathered pin: two marks
/// saying the same thing in two shapes would read as two different statements.
/// It sits *on* the mark rather than beside it — the mark is already as wide as
/// a fingertip wants, and a badge outside it would move where the thing appears
/// to be.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.surface, width: 1.5),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: _readableOn(color),
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }

  /// Black or white, whichever the badge's own colour can be read against — it
  /// takes the mark's colour, and that is the user's to pick.
  Color _readableOn(Color background) =>
      background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}

/// How large a photograph is drawn on the map.
///
/// Bigger than a pin, because it is a picture and has to be recognisable at a
/// glance; small enough that a day's worth of them does not bury the plan they
/// are pinned to.
const double kPhotoMarkerSize = 56;

/// A photo, as a marker: the thumbnail the import stored, framed.
///
/// The frame is what makes it a mark rather than a picture lying on the map —
/// a raster tile is busy, and a photograph of a street laid on a drawing of the
/// same street reads as an artefact until something says where one stops and
/// the other starts. It is drawn in the entry's color (the trip's accent
/// otherwise), which is the same thing the leg's line is drawn in, so the
/// picture and what it is about are visibly the same subject.
///
/// The thumbnail and not the picture: it is what `Attachments` carries in the
/// row the marker was built from, so a map of thirty photos costs thirty small
/// JPEGs and not thirty originals — the reason one is stored at all.
class MapPhotoMarker extends StatelessWidget {
  const MapPhotoMarker({
    super.key,
    required this.thumbnail,
    required this.color,
    this.size = kPhotoMarkerSize,
    this.count = 1,
  });

  /// The stored thumbnail, or null for a photo that somehow has none — drawn as
  /// an icon rather than skipped, since the position is still a statement.
  final Uint8List? thumbnail;
  final Color color;
  final double size;

  /// How many photographs this one thumbnail stands for. One draws no badge:
  /// a "1" beside a picture answers a question nobody asked.
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bytes = thumbnail;
    final frame = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0x33000000),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: bytes == null
            ? Icon(Icons.photo_camera_outlined, size: size * 0.55, color: color)
            // `gaplessPlayback` so a rebuild that hands the same photo over as a
            // fresh byte list does not blink the marker white while it decodes.
            : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
      ),
    );
    if (count < 2) return frame;

    // The count sits on the frame rather than beside it: the mark is already
    // as wide as it should be for a fingertip, and a badge outside it would
    // move where the picture appears to be.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        frame,
        Positioned(
          top: -4,
          right: -4,
          child: _CountBadge(count: count, color: color),
        ),
      ],
    );
  }
}
