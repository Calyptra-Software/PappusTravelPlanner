// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording_dao.dart';

// ignore_for_file: type=lint
mixin _$RecordingDaoMixin on DatabaseAccessor<AppDatabase> {
  $TripsTable get trips => attachedDatabase.trips;
  $RecordingsTable get recordings => attachedDatabase.recordings;
  $RecordingFixesTable get recordingFixes => attachedDatabase.recordingFixes;
  RecordingDaoManager get managers => RecordingDaoManager(this);
}

class RecordingDaoManager {
  final _$RecordingDaoMixin _db;
  RecordingDaoManager(this._db);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db.attachedDatabase, _db.trips);
  $$RecordingsTableTableManager get recordings =>
      $$RecordingsTableTableManager(_db.attachedDatabase, _db.recordings);
  $$RecordingFixesTableTableManager get recordingFixes =>
      $$RecordingFixesTableTableManager(
        _db.attachedDatabase,
        _db.recordingFixes,
      );
}
