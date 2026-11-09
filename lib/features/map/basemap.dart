/// What the trip is drawn *on*, as opposed to what is drawn.
///
/// A sealed type with a list behind it, rather than a URL constant next to the
/// map widget, because the map's ground is the part of this feature most likely
/// to change: today a choice of raster styles, later vector styles online and a
/// downloaded archive offline. Only the map widget switches on the type;
/// everything the app itself draws — routes, places, tracks, the "you are here"
/// mark — sits above it and never learns which one is underneath.
///
/// **Switched, never mixed.** Two grounds stacked would show a seam wherever one
/// stops, disagree about zoom depth, and — the part that matters here — go on
/// fetching tiles hidden under an opaque layer, which is traffic taken from
/// someone's donated server for pixels nobody sees. A [TileOverlay] is not a
/// second ground: it is transparent, hides nothing, and belongs to one entry.
library;

import '../../core/widgets/attribution.dart' show kOsmCopyrightUrl;

/// A source this app is allowed to *prefetch* from, or not.
///
/// Not a detail: the OpenStreetMap tile policy permits ordinary interactive
/// viewing and forbids downloading regions in advance, naming "download for
/// offline use" as the prohibited pattern. The offline feature therefore cannot
/// be a switch that applies to whatever source happens to be selected — it has
/// to ask the source first, which is what this answers.
enum OfflineDownload {
  /// The source welcomes (or sells) bulk download. Nothing here yet.
  allowed,

  /// Ordinary viewing only. Whatever the browse cache happens to keep is fine —
  /// caching is *required* by the same policy — but nothing may be fetched ahead
  /// of being looked at.
  forbidden,
}

/// A link that must be shown wherever this basemap is: the label to print and
/// where it points. Attribution is a condition of use, not a courtesy, and the
/// condition belongs to the source rather than to the screen — so it travels
/// with the entry and cannot be forgotten when a second one is added.
///
/// The label is printed as it stands, copyright sign included, because not every
/// source is a copyright holder: SRTM is credited, not claimed.
typedef MapAttribution = ({String label, String url});

/// What a style is for, which the picker says in a line under its name.
///
/// An enum rather than a text on the entry because that line is translated, and
/// `basemap.dart` knows nothing of localizations: the compiler then insists on a
/// sentence for every value. Never persisted.
enum BasemapPurpose { everyday, topographic, cycling, muted, ski }

sealed class Basemap {
  const Basemap({
    required this.id,
    required this.name,
    required this.purpose,
    required this.attributions,
    required this.offlineDownload,
  });

  /// Stable key, used to persist the choice. Append-only, like every other
  /// persisted identifier here: an entry that is removed must not free its id
  /// for a later, different map.
  final String id;

  /// Its name in the picker. A proper name, so not translated.
  final String name;
  final BasemapPurpose purpose;

  final List<MapAttribution> attributions;
  final OfflineDownload offlineDownload;
}

/// How far the camera may zoom, on every style alike.
///
/// The same number everywhere so that changing the style never moves the camera.
/// What differs per source is [RasterBasemap.maxNativeZoom].
const double kBasemapMaxZoom = 19;

/// Transparent image tiles drawn over a [RasterBasemap]'s own.
final class TileOverlay {
  const TileOverlay({required this.urlTemplate, required this.maxNativeZoom});

  final String urlTemplate;

  /// The deepest level the server has real tiles for; see
  /// [RasterBasemap.maxNativeZoom].
  final int maxNativeZoom;
}

/// Ordinary XYZ image tiles, the kind every raster server speaks.
final class RasterBasemap extends Basemap {
  const RasterBasemap({
    required super.id,
    required super.name,
    required super.purpose,
    required super.attributions,
    required super.offlineDownload,
    required this.urlTemplate,
    required this.maxNativeZoom,
    this.maxZoom = kBasemapMaxZoom,
    this.overlays = const [],
  });

  final String urlTemplate;

  /// The deepest level the server has real tiles for. Past it the last real
  /// level is enlarged. Measured rather than documented for most sources, and
  /// not optional: asking deeper gets a 404 or, worse, a picture saying there
  /// is no tile, drawn as if it were the map.
  final int maxNativeZoom;
  final double maxZoom;

  /// Drawn above the tiles, in order. Part of the entry rather than a switch of
  /// their own, so a server is asked for them only by someone who chose them.
  final List<TileOverlay> overlays;
}

