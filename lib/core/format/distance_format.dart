/// Distances, for the one place the app has to name one: the line a leg
/// followed, where the length is what tells two of them apart.
///
/// Pure, and no `intl`, exactly as `byte_format.dart` is and for the same
/// reason — this is a magnitude, not a measurement. What it has to do is let a
/// reader say "that one is the walk and this one is the bus", so it carries one
/// decimal place where the difference is a few hundred metres and none where it
/// is kilometres.
///
/// Deliberately not the point count: a number that describes how finely the
/// recorder sampled invites tuning something that has no dial, while a length
/// describes the line itself.
library;

/// Formats [meters] as a short human-readable distance, e.g. `820 m`, `4.2 km`.
String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000;
  if (km < 10) {
    // A recorded walk and the bus that followed it differ by a few hundred
    // metres, so below ten kilometres the decimal is what distinguishes them.
    final rounded = (km * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? '${rounded.round()} km'
        : '${rounded.toStringAsFixed(1)} km';
  }
  return '${km.round()} km';
}
