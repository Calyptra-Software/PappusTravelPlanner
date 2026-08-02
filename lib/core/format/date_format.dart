import 'package:intl/intl.dart';

import 'civil_date.dart';

import '../../l10n/app_localizations.dart';

export 'civil_date.dart';

/// Weekday + day + month, in the locale's own convention — used as itinerary
/// day headers. e.g. "Sun, Jul 5" (en) / "So., 5. Juli" (de).
String formatDay(DateTime date, String localeName) =>
    DateFormat.MMMEd(localeName).format(date);

/// Full date in the locale's convention: "July 5, 2026" (en) / "5. Juli 2026" (de).
String formatFullDate(DateTime date, String localeName) =>
    DateFormat.yMMMMd(localeName).format(date);

/// A human date range for a trip card, tolerant of missing dates. Uses
/// locale-aware skeletons so each language gets its correct format (e.g. the
/// German day-period in "5. Juli").
String formatDateRange(
  AppLocalizations l10n,
  String localeName,
  DateTime? start,
  DateTime? end,
) {
  final dayMonth = DateFormat.MMMMd(localeName);
  final full = DateFormat.yMMMMd(localeName);
  if (start == null && end == null) return l10n.datesNotSet;
  if (start != null && end == null) return full.format(start);
  if (start == null && end != null) return l10n.until(full.format(end));
  // Both set. Drop the redundant year on the start when they share one.
  if (start!.year == end!.year) {
    return '${dayMonth.format(start)} – ${full.format(end)}';
  }
  return '${full.format(start)} – ${full.format(end)}';
}

/// Inclusive number of days a trip spans, or null when it can't be computed.
int? tripDayCount(DateTime? start, DateTime? end) {
  if (start == null || end == null) return null;
  return daysBetween(start, end) + 1;
}

/// Formats minutes-since-midnight as a 24h "HH:mm" label, or '' when null.
String formatMinutes(int? minutes) {
  if (minutes == null) return '';
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// Formats a plain duration given in minutes as a compact "2h 30m" label
/// ("45m" under an hour, "3h" on the hour, "0m" for none). Like [formatMinutes]
/// the units are not localized — durations read the same way everywhere.
String formatDurationHm(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

/// Formats a start/end pair, e.g. "09:00 – 11:30", "09:00", or ''.
String formatTimeRange(int? startMinutes, int? endMinutes) {
  final start = formatMinutes(startMinutes);
  final end = formatMinutes(endMinutes);
  if (start.isEmpty && end.isEmpty) return '';
  if (end.isEmpty) return start;
  if (start.isEmpty) return end;
  return '$start – $end';
}

/// Formats how far an actual time missed its planned one, in minutes: "+15"
/// (a quarter of an hour late), "−5" (five minutes early), "±0" (to the minute).
/// From an hour out it reads as "+1:30" rather than as a large bare minute
/// count. Always shown next to the time it belongs to, so it carries no unit.
String formatSignedMinutes(int delta) {
  if (delta == 0) return '±0';
  final sign = delta > 0 ? '+' : '−';
  final abs = delta.abs();
  if (abs < 60) return '$sign$abs';
  return '$sign${abs ~/ 60}:${(abs % 60).toString().padLeft(2, '0')}';
}
