import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> makeTrip([String title = 'T']) =>
      db.tripDao.createTrip(TripsCompanion.insert(title: title));

  test('addParticipant creates the person and links them, sorted by name',
      () async {
    final tripId = await makeTrip();
    await db.tripDao.addParticipant(tripId, 'Bob');
    await db.tripDao.addParticipant(tripId, 'Alex');

    final participants = await db.tripDao.watchParticipants(tripId).first;
    expect(participants.map((p) => p.name), ['Alex', 'Bob']);
    // Both are now in the shared roster too.
    expect(await db.costDao.watchPeople().first, ['Alex', 'Bob']);
  });

  test('addParticipant reuses an existing roster person and is idempotent',
      () async {
    final tripId = await makeTrip();
    await db.costDao.upsertPerson('Alex');

    await db.tripDao.addParticipant(tripId, 'Alex');
    await db.tripDao.addParticipant(tripId, 'Alex'); // duplicate, ignored

    final participants = await db.tripDao.watchParticipants(tripId).first;
    expect(participants.map((p) => p.name), ['Alex']);
    // No duplicate person was created.
    expect(await db.costDao.watchPeople().first, ['Alex']);
  });

  test('participants stay scoped to their trip', () async {
    final a = await makeTrip('A');
    final b = await makeTrip('B');
    await db.tripDao.addParticipant(a, 'Alex');
    await db.tripDao.addParticipant(b, 'Bob');

    expect((await db.tripDao.watchParticipants(a).first).map((p) => p.name),
        ['Alex']);
    expect((await db.tripDao.watchParticipants(b).first).map((p) => p.name),
        ['Bob']);
  });

  test('removeParticipant unlinks but keeps the person in the roster',
      () async {
    final tripId = await makeTrip();
    await db.tripDao.addParticipant(tripId, 'Alex');
    final person =
        (await db.tripDao.watchParticipants(tripId).first).single;

    await db.tripDao.removeParticipant(tripId, person.id);

    expect(await db.tripDao.watchParticipants(tripId).first, isEmpty);
    expect(await db.costDao.watchPeople().first, ['Alex']);
  });

  test('deleting a person removes them from every trip they joined', () async {
    final tripId = await makeTrip();
    await db.tripDao.addParticipant(tripId, 'Alex');
    await db.tripDao.addParticipant(tripId, 'Bob');

    await db.costDao.deletePerson('Alex');

    final participants = await db.tripDao.watchParticipants(tripId).first;
    expect(participants.map((p) => p.name), ['Bob']);
  });

  test('deleting a trip cascades to its participant links', () async {
    final tripId = await makeTrip();
    await db.tripDao.addParticipant(tripId, 'Alex');

    await db.tripDao.deleteTrip(tripId);

    // The link is gone, but the person remains in the shared roster.
    expect(await db.costDao.watchPeople().first, ['Alex']);
  });
}
