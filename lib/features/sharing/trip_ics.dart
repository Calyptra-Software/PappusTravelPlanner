import 'dart:convert';

import '../../core/format/money_format.dart';
import '../../data/database/tables.dart';
import '../../l10n/app_localizations.dart';
import '../itinerary/widgets/transport_mode.dart';
import 'trip_bundle.dart';

/// MIME type of an exported calendar.
const String tripIcsMimeType = 'text/calendar';

/// File extension of an exported calendar.
const String tripIcsExtension = 'ics';

/// Renders a [TripBundle] — the same portable, database-free snapshot the app
/// shares as a `.tpt` file — into an iCalendar (RFC 5545) document, so a trip
/// can be dropped into whatever calendar the traveller already lives in.
///
/// This is **not** an interchange format: `.tpt` is the one that round-trips
/// losslessly. A calendar is a one-way view of the plan, so the export keeps
/// what a calendar can hold and drops the rest:
///
/// - **Only live entries** are exported — loose items and the chosen option of
///   each decision — exactly as the timeline, the totals and the PDF see them.
///   The roads not taken are not on the calendar.
/// - **Times are floating.** `DTSTART:20260724T090000`, with neither a `Z` nor
///   a `TZID`, means "09:00 local wall clock, wherever you are" — which is
///   precisely what the app stores (a day plus minutes since midnight, with no
///   timezone anywhere). Nothing has to be converted, and nothing can be
///   converted wrongly.
/// - **An untimed entry becomes an all-day event**, since a calendar has no way
///   to say "some time this day, after that other thing". This is the one real
///   loss: `sortOrder` has no representation in iCalendar — a calendar orders by
///   time or not at all — so a day's untimed entries arrive as an unordered
///   set of banners.
/// - **Groups, checklists, participants, alternatives and actual times have no
///   mapping** and are left out. Costs ride along as text in the description,
///   where they can be read but not counted.
///
/// Pure (no database, no `BuildContext`): everything it needs is the bundle plus
/// the localized [l10n] labels and [localeName], mirroring `trip_pdf.dart` so
/// the output is unit-testable without a database.
///
/// [exportedAt] stamps every event's `DTSTAMP` (defaults to now); tests pass a
/// fixed value to get a byte-stable document.
String buildTripIcs({
  required TripBundle bundle,
  required AppLocalizations l10n,
  required String localeName,
  DateTime? exportedAt,
}) {
  final builder = _TripIcsBuilder(
    bundle: bundle,
    l10n: l10n,
    localeName: localeName,
    stamp: exportedAt ?? DateTime.now(),
  );
  return builder.build();
}

class _TripIcsBuilder {
  _TripIcsBuilder({
    required this.bundle,
    required this.l10n,
    required this.localeName,
    required this.stamp,
  }) : chosenBranchIds = {
         for (final s in bundle.alternativeSets)
           for (final a in s.alternatives)
             if (a.chosen) a.localId,
       };

  final TripBundle bundle;
  final AppLocalizations l10n;
  final String localeName;
  final DateTime stamp;

  /// Local ids of the chosen option of every decision — the ones that count.
  final Set<int> chosenBranchIds;

  final StringBuffer _out = StringBuffer();

  /// Namespace for this trip's [_uid]s. A row id alone is not unique: the
  /// database is a portable file people copy around, so trip 3 of one copy and
  /// trip 3 of another would claim the same UID and overwrite each other in the
  /// calendar they were both imported into. The trip's creation instant is the
  /// closest thing the schema has to a stable identity for it.
  String get _namespace =>
      bundle.trip.createdAt.microsecondsSinceEpoch.toRadixString(36);

  String _uid(String suffix) => '$suffix-$_namespace@travelplanner';

  bool _itemIsLive(BundleItem i) =>
      i.alternativeLocalId == null ||
      chosenBranchIds.contains(i.alternativeLocalId);

  String build() {
    _line('BEGIN', 'VCALENDAR');
    _line('VERSION', '2.0');
    _line('PRODID', '-//Travel Planner//Trip Export//EN');
    _line('CALSCALE', 'GREGORIAN');
    // Non-standard but very widely honoured: names the imported calendar.
    _line('X-WR-CALNAME', bundle.trip.title);

    _tripEvent();
    for (final item in bundle.items) {
      if (_itemIsLive(item)) _itemEvent(item);
    }

    _line('END', 'VCALENDAR');
    return _out.toString();
  }

  /// The trip itself, as an all-day banner spanning its dates — the row that
  /// makes the rest of the events legible as one journey. Skipped for a trip
  /// still sketched out without dates.
  void _tripEvent() {
    final start = bundle.trip.startDate;
    if (start == null) return;
    final end = bundle.trip.endDate ?? start;

    _line('BEGIN', 'VEVENT');
    _line('UID', _uid('trip'));
    _line('DTSTAMP', _utcStamp(stamp));
    _line('SUMMARY', bundle.trip.title);
    _dayRange(start, end);
    if (bundle.trip.destination.trim().isNotEmpty) {
      _line('LOCATION', bundle.trip.destination.trim());
    }
    final notes = bundle.trip.notes?.trim() ?? '';
    if (notes.isNotEmpty) _line('DESCRIPTION', notes);
    // A trip spans days without occupying them: it must not mark the traveller
    // busy on top of the entries inside it.
    _line('TRANSP', 'TRANSPARENT');
    _line('END', 'VEVENT');
  }

