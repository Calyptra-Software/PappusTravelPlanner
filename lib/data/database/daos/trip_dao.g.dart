// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_dao.dart';

// ignore_for_file: type=lint
mixin _$TripDaoMixin on DatabaseAccessor<AppDatabase> {
  $TripsTable get trips => attachedDatabase.trips;
  TripDaoManager get managers => TripDaoManager(this);
}

class TripDaoManager {
  final _$TripDaoMixin _db;
  TripDaoManager(this._db);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db.attachedDatabase, _db.trips);
}
