// SpecimenRepository — SpecimensDao の上のリポジトリ層。
//
// 役割:
// - DAO を直接公開せず、domain が必要とするメタ情報のみを受け取る / 返す。
// - SpecimenParams は受け取らない（seed/generatorVersion 等メタのみ）。
// - domain↔DB行のマッピングはこのファイル内に閉じる。
//
// seal の仕様（ADR-0010 決定3: 封印は一方向・取り消し不可）:
// - 現在の status を findById で読み、alive→sealed に**一方向**で更新する。
// - 既に sealed の場合は何もせず true を返す（冪等）。
// - 存在しない id を渡した場合は何もせずに false を返す（silent no-op）。
import 'package:specimen_box/data/db/app_database.dart';

/// 標本を永続化するリポジトリ。
///
/// 依存: [SpecimensDao]（コンストラクタインジェクション）。
class SpecimenRepository {
  const SpecimenRepository(this._dao);

  final SpecimensDao _dao;

  /// 標本を1件保存する（id 衝突時は upsert）。
  ///
  /// 引数は domain の値。SpecimenParams は受け取らない。
  Future<void> save({
    required String id,
    required String date,
    required String questionId,
    required String questionText,
    required String answerText,
    required String status,
    required DateTime createdAt,
    String? imageId,
    String? localPath,
    int? imageRarity,
    String? name,
  }) async {
    await _dao.insertSpecimen(
      SpecimensCompanion(
        id: Value(id),
        date: Value(date),
        questionId: Value(questionId),
        questionText: Value(questionText),
        answerText: Value(answerText),
        status: Value(status),
        createdAt: Value(createdAt),
        // ADR-0011: 未取得（deferred）時は null。
        imageId: Value(imageId),
        localPath: Value(localPath),
        // ADR-0017: サーバー配信の画像レア度（1〜5）。欠損時は null。
        imageRarity: Value(imageRarity),
        // 標本の表示名（サーバー配信）。欠損時は null。
        name: Value(name),
      ),
    );
  }

  /// 全件を createdAt 降順（新しい順）で返す。
  Future<List<Specimen>> getAll() => _dao.getAllSpecimens();

  /// [id] に一致する標本を返す。見つからなければ null。
  Future<Specimen?> findById(String id) => _dao.findById(id);

  /// 画像未取得（deferred）の標本を返す（ADR-0011 決定6・オンライン復帰時の再取得用）。
  Future<List<Specimen>> findDeferred() => _dao.findDeferred();

  /// [id] の標本に取得済み画像（[imageId]/[localPath]/[rarity]/[name]）を設定する（deferred fetch 確定）。
  Future<void> setImage(String id, String imageId, String localPath,
          {int? rarity, String? name}) =>
      _dao.updateImage(id, imageId, localPath, rarity: rarity, name: name);

  /// [id] の標本を sealed に**一方向**で更新する（ADR-0010 決定3: 封印は永久・解除不可）。
  ///
  /// - alive → sealed に更新し true を返す。
  /// - 既に sealed の場合は何もせず true を返す（冪等）。
  /// - 該当 id が存在しない場合は false を返す（silent no-op）。
  Future<bool> seal(String id) async {
    final row = await _dao.findById(id);
    if (row == null) return false;
    if (row.status == 'sealed') return true;
    await _dao.updateStatus(id, 'sealed');
    return true;
  }
}
