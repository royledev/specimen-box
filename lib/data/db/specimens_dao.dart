// Specimens テーブルの DAO（Data Access Object）。
//
// 提供する操作:
//   insertSpecimen  - 1件挿入
//   getAllSpecimens - 全件取得（createdAt 降順 = 新しい順）
//   findById        - id で1件取得（なければ null）
//   updateStatus    - status を書き換える汎用プリミティブ（封印 alive→sealed ほか）。
//   findDeferred    - 画像未取得（local_path IS NULL）の行（deferred 再取得用）。
//   updateImage     - image_id / local_path を更新（deferred fetch 確定時）。
//                     封印の「一方向」制約は上位の SpecimenRepository.seal が担う。
library;

import 'package:drift/drift.dart';

import 'app_database.dart';

part 'specimens_dao.g.dart';

@DriftAccessor(tables: [Specimens])
class SpecimensDao extends DatabaseAccessor<AppDatabase>
    with _$SpecimensDaoMixin {
  SpecimensDao(super.db);

  /// 1件挿入する。id が衝突した場合は置き換える（upsert）。
  Future<void> insertSpecimen(SpecimensCompanion companion) =>
      into(specimens).insertOnConflictUpdate(companion);

  /// 全件を createdAt 降順（新しい順）で返す。
  Future<List<Specimen>> getAllSpecimens() =>
      (select(specimens)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  /// [id] に一致する行を返す。見つからなければ null。
  Future<Specimen?> findById(String id) =>
      (select(specimens)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// [id] の行の status を [newStatus] に更新する。
  Future<void> updateStatus(String id, String newStatus) =>
      (update(specimens)..where((t) => t.id.equals(id))).write(
        SpecimensCompanion(status: Value(newStatus)),
      );

  /// 画像未取得（local_path IS NULL）の行を返す（deferred 再取得用・ADR-0011 決定6）。
  ///
  /// プール枯渇で imageId=null のまま保存された行も local_path IS NULL なので対象に含む
  /// （オンライン復帰時に新規抽選で確定させるため意図的）。
  Future<List<Specimen>> findDeferred() =>
      (select(specimens)..where((t) => t.localPath.isNull())).get();

  /// [id] の行の image_id / local_path / image_rarity を更新する（deferred fetch 確定時）。
  Future<void> updateImage(
    String id,
    String imageId,
    String localPath, {
    int? rarity,
    String? name,
  }) =>
      (update(specimens)..where((t) => t.id.equals(id))).write(
        SpecimensCompanion(
          imageId: Value(imageId),
          localPath: Value(localPath),
          // rarity / name が null（サーバー欠損・API バージョン差）のときは既存値を
          // NULL で上書きしない（Value.absent = 「書かない」）。
          imageRarity: rarity == null ? const Value.absent() : Value(rarity),
          name: name == null ? const Value.absent() : Value(name),
        ),
      );
}
