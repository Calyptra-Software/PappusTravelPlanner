// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_dao.dart';

// ignore_for_file: type=lint
mixin _$GroupDaoMixin on DatabaseAccessor<AppDatabase> {
  $TripsTable get trips => attachedDatabase.trips;
  $ItemGroupsTable get itemGroups => attachedDatabase.itemGroups;
  $ItineraryItemsTable get itineraryItems => attachedDatabase.itineraryItems;
  $CostsTable get costs => attachedDatabase.costs;
  GroupDaoManager get managers => GroupDaoManager(this);
}

class GroupDaoManager {
  final _$GroupDaoMixin _db;
  GroupDaoManager(this._db);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db.attachedDatabase, _db.trips);
  $$ItemGroupsTableTableManager get itemGroups =>
      $$ItemGroupsTableTableManager(_db.attachedDatabase, _db.itemGroups);
  $$ItineraryItemsTableTableManager get itineraryItems =>
      $$ItineraryItemsTableTableManager(
        _db.attachedDatabase,
        _db.itineraryItems,
      );
  $$CostsTableTableManager get costs =>
      $$CostsTableTableManager(_db.attachedDatabase, _db.costs);
}
