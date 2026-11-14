import 'package:drift/drift.dart';

import '../../../core/format/civil_date.dart';
import '../../../features/itinerary/entry_times.dart';
import '../app_database.dart';
import '../item_copy.dart';
import '../stopovers.dart';
import '../tables.dart';

part 'trip_plan_dao.g.dart';

/// Where [TripPlanDao.copyPlan] put what it copied: each source item's and
/// each source group's id mapped to its copy's, for a caller that hangs more on
/// them afterwards (a routine's fare).
typedef PlanCopy = ({Map<int, int> items, Map<int, int> groups});

/// A trip's plan as a whole: copied into another trip, or moved to other
/// dates.
///
/// One copy for every path that writes a whole plan somewhere else: a routine
/// stamped out onto real dates (`RoutineDao.materializeRoutine`) and a trip
/// duplicated onto new ones ([duplicateTrip]). A column or a table added to the
/// plan thus reaches both at once, the way `copyItemPlan` does for a single
/// entry.
@DriftAccessor(
  tables: [
    Trips,
    TripParticipants,
    TripTags,
    ItineraryItems,
    ItemGroups,
    AlternativeSets,
    Alternatives,
    Checklists,
    CollapsedDays,
  ],
)
class TripPlanDao extends DatabaseAccessor<AppDatabase>
    with _$TripPlanDaoMixin {
  TripPlanDao(super.db);

  /// Copies [fromTripId]'s plan into the existing trip [toTripId], every day
  /// laid onto [shift] of itself.
  ///
  /// The plan is what the trip *is*: its participants and tags, its decisions
  /// with every option and which one is chosen, its groups (cloned, so the
  /// copy's bundling is its own), its entries through `copyItemPlan` and their
  /// lines through `copyItemTracks`, and its checklists through `copyChecklist`,
  /// which is where they arrive unticked. Not the trip row, which the caller
  /// writes, and not the money or the files: whether those travel is the
  /// caller's rule, not the plan's.
  ///
  /// [dropLiveTimes] clears what `copyItemPlan` otherwise carries of the day an
  /// entry was travelled on: its actual times and the delays at its stops. A
  /// copy of a trip that was already under way would else open on its new dates
  /// claiming it ran late.
  ///
  /// Not a transaction of its own: every caller writes the trip row in the same
  /// one.
  Future<PlanCopy> copyPlan(
    int fromTripId,
    int toTripId, {
    required DateTime Function(DateTime day) shift,
    bool dropLiveTimes = false,
  }) async {
    final participants = await (select(
      tripParticipants,
    )..where((tp) => tp.tripId.equals(fromTripId))).get();
    for (final participant in participants) {
      await into(tripParticipants).insert(
        TripParticipantsCompanion.insert(
          tripId: toTripId,
          personId: participant.personId,
        ),
      );
    }

    final links = await (select(
      tripTags,
    )..where((tt) => tt.tripId.equals(fromTripId))).get();
    for (final link in links) {
      await into(tripTags).insert(
        TripTagsCompanion.insert(tripId: toTripId, tagId: link.tagId),
        mode: InsertMode.insertOrIgnore,
      );
    }

    // The decisions first, so a branch item has a branch to land in. Dropping
    // one ("do I cycle or take the tram?") would quietly lose half the plan.
    final sets = await (select(
      alternativeSets,
    )..where((s) => s.tripId.equals(fromTripId))).get();
    final branchMap = <int, int>{};
    for (final set in sets) {
      final newSetId = await into(alternativeSets).insert(
        AlternativeSetsCompanion.insert(
          tripId: toTripId,
          date: shift(set.date),
          sortOrder: Value(set.sortOrder),
          label: Value(set.label),
        ),
      );
      final branches =
          await (select(alternatives)
                ..where((a) => a.setId.equals(set.id))
                ..orderBy([(a) => OrderingTerm(expression: a.sortOrder)]))
              .get();
      for (final branch in branches) {
        branchMap[branch.id] = await into(alternatives).insert(
          AlternativesCompanion.insert(
            setId: newSetId,
            label: Value(branch.label),
            sortOrder: Value(branch.sortOrder),
            chosen: Value(branch.chosen),
          ),
        );
      }
    }

    final items =
        await (select(itineraryItems)
              ..where((i) => i.tripId.equals(fromTripId))
              ..orderBy([
                (i) => OrderingTerm(expression: i.sortOrder),
                (i) => OrderingTerm(expression: i.startMinutes),
              ]))
            .get();
    // A group is part of what the plan *is* (these legs share one ticket), so
    // it is cloned rather than shared: the copy's bundling is its own.
    final groupMap = <int, int>{};
    final itemMap = <int, int>{};
    for (final item in items) {
      int? newGroupId;
      final sourceGroup = item.groupId;
      if (sourceGroup != null) {
        newGroupId = groupMap[sourceGroup];
        if (newGroupId == null) {
          final group = await (select(
            itemGroups,
          )..where((g) => g.id.equals(sourceGroup))).getSingle();
          newGroupId = await into(itemGroups).insert(
            ItemGroupsCompanion.insert(
              tripId: toTripId,
              label: Value(group.label),
            ),
          );
          groupMap[sourceGroup] = newGroupId;
        }
      }
      var entry = copyItemPlan(
        item,
        date: shift(item.date),
        alternativeId: item.alternativeId == null
            ? null
            : branchMap[item.alternativeId],
        groupId: newGroupId,
        sortOrder: item.sortOrder,
      ).copyWith(tripId: Value(toTripId));
      if (dropLiveTimes) {
        entry = entry.copyWith(
          actualStartMinutes: const Value(null),
          actualEndMinutes: const Value(null),
          stopovers: Value(stopoversWithoutLive(item.stopovers)),
          runStops: Value(runStopsWithoutLive(item.runStops)),
        );
      }
      final copy = await into(itineraryItems).insert(entry);
      itemMap[item.id] = copy;
      // The walk to the station is part of the plan, and a plan the user has
      // to redraw on every copy is missing by Thursday. The checklist travels
      // for the same reason.
      await attachedDatabase.trackDao.copyItemTracks(item.id, copy);
    }

    // In the order the source keeps them, so the copy reads the same way. The
    // copy arrives unticked; `copyChecklist` is where that rule lives.
    final lists =
        await (select(checklists)
              ..where((c) => c.tripId.equals(fromTripId))
              ..orderBy([
                (c) => OrderingTerm(expression: c.sortOrder),
                (c) => OrderingTerm(expression: c.createdAt),
              ]))
            .get();
    for (final list in lists) {
      await attachedDatabase.checklistDao.copyChecklist(list.id, toTripId);
    }

    return (items: itemMap, groups: groupMap);
  }

  /// The days [tripId]'s plan occupies, first and last, or null for a trip with
  /// neither dates nor entries.
  ///
  /// A trip's own range when it has one: that is what the user set and what
  /// the overview shows, including a free day at either end. A trip without
  /// dates is read off its entries instead (the days they start on, the days
  /// an overnight one ends on, and the days its decisions sit on), which is
  /// what its timeline draws.
  Future<({DateTime start, DateTime end})?> planRange(int tripId) async {
    final trip = await (select(
      trips,
    )..where((t) => t.id.equals(tripId))).getSingle();
    final start = trip.startDate;
    if (start != null) {
      return (
        start: normalizeDay(start),
        end: normalizeDay(trip.endDate ?? start),
      );
    }
    final itemRows = await (select(
      itineraryItems,
    )..where((i) => i.tripId.equals(tripId))).get();
    final setRows = await (select(
      alternativeSets,
    )..where((s) => s.tripId.equals(tripId))).get();
    final days = [
      for (final i in itemRows) ...daysCovered(i.date, i.endDayOffset),
      for (final s in setRows) s.date,
    ].map(normalizeDay).toList()..sort();
    if (days.isEmpty) return null;
    return (start: days.first, end: days.last);
  }

  /// Writes a copy of [tripId] as a new trip called [title] that begins on
  /// [startDate], and returns its id.
  ///
  /// Every day moves by the same number of calendar days, the distance from
  /// the old start to the new one ([planRange]), so the copy keeps the shape of
  /// the original: a free day in the middle stays free, and the range keeps its
  /// length. (A routine is read by *rank* instead and closes such a gap, see
  /// `RoutineDao.routineDays`; a trip has real dates, and they say where the
  /// gaps are.)
  ///
  /// The copy takes the **plan, not the money** (see `copyItemPlan`): a trip's
  /// costs record payments made for *that* trip, and copying them would invent
  /// spending, payers and debts on dates nobody has booked yet. Nor do its
  /// files travel, which are bookings and photographs of the original, nor
  /// anything of the day an entry was actually travelled on ([copyPlan]'s
  /// `dropLiveTimes`). Nor does `fromRoutineId`: the copy was made from a trip,
  /// and only an occurrence the routine itself produced is asked about before
  /// being recorded twice on a day.
  ///
  /// The journeys come across as a plan, exactly as from a routine: making
  /// them real connections on the new dates is `TripConnectionsController`'s
  /// job, after this returns.
  Future<int> duplicateTrip(
    int tripId, {
    required String title,
    required DateTime startDate,
  }) {
    return transaction(() async {
      final source = await (select(
        trips,
      )..where((t) => t.id.equals(tripId))).getSingle();
      if (source.kind != TripKind.trip) {
        throw ArgumentError('Trip $tripId is a routine, not a trip.');
      }
      final start = normalizeDay(startDate);
      final range = await planRange(tripId);
      final days = range == null ? 0 : daysBetween(range.start, start);
      DateTime shift(DateTime day) => addDays(day, days);

      final newTripId = await into(trips).insert(
        TripsCompanion.insert(
          title: title,
          destination: Value(source.destination),
          startDate: Value(start),
          endDate: Value(range == null ? start : shift(range.end)),
          notes: Value(source.notes),
          colorValue: Value(source.colorValue),
        ),
      );
      await copyPlan(tripId, newTripId, shift: shift, dropLiveTimes: true);
      return newTripId;
    });
  }

  /// What the question before moving [tripId] needs to know: whether it has
  /// anything to move, and whether moving it would clear actual times that
  /// were recorded on the old dates.
  Future<({bool hasEntries, bool hasActualTimes})> moveFacts(int tripId) async {
    final itemRows = await (select(
      itineraryItems,
    )..where((i) => i.tripId.equals(tripId))).get();
    final hasSets =
        await (select(alternativeSets)
              ..where((s) => s.tripId.equals(tripId))
              ..limit(1))
            .getSingleOrNull() !=
        null;
    return (
      hasEntries: itemRows.isNotEmpty || hasSets,
      hasActualTimes: itemRows.any(
        (i) => i.actualStartMinutes != null || i.actualEndMinutes != null,
      ),
    );
  }

  /// Writes [trip] and moves every entry of it by [days] calendar days, in one
  /// transaction: what the trip form does when its start date changes and the
  /// user asks for the entries to come along.
  ///
  /// In place, unlike [duplicateTrip]: the trip stays the one trip, with its
  /// costs, ticks, files, groups and decisions. What moves is every date the
  /// plan has: the entries, the decisions, and which days are collapsed. Each by
  /// [addDays], so a daylight-saving change in between costs no day.
  ///
  /// What the entries knew of the **old** days is cleared, for the reason
  /// [duplicateTrip] leaves it behind: `sourceTripId` names one dated run, and
  /// a live refresh would read that run's times onto a day it does not run on;
  /// the actual times and the delays at the stops describe how the old day
  /// went. The planned times, the places and the router's place ids stay, so
  /// the journeys can be looked up again for the new dates.
  ///
  /// The trip's range is [trip]'s, as written: an entry may end up outside it
  /// when the length was changed in the same edit, and the timeline still
  /// draws it.
  Future<void> moveTrip(Trip trip, {required int days}) {
    return transaction(() async {
      if (days != 0) {
        final items = await (select(
          itineraryItems,
        )..where((i) => i.tripId.equals(trip.id))).get();
        for (final item in items) {
          await (update(
            itineraryItems,
          )..where((i) => i.id.equals(item.id))).write(
            ItineraryItemsCompanion(
              date: Value(addDays(item.date, days)),
              sourceTripId: const Value(null),
              actualStartMinutes: const Value(null),
              actualEndMinutes: const Value(null),
              stopovers: Value(stopoversWithoutLive(item.stopovers)),
              runStops: Value(runStopsWithoutLive(item.runStops)),
            ),
          );
        }
        final sets = await (select(
          alternativeSets,
        )..where((s) => s.tripId.equals(trip.id))).get();
        for (final set in sets) {
          await (update(
            alternativeSets,
          )..where((s) => s.id.equals(set.id))).write(
            AlternativeSetsCompanion(date: Value(addDays(set.date, days))),
          );
        }
        // Keyed by (trip, day), so moving the rows one by one could collide
        // with a day not yet moved. Taken out and put back instead.
        final collapsed = await (select(
          collapsedDays,
        )..where((c) => c.tripId.equals(trip.id))).get();
        await (delete(
          collapsedDays,
        )..where((c) => c.tripId.equals(trip.id))).go();
        for (final row in collapsed) {
          await into(collapsedDays).insert(
            CollapsedDaysCompanion.insert(
              tripId: trip.id,
              day: addDays(row.day, days),
            ),
          );
        }
      }
      await update(trips).replace(trip);
    });
  }
}
