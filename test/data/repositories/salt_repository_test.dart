// SaltRepository のテスト（shared_preferences mock 使用）。
//
// 設計意図:
// - 初回呼び出しで salt を生成して保存し、その値を返す。
// - 2回目以降は保存済みの同じ値を返す（不変）。
// - キー名は定数化されており、テストで参照可能。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:specimen_box/data/repositories/salt_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ─────────────────────────────────────────────
  // 1. 初回生成と不変性
  // ─────────────────────────────────────────────
  group('SaltRepository: 初回生成と不変性', () {
    test('初回呼び出しで salt が生成されて返る（空でない）', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SaltRepository(prefs);

      final salt = await repo.getSalt();
      expect(salt, isNotEmpty);
    });

    test('2回目の呼び出しで初回と同じ値を返す（不変）', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SaltRepository(prefs);

      final first = await repo.getSalt();
      final second = await repo.getSalt();
      expect(second, equals(first));
    });

    test('同じ SharedPreferences インスタンスで別の SaltRepository を生成しても同じ salt', () async {
      final prefs = await SharedPreferences.getInstance();

      final repo1 = SaltRepository(prefs);
      final salt1 = await repo1.getSalt();

      // 同じ prefs を使う別インスタンス → 保存済み値を読み出すので同値
      final repo2 = SaltRepository(prefs);
      final salt2 = await repo2.getSalt();

      expect(salt2, equals(salt1));
    });
  });

  // ─────────────────────────────────────────────
  // 2. salt の品質
  // ─────────────────────────────────────────────
  group('SaltRepository: salt の品質', () {
    test('salt の長さが十分にある（32文字以上）', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SaltRepository(prefs);

      final salt = await repo.getSalt();
      // 暗号的乱数ベースで十分なエントロピーを確保
      expect(salt.length, greaterThanOrEqualTo(32));
    });

    test('別の SharedPreferences（初期値なし）で生成した salt は異なる値になることが多い', () async {
      // 注意: 確率論的テスト。同じになる確率は無視できるほど低い。
      SharedPreferences.setMockInitialValues({});
      final prefs1 = await SharedPreferences.getInstance();
      final salt1 = await SaltRepository(prefs1).getSalt();

      // モックをリセットして別の "デバイス" をシミュレート
      SharedPreferences.setMockInitialValues({});
      final prefs2 = await SharedPreferences.getInstance();
      final salt2 = await SaltRepository(prefs2).getSalt();

      // 同じ値になる確率は極めて低いため不等を期待
      // (fail する確率は 1/(2^192) 以下)
      expect(salt2, isNot(equals(salt1)));
    });
  });

  // ─────────────────────────────────────────────
  // 3. キー名の検証
  // ─────────────────────────────────────────────
  group('SaltRepository: キー名が定数化されている', () {
    test('SaltRepository.kSaltKey が空でない文字列', () {
      expect(SaltRepository.kSaltKey, isNotEmpty);
    });

    test('getSalt 後、SharedPreferences に kSaltKey で保存されている', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SaltRepository(prefs);

      final salt = await repo.getSalt();
      final stored = prefs.getString(SaltRepository.kSaltKey);
      expect(stored, equals(salt));
    });
  });
}
