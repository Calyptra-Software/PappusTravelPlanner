import 'dart:collection';

import '../../core/format/civil_date.dart';
import '../../data/database/app_database.dart';
import '../../data/database/tables.dart';

/// Everything about a trip's [TripKind] that is decidable without a database.
/// Pure, so it unit-tests without one.
///
/// There is deliberately very little here. A trip's *scale* is not a kind — a
/// walk is a trip whose start and end are the same day, and the dates say so
/// already — and how a trip is filed is a matter for [Tags], which the user
/// controls. What is left is the one thing the dates cannot say: whether a plan
/// is a trip or the template for one.

/// The kind named by [name] (an enum value's `name`, as it travels in the
/// `/new?kind=` link), falling back to [TripKind.trip] for null or anything
/// unrecognized — a stale or hand-typed link opens the ordinary form rather
/// than failing.
TripKind tripKindFromName(String? name) => TripKind.values.firstWhere(
  (k) => k.name == name,
  orElse: () => TripKind.trip,
);

/// Day one of [trip]'s plan, when it has no dates to give one.
///
/// A routine's entries are laid out from [kRoutineAnchorDay]; a trip's from its
/// own start date, or from nothing at all when it is still undated. The
/// timeline uses this only to decide which day an entry added to an *empty*
/// plan lands on — for a routine that must be the anchor, never today, or the
/// plan would scatter across whichever days it was written on.
DateTime? planAnchorDay(Trip trip) => switch (trip.kind) {
  TripKind.routine => kRoutineAnchorDay,
  TripKind.trip =>
    trip.startDate == null ? null : normalizeDay(trip.startDate!),
};

/// The distinct days a routine's plan occupies, in order — the days its
/// timeline shows.
///
/// The Dart mirror of `RoutineDao.routineDays`, and the same rule: a routine's
/// days are the days its entries sit on, read as *ranks* rather than as offsets
/// from the anchor. Kept here as well so the header can follow the plan as it
/// is edited — a day added to a routine must show up in its length at once, not
/// on the next visit — without a round trip per keystroke.
List<DateTime> routineDaysOf(
  Iterable<ItineraryItem> items,
  Iterable<AlternativeSet> sets,
) {
  final days = SplayTreeSet<DateTime>();
  for (final date in [
    for (final i in items) i.date,
    for (final s in sets) s.date,
  ]) {
    days.add(normalizeDay(date));
  }
  return days.toList();
}

/// How many days a routine's plan covers — at least one, since a routine with
/// nothing in it is still a plan for a day.
int routineDayCountOf(
  Iterable<ItineraryItem> items,
  Iterable<AlternativeSet> sets,
) {
  final days = routineDaysOf(items, sets);
  return days.isEmpty ? 1 : days.length;
}

/// Which day of a routine [date] is: 0 for day one, 1 for the next, and so on.
///
/// Counted in whole calendar days from [kRoutineAnchorDay], so a routine that
/// spans a daylight-saving boundary in some year the plan is stamped onto still
/// keeps its shape.
int routineDayOffset(DateTime date) => daysBetween(kRoutineAnchorDay, date);

/// The day `routineDayOffset(date)` maps to when a routine is stamped out
/// starting on [startDate].
DateTime routineDayOn(DateTime startDate, DateTime date) =>
    addDays(normalizeDay(startDate), routineDayOffset(date));
