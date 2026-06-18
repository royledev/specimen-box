/// 画像レア度（サーバー配信・1〜5）のドメインヘルパー。
///
/// サーバー（specimen-box-server）が `images/draw` で画像ごとに割り当てて返す
/// 希少度（1〜5・分布 50/30/14/5/1%）を表す。imageId から決定論的に決まる。
///
/// 注意: これは **標本が「いつ作られたか」由来**の [Rarity]（`rarity.dart`・
/// `rareBirthday`/`rareMidnight`）とは **別概念**。混同しないこと（ADR-0017）。
library;

/// 画像レア度の最小値（★1）。
const int kMinImageRarity = 1;

/// 画像レア度の最大値（★5）。
const int kMaxImageRarity = 5;

/// [rarity] が有効な画像レア度（1〜5）なら true。
///
/// null・範囲外（サーバー欠損・旧データ・不正値）は false。表示前のガードに使う。
bool isValidImageRarity(int? rarity) =>
    rarity != null && rarity >= kMinImageRarity && rarity <= kMaxImageRarity;

/// 画像レア度を★文字列にする（例: 3 → `'★★★☆☆'`）。
///
/// 呼び出し側は事前に [isValidImageRarity] でガードする想定（null は渡さない）。
/// 本関数は防御的に、範囲外を [kMinImageRarity]〜[kMaxImageRarity] に clamp する。
String imageRarityStars(int rarity) {
  final r = rarity.clamp(kMinImageRarity, kMaxImageRarity);
  return '★' * r + '☆' * (kMaxImageRarity - r);
}
