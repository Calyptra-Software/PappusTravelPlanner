// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routine_dao.dart';

// ignore_for_file: type=lint
mixin _$RoutineDaoMixin on DatabaseAccessor<AppDatabase> {
  $TripsTable get trips => attachedDatabase.trips;
  $PeopleTable get people => attachedDatabase.people;
  $TripParticipantsTable get tripParticipants =>
      attachedDatabase.tripParticipants;
  $TagsTable get tags => attachedDatabase.tags;
  $TripTagsTable get tripTags => attachedDatabase.tripTags;
  $ItemGroupsTable get itemGroups => attachedDatabase.itemGroups;
  $AlternativeSetsTable get alternativeSets => attachedDatabase.alternativeSets;
  $AlternativesTable get alternatives => attachedDatabase.alternatives;
  $TransportModesTable get transportModes => attachedDatabase.transportModes;
  $ItineraryItemsTable get itineraryItems => attachedDatabase.itineraryItems;
  $CurrenciesTable get currencies => attachedDatabase.currencies;
  $CostsTable get costs => attachedDatabase.costs;
  $CostBeneficiariesTable get costBeneficiaries =>
      attachedDatabase.costBeneficiaries;
  RoutineDaoManager get managers => RoutineDaoManager(this);
}

class RoutineDaoManager {
  final _$RoutineDaoMixin _db;
  RoutineDaoManager(this._db);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db.attachedDatabase, _db.trips);
  $$PeopleTableTableManager get people =>
      $$PeopleTableTableManager(_db.attachedDatabase, _db.people);
  $$TripParticipantsTableTableManager get tripParticipants =>
      $$TripParticipantsTableTableManager(
        _db.attachedDatabase,
        _db.tripParticipants,
      );
  $$TagsTableTableManager get tags =>
      $$TagsTableTableManager(_db.attachedDatabase, _db.tags);
  $$TripTagsTableTableManager get tripTags =>
      $$TripTagsTableTableManager(_db.attachedDatabase, _db.tripTags);
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
  $$CostBeneficiariesTableTableManager get costBeneficiaries =>
      $$CostBeneficiariesTableTableManager(
        _db.attachedDatabase,
        _db.costBeneficiaries,
      );
}
