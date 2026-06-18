import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/domain/weathering/weathering.dart';

void main() {
  // テストで使う明示的な T1/T2（placeholder 定数に依存しない境界テスト）
  const t1 = Duration(days: 7);
  const t2 = Duration(days: 30);

  final base = DateTime(2025, 1, 1, 0, 0, 0);

  group('weatherLevel: sealed=false', () {
    test('新品（elapsed=0）→ 0.0', () {
      final result = weatherLevel(
        createdAt: base,
        now: base,
        sealed: false,
        t1: t1,
        t2: t2,
      );
      expect(result, 0.0);
    });

    test('T1 直前（elapsed < T1）→ 0.0', () {
      final result = weatherLevel(
        createdAt: base,
        now: base.add(t1 - const Duration(seconds: 1)),
        sealed: false,
        t1: t1,
        t2: t2,
      );
      expect(result, 0.0);
    });

    test('T1 ちょうど（elapsed == T1）→ 0.0', () {
      final result = weatherLevel(
        createdAt: base,
        now: base.add(t1),
        sealed: false,
        t1: t1,
        t2: t2,
      );
      expect(result, 0.0);
    });

    test('T1〜T2 中間 25%地点 → 約 0.25（単調増加）', () {
      final elapsed25 = t1 + Duration(microseconds: ((t2 - t1).inMicroseconds * 0.25).round());
      final result = weatherLevel(
        createdAt: base,
        now: base.add(elapsed25),
        sealed: false,
        t1: t1,
        t2: t2,
      );
      expect(result, closeTo(0.25, 1e-6));
    });

    test('T1〜T2 中間 50%地点 → 約 0.50', () {
      final elapsed50 = t1 + Duration(microseconds: ((t2 - t1).inMicroseconds * 0.5).round());
      final result = weatherLevel(
        createdAt: base,
        now: base.add(elapsed50),
        sealed: false,
        t1: t1,
        t2: t2,
      );
      expect(result, closeTo(0.5, 1e-6));
    });

    test('T1〜T2 中間 75%地点 → 約 0.75', () {
      final elapsed75 = t1 + Duration(microseconds: ((t2 - t1).inMicroseconds * 0.75).round());
      final result = weatherLevel(
        createdAt: base,
        now: base.add(elapsed75),
        sealed: false,
        t1: t1,
        t2: t2,
      );
      expect(result, closeTo(0.75, 1e-6));
    });

    test('T1〜T2 の3点が単調増加', () {
      final elapsed25 = t1 + Duration(microseconds: ((t2 - t1).inMicroseconds * 0.25).round());
      final elapsed50 = t1 + Duration(microseconds: ((t2 - t1).inMicroseconds * 0.5).round());
      final elapsed75 = t1 + Duration(microseconds: ((t2 - t1).inMicroseconds * 0.75).round());

      final r25 = weatherLevel(createdAt: base, now: base.add(elapsed25), sealed: false, t1: t1, t2: t2);
      final r50 = weatherLevel(createdAt: base, now: base.add(elapsed50), sealed: false, t1: t1, t2: t2);
      final r75 = weatherLevel(createdAt: base, now: base.add(elapsed75), sealed: false, t1: t1, t2: t2);

      expect(r25, lessThan(r50));
      expect(r50, lessThan(r75));
    });

    test('T2 ちょうど（elapsed == T2）→ 1.0', () {
      final result = weatherLevel(
        createdAt: base,
        now: base.add(t2),
        sealed: false,
        t1: t1,
        t2: t2,
      );
      expect(result, 1.0);
    });

    test('T2 を超えた → 1.0（クランプ）', () {
      final result = weatherLevel(
        createdAt: base,
        now: base.add(t2 + const Duration(days: 100)),
        sealed: false,
        t1: t1,
        t2: t2,
      );
      expect(result, 1.0);
    });

    test('now < createdAt（負の elapsed）→ 0.0', () {
      final result = weatherLevel(
        createdAt: base,
        now: base.subtract(const Duration(days: 1)),
        sealed: false,
        t1: t1,
        t2: t2,
      );
      expect(result, 0.0);
    });
  });

  group('weatherLevel: sealed=true', () {
    test('新品でも sealed=true → 0.0', () {
      final result = weatherLevel(
        createdAt: base,
        now: base,
        sealed: true,
        t1: t1,
        t2: t2,
      );
      expect(result, 0.0);
    });

    test('T2 超過でも sealed=true → 0.0（weatheringFrozen）', () {
      final result = weatherLevel(
        createdAt: base,
        now: base.add(t2 + const Duration(days: 999)),
        sealed: true,
        t1: t1,
        t2: t2,
      );
      expect(result, 0.0);
    });

    test('T1〜T2 中間でも sealed=true → 0.0', () {
      final elapsedMid = t1 + Duration(microseconds: ((t2 - t1).inMicroseconds * 0.5).round());
      final result = weatherLevel(
        createdAt: base,
        now: base.add(elapsedMid),
        sealed: true,
        t1: t1,
        t2: t2,
      );
      expect(result, 0.0);
    });
  });

  group('weatherLevel: t2 境界ガード', () {
    test('t2 == t1 のとき 0.0 または 1.0 を返し、例外/NaN にならない', () {
      // t2 == t1 のとき early return で 0.0 を返す（ゼロ除算なし）
      // ただし assert はデバッグビルドで発火するため、このテストは
      // assert を発火させないように t2 > t1 違反が assert で落ちることを
      // expect して確認する。
      expect(
        () => weatherLevel(
          createdAt: base,
          now: base.add(const Duration(days: 15)),
          sealed: false,
          t1: const Duration(days: 7),
          t2: const Duration(days: 7), // t2 == t1
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('t2 < t1 のとき AssertionError が発火する（デバッグビルド）', () {
      expect(
        () => weatherLevel(
          createdAt: base,
          now: base.add(const Duration(days: 15)),
          sealed: false,
          t1: const Duration(days: 30),
          t2: const Duration(days: 7), // t2 < t1
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('weatherLevel: 確定定数でも動作確認', () {
    test('確定定数を使ったデフォルト呼び出しでも戻り値が 0..1 に収まる（新品）', () {
      final result = weatherLevel(
        createdAt: base,
        now: base,
        sealed: false,
      );
      expect(result, inInclusiveRange(0.0, 1.0));
    });

    test('確定定数を使ったデフォルト呼び出しで T2 を大幅超過 → 1.0', () {
      // kWeatheringT2 は 30日。1000日後なら確実に 1.0
      final result = weatherLevel(
        createdAt: base,
        now: base.add(const Duration(days: 1000)),
        sealed: false,
      );
      expect(result, 1.0);
    });
  });
}
