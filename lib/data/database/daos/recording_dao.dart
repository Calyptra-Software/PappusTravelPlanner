import 'package:drift/drift.dart';
import 'package:latlong2/latlong.dart';

import '../app_database.dart';
import '../tables.dart';

part 'recording_dao.g.dart';

/// Recordings being made, and the fixes they are made of.
///
/// Plain storage and nothing else. Which fixes are worth keeping is decided
/// before they get here (`acceptFix`), and what a recording becomes is decided
/// by the ordinary track import, which writes the [Tracks] rows; this only has
/// to make sure that nothing accepted is lost in between. Times go in and come
/// out as UTC [DateTime]s, and are stored as milliseconds so that what is
/// stored is never a question of which zone something was read in.
@DriftAccessor(tables: [Recordings, RecordingFixes])
class RecordingDao extends DatabaseAccessor<AppDatabase>
    with _$RecordingDaoMixin {
  RecordingDao(super.db);

  /// Starts a recording at [startedAt], noting the device's [utcOffset] at
  /// that moment (see [Recordings.utcOffsetMinutes]), and returns its id.
  Future<int> startRecording({
    int? tripId,
    required DateTime startedAt,
    required Duration utcOffset,
  }) => into(recordings).insert(
    RecordingsCompanion.insert(
      tripId: Value(tripId),
      startedAt: startedAt.toUtc().millisecondsSinceEpoch,
      utcOffsetMinutes: utcOffset.inMinutes,
    ),
  );

  /// Appends [fixes] to [segment] of recording [recordingId], in the order
  /// given.
  Future<void> addFixes(
    int recordingId,
    int segment,
    List<({LatLng position, DateTime at})> fixes,
  ) async {
    if (fixes.isEmpty) return;
    await batch((b) {
      for (final fix in fixes) {
        b.insert(
          recordingFixes,
          RecordingFixesCompanion.insert(
            recordingId: recordingId,
            segment: Value(segment),
            lat: fix.position.latitude,
            lon: fix.position.longitude,
            recordedAt: fix.at.toUtc().millisecondsSinceEpoch,
          ),
        );
      }
    });
  }

  /// Marks recording [id] as stopped at [at]. Its fixes stay until it is filed
  /// or thrown away.
  Future<void> stopRecording(int id, DateTime at) =>
      (update(recordings)..where((r) => r.id.equals(id))).write(
        RecordingsCompanion(
          stoppedAt: Value(at.toUtc().millisecondsSinceEpoch),
        ),
      );

  /// Takes up recording [id] again and returns the segment its next fixes
  /// belong to: one past the last one written, so the gap survives — or 0 for a
  /// recording that has none yet.
  Future<int> resumeRecording(int id) => transaction(() async {
    await (update(recordings)..where((r) => r.id.equals(id))).write(
      const RecordingsCompanion(stoppedAt: Value(null)),
    );
    final last =
        await (selectOnly(recordingFixes)
              ..addColumns([recordingFixes.segment.max()])
              ..where(recordingFixes.recordingId.equals(id)))
            .map((row) => row.read(recordingFixes.segment.max()))
            .getSingleOrNull();
    return last == null ? 0 : last + 1;
  });

  /// Every recording not yet filed, oldest first.
  Stream<List<Recording>> watchRecordings() => (select(
    recordings,
  )..orderBy([(r) => OrderingTerm(expression: r.startedAt)])).watch();

  /// Recording [id], or null when there is none.
  Future<Recording?> recordingOf(int id) =>
      (select(recordings)..where((r) => r.id.equals(id))).getSingleOrNull();

  /// The fixes of recording [id], in the order they were taken.
  Future<List<RecordingFix>> fixesOf(int id) =>
      (select(recordingFixes)
            ..where((f) => f.recordingId.equals(id))
            ..orderBy([(f) => OrderingTerm(expression: f.id)]))
          .get();

  /// Throws recording [id] away, its fixes with it — once it has been filed, or
  /// because the user said so.
  Future<void> deleteRecording(int id) =>
      (delete(recordings)..where((r) => r.id.equals(id))).go();
}
