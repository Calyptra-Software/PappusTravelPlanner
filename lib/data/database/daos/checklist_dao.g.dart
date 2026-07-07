// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checklist_dao.dart';

// ignore_for_file: type=lint
mixin _$ChecklistDaoMixin on DatabaseAccessor<AppDatabase> {
  $TripsTable get trips => attachedDatabase.trips;
  $ChecklistsTable get checklists => attachedDatabase.checklists;
  $ChecklistItemsTable get checklistItems => attachedDatabase.checklistItems;
  ChecklistDaoManager get managers => ChecklistDaoManager(this);
}

class ChecklistDaoManager {
  final _$ChecklistDaoMixin _db;
  ChecklistDaoManager(this._db);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db.attachedDatabase, _db.trips);
  $$ChecklistsTableTableManager get checklists =>
      $$ChecklistsTableTableManager(_db.attachedDatabase, _db.checklists);
  $$ChecklistItemsTableTableManager get checklistItems =>
      $$ChecklistItemsTableTableManager(
        _db.attachedDatabase,
        _db.checklistItems,
      );
}
