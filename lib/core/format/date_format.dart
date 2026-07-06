import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

/// Strips the time component so a [DateTime] can be used as a stable day key.
DateTime normalizeDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

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
  return normalizeDay(end).difference(normalizeDay(start)).inDays + 1;
}

/// Formats minutes-since-midnight as a 24h "HH:mm" label, or '' when null.
String formatMinutes(int? minutes) {
  if (minutes == null) return '';
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
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
