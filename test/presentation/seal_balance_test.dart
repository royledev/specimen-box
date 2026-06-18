import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/domain/purchase/seal_entitlement.dart';
import 'package:specimen_box/presentation/widgets/seal_balance.dart';

void main() {
  group('sealBalanceText', () {
    test('アンロック所有は ∞', () {
      expect(sealBalanceText(SealEntitlement(unlocked: true)), '∞');
      // unlocked が優先（credits があっても ∞）。
      expect(
          sealBalanceText(SealEntitlement(unlocked: true, credits: 3)), '∞');
    });

    test('クレジット残数を数値で返す', () {
      expect(sealBalanceText(SealEntitlement(credits: 4)), '4');
      expect(sealBalanceText(SealEntitlement()), '0');
    });
  });

  group('sealBalanceLabel', () {
    test('アンロックは「封印し放題（残り ∞）」', () {
      expect(sealBalanceLabel(SealEntitlement(unlocked: true)),
          '封印し放題（残り ∞）');
    });

    test('クレジットは「封印できる残り N個」', () {
      expect(sealBalanceLabel(SealEntitlement(credits: 4)), '封印できる残り 4個');
      expect(sealBalanceLabel(SealEntitlement()), '封印できる残り 0個');
    });
  });
}
