/// アプリのメイン Drift データベース。
///
/// テスト時は [AppDatabase.forTesting] を使って
/// `NativeDatabase.memory()` でインメモリ DB を生成する。
/// 本番実行時は接続を外から渡す（`AppDatabase(openConnection('specimen_box.db'))`）。
library;

import 'package:drift/drift.dart';

import 'specimens_dao.dart';
import 'settings_dao.dart';
import 'tables.dart';

export 'package:drift/drift.dart' show Value;
export 'tables.dart';
export 'specimens_dao.dart';
export 'settings_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Specimens, Settings], daos: [SpecimensDao, SettingsDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// テスト用コンストラクタ。[executor] に `NativeDatabase.memory()` を渡す。
  AppDatabase.forTesting(super.executor) : super();

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(settings);
      }
      if (from < 3) {
        // ADR-0011: サーバー配信画像のローカル保存。image_id / local_path を追加（null 可）。
        await m.addColumn(specimens, specimens.imageId);
        await m.addColumn(specimens, specimens.localPath);
      }
      if (from < 4) {
        // ADR-0011: ベクター生成廃止。seed / generator_version 列を削除する。
        // TableMigration はテーブルを再作成し、現在の Dart 定義に存在する列のみを
        // INSERT SELECT で引き継ぐ（= seed / generator_version が落ち、残る列は同名コピー）。
        // 生成は addColumn の結果ではなく現定義ベースのため、from<3 の addColumn を
        // 経由しない v1→v4 直接昇格でも image_id / local_path は新スキーマに含まれ安全。
        //
        // ADR-0017: image_rarity は schemaVersion 5 で追加した新列。v1〜v3 の旧テーブルには
        // 無いため newColumns に指定し、同名 INSERT SELECT の対象から除外する（指定しないと
        // 旧テーブルに存在しない image_rarity を SELECT しようとして落ちる）。値は null で埋まる。
        await m.alterTable(TableMigration(
          specimens,
          newColumns: [specimens.imageRarity, specimens.name],
        ));
      }
      if (from >= 4 && from < 5) {
        // ADR-0017: 画像レア度。image_rarity 列を追加（既存行は null）。
        // from<4 を経由した昇格では alterTable が既に列を作るため、ここは v4→v5 のみ。
        await m.addColumn(specimens, specimens.imageRarity);
      }
      if (from >= 4 && from < 6) {
        // 標本の表示名。name 列を追加（既存行は null）。
        // from<4 を経由した昇格では alterTable の newColumns で既に作るため、ここは v4/v5→v6 のみ。
        await m.addColumn(specimens, specimens.name);
      }
    },
  );
}
