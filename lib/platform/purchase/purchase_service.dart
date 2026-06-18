/// 封印 IAP（アプリ内課金）の抽象インターフェース。
///
/// OS 固有の型（in_app_purchase / StoreKit 等）を一切露出させない。
/// シグネチャには [SealProduct]・[PurchaseResult]・[RestoreResult]（自前モデル）と
/// 素の Dart 型のみを使用する（通知層 `notification_service.dart` と同じ方針）。
///
/// iOS 実装は `ios_purchase_service.dart`（T5 で追加）、
/// テスト・開発用のインメモリ実装は `fake_purchase_service.dart` で提供する。
///
/// 設計根拠は ADR-0010 を参照。
library;

import 'package:specimen_box/domain/purchase/seal_entitlement.dart';

// ---------------------------------------------------------------------------
// productId 定数（アプリ側で定数化・ADR-0010 決定1）
// ---------------------------------------------------------------------------

/// 単品封印（消耗型・封印クレジット +1）の productId。
///
/// App Store Connect に登録する商品ID。価格・名称はストア側で設定する。
const String kSealSingleProductId = 'com.royle.specimenbox.seal.single';

/// まとめパック5（消耗型・封印クレジット +5）の productId。
const String kSealPack5ProductId = 'com.royle.specimenbox.seal.pack5';

/// 封印アンロック（非消耗型・以後クレジット消費なしで封印し放題）の productId。
const String kSealUnlockProductId = 'com.royle.specimenbox.seal.unlock';

/// 本アプリが扱う全 productId（表示順 = 単品 → パック → アンロック）。
const List<String> kAllSealProductIds = [
  kSealSingleProductId,
  kSealPack5ProductId,
  kSealUnlockProductId,
];

/// [productId] から対応する [SealProductKind] を返す。
///
/// 未知の productId の場合は null を返す（OS が予期しない商品を返した場合の安全弁）。
SealProductKind? sealProductKindFromId(String productId) {
  return switch (productId) {
    kSealSingleProductId => SealProductKind.single,
    kSealPack5ProductId => SealProductKind.pack5,
    kSealUnlockProductId => SealProductKind.unlock,
    _ => null,
  };
}

/// [SealProductKind] から対応する productId を返す。
String sealProductIdFromKind(SealProductKind kind) {
  return switch (kind) {
    SealProductKind.single => kSealSingleProductId,
    SealProductKind.pack5 => kSealPack5ProductId,
    SealProductKind.unlock => kSealUnlockProductId,
  };
}

// ---------------------------------------------------------------------------
// モデル（OS 非依存）
// ---------------------------------------------------------------------------

/// ストアから取得した封印商品1件を表す軽量モデル。
///
/// OS 固有の型を含まない純粋 Dart クラス。
/// [price] は **ストアが配信するローカライズ済み表示文字列**（例: `"¥160"`）であり、
/// アプリ内に金額をハードコードしない（ADR-0010）。
final class SealProduct {
  const SealProduct({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.price,
  });

  /// productId（[kSealSingleProductId] 等）。
  final String id;

  /// 商品種別（消耗/非消耗の区別と付与内容は [SealProductKind] が表す）。
  final SealProductKind kind;

  /// 表示用タイトル（ストア配信のローカライズ済み文字列）。
  final String title;

  /// 表示用説明（ストア配信のローカライズ済み文字列）。
  final String description;

  /// 表示用価格文字列（ストア配信・ローカライズ済み。例: `"¥160"`）。
  ///
  /// アプリ内に金額をハードコードしないための表示専用フィールド。
  final String price;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SealProduct &&
          id == other.id &&
          kind == other.kind &&
          title == other.title &&
          description == other.description &&
          price == other.price;

  @override
  int get hashCode => Object.hash(id, kind, title, description, price);

  @override
  String toString() =>
      'SealProduct(id: $id, kind: $kind, title: $title, price: $price)';
}

/// 購入処理の結果種別。
enum PurchaseStatus {
  /// 購入成功（エンタイトルメント付与対象）。
  success,

  /// ユーザがキャンセルした（エラーではない）。
  canceled,

  /// 購入失敗（ネットワーク・ストアエラー等）。
  error,
}

