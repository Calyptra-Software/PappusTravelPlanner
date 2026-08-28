import '../../data/database/app_database.dart';
import '../../data/database/tables.dart';
import 'trip_filter.dart';

/// Ordering options for the routine list.
///
/// Deliberately shorter than [TripSort]: a routine has no dates, so every
/// date-ordered reading of it would be an ordering by nothing — and its costs
/// are *prices* rather than payments (they count toward no total, see
/// `allTripsStatsProvider`), so "most expensive first" would rank templates by
/// a number the app is careful never to add up. What is left is the two
/// questions a shelf of templates actually raises: what is it called, and which
/// did I make last. Persisted by index like every other stored enum here —
/// append only, never reorder.
enum RoutineSort { nameAsc, createdDesc }

/// The routine list's controls: free-text search, filters and sort.
///
/// The sibling of [TripQuery], and deliberately not that type: a routine has
/// no dates and is never stamped out of a routine, so [TripQuery]'s statuses,
/// date range and `routineIds` could only be dead controls here. What the two
/// share — the words a row is searched by, and the any-of reading of tags and
/// participants — is shared as code ([tripMatchesText]) rather than by widening
/// one type over both.
///
/// Empty [tagIds] / [participantIds] mean "no restriction". Pure and
/// value-equatable so it can drive `setState` and be unit-tested without a DB.
class RoutineQuery {
  const RoutineQuery({
    this.text = '',
    this.tagIds = const {},
    this.participantIds = const {},
    this.sort = RoutineSort.nameAsc,
  });

  final String text;

  /// The tags to narrow to, matched **any-of**, exactly as [TripQuery.tagIds]
  /// is. A routine carries tags for the same reason a trip does — they travel
  /// to every trip stamped out of it — so the roster that files the trips files
  /// the templates too.
  final Set<int> tagIds;

  /// The participants to narrow to, matched **any-of**.
  final Set<int> participantIds;

  final RoutineSort sort;

  /// Number of active filter facets (search and sort excluded) — drives the
  /// badge on the filter button.
  int get activeFilterCount {
    var count = 0;
    if (tagIds.isNotEmpty) count++;
    if (participantIds.isNotEmpty) count++;
    return count;
  }

  bool get hasActiveFilters => activeFilterCount > 0;

  RoutineQuery copyWith({
    String? text,
    Set<int>? tagIds,
    Set<int>? participantIds,
    RoutineSort? sort,
  }) {
    return RoutineQuery(
      text: text ?? this.text,
      tagIds: tagIds ?? this.tagIds,
      participantIds: participantIds ?? this.participantIds,
      sort: sort ?? this.sort,
    );
  }

  /// Same as this query but with every filter facet cleared, preserving the
  /// current [text] and [sort].
  RoutineQuery clearedFilters() => RoutineQuery(text: text, sort: sort);
}

int _compare(Trip a, Trip b, RoutineSort sort) {
  switch (sort) {
    case RoutineSort.nameAsc:
      final byName = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      return byName != 0 ? byName : b.createdAt.compareTo(a.createdAt);
    case RoutineSort.createdDesc:
      return b.createdAt.compareTo(a.createdAt);
  }
}

/// Applies [query] to [routines]: filters by text/tags/participants, then
/// sorts.
///
/// **Only routines are in the result**, the mirror of [applyTripQuery] dropping
/// them: the two lists are the two halves of one table, and each says so here
/// rather than trusting whichever query fed it.
///
/// [tagsByTrip] and [participantsByTrip] map a row id to its tag ids and its
/// participants' person ids; a routine matches either filter if it holds **any**
/// of the selected ids, the same reading the overview gives them.
List<Trip> applyRoutineQuery(
  List<Trip> routines, {
  required RoutineQuery query,
  Map<int, Set<int>> tagsByTrip = const {},
  Map<int, Set<int>> participantsByTrip = const {},
}) {
  final needle = query.text.trim().toLowerCase();
  final result = routines.where((routine) {
    if (routine.kind != TripKind.routine) return false;
    if (needle.isNotEmpty && !tripMatchesText(routine, needle)) return false;
    if (query.tagIds.isNotEmpty) {
      final ids = tagsByTrip[routine.id] ?? const <int>{};
      if (query.tagIds.intersection(ids).isEmpty) return false;
    }
    if (query.participantIds.isNotEmpty) {
      final ids = participantsByTrip[routine.id] ?? const <int>{};
      if (query.participantIds.intersection(ids).isEmpty) return false;
    }
    return true;
  }).toList();
  result.sort((a, b) => _compare(a, b, query.sort));
  return result;
}
