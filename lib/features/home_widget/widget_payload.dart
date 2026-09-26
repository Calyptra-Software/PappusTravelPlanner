import '../../core/format/date_format.dart';
import '../../data/database/app_database.dart';
import '../../data/database/tables.dart';
import '../../l10n/app_localizations.dart';
import '../itinerary/day_blocks.dart' show Continuation;
import '../itinerary/time_marks.dart';

/// One line of "today's plan" shown on the widget.
class WidgetRow {
  const WidgetRow({
    required this.id,
    required this.time,
    required this.text,
    this.note = '',
  });

  /// Itinerary item id, so a tapped row can deep-link into that specific item.
  final int id;

  /// The entry's planned times, each end carrying how far it missed its plan —
  /// the timeline's line, in the one form a `RemoteViews` text can be coloured
  /// in: HTML, parsed back into spans by `TodayItemsRemoteViewsService`. Plain
  /// text ("09:00 – 10:30") whenever nothing has been recorded to compare.
  final String time;
  final String text;
  final String note;
}

/// Red for late, green for early — a lighter pair than the app's, because the
/// widget paints on its own dark background rather than the app's theme.
const String _widgetLateColor = '#FF8A80';
const String _widgetEarlyColor = '#A5D6A7';

/// The item's times as the widget shows them: [timeMarks]' rule, with each miss
/// wrapped in a `<font>` the native row turns back into colour.
String widgetTime(ItineraryItem item) => [
  for (final mark in timeMarks(item))
    if (mark.delta case final delta?)
      '${formatMinutes(mark.minutes)}${formatDayMark(mark.day)} <font color="'
          '${delta > 0 ? _widgetLateColor : _widgetEarlyColor}">'
          '(${formatSignedMinutes(delta)})</font>'
    else
      '${formatMinutes(mark.minutes)}${formatDayMark(mark.day)}',
].join(' – ');

/// The mark a continuation's time opens with — the turn-down arrow the
/// timeline draws beside the same row, saying it came from an earlier day.
const String kWidgetContinuationMark = '↳';

/// A row for an entry that began on an earlier day and runs into today: the
/// night train on the morning it arrives. It goes above today's own rows, as it
/// does in the timeline, and deep-links into the entry like any other.
///
/// Its time is the end alone, behind [kWidgetContinuationMark], with its miss
/// coloured as [widgetTime] colours one ("↳ 07:12 (+15)") — the start was
/// yesterday and says nothing about today. Where there is no time to give — a
/// day the entry runs through, or an end with no time — the mark stands alone
/// and the note says in words what the time cannot.
WidgetRow continuationRow(
  Continuation continuation,
  AppLocalizations l10n, {
  Map<int, String> modeLabels = const {},
}) {
  final item = continuation.item;
  final end = continuation.arrives ? endMark(item) : null;
  final String time;
  if (end == null) {
    time = kWidgetContinuationMark;
  } else if (end.delta case final delta?) {
    time =
        '$kWidgetContinuationMark ${formatMinutes(end.minutes)} <font color="'
        '${delta > 0 ? _widgetLateColor : _widgetEarlyColor}">'
        '(${formatSignedMinutes(delta)})</font>';
  } else {
    time = '$kWidgetContinuationMark ${formatMinutes(end.minutes)}';
  }
  return WidgetRow(
    id: item.id,
    time: time,
    text: _itemText(item, l10n, modeLabels),
    note: !continuation.arrives
        ? l10n.continuationAllDay
        : end == null
        ? l10n.continuationEnds
        : '',
  );
}

/// Flat, pre-formatted data handed to the native Android widget. All strings are
/// already localised so the Kotlin side only has to display them.
class WidgetPayload {
  const WidgetPayload({
    required this.hasTrip,
    this.tripId,
    this.title = '',
    this.destination = '',
    this.dates = '',
    this.countdown = '',
    this.isOngoing = false,
    this.todayHeader = '',
    this.rows = const [],
    this.emptyTitle = '',
    this.emptyBody = '',
  });

  final bool hasTrip;
  final int? tripId;
  final String title;
  final String destination;
  final String dates;
  final String countdown;
  final bool isOngoing;
  final String todayHeader;
  final List<WidgetRow> rows;
  final String emptyTitle;
  final String emptyBody;
}

/// Whether [trip] has real start/end dates spanning [day].
bool isTripOngoing(Trip trip, DateTime day) {
  final start = trip.startDate;
  if (start == null) return false;
  final end = trip.endDate ?? start;
  // Normalize [day] too: callers may pass a raw `DateTime.now()` with a
  // time-of-day, which would otherwise test as "after" the end day's midnight
  // and wrongly report the last day as not ongoing.
  final d = normalizeDay(day);
  final s = normalizeDay(start);
  final e = normalizeDay(end);
  return !d.isBefore(s) && !d.isAfter(e);
}

