import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'trip_dao.g.dart';

@DriftAccessor(tables: [Trips, People, TripParticipants])
class TripDao extends DatabaseAccessor<AppDatabase> with _$TripDaoMixin {
  TripDao(super.db);

  /// All trips, upcoming/dated first (nulls last), then most recently created.
  Stream<List<Trip>> watchAllTrips() {
    return (select(trips)..orderBy([
          (t) => OrderingTerm(
            expression: t.startDate,
            mode: OrderingMode.asc,
            nulls: NullsOrder.last,
          ),
          (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
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

  // --- participants ---

  /// The people taking part in a trip, alphabetical by name.
  Stream<List<Person>> watchParticipants(int tripId) {
    final query =
        select(people).join([
            innerJoin(
              tripParticipants,
              tripParticipants.personId.equalsExp(people.id),
            ),
          ])
          ..where(tripParticipants.tripId.equals(tripId))
          ..orderBy([OrderingTerm(expression: people.name)]);
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(people)).toList(),
    );
  }

  /// Participants of every trip, keyed by trip id — used to filter the
  /// overview list by travel companion.
  Stream<Map<int, List<Person>>> watchAllParticipants() {
    final query = select(tripParticipants).join([
      innerJoin(people, people.id.equalsExp(tripParticipants.personId)),
    ])..orderBy([OrderingTerm(expression: people.name)]);
    return query.watch().map((rows) {
      final byTrip = <int, List<Person>>{};
      for (final row in rows) {
        final tripId = row.readTable(tripParticipants).tripId;
        byTrip.putIfAbsent(tripId, () => []).add(row.readTable(people));
      }
      return byTrip;
    });
  }

  /// Adds a participant to a trip by name: creates the person in the shared
  /// roster if needed, then links them to the trip. A no-op if already linked.
  Future<void> addParticipant(int tripId, String name) async {
    await transaction(() async {
      await into(people).insert(
        PeopleCompanion.insert(name: name),
        mode: InsertMode.insertOrIgnore,
      );
      final person = await (select(
        people,
      )..where((p) => p.name.equals(name))).getSingle();
      await into(tripParticipants).insert(
        TripParticipantsCompanion.insert(tripId: tripId, personId: person.id),
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  /// Removes a participant from a trip. The person stays in the shared roster.
  Future<int> removeParticipant(int tripId, int personId) {
    return (delete(tripParticipants)..where(
          (tp) => tp.tripId.equals(tripId) & tp.personId.equals(personId),
        ))
        .go();
  }
}