/// [PurchaseService.buy] の結果。
///
/// OS 固有の購入詳細・レシート型は出さず、結果種別と購入された商品種別のみを返す。
final class PurchaseResult {
  const PurchaseResult({
    required this.status,
    this.productId,
    this.kind,
    this.message,
  }) : assert(
          status != PurchaseStatus.success || kind != null,
          'success result must carry a non-null kind',
        );

  /// 成功結果を生成する。
  const PurchaseResult.success(this.productId, this.kind)
      : status = PurchaseStatus.success,
        message = null;

  /// キャンセル結果を生成する。
  const PurchaseResult.canceled()
      : status = PurchaseStatus.canceled,
        productId = null,
        kind = null,
        message = null;

  /// エラー結果を生成する。
  const PurchaseResult.error([this.message])
      : status = PurchaseStatus.error,
        productId = null,
        kind = null;

  /// 結果種別。
  final PurchaseStatus status;

  /// 購入された商品の productId（[PurchaseStatus.success] のときのみ非 null）。
  final String? productId;

  /// 購入された商品種別（[PurchaseStatus.success] のときのみ非 null）。
  ///
  /// 呼び出し側はこれを `grant(entitlement, kind)` に渡してエンタイトルメントを加算する。
  final SealProductKind? kind;

  /// エラー時の付随メッセージ（任意・表示/ログ用）。
  final String? message;

  /// 購入が成功したかどうか。
  bool get isSuccess => status == PurchaseStatus.success;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseResult &&
          status == other.status &&
          productId == other.productId &&
          kind == other.kind &&
          message == other.message;

  @override
  int get hashCode => Object.hash(status, productId, kind, message);

  @override
  String toString() =>
      'PurchaseResult(status: $status, productId: $productId, kind: $kind)';
}

/// [PurchaseService.restore] の結果。
///
/// 復元対象は非消耗型アンロック（`seal.unlock`）のみ（消耗型クレジットは復元不可・ADR-0010 決定5）。
final class RestoreResult {
  const RestoreResult({required this.unlockRestored, this.message});

  /// アンロックが復元されたかどうか。`true` なら `seal_unlocked` を true に再設定する。
  final bool unlockRestored;

  /// 付随メッセージ（任意・表示/ログ用）。
  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestoreResult &&
          unlockRestored == other.unlockRestored &&
          message == other.message;

  @override
  int get hashCode => Object.hash(unlockRestored, message);

  @override
  String toString() => 'RestoreResult(unlockRestored: $unlockRestored)';
}

// ---------------------------------------------------------------------------
// インターフェース
// ---------------------------------------------------------------------------

/// 封印 IAP の抽象インターフェース。
///
/// 実装クラスはこのインターフェースを `implements` して提供する。
/// 依存注入（Riverpod provider override 等）でテスト時に [FakePurchaseService] へ差し替える。
abstract interface class PurchaseService {
  /// 購入可能な封印商品の一覧を返す。
  ///
  /// ストアから取得した [SealProduct] を表示順（単品 → パック → アンロック）で返す。
  /// 取得できなかった商品は含めない（空リストもありうる）。
  Future<List<SealProduct>> products();

  /// [productId] の商品を購入する。
  ///
  /// 成功・キャンセル・エラーを [PurchaseResult] で表現する（例外は投げない方針）。
  /// 成功時の [PurchaseResult.kind] を `grant` に渡してエンタイトルメントを加算する。
  Future<PurchaseResult> buy(String productId);

  /// 過去購入を復元する。
  ///
  /// 非消耗型アンロック（`seal.unlock`）のみが復元対象（ADR-0010 決定5）。
  /// 復元結果を [RestoreResult] で返す。
  Future<RestoreResult> restore();
}

/// 何もしない [PurchaseService] 実装（no-op）。
///
/// 非 iOS プラットフォーム（web / 未サポート OS）でのフォールバックや、
/// 購入が不要な画面テストで実購入副作用を完全に排除したい場合に使う。
/// 商品は空・購入は常にエラー・復元は常に未復元を返す。
final class NoopPurchaseService implements PurchaseService {
  const NoopPurchaseService();

  @override
  Future<List<SealProduct>> products() async => const [];

  @override
  Future<PurchaseResult> buy(String productId) async =>
      const PurchaseResult.error('purchase unavailable');

  @override
  Future<RestoreResult> restore() async =>
      const RestoreResult(unlockRestored: false);
}

/// [NoopPurchaseService] の共有インスタンス。
const NoopPurchaseService noopPurchaseService = NoopPurchaseService();
