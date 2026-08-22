/// Sizes of files, for the two places the app has to name one: the refusal when
/// something is too big, and the line under an attachment saying what it costs.
///
/// Binary units under decimal names (`KB` = 1024 bytes), which is what a file
/// manager on every platform this runs on shows, so the number here matches the
/// number there. Pure, and no `intl`: this is a magnitude, not a measurement —
/// one decimal place above a megabyte and none below it, because nobody needs
/// three digits of precision about a photo.
library;

const int _kilo = 1024;

/// Formats [bytes] as a short human-readable size, e.g. `842 KB`, `3.4 MB`.
String formatBytes(int bytes) {
  if (bytes < _kilo) return '$bytes B';
  final kb = bytes / _kilo;
  if (kb < _kilo) return '${kb.round()} KB';
  final mb = kb / _kilo;
  if (mb < _kilo) return '${_oneDecimal(mb)} MB';
  return '${_oneDecimal(mb / _kilo)} GB';
}

/// One decimal place, without a trailing `.0` — `3.4 MB`, but `20 MB`.
String _oneDecimal(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.round().toString()
      : rounded.toStringAsFixed(1);
}
