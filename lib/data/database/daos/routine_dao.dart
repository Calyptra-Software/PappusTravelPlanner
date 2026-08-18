import 'dart:collection';

import 'package:drift/drift.dart';

import '../../../core/format/civil_date.dart';
import '../app_database.dart';
import '../item_copy.dart';
import '../tables.dart';

part 'routine_dao.g.dart';

/// Turning a [TripKind.routine] into a trip that actually happened.
///
/// A routine's occurrences are **virtual**: the app writes nothing for a day
/// that simply went as the routine says, because such a day records nothing the
/// routine does not already say — and materializing every one would put a few
/// hundred identical rows a year in front of the trips the user came for. What
/// the user *asks for* is materialized here, once, as an ordinary [TripKind.trip]
/// on real dates, which can then be edited, delayed and priced without
/// disturbing the template.
@DriftAccessor(
  tables: [
    Trips,
    TripParticipants,
    TripTags,
    ItineraryItems,
    ItemGroups,
    AlternativeSets,
    Alternatives,
    Costs,
    CostBeneficiaries,
    Checklists,
  ],
)
class RoutineDao extends DatabaseAccessor<AppDatabase> with _$RoutineDaoMixin {
  RoutineDao(super.db);

  /// Swaps the legs of one journey for freshly-searched ones, keeping the
  /// bundle they travel in.
  ///
  /// Used when a plan copied from a routine is looked up again for the dates it
  /// was stamped onto: the copied legs describe the right journey on the wrong
  /// day, and the search returns the right one. The **group survives** rather
  /// than being deleted and remade, for one reason — a group's cost is the
  /// shared ticket, and it hangs off the group. Re-making the bundle would take
  /// the fare with it.
  ///
  /// A cost attached to one of the *legs* is rescued rather than cascaded away:
  /// a single-leg journey has no group to hang its fare on, so letting the leg
  /// take it would mean the price of the ride disappeared the moment its
  /// connection was looked up. It lands on the group, or on the first leg of the
  /// replacement when there is none.
  ///
  /// **Each day of the replacement is one bundle**, exactly as importing a
  /// connection bundles one (`TripRepository.insertJourney`): a group means "these
  /// legs share a ticket", and a ticket is not shared across a night. So a run of
  /// two or more legs that arrives where there was no group — a lone leg the
  /// timetable now routes with a change, or a hand-entered one made real — is
  /// given one rather than left as loose legs with nothing to hang a fare on; and
  /// a replacement that crosses midnight where the old run did not keeps
  /// [groupId] for its first day and opens a fresh bundle for the next, rather
  /// than stretching one group across two days (which `GroupDao.groupItems`
  /// refuses to build in the first place).
  ///
  /// The trip's own dates are widened to cover what was written, for the same
  /// reason: a leg on a day the trip does not admit to shows in the timeline (its
  /// days are the union of the range and the entries) while the overview card goes
  /// on calling it a one-day trip.
  ///
  /// The **map color** survives too, when the old run wore one and wore it
  /// throughout. It belongs to the slot rather than to the run filling it — the
  /// same reason the group and its ticket are kept — and it is the one thing here
  /// a user chose by hand: a commute drawn in green stays green when this
  /// morning's connection is looked up, where otherwise it would quietly revert
  /// every time. A run whose legs disagreed has no one color to carry, so the
  /// replacement takes none rather than picking a leg's and calling it the run's.
  /// The recorded **line** deliberately does not travel the same way
  /// (`copyItemTracks` is not called here): a color says how to draw this
  /// stretch of the plan, while a track claims a particular route was followed,
  /// and that claim is about the run being replaced. The replacement's *own*
  /// routed shape is a different matter and is written — by
  /// `TripRepository.replaceJourneyLegs`, which owns that step for the import
  /// too, since decoding a polyline is no business of this table.
  ///
  /// [oldLegIds] are removed and [legs] inserted in their place, into
  /// [groupId] when there is one. Returns the new leg ids **in [legs] order**,
  /// not in the order the days were written, so a caller can line per-leg data
  /// up against them.
  Future<List<int>> replaceJourneyLegs(
    int tripId, {
    required List<int> oldLegIds,
    required List<ItineraryItemsCompanion> legs,
    int? groupId,
  }) {
    return transaction(() async {
      final oldLegs = await (select(
        itineraryItems,
      )..where((i) => i.id.isIn(oldLegIds))).get();
      // The slot the run occupied on each of its days: where it began, where it
      // ended, and how many entries wide it was. The replacement goes back into
      // that slot rather than onto the end of the day — appending would put a
      // stop added *after* the journey in front of it.
      final slots = <DateTime, ({int base, int last, int count})>{};
      for (final leg in oldLegs) {
        final day = DateTime(leg.date.year, leg.date.month, leg.date.day);
        final slot = slots[day];
        slots[day] = slot == null
            ? (base: leg.sortOrder, last: leg.sortOrder, count: 1)
            : (
                base: leg.sortOrder < slot.base ? leg.sortOrder : slot.base,
                last: leg.sortOrder > slot.last ? leg.sortOrder : slot.last,
                count: slot.count + 1,
              );
      }
      // A run lies entirely inside one option or entirely outside every one, so
      // any member answers for where the whole thing is ordered.
      final branchId = oldLegs.isEmpty ? null : oldLegs.first.alternativeId;

      // The color the old run wore, if it wore one throughout — see above.
      final colors = oldLegs.map((l) => l.colorValue).toSet();
      final keptColor = colors.length == 1 ? colors.first : null;

      // Taken off the doomed legs before they go, so the cascade cannot take
      // the fare with them. Parked on the trip for the moment; re-homed on the
      // replacement below.
      final rescued = await (select(
        costs,
      )..where((c) => c.itemId.isIn(oldLegIds))).get();
      if (rescued.isNotEmpty) {
        await (update(costs)..where((c) => c.itemId.isIn(oldLegIds))).write(
          CostsCompanion(itemId: const Value(null), tripId: Value(tripId)),
        );
      }

      for (final id in oldLegIds) {
        // Straight through the table, not GroupDao.deleteItem: that tidies away
        // a group left with fewer than two members, which is exactly the group
        // being kept here to hold on to its ticket.
        await (delete(itineraryItems)..where((i) => i.id.equals(id))).go();
      }

      // Each leg keeps the index it arrived at, so the ids can be returned in
      // **input** order however the days are walked. The caller lines its own
      // per-leg data up against them — the routed shapes an import writes as
      // tracks — and a run whose days were visited in another order would then
      // draw each leg along its neighbour's route.
      final byDay = <DateTime, List<(int, ItineraryItemsCompanion)>>{};
      for (final (index, leg) in legs.indexed) {
        final date = leg.date.value;
        byDay
            .putIfAbsent(DateTime(date.year, date.month, date.day), () => [])
            .add((index, leg));
      }

      final ids = List<int>.filled(legs.length, 0);
      // The bundle each day's legs end up in: the surviving [groupId] for the
      // first day written, a fresh one for any further day, and — where there was
      // no group at all — one opened for a day that now holds a run rather than a
      // single leg. Null stays null for a day of one leg with no group to join.
      final groupByDay = <DateTime, int?>{};
      for (final entry in byDay.entries) {
        final day = entry.key;
        final slot = slots[day];
        // A day the old run did not touch (a re-searched journey may cross
        // midnight where the old one did not) simply appends.
        final base =
            slot?.base ??
            await attachedDatabase.itineraryDao.nextSortOrder(tripId, day);

        // Deleting the old run leaves a hole its own width. Only a longer
        // replacement needs more room than that, and then everything that
        // followed the run moves down by the difference.
        final grew = entry.value.length - (slot?.count ?? 0);
        if (slot != null && grew > 0) {
          await _shiftAfter(
            tripId,
            day: day,
            after: slot.last,
            by: grew,
            branchId: branchId,
          );
        }

        final dayIds = <int>[];
        for (final (i, (index, leg)) in entry.value.indexed) {
          final id = await into(itineraryItems).insert(
            leg.copyWith(
              sortOrder: Value(base + i),
              alternativeId: Value(branchId),
              colorValue: Value(keptColor),
            ),
          );
          dayIds.add(id);
          ids[index] = id;
        }

        // This day's bundle. The surviving group takes the first day written and
        // no other: a ticket does not span a night. A day that came without one
        // gets its own as soon as it holds more than a single leg — the run needs
        // something to hang its fare on, and the journey sheet reads a group.
        final reuseSurvivor = groupId != null && groupByDay.isEmpty;
        final dayGroup = reuseSurvivor
            ? groupId
            : dayIds.length > 1
            ? await into(
                itemGroups,
              ).insert(ItemGroupsCompanion.insert(tripId: tripId))
            : null;
        groupByDay[day] = dayGroup;
        if (dayGroup != null) {
          await (update(itineraryItems)..where((i) => i.id.isIn(dayIds))).write(
            ItineraryItemsCompanion(groupId: Value(dayGroup)),
          );
        }
      }

      // A leg written onto a day the trip does not cover — a replacement that
      // crosses midnight where the old run did not — widens the trip rather than
      // sitting outside it.
      await attachedDatabase.tripDao.widenToCover(tripId, byDay.keys);

      // The rescued fares find their home on the replacement: its bundle when it
      // has one, its first leg otherwise. A replacement with no legs at all leaves
      // them on the trip, where they are at least still counted.
      final home = groupByDay.values.firstWhere(
        (id) => id != null,
        orElse: () => null,
      );
      if (rescued.isNotEmpty && (home != null || ids.isNotEmpty)) {
        for (final cost in rescued) {
          await (update(costs)..where((c) => c.id.equals(cost.id))).write(
            CostsCompanion(
              tripId: const Value(null),
              groupId: Value(home),
              itemId: Value(home == null ? ids.first : null),
            ),
          );
        }
      }
      return ids;
    });
  }

