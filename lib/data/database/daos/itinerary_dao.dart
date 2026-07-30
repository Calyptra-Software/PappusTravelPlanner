import 'package:drift/drift.dart';

import '../app_database.dart';
import '../item_copy.dart';
import '../tables.dart';

part 'itinerary_dao.g.dart';

@DriftAccessor(tables: [ItineraryItems, CollapsedDays, AlternativeSets])
class ItineraryDao extends DatabaseAccessor<AppDatabase>
    with _$ItineraryDaoMixin {
  ItineraryDao(super.db);

  /// All items for a trip, ordered day -> manual sort order -> start time.
  /// Includes items inside alternative branches (the timeline needs them to draw
  /// the branch you are looking at); callers that only want the plan as it
  /// stands must filter on [ItineraryItem.alternativeId].
  Stream<List<ItineraryItem>> watchItemsForTrip(int tripId) {
    return (select(itineraryItems)
          ..where((i) => i.tripId.equals(tripId))
          ..orderBy([
            (i) => OrderingTerm(expression: i.date),
            (i) => OrderingTerm(expression: i.sortOrder),
            (i) => OrderingTerm(
              expression: i.startMinutes,
              nulls: NullsOrder.last,
            ),
          ]))
        .watch();
  }

  Future<int> addItem(ItineraryItemsCompanion item) =>
      into(itineraryItems).insert(item);

  Future<bool> updateItem(ItineraryItem item) =>
      update(itineraryItems).replace(item);

  /// Writes just the actual (real-time) departure/arrival of an item, leaving
  /// the plan and everything else untouched — the live-times refresh's write.
  /// Writes everything the live-times refresh learned about one leg: its actual
  /// departure/arrival and the delay at each stop it passes through, in a single
  /// update — they are one answer to one question, and writing them separately
  /// would flash a leg whose ends had moved but whose stops had not.
  Future<void> setLiveTimes(
    int id, {
    required int? actualStart,
    required int? actualEnd,
    required String? stopovers,
  }) => (update(itineraryItems)..where((i) => i.id.equals(id))).write(
    ItineraryItemsCompanion(
      actualStartMinutes: Value(actualStart),
      actualEndMinutes: Value(actualEnd),
      stopovers: Value(stopovers),
    ),
  );

  Future<int> deleteItem(int id) =>
      (delete(itineraryItems)..where((i) => i.id.equals(id))).go();

  /// Inserts a run of connection legs (built elsewhere as transport companions),
  /// giving each the next free sort order at the end of *its* day — a journey
  /// crossing midnight lands its later legs on the following day. Returns the new
  /// row ids in input order. One transaction, so an import never lands half its
  /// legs. Grouping the legs (a shared ticket) is the caller's next step.
  Future<List<int>> insertJourneyLegs(
    int tripId,
    List<ItineraryItemsCompanion> legs,
  ) {
    return transaction(() async {
      final ids = <int>[];
      final nextByDate = <DateTime, int>{};
      for (final leg in legs) {
        final date = leg.date.value;
        final sortOrder = nextByDate[date] ?? await nextSortOrder(tripId, date);
        nextByDate[date] = sortOrder + 1;
        ids.add(await addItem(leg.copyWith(sortOrder: Value(sortOrder))));
      }
      return ids;
    });
  }

  /// Next sort order for a new entry on [date] within a trip (appended to the
  /// end). A day's ordering space is shared by its loose items and its
  /// [AlternativeSets] — each set is one block in the timeline — so both are
  /// considered. Items inside a branch are ordered within that branch, not the
  /// day, and are ignored here (see [nextSortOrderInAlternative]).
  Future<int> nextSortOrder(int tripId, DateTime date) async {
    final itemMax = itineraryItems.sortOrder.max();
    final itemQuery = selectOnly(itineraryItems)
      ..addColumns([itemMax])
      ..where(
        itineraryItems.tripId.equals(tripId) &
            itineraryItems.date.equals(date) &
            itineraryItems.alternativeId.isNull(),
      );
    final setMax = alternativeSets.sortOrder.max();
    final setQuery = selectOnly(alternativeSets)
      ..addColumns([setMax])
      ..where(
        alternativeSets.tripId.equals(tripId) &
            alternativeSets.date.equals(date),
      );

    final itemRow = await itemQuery.getSingleOrNull();
    final setRow = await setQuery.getSingleOrNull();
    final lastItem = itemRow?.read(itemMax) ?? -1;
    final lastSet = setRow?.read(setMax) ?? -1;
    return (lastItem > lastSet ? lastItem : lastSet) + 1;
  }

  // --- moving and copying between lists ---

  /// Moves [itemId] to the end of another list: [day]'s loose items, or — when
  /// [alternativeId] is given — that option's items. This is how an entry
  /// crosses a boundary dragging cannot: to another day, into an option, or back
  /// out of one. Reordering *within* a list stays the drag's job.
  ///
  /// The item **leaves its group**: a group means "these share a ticket", so it
  /// has to stay one contiguous run inside a single day or option (see
  /// [GroupDao.groupItems], which refuses to build one that straddles). A group
  /// left with a single member is dissolved, its shared costs preserved — the
  /// item's own costs travel with it either way, since they hang off the item.
  ///
  /// Emptying an option is allowed: an option with nothing planned in it yet is
  /// a normal state, so nothing is tidied away behind the move.
  Future<void> moveItem(
    int itemId, {
    required DateTime day,
    int? alternativeId,
  }) {
    return transaction(() async {
      final item = await _item(itemId);
      // Same transaction, so a move that lands is never half a move: the item
      // cannot end up out of its group but still in its old slot.
      await attachedDatabase.groupDao.removeFromGroup(itemId);
      final sortOrder = alternativeId != null
          ? await nextSortOrderInAlternative(alternativeId)
          : await nextSortOrder(item.tripId, day);
      await (update(itineraryItems)..where((i) => i.id.equals(itemId))).write(
        ItineraryItemsCompanion(
          date: Value(day),
          alternativeId: Value(alternativeId),
          sortOrder: Value(sortOrder),
        ),
      );
    });
  }

  /// Copies [itemId] to the end of the same list [moveItem] would move it to,
  /// and returns the new item's id.
  ///
  /// The copy takes the **plan** — title, times, notes, location, route, mode —
  /// but neither the costs nor the group. A cost records a payment that happened
  /// once; duplicating it would invent money, and it would do so silently inside
  /// a trip whose totals and settle-up depend on it. Adding the cost back takes
  /// seconds; noticing an invented one takes a wrong balance.
  Future<int> duplicateItem(
    int itemId, {
    required DateTime day,
    int? alternativeId,
  }) {
    return transaction(() async {
      final item = await _item(itemId);
      final sortOrder = alternativeId != null
          ? await nextSortOrderInAlternative(alternativeId)
          : await nextSortOrder(item.tripId, day);
      // No groupId passed: a lone copy does not join the original's group (that
      // would put a third leg on a two-leg ticket, and break the run's
      // adjacency). Copying a *whole* group is `GroupDao.copyGroup`.
      return into(itineraryItems).insert(
        copyItemPlan(
          item,
          date: day,
          alternativeId: alternativeId,
          sortOrder: sortOrder,
        ),
      );
    });
  }

  Future<ItineraryItem> _item(int id) =>
      (select(itineraryItems)..where((i) => i.id.equals(id))).getSingle();

  /// Next sort order for a new entry appended to the end of an alternative
  /// branch, whose items are ordered among themselves rather than in the day.
  Future<int> nextSortOrderInAlternative(int alternativeId) async {
    final maxExpr = itineraryItems.sortOrder.max();
    final query = selectOnly(itineraryItems)
      ..addColumns([maxExpr])
      ..where(itineraryItems.alternativeId.equals(alternativeId));
    final row = await query.getSingleOrNull();
    return (row?.read(maxExpr) ?? -1) + 1;
  }

  // --- collapsed days ---

  /// The set of a trip's days (normalized to midnight) shown collapsed. Days
  /// without a row are expanded.
  Stream<Set<DateTime>> watchCollapsedDays(int tripId) {
    return (select(collapsedDays)..where((d) => d.tripId.equals(tripId)))
        .watch()
        .map((rows) => rows.map((r) => r.day).toSet());
  }

  /// Marks [day] (of [tripId]) collapsed or expanded, inserting or deleting the
  /// backing row accordingly.
  Future<void> setDayCollapsed(int tripId, DateTime day, bool collapsed) async {
    if (collapsed) {
      await into(collapsedDays).insert(
        CollapsedDaysCompanion.insert(tripId: tripId, day: day),
        mode: InsertMode.insertOrIgnore,
      );
    } else {
      await (delete(
        collapsedDays,
      )..where((d) => d.tripId.equals(tripId) & d.day.equals(day))).go();
    }
  }
}
