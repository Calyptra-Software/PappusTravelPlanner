import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'itinerary_dao.g.dart';

@DriftAccessor(tables: [ItineraryItems])
class ItineraryDao extends DatabaseAccessor<AppDatabase>
    with _$ItineraryDaoMixin {
  ItineraryDao(super.db);

  /// All items for a trip, ordered day -> manual sort order -> start time.
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

  /// Next sort order for a new entry on [date] within a trip (appended to the end).
  Future<int> nextSortOrder(int tripId, DateTime date) async {
    final maxExpr = itineraryItems.sortOrder.max();
    final query = selectOnly(itineraryItems)
      ..addColumns([maxExpr])
      ..where(itineraryItems.tripId.equals(tripId) &
          itineraryItems.date.equals(date));
    final row = await query.getSingleOrNull();
    final current = row?.read(maxExpr);
    return (current ?? -1) + 1;
  }
}
