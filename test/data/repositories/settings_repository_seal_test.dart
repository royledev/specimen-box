// SettingsRepository の封印エンタイトルメント永続化テスト（NativeDatabase.memory 上で実行）。
//
// 設計意図:
// - getSealEntitlement / setSealEntitlement の往復一致を確認する。
// - 未設定キーでは unlocked=false, credits=0 のデフォルト値が返ることを確認する。
// - bool 保存形式（'1'/'0'）・int 保存形式（数値文字列）を確認する。
// - 既存 birthDate テストと別キーのため衝突しない。
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/data/db/app_database.dart';
import 'package:specimen_box/data/repositories/settings_repository.dart';
import 'package:specimen_box/domain/purchase/seal_entitlement.dart';

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
  // 1. 未設定デフォルト値
  // ─────────────────────────────────────────────
  group('SettingsRepository: 未設定の getSealEntitlement', () {
    test('何も保存していない状態で getSealEntitlement は unlocked=false, credits=0 を返す',
        () async {
      final result = await repository.getSealEntitlement();
      expect(result, equals(SealEntitlement()));
      expect(result.unlocked, isFalse);
      expect(result.credits, equals(0));
    });
  });

  // ─────────────────────────────────────────────
  // 2. setSealEntitlement → getSealEntitlement 往復一致
  // ─────────────────────────────────────────────
  group('SettingsRepository: setSealEntitlement → getSealEntitlement 往復一致', () {
    test('unlocked=true, credits=3 を保存すると同値が返る', () async {
      final entitlement = SealEntitlement(unlocked: true, credits: 3);
      await repository.setSealEntitlement(entitlement);

      final result = await repository.getSealEntitlement();
      expect(result, equals(entitlement));
    });

    test('unlocked=false, credits=0 を保存すると同値が返る', () async {
      final entitlement = SealEntitlement();
      await repository.setSealEntitlement(entitlement);

      final result = await repository.getSealEntitlement();
      expect(result, equals(entitlement));
    });

    test('unlocked=true, credits=0 を保存すると同値が返る', () async {
      final entitlement = SealEntitlement(unlocked: true);
      await repository.setSealEntitlement(entitlement);

      final result = await repository.getSealEntitlement();
      expect(result, equals(entitlement));
    });

    test('unlocked=false, credits=5 を保存すると同値が返る', () async {
      final entitlement = SealEntitlement(credits: 5);
      await repository.setSealEntitlement(entitlement);

      final result = await repository.getSealEntitlement();
      expect(result, equals(entitlement));
    });
  });

  // ─────────────────────────────────────────────
  // 3. bool 保存形式の確認（'1'/'0'）
  // ─────────────────────────────────────────────
  group('SettingsRepository: bool 保存形式の確認', () {
    test('unlocked=true は "1" で保存される', () async {
      await repository.setSealEntitlement(SealEntitlement(unlocked: true));
      final raw = await db.settingsDao.getValue(SettingsRepository.kSealUnlockedKey);
      expect(raw, equals('1'));
    });

    test('unlocked=false は "0" で保存される', () async {
      await repository.setSealEntitlement(SealEntitlement());
      final raw = await db.settingsDao.getValue(SettingsRepository.kSealUnlockedKey);
      expect(raw, equals('0'));
    });
  });

  // ─────────────────────────────────────────────
  // 4. int 保存形式の確認（数値文字列）
  // ─────────────────────────────────────────────
  group('SettingsRepository: int 保存形式の確認', () {
    test('credits=3 は "3" で保存される', () async {
      await repository.setSealEntitlement(SealEntitlement(credits: 3));
      final raw = await db.settingsDao.getValue(SettingsRepository.kSealCreditsKey);
      expect(raw, equals('3'));
    });

    test('credits=0 は "0" で保存される', () async {
      await repository.setSealEntitlement(SealEntitlement());
      final raw = await db.settingsDao.getValue(SettingsRepository.kSealCreditsKey);
      expect(raw, equals('0'));
    });
  });

  // ─────────────────────────────────────────────
  // 5. 上書き（upsert）
  // ─────────────────────────────────────────────
  group('SettingsRepository: 上書き（upsert）', () {
    test('別の値で setSealEntitlement すると新しい値が返る', () async {
      await repository.setSealEntitlement(SealEntitlement(unlocked: false, credits: 1));
      await repository.setSealEntitlement(SealEntitlement(unlocked: true, credits: 10));

      final result = await repository.getSealEntitlement();
      expect(result, equals(SealEntitlement(unlocked: true, credits: 10)));
    });

    test('複数回上書きしても最後の値だけ返る', () async {
      await repository.setSealEntitlement(SealEntitlement(credits: 1));
      await repository.setSealEntitlement(SealEntitlement(credits: 5));
      await repository.setSealEntitlement(SealEntitlement(unlocked: true, credits: 0));

      final result = await repository.getSealEntitlement();
      expect(result, equals(SealEntitlement(unlocked: true)));
    });
  });

  // ─────────────────────────────────────────────
  // 6. credits のみ・unlocked のみの往復
  // ─────────────────────────────────────────────
  group('SettingsRepository: credits のみ・unlocked のみの往復', () {
    test('credits だけ変化（unlocked は false のまま）', () async {
      await repository.setSealEntitlement(SealEntitlement(credits: 7));

      final result = await repository.getSealEntitlement();
      expect(result.unlocked, isFalse);
      expect(result.credits, equals(7));
    });

    test('unlocked だけ変化（credits は 0 のまま）', () async {
      await repository.setSealEntitlement(SealEntitlement(unlocked: true));

      final result = await repository.getSealEntitlement();
      expect(result.unlocked, isTrue);
      expect(result.credits, equals(0));
    });
  });

  // ─────────────────────────────────────────────
  // 7. キー定数の確認
  // ─────────────────────────────────────────────
  group('SettingsRepository: キー定数', () {
    test('kSealUnlockedKey が空でない文字列', () {
      expect(SettingsRepository.kSealUnlockedKey, isNotEmpty);
    });

    test('kSealCreditsKey が空でない文字列', () {
      expect(SettingsRepository.kSealCreditsKey, isNotEmpty);
    });

    test('kSealUnlockedKey が kBirthDateKey と異なる（キー衝突なし）', () {
      expect(
        SettingsRepository.kSealUnlockedKey,
        isNot(equals(SettingsRepository.kBirthDateKey)),
      );
    });

    test('kSealCreditsKey が kBirthDateKey と異なる（キー衝突なし）', () {
      expect(
        SettingsRepository.kSealCreditsKey,
        isNot(equals(SettingsRepository.kBirthDateKey)),
      );
    });
  });
}