  /// Copies a routine's costs onto the trip stamped out of it.
  ///
  /// A routine's cost is the **fare**, not a record of a payment: it says what
  /// this ride costs, which is the only reason to put one on a template at all.
  /// So — unlike every other copy in this app, which takes the plan and not the
  /// money — these travel. What does not travel is the claim that they were
  /// *settled*: a copied cost arrives **unpaid**, exactly as a copied checklist
  /// arrives unticked, because paying is something an occurrence does.
  ///
  /// A settlement is left behind entirely. It records money handed from one
  /// person to another to square a particular trip up; there is no sense in
  /// which a template can be owed.
  Future<void> _copyCosts(
    int routineId,
    int newTripId, {
    required Map<int, int> itemMap,
    required Map<int, int> groupMap,
  }) async {
    final rows =
        await (select(costs)..where(
              (c) =>
                  c.isTransfer.equals(false) &
                  (c.tripId.equals(routineId) |
                      c.itemId.isIn(itemMap.keys.toList()) |
                      c.groupId.isIn(groupMap.keys.toList())),
            ))
            .get();

    for (final cost in rows) {
      final newId = await into(costs).insert(
        CostsCompanion.insert(
          // Attached exactly as it was, to the copy of whatever it was on.
          itemId: Value(cost.itemId == null ? null : itemMap[cost.itemId]),
          groupId: Value(cost.groupId == null ? null : groupMap[cost.groupId]),
          tripId: Value(cost.tripId == null ? null : newTripId),
          amountMinor: cost.amountMinor,
          currency: cost.currency,
          reason: cost.reason,
          paidBy: Value(cost.paidBy),
        ),
      );
      // Who it was for travels with it: the split is part of what the fare *is*
      // when more than one person rides.
      final beneficiaries = await (select(
        costBeneficiaries,
      )..where((b) => b.costId.equals(cost.id))).get();
      for (final person in beneficiaries) {
        await into(costBeneficiaries).insert(
          CostBeneficiariesCompanion.insert(
            costId: newId,
            personId: person.personId,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    }
  }

  /// Moves everything on [day] ordered after [after] down by [by] slots, to make
  /// room for a replacement run that is wider than the one it replaces.
  ///
  /// A day's loose items and its decisions share one ordering space — a whole
  /// decision is a single block in the timeline — so both are moved. Inside an
  /// option there are no decisions to move: a set never nests in a branch.
  Future<void> _shiftAfter(
    int tripId, {
    required DateTime day,
    required int after,
    required int by,
    required int? branchId,
  }) async {
    final followers =
        await (select(itineraryItems)..where(
              (i) =>
                  i.tripId.equals(tripId) &
                  i.date.equals(day) &
                  i.sortOrder.isBiggerThanValue(after) &
                  (branchId == null
                      ? i.alternativeId.isNull()
                      : i.alternativeId.equals(branchId)),
            ))
            .get();
    for (final item in followers) {
      await (update(itineraryItems)..where((i) => i.id.equals(item.id))).write(
        ItineraryItemsCompanion(sortOrder: Value(item.sortOrder + by)),
      );
    }
    if (branchId != null) return;
    final sets =
        await (select(alternativeSets)..where(
              (s) =>
                  s.tripId.equals(tripId) &
                  s.date.equals(day) &
                  s.sortOrder.isBiggerThanValue(after),
            ))
            .get();
    for (final set in sets) {
      await (update(alternativeSets)..where((s) => s.id.equals(set.id))).write(
        AlternativeSetsCompanion(sortOrder: Value(set.sortOrder + by)),
      );
    }
  }

  /// Every routine, most recently created first — the routine list, and the
  /// "from routine…" picker.
  Stream<List<Trip>> watchRoutines() {
    return (select(trips)
          ..where((t) => t.kind.equalsValue(TripKind.routine))
          ..orderBy([(t) => OrderingTerm(expression: t.title)]))
        .watch();
  }

  /// The trips already stamped out of [routineId] that begin on [day].
  ///
  /// Only used to *ask* before recording the same routine twice on one day —
  /// which is easy to do when the point of the feature is recording a commute
  /// twice a day. It is a question, never a refusal: two trips from one routine
  /// on one day is unusual, not wrong.
  Future<List<Trip>> tripsFromRoutineOn(int routineId, DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return (select(trips)..where(
          (t) => t.fromRoutineId.equals(routineId) & t.startDate.equals(date),
        ))
        .get();
  }

  /// The distinct days [routineId]'s entries occupy, in order.
  ///
  /// A routine's days are exactly the days it *shows*: the timeline collects a
  /// dateless plan's days from its entries, so day one is the earliest day any
  /// entry sits on, day two the next, and so on. The absolute dates are only a
  /// sort origin — [kRoutineAnchorDay] is where a plan built inside the app
  /// starts, but a plan may also have picked up real dates (a connection
  /// imported for a real timetable), and reading the *rank* rather than the
  /// offset means the plan's shape is the same either way. Reading the offset
  /// is what once turned a one-day commute into a trip ending in 2083.
  ///
  /// A day with no entries is not a day of the plan: nothing shows it, so
  /// nothing can be added to it, so a gap in the dates closes up.
  Future<List<DateTime>> routineDays(int routineId) async {
    final itemRows = await (select(
      itineraryItems,
    )..where((i) => i.tripId.equals(routineId))).get();
    final setRows = await (select(
      alternativeSets,
    )..where((s) => s.tripId.equals(routineId))).get();
    final days = SplayTreeSet<DateTime>();
    for (final day in [
      for (final i in itemRows) i.date,
      for (final s in setRows) s.date,
    ]) {
      days.add(DateTime(day.year, day.month, day.day));
    }
    return days.toList();
  }

  /// How many days [routineId]'s plan covers — at least one, even when it holds
  /// nothing yet, since a routine with no entries is still a plan for a day.
  Future<int> routineDaySpan(int routineId) async {
    final days = await routineDays(routineId);
    return days.isEmpty ? 1 : days.length;
  }

  /// Writes [routineId]'s plan into a fresh [TripKind.trip] beginning on
  /// [startDate], and returns its trip id.
  ///
  /// Any date, not only today: a work day is often planned the evening before,
  /// and a day that was travelled but not recorded is worth adding afterwards.
  /// A routine that spans several days lands on as many, day *n* of the plan on
  /// [startDate] plus *n* — which is exactly how the routine stores it, as an
  /// offset from [kRoutineAnchorDay], so the shape of the plan comes through
  /// without anything having to be recomputed.
  ///
  /// The copy takes the **plan, not the money** — the same rule that governs
  /// duplicating an item, a group or an option. A cost records a payment that
  /// happened once; a routine's monthly ticket is not re-spent every morning,
  /// and copying it would invent that money inside every settle-up. What the
  /// occurrence costs is recorded on the occurrence, if it cost anything.
  ///
  /// Participants *do* travel: they say who the trip is with, not what was
  /// spent, so a shared commute stays shared. So do the routine's **tags** —
  /// filing is the whole reason the overview stays navigable once a commute is
  /// recorded twice a day, and a tag the user would have to add by hand every
  /// morning is a tag that will be missing by Thursday.
  ///
  /// And so do its **checklists**, for that same reason and by that same rule as
  /// everywhere else: a copy arrives **unticked** (`ChecklistDao.copyChecklist`).
  /// A routine's list is what to take *every time* — the badge, the laptop, the
  /// season ticket — which is a template exactly as its legs are; one the user had
  /// to copy across by hand each morning would be a list they stopped keeping. The
  /// ticks belong to the occurrence, like the fare's being paid.
  ///
  /// What this does *not* do is make the journeys live: an imported leg's
  /// `sourceTripId` names one dated run of one service, so it is deliberately
  /// left behind (see `copyItemPlan`) and the copy is a plan. Turning that plan
  /// into a real, refreshable connection for these dates means searching again,
  /// which needs the network and the user's eye — `RoutineController` does it
  /// after this returns.
  Future<int> materializeRoutine(int routineId, {required DateTime startDate}) {
    return transaction(() async {
      final routine = await (select(
        trips,
      )..where((t) => t.id.equals(routineId))).getSingle();
      if (routine.kind != TripKind.routine) {
        throw ArgumentError('Trip $routineId is not a routine.');
      }
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      // Day n of the routine lands on day n of the trip, counted by the *rank*
      // of the days its entries occupy rather than by their distance from the
      // anchor — see [routineDays]. Both ends are civil dates, so the target is
      // reached by adding whole calendar days: a Duration would be short an
      // hour across a spring-forward and silently pull a day back.
      final days = await routineDays(routineId);
      final span = days.isEmpty ? 1 : days.length;
      DateTime shift(DateTime routineDay) => addDays(
        start,
        days.indexOf(
          DateTime(routineDay.year, routineDay.month, routineDay.day),
        ),
      );

      final newTripId = await into(trips).insert(
        TripsCompanion.insert(
          title: routine.title,
          destination: Value(routine.destination),
          startDate: Value(start),
          // A one-day routine gives a trip whose ends are the same day, which
          // is all "one day" has ever meant here.
          endDate: Value(addDays(start, span - 1)),
          notes: Value(routine.notes),
          kind: const Value(TripKind.trip),
          fromRoutineId: Value(routineId),
          colorValue: Value(routine.colorValue),
        ),
      );

      final participants = await (select(
        tripParticipants,
      )..where((tp) => tp.tripId.equals(routineId))).get();
      for (final participant in participants) {
        await into(tripParticipants).insert(
          TripParticipantsCompanion.insert(
            tripId: newTripId,
            personId: participant.personId,
          ),
        );
      }

      final routineTags = await (select(
        tripTags,
      )..where((tt) => tt.tripId.equals(routineId))).get();
      for (final link in routineTags) {
        await into(tripTags).insert(
          TripTagsCompanion.insert(tripId: newTripId, tagId: link.tagId),
          mode: InsertMode.insertOrIgnore,
        );
      }

      // The routine's decisions first, so a branch item has a branch to land
      // in. A routine may hold one ("do I cycle or take the tram?"), and
      // dropping it would quietly lose half the plan.
      final sets = await (select(
        alternativeSets,
      )..where((s) => s.tripId.equals(routineId))).get();
      final branchMap = <int, int>{};
      for (final set in sets) {
        final newSetId = await into(alternativeSets).insert(
          AlternativeSetsCompanion.insert(
            tripId: newTripId,
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
                ..where((i) => i.tripId.equals(routineId))
                ..orderBy([
                  (i) => OrderingTerm(expression: i.sortOrder),
                  (i) => OrderingTerm(expression: i.startMinutes),
                ]))
              .get();
      // A group is part of what the plan *is* (these legs share one ticket), so
      // it is cloned rather than shared: the occurrence's bundling is its own.
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
                tripId: newTripId,
                label: Value(group.label),
              ),
            );
            groupMap[sourceGroup] = newGroupId;
          }
        }
        final copy = await into(itineraryItems).insert(
          copyItemPlan(
            item,
            date: shift(item.date),
            alternativeId: item.alternativeId == null
                ? null
                : branchMap[item.alternativeId],
            groupId: newGroupId,
            sortOrder: item.sortOrder,
          ).copyWith(tripId: Value(newTripId)),
        );
        itemMap[item.id] = copy;
        // The walk to the station is part of the plan, and a plan the user has
        // to redraw every morning is missing by Thursday — the same reason the
        // checklist and the fare travel.
        await attachedDatabase.trackDao.copyItemTracks(item.id, copy);
      }

      await _copyCosts(
        routineId,
        newTripId,
        itemMap: itemMap,
        groupMap: groupMap,
      );

      // In the order the routine keeps them, so the trip reads the same way. The
      // copy arrives unticked; `copyChecklist` is where that rule lives.
      final lists =
          await (select(checklists)
                ..where((c) => c.tripId.equals(routineId))
                ..orderBy([
                  (c) => OrderingTerm(expression: c.sortOrder),
                  (c) => OrderingTerm(expression: c.createdAt),
                ]))
              .get();
      for (final list in lists) {
        await attachedDatabase.checklistDao.copyChecklist(list.id, newTripId);
      }
      return newTripId;
    });
  }

