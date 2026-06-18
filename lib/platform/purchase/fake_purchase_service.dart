import 'package:specimen_box/domain/purchase/seal_entitlement.dart';
import 'package:specimen_box/platform/purchase/purchase_service.dart';

/// テスト・開発用のインメモリ [PurchaseService] 実装。
///
/// 実際のストア通信は一切行わず、注入された設定に従って
/// 商品一覧・購入結果・復元結果を返す。
///
/// ### テスト向け注入 API
/// - [products] が返す商品: [availableProducts]（デフォルトは3商品の既定セット）。
/// - [buy] の結果: [nextPurchaseStatus]（デフォルト [PurchaseStatus.success]）。
/// - [restore] の結果: [restoreUnlock]（デフォルト `false`）。
/// - 呼び出し記録: [buyCalls]・[restoreCallCount] で副作用を検証できる。
final class FakePurchaseService implements PurchaseService {
  /// コンストラクタ。
  ///
  /// [availableProducts] を渡さない場合は3商品（単品/パック/アンロック）の
  /// 既定セット [defaultProducts] を返す。
  FakePurchaseService({
    List<SealProduct>? availableProducts,
    this.nextPurchaseStatus = PurchaseStatus.success,
    this.restoreUnlock = false,
  }) : availableProducts = availableProducts ?? defaultProducts;

  /// [products] が返す商品一覧。テストで差し替え可能。
  List<SealProduct> availableProducts;

  /// [buy] が返す結果種別。テストで成功/キャンセル/失敗を切り替える。
  ///
  /// [PurchaseStatus.success] のときは購入された商品の [SealProductKind] を含む
  /// 成功結果を返す（未知 productId はエラーになる）。
  PurchaseStatus nextPurchaseStatus;

  /// [restore] が返すアンロック復元有無。テストで切り替える。
  bool restoreUnlock;

  /// [buy] に渡された productId の記録（呼び出し順）。
  final List<String> buyCalls = [];

  /// [restore] が呼ばれた回数。
  int restoreCallCount = 0;

  // ---------------------------------------------------------------------------
  // PurchaseService インターフェース実装
  // ---------------------------------------------------------------------------

  @override
  Future<List<SealProduct>> products() async =>
      List.unmodifiable(availableProducts);

  @override
  Future<PurchaseResult> buy(String productId) async {
    buyCalls.add(productId);
    switch (nextPurchaseStatus) {
      case PurchaseStatus.canceled:
        return const PurchaseResult.canceled();
      case PurchaseStatus.error:
        return const PurchaseResult.error('fake error');
      case PurchaseStatus.success:
        final kind = sealProductKindFromId(productId);
        if (kind == null) {
          return PurchaseResult.error('unknown productId: $productId');
        }
        return PurchaseResult.success(productId, kind);
    }
  }

  @override
  Future<RestoreResult> restore() async {
    restoreCallCount++;
    return RestoreResult(unlockRestored: restoreUnlock);
  }

  // ---------------------------------------------------------------------------
  // 既定の商品セット
  // ---------------------------------------------------------------------------

  /// 開発・テスト用の既定3商品（表示順 = 単品 → パック → アンロック）。
  ///
  /// 価格はあくまでダミー表示文字列（本番はストア配信値を使う）。
  static final List<SealProduct> defaultProducts = List.unmodifiable(const [
    SealProduct(
      id: kSealSingleProductId,
      kind: SealProductKind.single,
      title: '封印（1個）',
      description: 'この化石を1つ封印します',
      price: '¥160',
    ),
    SealProduct(
      id: kSealPack5ProductId,
      kind: SealProductKind.pack5,
      title: '封印パック（5個）',
      description: '封印クレジットを5つまとめて獲得',
      price: '¥600',
    ),
    SealProduct(
      id: kSealUnlockProductId,
      kind: SealProductKind.unlock,
      title: '封印アンロック',
      description: '以後すべての化石を封印し放題',
      price: '¥1,200',
    ),
  ]);
}