/// Picks the trip to feature: an ongoing trip first, then the nearest upcoming,
/// then the most recently finished, then any trip; null when there are none.
///
/// A [TripKind.routine] is never featured. It has no dates, so it can only ever
/// reach the final "any trip" fallback — and there it would put a template on
/// the home screen under a date it does not have, with an anchor day the
/// widget's "today" would find nothing on. An outing needs no special case: it
/// is a dated one-day trip, and every clause here already reads it correctly.
Trip? pickFeaturedTrip(List<Trip> allTrips, DateTime now) {
  final trips = [
    for (final t in allTrips)
      if (t.kind != TripKind.routine) t,
  ];
  if (trips.isEmpty) return null;
  final today = normalizeDay(now);

  final ongoing = trips.where((t) => isTripOngoing(t, today)).toList()
    ..sort((a, b) => a.startDate!.compareTo(b.startDate!));
  if (ongoing.isNotEmpty) return ongoing.first;

  final upcoming =
      trips
          .where(
            (t) =>
                t.startDate != null &&
                normalizeDay(t.startDate!).isAfter(today),
          )
          .toList()
        ..sort((a, b) => a.startDate!.compareTo(b.startDate!));
  if (upcoming.isNotEmpty) return upcoming.first;

  final past = trips.where((t) => t.startDate != null).toList()
    ..sort(
      (a, b) =>
          (b.endDate ?? b.startDate!).compareTo(a.endDate ?? a.startDate!),
    );
  if (past.isNotEmpty) return past.first;

  return trips.first;
}

/// Display text for a single itinerary item. [modeLabels] resolves a leg's
/// transport-mode row id to its already-localized label.
String _itemText(
  ItineraryItem item,
  AppLocalizations l10n,
  Map<int, String> modeLabels,
) {
  if (item.kind == ItemKind.transport) {
    final mode = modeLabels[item.mode] ?? l10n.modeOther;
    final route = [
      item.fromLocation ?? '',
      item.toLocation ?? '',
    ].where((s) => s.isNotEmpty).join(' → ');
    return route.isEmpty ? mode : '$mode: $route';
  }
  final title = item.title ?? '';
  if (title.isNotEmpty) return title;
  return item.location ?? '';
}

/// Builds the full payload. [todayItems] are the featured trip's items for
/// today, already ordered, and [continuations] the entries running into today
/// from an earlier day (`continuationsOn`); both only used when the featured
/// trip is ongoing.
WidgetPayload buildWidgetPayload(
  List<Trip> trips,
  List<ItineraryItem> todayItems,
  DateTime now,
  AppLocalizations l10n,
  String localeName, {
  Map<int, String> modeLabels = const {},
  List<Continuation> continuations = const [],
}) {
  final trip = pickFeaturedTrip(trips, now);
  if (trip == null) {
    return WidgetPayload(
      hasTrip: false,
      emptyTitle: l10n.widgetNoTripsTitle,
      emptyBody: l10n.widgetNoTripsBody,
    );
  }

  final today = normalizeDay(now);
  final ongoing = isTripOngoing(trip, today);

  String countdown = '';
  if (ongoing) {
    final start = normalizeDay(trip.startDate!);
    final end = normalizeDay(trip.endDate ?? trip.startDate!);
    final dayNumber = today.difference(start).inDays + 1;
    final total = end.difference(start).inDays + 1;
    countdown = l10n.widgetDayXofY(dayNumber, total);
  } else if (trip.startDate != null) {
    final start = normalizeDay(trip.startDate!);
    final daysUntil = start.difference(today).inDays;
    if (daysUntil > 1) {
      countdown = l10n.widgetInDays(daysUntil);
    } else if (daysUntil == 1) {
      countdown = l10n.widgetTomorrow;
    } else {
      // A trip starting today is ongoing, so what is left here is over. It is
      // featured only because nothing is ongoing or ahead; without a line
      // saying it has ended it reads as the current trip.
      final end = normalizeDay(trip.endDate ?? trip.startDate!);
      final daysSince = today.difference(end).inDays;
      countdown = daysSince == 1
          ? l10n.widgetEndedYesterday
          : l10n.widgetEndedDaysAgo(daysSince);
    }
  }

  // Send every item for today; the native widget decides how many fit its
  // current size and renders a "+N" only when some genuinely don't fit.
  // What began on an earlier day comes first, as it does in the timeline: it
  // started before anything planned today, and on the morning a night train
  // is due it is what the day is spent on.
  List<WidgetRow> rows = const [];
  if (ongoing) {
    rows = [
      for (final c in continuations)
        continuationRow(c, l10n, modeLabels: modeLabels),
      for (final i in todayItems)
        WidgetRow(
          id: i.id,
          time: widgetTime(i),
          text: _itemText(i, l10n, modeLabels),
          note: i.notes?.trim() ?? '',
        ),
    ];
  }

  return WidgetPayload(
    hasTrip: true,
    tripId: trip.id,
    title: trip.title,
    destination: trip.destination,
    dates: formatDateRange(l10n, localeName, trip.startDate, trip.endDate),
    countdown: countdown,
    isOngoing: ongoing,
    todayHeader: l10n.widgetTodayHeader,
    rows: rows,
  );
}