  /// Adds a routine that runs the same plan the other way round, and returns
  /// its trip id.
  ///
  /// The commute is a pair — out in the morning, back in the evening — but the
  /// return is genuinely a different journey, with its own connections and its
  /// own times, so it is a routine of its own rather than a second half of this
  /// one. This only saves the typing: it reverses the order of the legs and
  /// swaps each one's endpoints, leaving the times to be filled in, since the
  /// 17:40 home is not the 07:42 in read backwards.
  Future<int> duplicateReversed(int routineId, {required String title}) {
    return transaction(() async {
      final routine = await (select(
        trips,
      )..where((t) => t.id.equals(routineId))).getSingle();
      if (routine.kind != TripKind.routine) {
        throw ArgumentError('Trip $routineId is not a routine.');
      }

      final newTripId = await into(trips).insert(
        TripsCompanion.insert(
          title: title,
          // The destination of the way back is where the way out started.
          destination: const Value(''),
          notes: Value(routine.notes),
          kind: const Value(TripKind.routine),
          colorValue: Value(routine.colorValue),
        ),
      );

      final participants = await (select(
        tripParticipants,
      )..where((tp) => tp.tripId.equals(routineId))).get();
      for (final participant in participants) {
        await into(tripParticipants).insert(
          TripParticipantsCompanion.insert(
            tripId: newTripId,
            personId: participant.personId,
          ),
        );
      }

      final routineTags = await (select(
        tripTags,
      )..where((tt) => tt.tripId.equals(routineId))).get();
      for (final link in routineTags) {
        await into(tripTags).insert(
          TripTagsCompanion.insert(tripId: newTripId, tagId: link.tagId),
          mode: InsertMode.insertOrIgnore,
        );
      }

      // Only the loose items travel: a decision on the way out has no
      // meaningful mirror on the way back, and inventing one would be a guess
      // about a plan the user has not made yet.
      final span = await routineDaySpan(routineId);
      final items =
          await (select(itineraryItems)
                ..where(
                  (i) => i.tripId.equals(routineId) & i.alternativeId.isNull(),
                )
                ..orderBy([
                  (i) => OrderingTerm(expression: i.sortOrder),
                  (i) => OrderingTerm(expression: i.startMinutes),
                ]))
              .get();
      final reversed = items.reversed.toList();
      for (var i = 0; i < reversed.length; i++) {
        final item = reversed[i];
        final copy = await into(itineraryItems).insert(
          copyItemPlan(
            item,
            // The days mirror along with the order: the last day of the way out
            // is the first of the way back, so a two-day route reads the right
            // way round rather than collapsing onto one day.
            date: addDays(
              kRoutineAnchorDay,
              span - 1 - daysBetween(kRoutineAnchorDay, item.date),
            ),
            sortOrder: i,
          ).copyWith(
            tripId: Value(newTripId),
            // Endpoints swap; the coordinates and the router's own ids go with
            // the names they belong to, so the way back is searchable too.
            fromLocation: Value(item.toLocation),
            toLocation: Value(item.fromLocation),
            fromLat: Value(item.toLat),
            fromLon: Value(item.toLon),
            toLat: Value(item.fromLat),
            toLon: Value(item.fromLon),
            fromPlaceId: Value(item.toPlaceId),
            toPlaceId: Value(item.fromPlaceId),
            // The times, the live stops and the service this came from all
            // describe one dated run in one direction. Kept, they would say the
            // evening train leaves at the morning train's minute and calls at
            // its stations in its order — so they are dropped rather than
            // reversed into a plausible-looking fiction.
            startMinutes: const Value(null),
            endMinutes: const Value(null),
            actualStartMinutes: const Value(null),
            actualEndMinutes: const Value(null),
            stopovers: const Value(null),
            sourceTripId: const Value(null),
          ),
        );
        // The line *does* travel, where the times did not: a path from A to B is
        // the path from B to A, the same ground either way. Only its point order
        // turns round with the leg.
        await attachedDatabase.trackDao.copyItemTracks(
          item.id,
          copy,
          reversed: true,
        );
      }
      return newTripId;
    });
  }
}
