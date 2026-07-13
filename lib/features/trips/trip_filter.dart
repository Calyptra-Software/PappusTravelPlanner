import '../../core/format/date_format.dart';
import '../../data/database/app_database.dart';
import '../../data/database/tables.dart';

/// Where a trip sits relative to today, derived from its dates.
enum TripStatus { upcoming, ongoing, past, undated }

/// Ordering options for the overview list.
enum TripSort {
  dateAsc,
  dateDesc,
  nameAsc,
  createdDesc,
  expenseDesc,
  expenseAsc,
}

/// Collapses a trip's per-currency totals to one comparable number: its largest
/// single-currency bucket (the app never converts between currencies, so cross-
/// currency sums would be meaningless). A trip with no costs — or an absent
/// entry — ranks as 0.
int tripExpenseKey(Map<Currency, int>? totals) {
  if (totals == null || totals.isEmpty) return 0;
  return totals.values.reduce((a, b) => a > b ? a : b);
}

/// Classifies a trip against [today]. Mirrors [isTripOngoing]: a trip with no
/// start date is [TripStatus.undated]; a missing end date is treated as a
/// single-day trip.
TripStatus tripStatus(Trip trip, DateTime today) {
  final start = trip.startDate;
  if (start == null) return TripStatus.undated;
  final s = normalizeDay(start);
  final e = normalizeDay(trip.endDate ?? start);
  final d = normalizeDay(today);
  if (d.isBefore(s)) return TripStatus.upcoming;
  if (d.isAfter(e)) return TripStatus.past;
  return TripStatus.ongoing;
}

/// The full set of overview list controls: free-text search, filters and sort.
///
/// Empty [statuses] / [participantIds] mean "no restriction". Pure and
/// value-equatable so it can drive `setState` and be unit-tested without a DB.
class TripQuery {
  const TripQuery({
    this.text = '',
    this.statuses = const {},
    this.participantIds = const {},
    this.from,
    this.to,
    this.sort = TripSort.dateAsc,
  });

  final String text;
  final Set<TripStatus> statuses;
  final Set<int> participantIds;
  final DateTime? from;
  final DateTime? to;
  final TripSort sort;

  /// Number of active filter facets (search and sort excluded) — drives the
  /// badge on the filter button.
  int get activeFilterCount {
    var count = 0;
    if (statuses.isNotEmpty) count++;
    if (participantIds.isNotEmpty) count++;
    if (from != null || to != null) count++;
    return count;
  }

  bool get hasActiveFilters => activeFilterCount > 0;

  TripQuery copyWith({
    String? text,
    Set<TripStatus>? statuses,
    Set<int>? participantIds,
    DateTime? from,
    DateTime? to,
    TripSort? sort,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return TripQuery(
      text: text ?? this.text,
      statuses: statuses ?? this.statuses,
      participantIds: participantIds ?? this.participantIds,
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      sort: sort ?? this.sort,
    );
  }

  /// Same as this query but with every filter facet cleared, preserving the
  /// current [text] and [sort].
  TripQuery clearedFilters() => TripQuery(text: text, sort: sort);
}

bool _matchesText(Trip trip, String needle) {
  return trip.title.toLowerCase().contains(needle) ||
      trip.destination.toLowerCase().contains(needle) ||
      (trip.notes?.toLowerCase().contains(needle) ?? false);
}

/// Whether the trip's date span overlaps the closed range [from, to] (either
/// bound optional). Undated trips never match a date-range filter.
bool _matchesDateRange(Trip trip, DateTime? from, DateTime? to) {
  if (from == null && to == null) return true;
  final start = trip.startDate;
  if (start == null) return false;
  final s = normalizeDay(start);
  final e = normalizeDay(trip.endDate ?? start);
  if (from != null && e.isBefore(normalizeDay(from))) return false;
  if (to != null && s.isAfter(normalizeDay(to))) return false;
  return true;
}

int _compare(
  Trip a,
  Trip b,
  TripSort sort,
  Map<int, Map<Currency, int>> totalsByTrip,
) {
  switch (sort) {
    case TripSort.dateAsc:
    case TripSort.dateDesc:
      final sa = a.startDate;
      final sb = b.startDate;
      // Undated trips always sort to the end, regardless of direction.
      if (sa == null && sb == null) {
        return b.createdAt.compareTo(a.createdAt);
      }
      if (sa == null) return 1;
      if (sb == null) return -1;
      final byDate = sort == TripSort.dateAsc
          ? sa.compareTo(sb)
          : sb.compareTo(sa);
      return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
    case TripSort.nameAsc:
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    case TripSort.createdDesc:
      return b.createdAt.compareTo(a.createdAt);
    case TripSort.expenseDesc:
    case TripSort.expenseAsc:
      final ka = tripExpenseKey(totalsByTrip[a.id]);
      final kb = tripExpenseKey(totalsByTrip[b.id]);
      final byExpense = sort == TripSort.expenseDesc
          ? kb.compareTo(ka)
          : ka.compareTo(kb);
      return byExpense != 0 ? byExpense : b.createdAt.compareTo(a.createdAt);
  }
}

/// Applies [query] to [trips]: filters by text/status/participants/date range,
/// then sorts. [participantsByTrip] maps a trip id to its participants' person
/// ids; a trip matches the participant filter if it includes any selected
/// person. [today] anchors status classification.
List<Trip> applyTripQuery(
  List<Trip> trips, {
  required TripQuery query,
  required Map<int, Set<int>> participantsByTrip,
  required DateTime today,
  Map<int, Map<Currency, int>> totalsByTrip = const {},
}) {
  final needle = query.text.trim().toLowerCase();
  final result = trips.where((trip) {
    if (needle.isNotEmpty && !_matchesText(trip, needle)) return false;
    if (query.statuses.isNotEmpty &&
        !query.statuses.contains(tripStatus(trip, today))) {
      return false;
    }
    if (query.participantIds.isNotEmpty) {
      final ids = participantsByTrip[trip.id] ?? const <int>{};
      if (query.participantIds.intersection(ids).isEmpty) return false;
    }
    if (!_matchesDateRange(trip, query.from, query.to)) return false;
    return true;
  }).toList();
  result.sort((a, b) => _compare(a, b, query.sort, totalsByTrip));
  return result;
}
