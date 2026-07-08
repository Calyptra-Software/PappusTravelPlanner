// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'itinerary_dao.dart';

// ignore_for_file: type=lint
mixin _$ItineraryDaoMixin on DatabaseAccessor<AppDatabase> {
  $TripsTable get trips => attachedDatabase.trips;
  $ItineraryItemsTable get itineraryItems => attachedDatabase.itineraryItems;
  $CollapsedDaysTable get collapsedDays => attachedDatabase.collapsedDays;
  ItineraryDaoManager get managers => ItineraryDaoManager(this);
}

class ItineraryDaoManager {
  final _$ItineraryDaoMixin _db;
  ItineraryDaoManager(this._db);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db.attachedDatabase, _db.trips);
  $$ItineraryItemsTableTableManager get itineraryItems =>
      $$ItineraryItemsTableTableManager(
        _db.attachedDatabase,
        _db.itineraryItems,
      );
  $$CollapsedDaysTableTableManager get collapsedDays =>
      $$CollapsedDaysTableTableManager(_db.attachedDatabase, _db.collapsedDays);
}
