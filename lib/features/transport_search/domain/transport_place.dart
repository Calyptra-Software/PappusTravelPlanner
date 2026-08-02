/// What kind of location a geocoder match refers to.
enum PlaceKind { stop, address, place, other }

/// How a bare point is addressed in a journey query.
///
/// The routing service takes a coordinate anywhere it takes a stop id, so this
/// is the fallback for anything that has no id of its own — and, since an
/// imported leg stores its ends' coordinates, the way a journey can still be
/// searched again when the id it was found by has been lost.
String coordinateQueryId(double lat, double lon) => '$lat,$lon';

/// A location returned by the geocoder — a station, an address, or a point of
/// interest — that the user can pick as the origin or destination of a search.
///
/// [id] is the routing service's own opaque identifier; it is what a journey
/// query is issued against (as `fromPlace`/`toPlace`), so it is carried through
/// verbatim rather than reconstructed from the coordinates. [lat]/[lon] and
/// [timeZone] are captured now for later use (map, floating-time conversion)
/// even though nothing consumes them yet.
class TransportPlace {
  const TransportPlace({
    required this.id,
    required this.name,
    required this.kind,
    this.lat,
    this.lon,
    this.area,
    this.timeZone,
  });

  final String id;
  final String name;
  final PlaceKind kind;
  final double? lat;
  final double? lon;

  /// A human-readable containing area (e.g. the city), for disambiguating two
  /// stops that share a name. Null when the geocoder gave none.
  final String? area;

  /// The IANA timezone of this location (e.g. `Europe/Berlin`), when known.
  final String? timeZone;

  /// How a journey query addresses this place.
  ///
  /// Only a **stop** is addressable by its [id]: the geocoder answers for
  /// addresses and points of interest with identifiers of its own (`way/[…]`)
  /// that the routing endpoint rejects outright — a search from a picked
  /// address fails with a 404 rather than routing from it. Those are therefore
  /// addressed by coordinate, which the router accepts anywhere a stop id is
  /// accepted, and which is also the only form that lets it route *to the door*
  /// (cycling or walking the first and last mile).
  ///
  /// A place with neither a usable kind nor coordinates falls back to [id];
  /// there is nothing better to send, and the service says so plainly.
  String get queryId {
    if (kind == PlaceKind.stop) return id;
    final lat = this.lat;
    final lon = this.lon;
    return lat == null || lon == null ? id : coordinateQueryId(lat, lon);
  }

  @override
  String toString() => 'TransportPlace($name${area == null ? '' : ', $area'})';
}
