// Settings DAO の CRUD テスト（NativeDatabase.memory 上で実行）。
//
// テスト観点:
//   1. setValue → getValue で値が往復すること
//   2. 未設定の key に対して getValue は null を返すこと
//   3. 同一 key に setValue すると上書きされること（upsert）
//   4. v1→v2 onUpgrade 経路で settings 表が作成される
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/data/db/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3_lib;

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // ─────────────────────────────────────────────
  // 1. set → get 往復
  // ─────────────────────────────────────────────
  group('SettingsDao: set → get 往復', () {
    test('setValue した値を getValue で取得できる', () async {
      await db.settingsDao.setValue('birth_date', '1990-04-15');

      final result = await db.settingsDao.getValue('birth_date');
      expect(result, equals('1990-04-15'));
    });

    test('複数の key を個別に保存・取得できる', () async {
      await db.settingsDao.setValue('key_a', 'value_a');
      await db.settingsDao.setValue('key_b', 'value_b');

      expect(await db.settingsDao.getValue('key_a'), equals('value_a'));
      expect(await db.settingsDao.getValue('key_b'), equals('value_b'));
    });
  });

  // ─────────────────────────────────────────────
  // 2. 未設定 key は null
  // ─────────────────────────────────────────────
  group('SettingsDao: 未設定 key', () {
    test('存在しない key に対して getValue は null を返す', () async {
      final result = await db.settingsDao.getValue('nonexistent_key');
      expect(result, isNull);
    });

    test('一度も setValue していない状態では任意の key が null', () async {
      expect(await db.settingsDao.getValue('birth_date'), isNull);
      expect(await db.settingsDao.getValue('some_other_key'), isNull);
    });
  });

  // ─────────────────────────────────────────────
  // 3. 同一 key の上書き（upsert）
  // ─────────────────────────────────────────────
  group('SettingsDao: 同一 key の上書き', () {
    test('同一 key に setValue すると最新値で上書きされる', () async {
      await db.settingsDao.setValue('birth_date', '1990-04-15');
      await db.settingsDao.setValue('birth_date', '1995-12-01');

      final result = await db.settingsDao.getValue('birth_date');
      expect(result, equals('1995-12-01'));
    });

    test('上書き後は古い値が残らない', () async {
      await db.settingsDao.setValue('theme', 'light');
      await db.settingsDao.setValue('theme', 'dark');
      await db.settingsDao.setValue('theme', 'light');

      final result = await db.settingsDao.getValue('theme');
      expect(result, equals('light'));
    });
  });

  // ─────────────────────────────────────────────
  // 4. schemaVersion 2 で Settings テーブルが存在する
  // ─────────────────────────────────────────────
  group('スキーマ検証: Settings テーブルが schemaVersion 2 に存在する', () {
    test('Settings テーブルのカラムは key と value の 2 列', () async {
      final columnNames = db.settings.columnsByName.keys.toSet();
      expect(columnNames.length, equals(2));
      expect(columnNames, containsAll(<String>['key', 'value']));
    });

    test('Settings テーブルに読み書きできる（テーブルが存在している）', () async {
      // テーブルが存在しない場合は例外が発生するため、正常完了をもって確認とする。
      await db.settingsDao.setValue('test_key', 'test_value');
      final result = await db.settingsDao.getValue('test_key');
      expect(result, equals('test_value'));
    });
  });

  // ─────────────────────────────────────────────
  // 5. v1→v2 onUpgrade 経路で settings 表が作成される
  // ─────────────────────────────────────────────
  group('migration: v1→v2 onUpgrade で settings 表が作成される', () {
    setUpAll(() {
      // migration テストは setUp の db とは別に AppDatabase を開くため、
      // drift の "複数インスタンス" 開発警告を抑制する。
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    test('v1 相当の DB（specimens 表のみ）を開くと onUpgrade が走り settings に読み書きできる',
        () async {
      // v1 相当のインメモリ DB を sqlite3 パッケージで直接作成する。
      // specimens 表のみ作り、user_version=1 に設定して "v1 のデータベース" を模倣する。
      final rawDb = sqlite3_lib.sqlite3.openInMemory();
      rawDb.execute('''
        CREATE TABLE specimens (
          id TEXT PRIMARY KEY NOT NULL,
          date TEXT NOT NULL,
          question_id TEXT NOT NULL,
          question_text TEXT NOT NULL,
          answer_text TEXT NOT NULL,
          seed INTEGER NOT NULL,
          generator_version INTEGER NOT NULL,
          status TEXT NOT NULL DEFAULT 'alive',
          created_at INTEGER NOT NULL
        )
      ''');
      rawDb.userVersion = 1;

      // drift の NativeDatabase.opened で同じ sqlite3 接続を包む。
      // AppDatabase はこの接続を開いたとき schemaVersion=1 を検出し、
      // onUpgrade(m, from:1, to:2) を呼んで settings 表を createTable する。
      final executor = NativeDatabase.opened(rawDb);
      final migratedDb = AppDatabase.forTesting(executor);

      // onUpgrade が正しく走ったことを、settings 表への読み書きで確認する。
      // テーブルが存在しない場合は例外が発生してテストが失敗する。
      await migratedDb.settingsDao.setValue('birth_date', '1990-04-15');
      final value = await migratedDb.settingsDao.getValue('birth_date');
      expect(value, equals('1990-04-15'));

      // v1 から引き継いだ specimens 表も壊れていないことを確認する。
      final specimens = await migratedDb.specimensDao.getAllSpecimens();
      expect(specimens, isEmpty);

      await migratedDb.close();
    });

    test('v1→v2 migration 後の settings 表に複数 key を保存できる', () async {
      final rawDb = sqlite3_lib.sqlite3.openInMemory();
      rawDb.execute('''
        CREATE TABLE specimens (
          id TEXT PRIMARY KEY NOT NULL,
          date TEXT NOT NULL,
          question_id TEXT NOT NULL,
          question_text TEXT NOT NULL,
          answer_text TEXT NOT NULL,
          seed INTEGER NOT NULL,
          generator_version INTEGER NOT NULL,
          status TEXT NOT NULL DEFAULT 'alive',
          created_at INTEGER NOT NULL
        )
      ''');
      rawDb.userVersion = 1;

      final executor = NativeDatabase.opened(rawDb);
      final migratedDb = AppDatabase.forTesting(executor);

      await migratedDb.settingsDao.setValue('birth_date', '1985-07-20');
      await migratedDb.settingsDao.setValue('theme', 'dark');

      expect(
        await migratedDb.settingsDao.getValue('birth_date'),
        equals('1985-07-20'),
      );
      expect(
        await migratedDb.settingsDao.getValue('theme'),
        equals('dark'),
      );
      // migration 前から存在しない key は null
      expect(
        await migratedDb.settingsDao.getValue('nonexistent'),
        isNull,
      );

      await migratedDb.close();
    });
  });
}
