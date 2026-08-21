// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visited_country_dao.dart';

// ignore_for_file: type=lint
mixin _$VisitedCountryDaoMixin on DatabaseAccessor<AppDatabase> {
  $VisitedCountriesTable get visitedCountries =>
      attachedDatabase.visitedCountries;
  VisitedCountryDaoManager get managers => VisitedCountryDaoManager(this);
}

class VisitedCountryDaoManager {
  final _$VisitedCountryDaoMixin _db;
  VisitedCountryDaoManager(this._db);
  $$VisitedCountriesTableTableManager get visitedCountries =>
      $$VisitedCountriesTableTableManager(
        _db.attachedDatabase,
        _db.visitedCountries,
      );
}
