import 'package:drift/drift.dart';

import '../app_database.dart';
import '../item_copy.dart';
import '../tables.dart';

part 'trip_plan_dao.g.dart';

/// Where [TripPlanDao.copyPlan] put what it copied: each source item's and
/// each source group's id mapped to its copy's, for a caller that hangs more on
/// them afterwards (a routine's fare).
typedef PlanCopy = ({Map<int, int> items, Map<int, int> groups});

/// A trip's plan as a whole, copied into another trip.
///
/// One copy for every path that writes a whole plan somewhere else — a routine
/// stamped out onto real dates (`RoutineDao.materializeRoutine`) and a trip
/// duplicated onto new ones — so a column or a table added to the plan reaches
/// both at once, the way `copyItemPlan` does for a single entry.
@DriftAccessor(
  tables: [
    TripParticipants,
    TripTags,
    ItineraryItems,
    ItemGroups,
    AlternativeSets,
    Alternatives,
    Checklists,
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
  /// [dropActualTimes] clears what `copyItemPlan` otherwise carries of the day
  /// an entry was travelled on: its actual times. A copy of a trip that was
  /// already under way would else open on its new dates claiming it ran late.
  ///
  /// Not a transaction of its own: every caller writes the trip row in the same
  /// one.
  Future<PlanCopy> copyPlan(
    int fromTripId,
    int toTripId, {
    required DateTime Function(DateTime day) shift,
    bool dropActualTimes = false,
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
      if (dropActualTimes) {
        entry = entry.copyWith(
          actualStartMinutes: const Value(null),
          actualEndMinutes: const Value(null),
        );
      }
      final copy = await into(itineraryItems).insert(entry);
      itemMap[item.id] = copy;
      // The walk to the station is part of the plan, and a plan the user has
      // to redraw on every copy is missing by Thursday — the same reason the
      // checklist travels.
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
}
