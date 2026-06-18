import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/presentation/providers/providers.dart';

void main() {
  group('nowProvider', () {
    test('overrideWithValue が効く（固定 DateTime を返す）', () {
      final fixedNow = DateTime(2026, 6, 10, 12, 0, 0);
      final container = ProviderContainer(
        overrides: [
          nowProvider.overrideWithValue(fixedNow),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(nowProvider), fixedNow);
    });

    test('container.dispose() 後に例外が出ない（onDispose で timer がキャンセルされる）', () {
      // override なし：実際の Timer.periodic が生成されることを確認し、
      // dispose 後にエラーが起きないことを検証する。
      final container = ProviderContainer();

      // nowProvider を read してプロバイダを活性化し、Timer を起動させる。
      final value = container.read(nowProvider);
      expect(value, isA<DateTime>());

      // dispose で timer.cancel() が呼ばれ、例外が発生しないことを確認する。
      expect(container.dispose, returnsNormally);
    });

    test('fakeAsync: 61秒経過後に nowProvider が再実行される（tick→invalidateSelf 検証）',
        () {
      // Timer.periodic(60秒) + ref.invalidateSelf() のため、
      // 仮想時間を 61 秒以上進めると Provider が再実行（再生成）される。
      // DateTime.now() は fakeAsync の仮想時計に連動しないため、
      // 再実行回数（Provider が再評価されたか）をリスナー呼び出し回数で確認する。
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // 初回 read でプロバイダを活性化しタイマーを起動させる。
        container.read(nowProvider);

        var listenerCallCount = 0;
        final subscription = container.listen<DateTime>(
          nowProvider,
          (prev, next) => listenerCallCount++,
        );
        addTearDown(subscription.close);

        // タイマー発火前はリスナーが呼ばれていない。
        expect(listenerCallCount, 0,
            reason: '61秒経過前はリスナーが呼ばれていない');

        // 仮想時間を 61 秒進める → Timer.periodic が発火 → invalidateSelf →
        // Provider が再評価 → リスナー通知。
        async.elapse(const Duration(seconds: 61));

        // リスナーが 1 回以上呼ばれた = Provider が再実行された。
        expect(listenerCallCount, greaterThanOrEqualTo(1),
            reason: '61秒経過後に Timer 発火 → invalidateSelf → リスナー通知');
      });
    });
  });
}
