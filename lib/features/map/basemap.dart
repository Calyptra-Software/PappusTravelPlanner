/// What the trip is drawn *on*, as opposed to what is drawn.
///
/// A sealed type with a list behind it, rather than a URL constant next to the
/// map widget, because the map's ground is the part of this feature most likely
/// to change: today one raster source, later a choice of vector styles online
/// and a downloaded archive offline. Only the map widget switches on the type;
/// everything the app itself draws — routes, places, tracks, the "you are here"
/// mark — sits above it and never learns which one is underneath.
///
/// **Switched, never mixed.** Two grounds stacked would show a seam wherever one
/// stops, disagree about zoom depth, and — the part that matters here — go on
/// fetching tiles hidden under an opaque layer, which is traffic taken from
/// someone's donated server for pixels nobody sees.
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
typedef MapAttribution = ({String label, String url});

sealed class Basemap {
  const Basemap({
    required this.id,
    required this.attributions,
    required this.offlineDownload,
  });

  /// Stable key, used to persist the choice. Append-only, like every other
  /// persisted identifier here: an entry that is removed must not free its id
  /// for a later, different map.
  final String id;

  final List<MapAttribution> attributions;
  final OfflineDownload offlineDownload;
}

/// Ordinary XYZ image tiles, the kind every raster server speaks.
final class RasterBasemap extends Basemap {
  const RasterBasemap({
    required super.id,
    required super.attributions,
    required super.offlineDownload,
    required this.urlTemplate,
    required this.maxZoom,
  });

  final String urlTemplate;
  final double maxZoom;
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
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  maxZoom: 19,
  attributions: [(label: 'OpenStreetMap', url: kOsmCopyrightUrl)],
  offlineDownload: OfflineDownload.forbidden,
);

/// Every basemap the user can pick, in menu order.
///
/// One entry today, so nothing offers a choice yet — the list exists so that
/// adding the second is an entry here rather than a rewrite of the map screen.
const List<Basemap> kBasemaps = [osmStandardBasemap];

const Basemap kDefaultBasemap = osmStandardBasemap;
