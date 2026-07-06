/// A reference to a place. For now it is just a human-entered [name], but the
/// optional coordinates are reserved so a geocoder can populate them later
/// without changing call sites — this is the seam for future maps support.
class PlaceRef {
  const PlaceRef({required this.name, this.latitude, this.longitude});

  final String name;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  @override
  String toString() => name;
}
