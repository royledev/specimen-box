// 封印エンタイトルメントの純粋モデルと純粋関数群。
//
// OS 非依存・イミュータブル。設計根拠は ADR-0010 を参照。
// 「封印できる権利」= `unlocked`（非消耗アンロック所有）または `credits > 0`（消耗クレジット残あり）。

/// 封印 IAP の商品種別。
///
/// - [single]: 消耗型・封印クレジット +1。
/// - [pack5]: 消耗型・封印クレジット +5（まとめ封印）。
/// - [unlock]: 非消耗型・封印アンロック（以後クレジット消費なしで封印し放題）。
///
/// ADR-0010 決定1 を参照。
enum SealProductKind { single, pack5, unlock }

/// 封印エンタイトルメント（封印できる権利の状態）。
///
/// - [unlocked]: 非消耗型アンロック所有フラグ。`true` の場合はクレジット消費なしで封印し放題。
/// - [credits]: 消耗型購入で貯まる封印クレジット残。0 未満はクランプされ 0 として扱われる。
///
/// イミュータブル。値等価（`==`/`hashCode`）を実装。
/// エンタイトルメントの変更は [copyWith]、封印可否の判定は [canSeal]、
/// 封印消費後の状態は [applySeal]、購入付与は [grant] を使用する。
///
/// ADR-0010 決定2 を参照。
class SealEntitlement {
  /// 非消耗型アンロック所有フラグ。
  final bool unlocked;

  /// 消耗型封印クレジット残（0 以上を保証）。
  final int credits;

  /// [credits] は 0 未満の場合に 0 へクランプされる。
  /// 負値を渡してもエラーにはならず、安全に 0 として扱われる。
  SealEntitlement({this.unlocked = false, int credits = 0})
      : credits = credits < 0 ? 0 : credits;

  /// フィールドを選択的に上書きした新しい [SealEntitlement] を返す。
  ///
  /// [credits] の負値クランプは新しいインスタンス生成時にも適用される。
  SealEntitlement copyWith({bool? unlocked, int? credits}) {
    return SealEntitlement(
      unlocked: unlocked ?? this.unlocked,
      credits: credits ?? this.credits,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SealEntitlement &&
        other.unlocked == unlocked &&
        other.credits == credits;
  }

  @override
  int get hashCode => Object.hash(unlocked, credits);

  @override
  String toString() =>
      'SealEntitlement(unlocked: $unlocked, credits: $credits)';
}

/// 封印可否を判定する純粋関数。
///
/// アンロック所有（[SealEntitlement.unlocked] が `true`）またはクレジット残あり
/// （[SealEntitlement.credits] > 0）のとき `true` を返す。
///
/// ADR-0010: `canSeal(unlocked, credits) = unlocked || credits > 0`
bool canSeal(SealEntitlement e) => e.unlocked || e.credits > 0;

/// 封印1回の消費後の [SealEntitlement] を返す純粋関数。
///
/// - [e.unlocked] が `true` の場合: クレジットを消費しないため [e] を不変で返す。
/// - [e.credits] > 0 の場合: `credits - 1` とした新しい [SealEntitlement] を返す。
/// - [canSeal] が `false`（unlocked=false かつ credits=0）の場合: 消費できないため
///   [e] を不変で返す。呼び出し側は事前に [canSeal] を確認することを**契約**とする。
///   安全側で例外は投げず、状態をそのまま返す。
///
/// ADR-0010 決定2 および決定4 を参照。
SealEntitlement applySeal(SealEntitlement e) {
  if (e.unlocked) return e;
  if (e.credits > 0) return e.copyWith(credits: e.credits - 1);
  // canSeal が false のまま呼ばれた場合: 安全側で不変返し。
  // 呼び出し側が canSeal を先に確認していることを前提とする。
  return e;
}

/// 購入付与後の [SealEntitlement] を返す純粋関数。
///
/// - [SealProductKind.single]: [SealEntitlement.credits] を +1 する。
/// - [SealProductKind.pack5]: [SealEntitlement.credits] を +5 する。
/// - [SealProductKind.unlock]: [SealEntitlement.unlocked] を `true` にする（credits は据え置き）。
///
/// ADR-0010 決定1 を参照。
SealEntitlement grant(SealEntitlement e, SealProductKind kind) {
  return switch (kind) {
    SealProductKind.single => e.copyWith(credits: e.credits + 1),
    SealProductKind.pack5 => e.copyWith(credits: e.credits + 5),
    SealProductKind.unlock => e.copyWith(unlocked: true),
  };
}
