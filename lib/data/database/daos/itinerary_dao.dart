import 'package:drift/drift.dart';

import '../app_database.dart';
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

  Future<int> deleteItem(int id) =>
      (delete(itineraryItems)..where((i) => i.id.equals(id))).go();

  /// Next sort order for a new entry on [date] within a trip (appended to the
  /// end). A day's ordering space is shared by its loose items and its
  /// [AlternativeSets] — each set is one block in the timeline — so both are
  /// considered. Items inside a branch are ordered within that branch, not the
  /// day, and are ignored here (see [nextSortOrderInAlternative]).
  Future<int> nextSortOrder(int tripId, DateTime date) async {
    final itemMax = itineraryItems.sortOrder.max();
    final itemQuery = selectOnly(itineraryItems)
      ..addColumns([itemMax])
      ..where(itineraryItems.tripId.equals(tripId) &
          itineraryItems.date.equals(date) &
          itineraryItems.alternativeId.isNull());
    final setMax = alternativeSets.sortOrder.max();
    final setQuery = selectOnly(alternativeSets)
      ..addColumns([setMax])
      ..where(alternativeSets.tripId.equals(tripId) &
          alternativeSets.date.equals(date));

    final itemRow = await itemQuery.getSingleOrNull();
    final setRow = await setQuery.getSingleOrNull();
    final lastItem = itemRow?.read(itemMax) ?? -1;
    final lastSet = setRow?.read(setMax) ?? -1;
    return (lastItem > lastSet ? lastItem : lastSet) + 1;
  }

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
      await (delete(collapsedDays)
            ..where((d) => d.tripId.equals(tripId) & d.day.equals(day)))
          .go();
    }
  }
}
