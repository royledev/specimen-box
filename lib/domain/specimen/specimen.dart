/// メモリ上の標本ドメインモデル。
///
/// ADR-0011: 標本画像はサーバー配信＋ローカル保存（[imageId]/[localPath]）。
/// 旧ベクター生成（seed/generatorVersion から都度再生成）は廃止した。
///
/// status の扱い:
/// - DBと同じ文字列 'alive' / 'sealed' を domain でも正とする。
/// - [sealed] getter で bool が必要な箇所に対応する。
/// - 封印は一方向（取り消し不可・ADR-0010 決定3）。sealed→alive へ戻す導線は持たない。
class Specimen {
  /// 生成時に付与する一意ID（microsecondsSinceEpoch ベース）。
  final String id;
  final String answer;
  final String questionId;
  final String questionText;
  final String date; // YYYY-MM-DD

  /// 'alive' または 'sealed'。
  final String status;
  final DateTime createdAt;

  /// ADR-0011: サーバー配信画像。未取得（deferred）時は null。
  ///   [imageId]   - サーバー画像ID（UUID）。
  ///   [localPath] - 端末ローカルの保存先パス。
  final String? imageId;
  final String? localPath;

  /// ADR-0017: 画像レア度（1〜5）。サーバー欠損・未取得・旧データ時は null。
  /// 既存の [Rarity]（時刻/誕生日由来）とは別概念。
  final int? imageRarity;

  /// 標本の表示名（サーバー配信・例「怒った扇風機」）。
  /// 未取得（deferred）・旧データ・サーバー欠損時は null。
  final String? name;

  const Specimen({
    required this.id,
    required this.answer,
    required this.questionId,
    required this.questionText,
    required this.date,
    this.status = 'alive',
    required this.createdAt,
    this.imageId,
    this.localPath,
    this.imageRarity,
    this.name,
  });

  /// `status == 'sealed'` のとき true を返す。
  bool get sealed => status == 'sealed';

  /// 一意な id を生成して返す。
  /// microsecondsSinceEpoch を使うことで同一ミリ秒内でも衝突しにくい。
  static String generateId() =>
      DateTime.now().microsecondsSinceEpoch.toString();
}
