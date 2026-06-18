import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/domain/purchase/seal_entitlement.dart';
import 'package:specimen_box/platform/purchase/fake_purchase_service.dart';
import 'package:specimen_box/platform/purchase/purchase_service.dart';

void main() {
  late FakePurchaseService svc;

  setUp(() {
    svc = FakePurchaseService();
  });

  // ---------------------------------------------------------------------------
  // productId 定数・写像
  // ---------------------------------------------------------------------------
  group('productId 定数と写像', () {
    test('kAllSealProductIds は3つで表示順（単品→パック→アンロック）', () {
      expect(kAllSealProductIds, [
        kSealSingleProductId,
        kSealPack5ProductId,
        kSealUnlockProductId,
      ]);
    });

    test('3つの productId は互いに異なる', () {
      expect({kSealSingleProductId, kSealPack5ProductId, kSealUnlockProductId},
          hasLength(3));
    });

    test('sealProductKindFromId は各 productId を正しい kind に写像', () {
      expect(sealProductKindFromId(kSealSingleProductId),
          SealProductKind.single);
      expect(sealProductKindFromId(kSealPack5ProductId), SealProductKind.pack5);
      expect(sealProductKindFromId(kSealUnlockProductId),
          SealProductKind.unlock);
    });

    test('sealProductKindFromId は未知 productId に null を返す', () {
      expect(sealProductKindFromId('com.example.unknown'), isNull);
    });

    test('sealProductIdFromKind は各 kind を正しい productId に写像', () {
      expect(sealProductIdFromKind(SealProductKind.single),
          kSealSingleProductId);
      expect(
          sealProductIdFromKind(SealProductKind.pack5), kSealPack5ProductId);
      expect(sealProductIdFromKind(SealProductKind.unlock),
          kSealUnlockProductId);
    });

    test('kind→id→kind の往復で同一に戻る', () {
      for (final kind in SealProductKind.values) {
        expect(sealProductKindFromId(sealProductIdFromKind(kind)), kind);
      }
    });

    test('id→kind→id の往復で同一に戻る', () {
      for (final id in kAllSealProductIds) {
        expect(sealProductIdFromKind(sealProductKindFromId(id)!), id);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // products()
  // ---------------------------------------------------------------------------
  group('products', () {
    test('既定で3商品を表示順で返す', () async {
      final list = await svc.products();
      expect(list, hasLength(3));
      expect(list.map((p) => p.kind), [
        SealProductKind.single,
        SealProductKind.pack5,
        SealProductKind.unlock,
      ]);
    });

    test('各商品が productId と一致した kind を持つ', () async {
      final list = await svc.products();
      for (final p in list) {
        expect(sealProductKindFromId(p.id), p.kind);
        expect(p.price, isNotEmpty);
      }
    });

    test('注入した商品一覧を返す', () async {
      final custom = FakePurchaseService(availableProducts: const [
        SealProduct(
          id: kSealUnlockProductId,
          kind: SealProductKind.unlock,
          title: 'only unlock',
          description: 'd',
          price: '¥999',
        ),
      ]);
      final list = await custom.products();
      expect(list, hasLength(1));
      expect(list.first.kind, SealProductKind.unlock);
    });

    test('返されたリストは変更不可', () async {
      final list = await svc.products();
      expect(
        () => list.add(FakePurchaseService.defaultProducts.first),
        throwsUnsupportedError,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // buy()
  // ---------------------------------------------------------------------------
  group('buy', () {
    test('成功時は productId と kind を含む success を返す', () async {
      final r = await svc.buy(kSealPack5ProductId);
      expect(r.status, PurchaseStatus.success);
      expect(r.isSuccess, isTrue);
      expect(r.productId, kSealPack5ProductId);
      expect(r.kind, SealProductKind.pack5);
    });

    test('キャンセル注入時は canceled を返す', () async {
      svc.nextPurchaseStatus = PurchaseStatus.canceled;
      final r = await svc.buy(kSealSingleProductId);
      expect(r.status, PurchaseStatus.canceled);
      expect(r.isSuccess, isFalse);
      expect(r.kind, isNull);
    });

    test('エラー注入時は error を返す', () async {
      svc.nextPurchaseStatus = PurchaseStatus.error;
      final r = await svc.buy(kSealSingleProductId);
      expect(r.status, PurchaseStatus.error);
      expect(r.isSuccess, isFalse);
      expect(r.message, isNotNull);
    });

    test('成功設定でも未知 productId は error を返す', () async {
      final r = await svc.buy('com.example.unknown');
      expect(r.status, PurchaseStatus.error);
    });

    test('buy 呼び出しが productId 付きで記録される', () async {
      await svc.buy(kSealSingleProductId);
      await svc.buy(kSealUnlockProductId);
      expect(svc.buyCalls, [kSealSingleProductId, kSealUnlockProductId]);
    });

    test('成功した buy の kind を grant に渡すとエンタイトルメントが増える', () async {
      var e = SealEntitlement();
      final r = await svc.buy(kSealPack5ProductId);
      e = grant(e, r.kind!);
      expect(e.credits, 5);
    });
  });

  // ---------------------------------------------------------------------------
  // restore()
  // ---------------------------------------------------------------------------
  group('restore', () {
    test('既定ではアンロック未復元', () async {
      final r = await svc.restore();
      expect(r.unlockRestored, isFalse);
    });

    test('復元あり注入時は unlockRestored=true', () async {
      svc.restoreUnlock = true;
      final r = await svc.restore();
      expect(r.unlockRestored, isTrue);
    });

    test('restore 呼び出し回数が記録される', () async {
      await svc.restore();
      await svc.restore();
      expect(svc.restoreCallCount, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // PurchaseResult / SealProduct モデル
  // ---------------------------------------------------------------------------
  group('モデル', () {
    test('PurchaseResult.success は kind/productId を保持', () {
      const r = PurchaseResult.success(
          kSealSingleProductId, SealProductKind.single);
      expect(r.isSuccess, isTrue);
      expect(r.kind, SealProductKind.single);
    });

    test('PurchaseResult は値等価', () {
      const a = PurchaseResult.success(
          kSealSingleProductId, SealProductKind.single);
      const b = PurchaseResult.success(
          kSealSingleProductId, SealProductKind.single);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const PurchaseResult.canceled()));
    });

    test('RestoreResult は値等価', () {
      expect(const RestoreResult(unlockRestored: true),
          const RestoreResult(unlockRestored: true));
      expect(const RestoreResult(unlockRestored: true),
          isNot(const RestoreResult(unlockRestored: false)));
    });

    test('SealProduct は値等価', () {
      const a = SealProduct(
        id: kSealSingleProductId,
        kind: SealProductKind.single,
        title: 't',
        description: 'd',
        price: '¥1',
      );
      const b = SealProduct(
        id: kSealSingleProductId,
        kind: SealProductKind.single,
        title: 't',
        description: 'd',
        price: '¥1',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  // ---------------------------------------------------------------------------
  // NoopPurchaseService
  // ---------------------------------------------------------------------------
  group('NoopPurchaseService', () {
    test('商品は空・購入はエラー・復元は未復元', () async {
      const noop = noopPurchaseService;
      expect(await noop.products(), isEmpty);
      final r = await noop.buy(kSealSingleProductId);
      expect(r.status, PurchaseStatus.error);
      final rr = await noop.restore();
      expect(rr.unlockRestored, isFalse);
    });
  });
}
