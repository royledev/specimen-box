import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:specimen_box/domain/purchase/seal_entitlement.dart';
// 自前の PurchaseStatus は in_app_purchase の同名 enum と衝突するため hide する
// （本ファイルでは自前 enum を直接参照せず PurchaseResult 等の生成子のみ使う）。
import 'package:specimen_box/platform/purchase/purchase_service.dart'
    hide PurchaseStatus;

/// iOS（StoreKit）向け [PurchaseService] 実装（skeleton）。
///
/// `in_app_purchase` を使い、OS 固有の型（[ProductDetails]・[PurchaseDetails] 等）を
/// このファイル内に完全に閉じ込める（IF シグネチャには漏らさない・通知層と同方針）。
///
/// ### ストリーム → Future のブリッジ
/// `in_app_purchase` の購入結果は [InAppPurchase.purchaseStream] に非同期で流れる。
/// 本実装は productId 単位の [Completer] を保持し、ストリームで該当 productId の
/// 購入/キャンセル/失敗イベントが届いた時点で [buy] の Future を解決する。
///
/// ### 注意（skeleton）
/// 実 StoreKit の購入/復元の最終検証は **Sandbox 実機**（App Store Connect で
/// 商品登録・有料デベロッパ契約・Sandbox テスターが前提）。本実装はコンパイル可・
/// analyze クリーンまでを担保し、e2e は別途 Sandbox で確認する（ADR-0010 決定6）。
final class IosPurchaseService implements PurchaseService {
  IosPurchaseService._(this._iap);

  /// インスタンスを生成し、購入ストリームの購読を開始する。
  ///
  /// [iap] を渡さない場合は [InAppPurchase.instance] を使う。
  /// アプリ終了時/Provider dispose 時に [dispose] を呼ぶこと。
  static IosPurchaseService create([InAppPurchase? iap]) {
    final svc = IosPurchaseService._(iap ?? InAppPurchase.instance);
    svc._subscribe();
    return svc;
  }

  final InAppPurchase _iap;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// productId 単位の進行中購入を待つ Completer。
  final Map<String, Completer<PurchaseResult>> _pendingBuys = {};

  /// [products] で取得済みの ProductDetails キャッシュ（[buy] で再利用）。
  final Map<String, ProductDetails> _detailsCache = {};

  /// 直近の [restore] でアンロックが復元されたか。
  bool _restoredUnlock = false;

