// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'specimens_dao.dart';

// ignore_for_file: type=lint
mixin _$SpecimensDaoMixin on DatabaseAccessor<AppDatabase> {
  $SpecimensTable get specimens => attachedDatabase.specimens;
  SpecimensDaoManager get managers => SpecimensDaoManager(this);
}

class SpecimensDaoManager {
  final _$SpecimensDaoMixin _db;
  SpecimensDaoManager(this._db);
  $$SpecimensTableTableManager get specimens =>
      $$SpecimensTableTableManager(_db.attachedDatabase, _db.specimens);
}