/// OpenStreetMap's own tiles — the cartography people recognise as *the* OSM
/// map, rendered server-side by a mature renderer.
///
/// Permitted for what this screen does (a human panning around a viewport) as
/// long as three conditions hold, all of which are met where the layer is built:
/// a `User-Agent` naming this application and its version, conforming caching,
/// and the attribution below shown and tappable. The fourth condition is the one
/// encoded in [OfflineDownload.forbidden].
///
/// Deliberately the *default* only for as long as there is nothing better: it is
/// donated capacity with no uptime promise, and a source that welcomes the
/// traffic is the more considerate ground to stand on once one is wired up.
const RasterBasemap osmStandardBasemap = RasterBasemap(
  id: 'osm',
  name: 'OpenStreetMap',
  purpose: BasemapPurpose.everyday,
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  maxNativeZoom: 19,
  attributions: [_osmAttribution],
  offlineDownload: OfflineDownload.forbidden,
);

const MapAttribution _osmAttribution = (
  label: '© OpenStreetMap',
  url: kOsmCopyrightUrl,
);

const String _openTopoMapTiles =
    'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';

/// Tiles above this level are one identical placeholder image.
const int _openTopoMapNativeZoom = 17;

/// The credit OpenTopoMap asks for: its data sources and the style's license.
const List<MapAttribution> _openTopoMapAttributions = [
  _osmAttribution,
  (label: 'SRTM', url: 'https://www.earthdata.nasa.gov/data/instruments/srtm'),
  (label: '© OpenTopoMap (CC-BY-SA)', url: 'https://opentopomap.org/about'),
];

/// Embedding in an app is welcome as long as the server is not burdened, its
/// FAQ says, naming mass downloads; hence [OfflineDownload.forbidden].
const RasterBasemap openTopoMapBasemap = RasterBasemap(
  id: 'opentopomap',
  name: 'OpenTopoMap',
  purpose: BasemapPurpose.topographic,
  urlTemplate: _openTopoMapTiles,
  maxNativeZoom: _openTopoMapNativeZoom,
  attributions: _openTopoMapAttributions,
  offlineDownload: OfflineDownload.forbidden,
);

/// Served by OpenStreetMap France under the general OpenStreetMap tile policy,
/// so what holds for [osmStandardBasemap] holds here.
const RasterBasemap cyclOsmBasemap = RasterBasemap(
  id: 'cyclosm',
  name: 'CyclOSM',
  purpose: BasemapPurpose.cycling,
  urlTemplate:
      'https://{s}.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png',
  maxNativeZoom: 19,
  attributions: [
    _osmAttribution,
    (label: 'CyclOSM', url: 'https://www.cyclosm.org/'),
  ],
  offlineDownload: OfflineDownload.forbidden,
);

/// OpenStreetMap France's usage terms admit a mobile app that is free, not for
/// profit, and sends a full `User-Agent`, with the attribution visible in a
/// corner of the map without having to be asked for.
const RasterBasemap humanitarianBasemap = RasterBasemap(
  id: 'hot',
  name: 'Humanitarian',
  purpose: BasemapPurpose.muted,
  urlTemplate: 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
  maxNativeZoom: 18,
  attributions: [
    _osmAttribution,
    (label: 'Humanitarian OSM Team', url: 'https://www.hotosm.org/'),
    (label: 'OpenStreetMap France', url: 'https://www.openstreetmap.fr/'),
  ],
  offlineDownload: OfflineDownload.forbidden,
);

/// OpenSnowMap's pistes and lifts, over OpenTopoMap's relief.
///
/// The pistes are all OpenSnowMap serves to an app: its own grounds answer with
/// an access-denied image. Its terms forbid bulk download by any application and
/// require the credit below wherever the tiles are used. Past level 18 the
/// server answers with a picture saying so, not a tile.
const RasterBasemap openSnowMapBasemap = RasterBasemap(
  id: 'opensnowmap',
  name: 'OpenSnowMap',
  purpose: BasemapPurpose.ski,
  urlTemplate: _openTopoMapTiles,
  maxNativeZoom: _openTopoMapNativeZoom,
  overlays: [
    TileOverlay(
      urlTemplate: 'https://tiles.opensnowmap.org/pistes/{z}/{x}/{y}.png',
      maxNativeZoom: 18,
    ),
  ],
  attributions: [
    ..._openTopoMapAttributions,
    (
      label: '© opensnowmap.org (CC-BY-SA)',
      url: 'https://www.opensnowmap.org/',
    ),
  ],
  offlineDownload: OfflineDownload.forbidden,
);

/// Every basemap the user can pick, in menu order.
const List<Basemap> kBasemaps = [
  osmStandardBasemap,
  openTopoMapBasemap,
  cyclOsmBasemap,
  humanitarianBasemap,
  openSnowMapBasemap,
];

const Basemap kDefaultBasemap = osmStandardBasemap;

/// The entry stored under [id], or the default for anything this build cannot
/// name: nothing stored yet, or a style from a newer version.
Basemap basemapById(String? id) => kBasemaps.firstWhere(
  (basemap) => basemap.id == id,
  orElse: () => kDefaultBasemap,
);
