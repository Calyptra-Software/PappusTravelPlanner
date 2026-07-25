// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_dao.dart';

// ignore_for_file: type=lint
mixin _$GroupDaoMixin on DatabaseAccessor<AppDatabase> {
  $TripsTable get trips => attachedDatabase.trips;
  $ItemGroupsTable get itemGroups => attachedDatabase.itemGroups;
  $AlternativeSetsTable get alternativeSets => attachedDatabase.alternativeSets;
  $AlternativesTable get alternatives => attachedDatabase.alternatives;
  $TransportModesTable get transportModes => attachedDatabase.transportModes;
  $ItineraryItemsTable get itineraryItems => attachedDatabase.itineraryItems;
  $CurrenciesTable get currencies => attachedDatabase.currencies;
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
  $$AlternativeSetsTableTableManager get alternativeSets =>
      $$AlternativeSetsTableTableManager(
        _db.attachedDatabase,
        _db.alternativeSets,
      );
  $$AlternativesTableTableManager get alternatives =>
      $$AlternativesTableTableManager(_db.attachedDatabase, _db.alternatives);
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
  $$CurrenciesTableTableManager get currencies =>
      $$CurrenciesTableTableManager(_db.attachedDatabase, _db.currencies);
  $$CostsTableTableManager get costs =>
      $$CostsTableTableManager(_db.attachedDatabase, _db.costs);
}
