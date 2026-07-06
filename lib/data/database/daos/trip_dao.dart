import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'trip_dao.g.dart';

@DriftAccessor(tables: [Trips])
class TripDao extends DatabaseAccessor<AppDatabase> with _$TripDaoMixin {
  TripDao(super.db);

  /// All trips, upcoming/dated first (nulls last), then most recently created.
  Stream<List<Trip>> watchAllTrips() {
    return (select(trips)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.startDate,
                  mode: OrderingMode.asc,
                  nulls: NullsOrder.last,
                ),
            (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }

  Stream<Trip> watchTrip(int id) =>
      (select(trips)..where((t) => t.id.equals(id))).watchSingle();

  Future<Trip?> findTrip(int id) =>
      (select(trips)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> createTrip(TripsCompanion trip) => into(trips).insert(trip);

  Future<bool> updateTrip(Trip trip) => update(trips).replace(trip);

  Future<int> deleteTrip(int id) =>
      (delete(trips)..where((t) => t.id.equals(id))).go();

  /// Sets the custom checklist heading (null restores the default label).
  Future<void> setChecklistTitle(int tripId, String? title) {
    return (update(trips)..where((t) => t.id.equals(tripId)))
        .write(TripsCompanion(checklistTitle: Value(title)));
  }
}
