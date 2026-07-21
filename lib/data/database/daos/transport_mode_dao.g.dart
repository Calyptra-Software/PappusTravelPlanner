// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transport_mode_dao.dart';

// ignore_for_file: type=lint
mixin _$TransportModeDaoMixin on DatabaseAccessor<AppDatabase> {
  $TransportModesTable get transportModes => attachedDatabase.transportModes;
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
}
