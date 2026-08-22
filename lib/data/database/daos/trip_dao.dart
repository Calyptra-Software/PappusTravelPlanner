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

  /// Picks the photograph the overview card shows, or goes back to deriving one.
  ///
  /// [attachmentId] null clears the choice; the card then falls back to the
  /// first picture in gallery order. Either way [Trips.coverHidden] is cleared:
  /// naming a picture — or asking for the derived one back — is a statement
  /// that a cover is wanted.
  Future<void> setCover(int tripId, int? attachmentId) =>
      (update(trips)..where((t) => t.id.equals(tripId))).write(
        TripsCompanion(
          coverAttachmentId: Value(attachmentId),
          coverHidden: const Value(false),
        ),
      );

  /// Says the overview card is to show no photograph at all, or takes that back.
  ///
  /// Hiding **clears** any chosen picture rather than parking it, which is the
  /// invariant [Trips.coverHidden] documents: un-hiding then returns to the
  /// derived photograph, and not to a remembered choice that nothing on screen
  /// could have hinted at.
  Future<void> setCoverHidden(int tripId, bool hidden) =>
      (update(trips)..where((t) => t.id.equals(tripId))).write(
        TripsCompanion(
          coverHidden: Value(hidden),
          coverAttachmentId: hidden ? const Value(null) : const Value.absent(),
        ),
      );

  /// Collapses or expands the trip's strip of photographs.
  ///
  /// A targeted update rather than `updateTrip`, which replaces the whole row:
  /// this is written from a screen holding the trip as it was when it opened,
  /// and a full replace would undo anything that has changed since.
  Future<void> setPhotosCollapsed(int tripId, bool collapsed) =>
      (update(trips)..where((t) => t.id.equals(tripId))).write(
        TripsCompanion(photosCollapsed: Value(collapsed)),
      );

  Future<int> deleteTrip(int id) =>
      (delete(trips)..where((t) => t.id.equals(id))).go();

  /// Widens [tripId]'s dates to cover [days] — the days entries have just been
  /// written onto, when they fall outside what the trip admits to.
  ///
  /// A connection is what puts an entry outside the range without anyone choosing
  /// to: a journey searched for the last evening of a trip can arrive after
  /// midnight, and one looked up again can cross a midnight the old run did not.
  /// The entry is not lost either way — the timeline's days are the union of the
  /// trip's range and its entries' own dates — but the overview card, the calendar
  /// and the trip header all read the range, so the trip would go on calling itself
  /// a day shorter than it is.
  ///
  /// Nothing to widen for a **routine** (its days are ordinals, and its plan is
  /// read off the entries) or for a trip that carries no dates at all: an absent
  /// range is a deliberate "not decided yet", not a range of zero length, and
  /// inventing one from an import would be answering a question nobody asked.
  Future<void> widenToCover(int tripId, Iterable<DateTime> days) async {
    if (days.isEmpty) return;
    final trip = await findTrip(tripId);
    if (trip == null || trip.kind == TripKind.routine) return;
    final start = trip.startDate;
    final end = trip.endDate;
    if (start == null || end == null) return;

    var earliest = start;
    var latest = end;
    for (final day in days) {
      final date = DateTime(day.year, day.month, day.day);
      if (date.isBefore(earliest)) earliest = date;
      if (date.isAfter(latest)) latest = date;
    }
    if (earliest == start && latest == end) return;
    await (update(trips)..where((t) => t.id.equals(tripId))).write(
      TripsCompanion(startDate: Value(earliest), endDate: Value(latest)),
    );
  }

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
