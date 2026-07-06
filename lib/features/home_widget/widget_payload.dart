import '../../core/format/date_format.dart';
import '../../data/database/app_database.dart';
import '../../data/database/tables.dart';
import '../../l10n/app_localizations.dart';
import '../itinerary/widgets/transport_mode.dart';

/// One line of "today's plan" shown on the widget.
class WidgetRow {
  const WidgetRow({required this.time, required this.text});
  final String time;
  final String text;
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
    this.moreCount = 0,
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
  final int moreCount;
  final String emptyTitle;
  final String emptyBody;
}

/// Whether [trip] has real start/end dates spanning [day].
bool isTripOngoing(Trip trip, DateTime day) {
  final start = trip.startDate;
  if (start == null) return false;
  final end = trip.endDate ?? start;
  final s = normalizeDay(start);
  final e = normalizeDay(end);
  return !day.isBefore(s) && !day.isAfter(e);
}

/// Picks the trip to feature: an ongoing trip first, then the nearest upcoming,
/// then the most recently finished, then any trip; null when there are none.
Trip? pickFeaturedTrip(List<Trip> trips, DateTime now) {
  if (trips.isEmpty) return null;
  final today = normalizeDay(now);

  final ongoing = trips.where((t) => isTripOngoing(t, today)).toList()
    ..sort((a, b) => a.startDate!.compareTo(b.startDate!));
  if (ongoing.isNotEmpty) return ongoing.first;

  final upcoming = trips
      .where((t) => t.startDate != null && normalizeDay(t.startDate!).isAfter(today))
      .toList()
    ..sort((a, b) => a.startDate!.compareTo(b.startDate!));
  if (upcoming.isNotEmpty) return upcoming.first;

  final past = trips.where((t) => t.startDate != null).toList()
    ..sort((a, b) =>
        (b.endDate ?? b.startDate!).compareTo(a.endDate ?? a.startDate!));
  if (past.isNotEmpty) return past.first;

  return trips.first;
}

/// Display text for a single itinerary item.
String _itemText(ItineraryItem item, AppLocalizations l10n) {
  if (item.kind == ItemKind.transport) {
    final mode = (item.mode ?? TransportMode.other).label(l10n);
    final route = [item.fromLocation ?? '', item.toLocation ?? '']
        .where((s) => s.isNotEmpty)
        .join(' → ');
    return route.isEmpty ? mode : '$mode: $route';
  }
  final title = item.title ?? '';
  if (title.isNotEmpty) return title;
  return item.location ?? '';
}

/// Builds the full payload. [todayItems] are the featured trip's items for
/// today, already ordered; only used when the featured trip is ongoing.
WidgetPayload buildWidgetPayload(
  List<Trip> trips,
  List<ItineraryItem> todayItems,
  DateTime now,
  AppLocalizations l10n,
  String localeName,
) {
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
    } else if (daysUntil == 0) {
      countdown = l10n.widgetToday;
    }
  }

  List<WidgetRow> rows = const [];
  var moreCount = 0;
  if (ongoing && todayItems.isNotEmpty) {
    rows = todayItems
        .take(3)
        .map((i) => WidgetRow(
              time: formatMinutes(i.startMinutes),
              text: _itemText(i, l10n),
            ))
        .toList();
    moreCount = todayItems.length > 3 ? todayItems.length - 3 : 0;
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
    moreCount: moreCount,
  );
}
