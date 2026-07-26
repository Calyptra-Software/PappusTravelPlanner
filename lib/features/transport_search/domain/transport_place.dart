/// What kind of location a geocoder match refers to.
enum PlaceKind { stop, address, place, other }

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

  @override
  String toString() => 'TransportPlace($name${area == null ? '' : ', $area'})';
}
