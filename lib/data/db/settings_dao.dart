// Settings テーブルの DAO（Data Access Object）。
//
// 提供する操作:
//   getValue  - key に対応する value を返す（なければ null）
//   setValue  - key-value を保存する（同一 key は上書き upsert）
library;

import 'package:drift/drift.dart';

import 'app_database.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  /// [key] に対応する value を返す。存在しなければ null。
  Future<String?> getValue(String key) async {
    final row = await (select(settings)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// [key] に [value] を保存する。同一 key が存在する場合は上書き（upsert）。
  Future<void> setValue(String key, String value) =>
      into(settings).insertOnConflictUpdate(
        SettingsCompanion(
          key: Value(key),
          value: Value(value),
        ),
      );
}
