// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sharing_dao.dart';

// ignore_for_file: type=lint
mixin _$SharingDaoMixin on DatabaseAccessor<AppDatabase> {
  $TripsTable get trips => attachedDatabase.trips;
  $ItemGroupsTable get itemGroups => attachedDatabase.itemGroups;
  $ItineraryItemsTable get itineraryItems => attachedDatabase.itineraryItems;
  $CostsTable get costs => attachedDatabase.costs;
  $CostReasonsTable get costReasons => attachedDatabase.costReasons;
  $PeopleTable get people => attachedDatabase.people;
  $TripParticipantsTable get tripParticipants =>
      attachedDatabase.tripParticipants;
  $CostBeneficiariesTable get costBeneficiaries =>
      attachedDatabase.costBeneficiaries;
  $ChecklistsTable get checklists => attachedDatabase.checklists;
  $ChecklistItemsTable get checklistItems => attachedDatabase.checklistItems;
  $CollapsedDaysTable get collapsedDays => attachedDatabase.collapsedDays;
  SharingDaoManager get managers => SharingDaoManager(this);
}

class SharingDaoManager {
  final _$SharingDaoMixin _db;
  SharingDaoManager(this._db);
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
  $$CostReasonsTableTableManager get costReasons =>
      $$CostReasonsTableTableManager(_db.attachedDatabase, _db.costReasons);
  $$PeopleTableTableManager get people =>
      $$PeopleTableTableManager(_db.attachedDatabase, _db.people);
  $$TripParticipantsTableTableManager get tripParticipants =>
      $$TripParticipantsTableTableManager(
        _db.attachedDatabase,
        _db.tripParticipants,
      );
  $$CostBeneficiariesTableTableManager get costBeneficiaries =>
      $$CostBeneficiariesTableTableManager(
        _db.attachedDatabase,
        _db.costBeneficiaries,
      );
  $$ChecklistsTableTableManager get checklists =>
      $$ChecklistsTableTableManager(_db.attachedDatabase, _db.checklists);
  $$ChecklistItemsTableTableManager get checklistItems =>
      $$ChecklistItemsTableTableManager(
        _db.attachedDatabase,
        _db.checklistItems,
      );
  $$CollapsedDaysTableTableManager get collapsedDays =>
      $$CollapsedDaysTableTableManager(_db.attachedDatabase, _db.collapsedDays);
}
