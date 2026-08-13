import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/app_info.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../basemap.dart';
import '../widgets/map_overlays.dart';

/// Opens the map so the user can point at a place, and returns what they chose —
/// or null if they backed out.
///
/// A **full screen route**, not a bottom sheet: a map is dragged, and a sheet
/// answers a vertical drag by closing itself. The two gestures are the same one,
/// and no amount of tuning makes "pan south" and "dismiss" reliably different.
Future<LatLng?> pickPointOnMap(
  BuildContext context, {
  required String title,
  LatLng? initial,
  List<LatLng> nearby = const [],
}) {
  return Navigator.of(context).push<LatLng>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          MapPickerScreen(title: title, initial: initial, nearby: nearby),
    ),
  );
}

/// Picking a position by tapping the map.
///
/// A tap drops the marker, the readout underneath says where it landed, and
/// *Use this point* is disabled until there is one — so the screen never returns
/// a position nobody chose. Tapping again moves it; the map itself still pans
/// and zooms, since a drag is not a tap.
///
/// (It began as a fixed crosshair with the map moving underneath, on the theory
/// that a fingertip hides the point it is placing. Tapping won on being the more
/// obvious of the two: the mark appears where you pointed, which is what a map
/// invites you to expect.)
class MapPickerScreen extends ConsumerStatefulWidget {
  const MapPickerScreen({
    super.key,
    required this.title,
    this.initial,
    this.nearby = const [],
  });

  final String title;

  /// Where the point already is, when this is an edit rather than a first pick.
  final LatLng? initial;

  /// Other points of the same trip. Used only to open somewhere useful when
  /// there is no [initial]: the next place of a trip is nearly always near the
  /// last one, and an empty world map is a poor place to start hunting from.
  final List<LatLng> nearby;

  @override
  ConsumerState<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends ConsumerState<MapPickerScreen> {
  final MapController _controller = MapController();

  /// What has been chosen, or null until the map is tapped. An edit starts on
  /// the position it is editing, so confirming straight away is a no-op rather
  /// than a trap.
  late LatLng? _picked = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    const basemap = kDefaultBasemap;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: _picked == null
                ? null
                : () => Navigator.of(context).pop(_picked),
            child: Text(l10n.mapPickConfirm),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              minZoom: kMinMapZoom,
              maxZoom: maxZoomOf(basemap),
              initialCenter:
                  widget.initial ??
                  (widget.nearby.isNotEmpty
                      ? widget.nearby.first
                      : const LatLng(0, 0)),
              // Close in when there is a point to correct, wider when opening
              // near the trip's other entries, and all the way out when there is
              // nothing to go on at all.
              initialZoom: widget.initial != null
                  ? 16
                  : widget.nearby.isNotEmpty
                  ? 11
                  : 2,
              initialCameraFit:
                  widget.initial == null && widget.nearby.length > 1
                  ? CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(widget.nearby),
                      padding: const EdgeInsets.all(48),
                    )
                  : null,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (_, point) => setState(() => _picked = point),
            ),
            children: [
              switch (basemap) {
                RasterBasemap(:final urlTemplate, :final maxZoom) => TileLayer(
                  urlTemplate: urlTemplate,
                  maxZoom: maxZoom,
                  tileProvider: NetworkTileProvider(
                    headers: {
                      'User-Agent': buildUserAgent(
                        ref.watch(appVersionProvider),
                      ),
                    },
                  ),
                ),
              },
              // The trip's other points, so the user can see what they are
              // placing this one relative to. Deliberately faint: they are
              // context, not the thing being chosen.
              if (widget.nearby.isNotEmpty)
                MarkerLayer(
                  markers: [
                    for (final point in widget.nearby)
                      Marker(
                        point: point,
                        width: 20,
                        height: 20,
                        child: Icon(
                          Icons.circle,
                          size: 10,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              if (_picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _picked!,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      // The one being chosen, in the same red the app uses for
                      // "this is the thing" elsewhere — and in map colours, not
                      // theme colours: raster tiles are pale in both themes, so
                      // a mark tinted by the theme is a road.
                      child: const MapPlacePin(
                        color: Color(0xFFD32F2F),
                        size: 32,
                      ),
                    ),
                  ],
                ),
            ],
          ),
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
          // What will be saved, in the open. A coordinate is not something you
          // can check against the map by eye, so the app says the number it is
          // about to write down rather than only implying it.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _PickedReadout(
              picked: _picked,
              hint: l10n.mapPickHint,
              basemap: basemap,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickedReadout extends StatelessWidget {
  const _PickedReadout({
    required this.picked,
    required this.hint,
    required this.basemap,
  });

  /// Null until the map has been tapped, which is when the readout says what to
  /// do instead of what was chosen.
  final LatLng? picked;
  final String hint;
  final Basemap basemap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insets = MediaQuery.paddingOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          color: theme.colorScheme.surface.withValues(alpha: 0.9),
          padding: EdgeInsets.only(
            left: 16 + insets.left,
            right: 16 + insets.right,
            top: 8,
            bottom: 8,
          ),
          child: Text(
            picked == null ? hint : formatCoordinates(picked!),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              color: picked == null ? theme.colorScheme.onSurfaceVariant : null,
            ),
          ),
        ),
        MapAttributionBar(basemap: basemap),
      ],
    );
  }
}

/// A coordinate as the app writes it: latitude then longitude, five decimals.
///
/// Five is about a metre, which is finer than anything picked by dragging a map
/// under a crosshair and short enough to read back. Deliberately not localized:
/// a coordinate is a coordinate, and a decimal comma in one is how it stops
/// being copy-pasteable into every other map on earth.
String formatCoordinates(LatLng point) =>
    '${point.latitude.toStringAsFixed(5)}, '
    '${point.longitude.toStringAsFixed(5)}';
