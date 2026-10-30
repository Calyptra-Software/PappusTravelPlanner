import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/data/database/app_database.dart';

/// Keeping a recording while it is made, until the import files it.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final start = DateTime.utc(2026, 5, 1, 12);
  ({LatLng position, DateTime at}) fix(int minute, double lat) =>
      (position: LatLng(lat, 9.9), at: start.add(Duration(minutes: minute)));

  Future<int> makeTrip() => db
      .into(db.trips)
      .insert(TripsCompanion.insert(title: 'T', destination: const Value('')));

  test(
    'a recording keeps its start, its zone and its fixes in order',
    () async {
      final id = await db.recordingDao.startRecording(
        startedAt: start,
        utcOffset: const Duration(hours: 2),
      );
      await db.recordingDao.addFixes(id, 0, [fix(0, 53.50), fix(1, 53.51)]);
      await db.recordingDao.addFixes(id, 0, [fix(2, 53.52)]);

      final recording = (await db.recordingDao.unfiledRecordings()).single;
      expect(recording.startedAt, start.millisecondsSinceEpoch);
      expect(recording.utcOffsetMinutes, 120);
      expect(recording.stoppedAt, isNull, reason: 'it is running');

      final fixes = await db.recordingDao.fixesOf(id);
      expect([for (final f in fixes) f.lat], [53.50, 53.51, 53.52]);
      expect(fixes.last.recordedAt, start.millisecondsSinceEpoch + 2 * 60000);
      expect({for (final f in fixes) f.segment}, {0});
    },
  );

  test('times are stored as the instant, whatever zone they came in', () async {
    final id = await db.recordingDao.startRecording(
      startedAt: start.toLocal(),
      utcOffset: Duration.zero,
    );
    await db.recordingDao.addFixes(id, 0, [
      (position: const LatLng(53.5, 9.9), at: start.toLocal()),
    ]);

    final recording = (await db.recordingDao.unfiledRecordings()).single;
    expect(recording.startedAt, start.millisecondsSinceEpoch);
    final stored = (await db.recordingDao.fixesOf(id)).single;
    expect(stored.recordedAt, start.millisecondsSinceEpoch);
  });

  test('stopping marks it, and resuming starts the next segment', () async {
    final id = await db.recordingDao.startRecording(
      startedAt: start,
      utcOffset: Duration.zero,
    );
    await db.recordingDao.addFixes(id, 0, [fix(0, 53.50), fix(1, 53.51)]);
    await db.recordingDao.stopRecording(
      id,
      start.add(const Duration(hours: 1)),
    );

    var recording = (await db.recordingDao.unfiledRecordings()).single;
    expect(
      recording.stoppedAt,
      start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
    );

    final segment = await db.recordingDao.resumeRecording(id);
    expect(segment, 1, reason: 'the pause stays a gap');
    recording = (await db.recordingDao.unfiledRecordings()).single;
    expect(recording.stoppedAt, isNull);

    await db.recordingDao.addFixes(id, segment, [fix(70, 53.60)]);
    expect(await db.recordingDao.resumeRecording(id), 2);
  });

  test('a recording resumed before any fix starts at segment 0', () async {
    final id = await db.recordingDao.startRecording(
      startedAt: start,
      utcOffset: Duration.zero,
    );
    expect(await db.recordingDao.resumeRecording(id), 0);
  });

  test('deleting a recording takes its fixes with it', () async {
    final id = await db.recordingDao.startRecording(
      startedAt: start,
      utcOffset: Duration.zero,
    );
    await db.recordingDao.addFixes(id, 0, [fix(0, 53.50), fix(1, 53.51)]);

    await db.recordingDao.deleteRecording(id);
    expect(await db.recordingDao.unfiledRecordings(), isEmpty);
    expect(await db.select(db.recordingFixes).get(), isEmpty);
  });

  test('deleting the trip it was started from keeps the recording', () async {
    // The trip is a hint for filing it, not its owner: a walk nobody has filed
    // anywhere must not go with a trip somebody threw away meanwhile.
    final tripId = await makeTrip();
    final id = await db.recordingDao.startRecording(
      tripId: tripId,
      startedAt: start,
      utcOffset: Duration.zero,
    );
    await db.recordingDao.addFixes(id, 0, [fix(0, 53.50)]);

    await (db.delete(db.trips)..where((t) => t.id.equals(tripId))).go();

    final recording = (await db.recordingDao.unfiledRecordings()).single;
    expect(recording.tripId, isNull);
    expect(await db.recordingDao.fixesOf(id), hasLength(1));
  });

  test('recordings are listed oldest first', () async {
    final later = await db.recordingDao.startRecording(
      startedAt: start.add(const Duration(days: 1)),
      utcOffset: Duration.zero,
    );
    final earlier = await db.recordingDao.startRecording(
      startedAt: start,
      utcOffset: Duration.zero,
    );
    final listed = await db.recordingDao.unfiledRecordings();
    expect([for (final r in listed) r.id], [earlier, later]);
  });
}