  void _subscribe() {
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object e) {
        // ストリームがエラー終了すると以降イベントは来ないため、
        // 進行中の全 buy を失敗で解決して Future のハングを防ぐ。
        _failAllPending('purchase stream error: $e');
      },
    );
  }

  /// 購読を解除する。Provider の dispose で呼ぶ。
  ///
  /// 進行中の buy Completer を全て失敗で解決してから破棄する（ハング防止）。
  void dispose() {
    _failAllPending('purchase service disposed');
    _sub?.cancel();
    _sub = null;
  }

  /// 進行中の全 buy Completer を失敗で解決してクリアする。
  void _failAllPending(String message) {
    // values をスナップショット化して反復中の再入変更（将来）に備える。
    for (final completer in _pendingBuys.values.toList()) {
      if (!completer.isCompleted) {
        completer.complete(PurchaseResult.error(message));
      }
    }
    _pendingBuys.clear();
  }

  // ---------------------------------------------------------------------------
  // 購入ストリームのハンドリング
  // ---------------------------------------------------------------------------

  void _onPurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          // 進行中。何もしない。
          break;
        case PurchaseStatus.purchased:
          if (p.pendingCompletePurchase) {
            unawaited(_iap.completePurchase(p));
          }
          final kind = sealProductKindFromId(p.productID);
          if (kind != null) {
            _resolveBuy(p.productID, PurchaseResult.success(p.productID, kind));
          }
        case PurchaseStatus.restored:
          if (p.pendingCompletePurchase) {
            unawaited(_iap.completePurchase(p));
          }
          final restoredKind = sealProductKindFromId(p.productID);
          // 復元対象は非消耗アンロックのみ（ADR-0010 決定5）。
          if (restoredKind == SealProductKind.unlock) {
            _restoredUnlock = true;
          }
          // 既所有の非消耗品を buy() で再購入リクエストすると StoreKit は
          // purchased ではなく restored を返す。該当 buy の Completer を成功で解決する
          // （restore() 経由の restored は進行中 buy が無いため _resolveBuy は no-op）。
          if (restoredKind != null) {
            _resolveBuy(
              p.productID,
              PurchaseResult.success(p.productID, restoredKind),
            );
          }
        case PurchaseStatus.canceled:
          _resolveBuy(p.productID, const PurchaseResult.canceled());
        case PurchaseStatus.error:
          _resolveBuy(p.productID, PurchaseResult.error(p.error?.message));
      }
    }
  }

  void _resolveBuy(String productId, PurchaseResult result) {
    final completer = _pendingBuys.remove(productId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
  }

  // ---------------------------------------------------------------------------
  // PurchaseService インターフェース実装
  // ---------------------------------------------------------------------------

  @override
  Future<List<SealProduct>> products() async {
    if (!await _iap.isAvailable()) return const [];
    final response = await _iap.queryProductDetails(kAllSealProductIds.toSet());
    final products = <SealProduct>[];
    for (final pd in response.productDetails) {
      final kind = sealProductKindFromId(pd.id);
      if (kind == null) continue; // 未知商品はスキップ（安全弁）。
      _detailsCache[pd.id] = pd;
      products.add(
        SealProduct(
          id: pd.id,
          kind: kind,
          title: pd.title,
          description: pd.description,
          price: pd.price, // ストア配信のローカライズ済み表示文字列。
        ),
      );
    }
    // 表示順（単品 → パック → アンロック）に整列。
    products.sort(
      (a, b) => kAllSealProductIds
          .indexOf(a.id)
          .compareTo(kAllSealProductIds.indexOf(b.id)),
    );
    return products;
  }

  @override
  Future<PurchaseResult> buy(String productId) async {
    final kind = sealProductKindFromId(productId);
    if (kind == null) {
      return PurchaseResult.error('unknown productId: $productId');
    }

    // ProductDetails をキャッシュ or 単発クエリで取得。
    var details = _detailsCache[productId];
    if (details == null) {
      final response = await _iap.queryProductDetails({productId});
      if (response.productDetails.isEmpty) {
        return PurchaseResult.error('product not found: $productId');
      }
      details = response.productDetails.first;
      _detailsCache[productId] = details;
    }

    // 同一 productId の購入が進行中なら多重起動しない（Completer リーク防止）。
    if (_pendingBuys.containsKey(productId)) {
      return PurchaseResult.error('purchase already in progress: $productId');
    }

    final completer = Completer<PurchaseResult>();
    _pendingBuys[productId] = completer;

    final param = PurchaseParam(productDetails: details);
    try {
      // buyConsumable/buyNonConsumable は「購入リクエスト送信に成功したか」を返す。
      // false の場合は以降ストリームイベントが来ないため Completer を片付ける。
      final sent = kind == SealProductKind.unlock
          ? await _iap.buyNonConsumable(purchaseParam: param) // 非消耗型
          : await _iap.buyConsumable(purchaseParam: param); // 消耗型(single/pack5)
      if (!sent) {
        _pendingBuys.remove(productId);
        return PurchaseResult.error('purchase initiation failed: $productId');
      }
    } catch (e) {
      _pendingBuys.remove(productId);
      return PurchaseResult.error(e.toString());
    }

    // 購入結果はストリーム経由で _resolveBuy により解決される。
    return completer.future;
  }

  @override
  Future<RestoreResult> restore() async {
    _restoredUnlock = false;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      return RestoreResult(unlockRestored: false, message: e.toString());
    }
    // 復元イベントはストリームに非同期到着する。終端通知が無いため短時間待って
    // 結果を確定させる（skeleton）。
    // TODO(sandbox): 2秒では不足する可能性あり。実機で StoreKit の
    // paymentQueueRestoreCompletedTransactionsFinished 完了通知を待つ設計に変更する。
    await Future<void>.delayed(const Duration(seconds: 2));
    return RestoreResult(unlockRestored: _restoredUnlock);
  }
}
