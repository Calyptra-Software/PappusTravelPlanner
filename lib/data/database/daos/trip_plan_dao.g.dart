// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_plan_dao.dart';

// ignore_for_file: type=lint
mixin _$TripPlanDaoMixin on DatabaseAccessor<AppDatabase> {
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
  $ChecklistsTable get checklists => attachedDatabase.checklists;
  $CollapsedDaysTable get collapsedDays => attachedDatabase.collapsedDays;
  TripPlanDaoManager get managers => TripPlanDaoManager(this);
}

class TripPlanDaoManager {
  final _$TripPlanDaoMixin _db;
  TripPlanDaoManager(this._db);
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
  $$ChecklistsTableTableManager get checklists =>
      $$ChecklistsTableTableManager(_db.attachedDatabase, _db.checklists);
  $$CollapsedDaysTableTableManager get collapsedDays =>
      $$CollapsedDaysTableTableManager(_db.attachedDatabase, _db.collapsedDays);
}
