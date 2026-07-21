// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alternative_dao.dart';

// ignore_for_file: type=lint
mixin _$AlternativeDaoMixin on DatabaseAccessor<AppDatabase> {
  $TripsTable get trips => attachedDatabase.trips;
  $AlternativeSetsTable get alternativeSets => attachedDatabase.alternativeSets;
  $AlternativesTable get alternatives => attachedDatabase.alternatives;
  $ItemGroupsTable get itemGroups => attachedDatabase.itemGroups;
  $TransportModesTable get transportModes => attachedDatabase.transportModes;
  $ItineraryItemsTable get itineraryItems => attachedDatabase.itineraryItems;
  AlternativeDaoManager get managers => AlternativeDaoManager(this);
}

class AlternativeDaoManager {
  final _$AlternativeDaoMixin _db;
  AlternativeDaoManager(this._db);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db.attachedDatabase, _db.trips);
  $$AlternativeSetsTableTableManager get alternativeSets =>
      $$AlternativeSetsTableTableManager(
        _db.attachedDatabase,
        _db.alternativeSets,
      );
  $$AlternativesTableTableManager get alternatives =>
      $$AlternativesTableTableManager(_db.attachedDatabase, _db.alternatives);
  $$ItemGroupsTableTableManager get itemGroups =>
      $$ItemGroupsTableTableManager(_db.attachedDatabase, _db.itemGroups);
  $$TransportModesTableTableManager get transportModes =>
      $$TransportModesTableTableManager(
        _db.attachedDatabase,
        _db.transportModes,
      );
  $$ItineraryItemsTableTableManager get itineraryItems =>
      $$ItineraryItemsTableTableManager(
        _db.attachedDatabase,
        _db.itineraryItems,
      );
}
