import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';

/// The countries the user says they have been to without a trip here for them.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('nothing is marked to begin with', () async {
    expect(await db.visitedCountryDao.watchMarked().first, isEmpty);
  });

  test('a mark is a statement, and can be taken back', () async {
    await db.visitedCountryDao.setMarked('JP', true);
    await db.visitedCountryDao.setMarked('NZ', true);
    expect(await db.visitedCountryDao.watchMarked().first, {'JP', 'NZ'});

    await db.visitedCountryDao.setMarked('JP', false);
    expect(await db.visitedCountryDao.watchMarked().first, {'NZ'});
  });

  test('marking twice is marking once', () async {
    // The code is the row's identity, so saying it again is not a second visit.
    await db.visitedCountryDao.setMarked('JP', true);
    await db.visitedCountryDao.setMarked('JP', true);
    expect(await db.visitedCountryDao.watchMarked().first, {'JP'});
  });

  test('unmarking something never marked is not an error', () async {
    await db.visitedCountryDao.setMarked('JP', false);
    expect(await db.visitedCountryDao.watchMarked().first, isEmpty);
  });

  test('a code the outline set does not know is still kept', () async {
    // The set may be replaced by a finer one, and a mark nobody can currently
    // draw is still something the user said.
    await db.visitedCountryDao.setMarked('XK', true);
    expect(await db.visitedCountryDao.watchMarked().first, {'XK'});
  });

  test('several are taken back in one write', () async {
    // What unticking a state in the list does: a mark on one of its
    // territories is what was making the row true, so it goes too.
    await db.visitedCountryDao.setMarked('DK', true);
    await db.visitedCountryDao.setMarked('GRL', true);
    await db.visitedCountryDao.setMarked('JP', true);

    await db.visitedCountryDao.clearMarks({'DK', 'GRL'});
    expect(await db.visitedCountryDao.watchMarked().first, {'JP'});
  });

  test('clearing nothing is not a clearing of everything', () async {
    await db.visitedCountryDao.setMarked('JP', true);
    await db.visitedCountryDao.clearMarks(const {});
    expect(await db.visitedCountryDao.watchMarked().first, {'JP'});
  });

  test('a mark survives what a trip does', () async {
    // The two answers come from different places on purpose: deleting every
    // trip in the app does not un-say where somebody has been.
    await db.visitedCountryDao.setMarked('JP', true);
    final trip = await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(title: 'T', destination: const Value('')),
        );
    await (db.delete(db.trips)..where((t) => t.id.equals(trip))).go();

    expect(await db.visitedCountryDao.watchMarked().first, {'JP'});
  });
}