  void _itemEvent(BundleItem item) {
    _line('BEGIN', 'VEVENT');
    _line('UID', _uid('item-${item.localId}'));
    _line('DTSTAMP', _utcStamp(stamp));
    _line('SUMMARY', _summary(item));

    final start = item.startMinutes;
    if (start == null) {
      // Nothing to place it at within the day, so it takes the whole day.
      _dayRange(item.date, item.date);
      _line('TRANSP', 'TRANSPARENT');
    } else {
      _line('DTSTART', _floating(item.date, start));
      final end = item.endMinutes;
      // An entry lives inside one day, so an end at or before its start can
      // only be an unfinished edit — and RFC 5545 requires DTEND to be strictly
      // later. An event with no DTEND simply takes up no time, which is the
      // honest reading of "we know when it starts and nothing more".
      if (end != null && end > start) {
        _line('DTEND', _floating(item.date, end));
      }
      _line('TRANSP', 'OPAQUE');
    }

    final location = _location(item);
    if (location.isNotEmpty) _line('LOCATION', location);

    final description = _description(item);
    if (description.isNotEmpty) _line('DESCRIPTION', description);

    _line('END', 'VEVENT');
  }

  /// Writes the DTSTART/DTEND pair of an all-day event covering [first] to
  /// [last] inclusive. iCalendar's all-day DTEND is **exclusive**, hence the
  /// extra day.
  void _dayRange(DateTime first, DateTime last) {
    _line('DTSTART', _dateOnly(first), params: ';VALUE=DATE');
    _line(
      'DTEND',
      _dateOnly(DateTime(last.year, last.month, last.day + 1)),
      params: ';VALUE=DATE',
    );
  }

  // --- item text ---

  /// The event's title. Mirrors the PDF's row title so a trip reads the same
  /// however it leaves the app.
  String _summary(BundleItem item) {
    if (item.kind == ItemKind.transport) return _transportSummary(item);
    final title = item.title?.trim() ?? '';
    if (title.isNotEmpty) return title;
    final location = item.location?.trim() ?? '';
    return location.isNotEmpty ? location : l10n.untitledEntry;
  }

  String _transportSummary(BundleItem item) {
    final mode = item.mode == null
        ? l10n.modeOther
        : labelForTransportModeKey(item.mode!, l10n);
    final from = item.fromLocation?.trim() ?? '';
    final to = item.toLocation?.trim() ?? '';
    if (from.isEmpty && to.isEmpty) return mode;
    // Unlike the PDF — whose bundled Roboto has no arrow glyph — an iCalendar
    // file is plain UTF-8 read by the calendar's own fonts.
    return '$mode: $from → $to';
  }

  /// Where the entry happens: a place's location, a leg's departure point.
  String _location(BundleItem item) {
    if (item.kind == ItemKind.transport) {
      return item.fromLocation?.trim() ?? '';
    }
    final location = item.location?.trim() ?? '';
    // Already the summary when the entry has no title of its own; repeating it
    // in LOCATION is harmless and lets the calendar offer directions.
    return location;
  }

  /// The notes, plus the entry's own costs as text. A calendar cannot add money
  /// up, so these are a reminder of what was budgeted, not a total.
  String _description(BundleItem item) {
    final parts = <String>[];
    final notes = item.notes?.trim() ?? '';
    if (notes.isNotEmpty) parts.add(notes);
    for (final c in bundle.costs) {
      if (c.itemLocalId != item.localId) continue;
      final amount = formatMoney(
        c.amountMinor,
        bundle.currencyBook.byCode(c.currency),
        localeName,
      );
      final reason = c.reason.trim();
      parts.add(reason.isEmpty ? amount : '$reason: $amount');
    }
    return parts.join('\n');
  }

  // --- iCalendar plumbing ---

  /// Writes one content line: `NAME[params]:escaped-value`, folded and
  /// CRLF-terminated. [params] must already be escaped and start with `;`.
  void _line(String name, String value, {String params = ''}) {
    _writeFolded('$name$params:${_escape(value)}');
  }

  /// Escapes a TEXT value per RFC 5545 §3.3.11. Backslash first, or it would
  /// escape the escapes added after it.
  static String _escape(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\n', '\\n');

  /// Folds a content line to 75 octets and terminates it with CRLF, per RFC
  /// 5545 §3.1. The limit counts **octets**, not characters, and a fold may not
  /// land inside a UTF-8 sequence — so this measures each rune's encoded length
  /// rather than slicing the string. The continuation line's leading space
  /// counts toward its own 75.
  void _writeFolded(String line) {
    const limit = 75;
    var used = 0;
    for (final rune in line.runes) {
      final char = String.fromCharCode(rune);
      final width = utf8.encode(char).length;
      if (used + width > limit) {
        _out.write('\r\n ');
        used = 1;
      }
      _out.write(char);
      used += width;
    }
    _out.write('\r\n');
  }

  /// `yyyyMMdd` — the DATE form, used for all-day events.
  static String _dateOnly(DateTime d) =>
      '${_pad(d.year, 4)}${_pad(d.month, 2)}${_pad(d.day, 2)}';

  /// `yyyyMMddTHHmmss` — a *floating* DATE-TIME: no `Z`, no `TZID`, so it means
  /// the same wall-clock time wherever it is read. See the class doc.
  static String _floating(DateTime day, int minutes) =>
      '${_dateOnly(day)}T${_pad(minutes ~/ 60, 2)}${_pad(minutes % 60, 2)}00';

  /// `yyyyMMddTHHmmssZ` — DTSTAMP is always UTC, unlike the event's own times.
  static String _utcStamp(DateTime t) {
    final u = t.toUtc();
    return '${_dateOnly(u)}T${_pad(u.hour, 2)}${_pad(u.minute, 2)}'
        '${_pad(u.second, 2)}Z';
  }

  static String _pad(int value, int width) =>
      value.toString().padLeft(width, '0');
}
