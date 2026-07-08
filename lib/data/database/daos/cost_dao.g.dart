// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cost_dao.dart';

// ignore_for_file: type=lint
mixin _$CostDaoMixin on DatabaseAccessor<AppDatabase> {
  $TripsTable get trips => attachedDatabase.trips;
  $ItemGroupsTable get itemGroups => attachedDatabase.itemGroups;
  $ItineraryItemsTable get itineraryItems => attachedDatabase.itineraryItems;
  $CostsTable get costs => attachedDatabase.costs;
  $CostReasonsTable get costReasons => attachedDatabase.costReasons;
  $PeopleTable get people => attachedDatabase.people;
  $CostBeneficiariesTable get costBeneficiaries =>
      attachedDatabase.costBeneficiaries;
  CostDaoManager get managers => CostDaoManager(this);
}

class CostDaoManager {
  final _$CostDaoMixin _db;
  CostDaoManager(this._db);
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
  $$CostBeneficiariesTableTableManager get costBeneficiaries =>
      $$CostBeneficiariesTableTableManager(
        _db.attachedDatabase,
        _db.costBeneficiaries,
      );
}
