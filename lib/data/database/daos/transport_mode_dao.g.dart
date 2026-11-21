// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transport_mode_dao.dart';

// ignore_for_file: type=lint
mixin _$TransportModeDaoMixin on DatabaseAccessor<AppDatabase> {
  $TransportModesTable get transportModes => attachedDatabase.transportModes;
  $TripsTable get trips => attachedDatabase.trips;
  $ItemGroupsTable get itemGroups => attachedDatabase.itemGroups;
  $AlternativeSetsTable get alternativeSets => attachedDatabase.alternativeSets;
  $AlternativesTable get alternatives => attachedDatabase.alternatives;
  $ItineraryItemsTable get itineraryItems => attachedDatabase.itineraryItems;
  TransportModeDaoManager get managers => TransportModeDaoManager(this);
}

class TransportModeDaoManager {
  final _$TransportModeDaoMixin _db;
  TransportModeDaoManager(this._db);
  $$TransportModesTableTableManager get transportModes =>
      $$TransportModesTableTableManager(
        _db.attachedDatabase,
        _db.transportModes,
      );
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db.attachedDatabase, _db.trips);
  $$ItemGroupsTableTableManager get itemGroups =>
      $$ItemGroupsTableTableManager(_db.attachedDatabase, _db.itemGroups);
  $$AlternativeSetsTableTableManager get alternativeSets =>
      $$AlternativeSetsTableTableManager(
        _db.attachedDatabase,
        _db.alternativeSets,
      );
  $$AlternativesTableTableManager get alternatives =>
      $$AlternativesTableTableManager(_db.attachedDatabase, _db.alternatives);
  $$ItineraryItemsTableTableManager get itineraryItems =>
      $$ItineraryItemsTableTableManager(
        _db.attachedDatabase,
        _db.itineraryItems,
      );
}
