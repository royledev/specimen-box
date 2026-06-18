// SettingsRepository のテスト（NativeDatabase.memory 上で実行）。
//
// 設計意図:
// - DAO を通じた DB への保存/取得の往復一致を確認する。
// - 未設定キーは null を返すことを確認する。
// - 上書き（upsert）が機能することを確認する。
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/data/db/app_database.dart';
import 'package:specimen_box/data/repositories/settings_repository.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = SettingsRepository(db.settingsDao);
  });

  tearDown(() async {
    await db.close();
  });

  // ─────────────────────────────────────────────
  // 1. getBirthDate: 未設定は null
  // ─────────────────────────────────────────────
  group('SettingsRepository: 未設定の getBirthDate', () {
    test('何も保存していない状態で getBirthDate は null を返す', () async {
      final result = await repository.getBirthDate();
      expect(result, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // 2. setBirthDate → getBirthDate 往復一致
  // ─────────────────────────────────────────────
  group('SettingsRepository: setBirthDate → getBirthDate 往復一致', () {
    test('setBirthDate(DateTime(1990,6,15)) → getBirthDate が同値を返す', () async {
      final date = DateTime(1990, 6, 15);
      await repository.setBirthDate(date);

      final result = await repository.getBirthDate();
      expect(result, equals(date));
    });

    test('年月日ゼロ埋めが必要な日付でも往復一致する（2000-01-01）', () async {
      final date = DateTime(2000, 1, 1);
      await repository.setBirthDate(date);

      final result = await repository.getBirthDate();
      expect(result, equals(date));
    });

    test('月末日（2004-02-29）の往復一致（うるう年）', () async {
      final date = DateTime(2004, 2, 29);
      await repository.setBirthDate(date);

      final result = await repository.getBirthDate();
      expect(result, equals(date));
    });
  });

  // ─────────────────────────────────────────────
  // 3. 上書き（upsert）
  // ─────────────────────────────────────────────
  group('SettingsRepository: 上書き（upsert）', () {
    test('別の日付で setBirthDate すると新しい値が返る', () async {
      await repository.setBirthDate(DateTime(1990, 6, 15));
      await repository.setBirthDate(DateTime(1985, 12, 3));

      final result = await repository.getBirthDate();
      expect(result, equals(DateTime(1985, 12, 3)));
    });

    test('複数回上書きしても最後の値だけ返る', () async {
      await repository.setBirthDate(DateTime(1990, 1, 1));
      await repository.setBirthDate(DateTime(1991, 2, 2));
      await repository.setBirthDate(DateTime(1992, 3, 3));

      final result = await repository.getBirthDate();
      expect(result, equals(DateTime(1992, 3, 3)));
    });
  });

  // ─────────────────────────────────────────────
  // 4. kBirthDateKey 定数の確認
  // ─────────────────────────────────────────────
  group('SettingsRepository: kBirthDateKey 定数', () {
    test('kBirthDateKey が空でない文字列', () {
      expect(SettingsRepository.kBirthDateKey, isNotEmpty);
    });
  });

  // ─────────────────────────────────────────────
  // 5. getOrCreateDeviceToken: 生成→永続→以後は同じ値（get-or-create）
  // ─────────────────────────────────────────────
  group('SettingsRepository: getOrCreateDeviceToken', () {
    test('初回は生成して永続化し、2回目以降は同じトークンを返す', () async {
      final first = await repository.getOrCreateDeviceToken();
      expect(first, isNotEmpty);
      expect(first.length, 32);

      final second = await repository.getOrCreateDeviceToken();
      expect(second, equals(first), reason: '永続化された同一トークンを返す');

      // 別インスタンス（同一 DB）でも残存している。
      final repo2 = SettingsRepository(db.settingsDao);
      expect(await repo2.getOrCreateDeviceToken(), equals(first));
    });

    test('生成前は未設定（null）、生成後は値が入る', () async {
      expect(
        await db.settingsDao.getValue(SettingsRepository.kDeviceTokenKey),
        isNull,
      );
      await repository.getOrCreateDeviceToken();
      expect(
        await db.settingsDao.getValue(SettingsRepository.kDeviceTokenKey),
        isNotNull,
      );
    });
  });

  // ─────────────────────────────────────────────
  // 6. recent 問いID窓 / owned 画像ID集合（JSON KV ラウンドトリップ）
  // ─────────────────────────────────────────────
  group('SettingsRepository: recent 問いID窓', () {
    test('未設定は空リスト', () async {
      expect(await repository.getRecentQuestionIds(), isEmpty);
    });

    test('push → 末尾が最新で永続化される', () async {
      await repository.pushRecentQuestionId('q-a');
      await repository.pushRecentQuestionId('q-b');
      expect(await repository.getRecentQuestionIds(), ['q-a', 'q-b']);

      // 別インスタンス（同一 DB）でも残存。
      final repo2 = SettingsRepository(db.settingsDao);
      expect(await repo2.getRecentQuestionIds(), ['q-a', 'q-b']);
    });

    test('windowSize を超えると先頭から落ちる', () async {
      await repository.pushRecentQuestionId('q-a', windowSize: 2);
      await repository.pushRecentQuestionId('q-b', windowSize: 2);
      await repository.pushRecentQuestionId('q-c', windowSize: 2);
      expect(await repository.getRecentQuestionIds(), ['q-b', 'q-c']);
    });

    test('重複 push は最新へ移動し増えない', () async {
      await repository.pushRecentQuestionId('q-a');
      await repository.pushRecentQuestionId('q-b');
      await repository.pushRecentQuestionId('q-a');
      expect(await repository.getRecentQuestionIds(), ['q-b', 'q-a']);
    });

    test('不正 JSON は空扱い（安全側）', () async {
      await db.settingsDao
          .setValue(SettingsRepository.kRecentQuestionIdsKey, 'not-json');
      expect(await repository.getRecentQuestionIds(), isEmpty);
    });
  });

  group('SettingsRepository: owned 画像ID集合', () {
    test('未設定は空・add で重複なく追加・永続', () async {
      expect(await repository.getOwnedImageIds(), isEmpty);
      await repository.addOwnedImageId('img-1');
      await repository.addOwnedImageId('img-2');
      await repository.addOwnedImageId('img-1'); // 重複
      expect(await repository.getOwnedImageIds(), ['img-1', 'img-2']);

      final repo2 = SettingsRepository(db.settingsDao);
      expect(await repo2.getOwnedImageIds(), ['img-1', 'img-2']);
    });
  });

  // ─────────────────────────────────────────────
  // 6.5 アンケート送信オプトイン（ADR-0012・既定オフ）
  // ─────────────────────────────────────────────
  group('SettingsRepository: surveyOptIn', () {
    test('未設定は false（既定オフ）', () async {
      expect(await repository.getSurveyOptIn(), isFalse);
    });

    test('set(true)→get true / set(false)→get false・永続', () async {
      await repository.setSurveyOptIn(true);
      expect(await repository.getSurveyOptIn(), isTrue);
      final repo2 = SettingsRepository(db.settingsDao);
      expect(await repo2.getSurveyOptIn(), isTrue);

      await repository.setSurveyOptIn(false);
      expect(await repository.getSurveyOptIn(), isFalse);
    });
  });
}
