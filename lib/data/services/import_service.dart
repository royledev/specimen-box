// ImportService — zip バイトから標本・画像・生年月日をマージインポート（ADR-0014）。
//
// 方針（ADR-0014 決定3）:
// - 未知 id の標本のみ追加。既存 id はスキップ（既存データを壊さない・冪等）。
// - 画像バイトがあれば ImageStore.save → local_path を設定。なければ deferred（local_path=null）。
// - 生年月日は現在未設定のときのみ manifest 値で補完（既存設定は上書きしない）。
library;

import 'package:specimen_box/data/repositories/settings_repository.dart';
import 'package:specimen_box/data/repositories/specimen_repository.dart';
import 'package:specimen_box/domain/export/export_archive.dart';
import 'package:specimen_box/platform/image_store/image_store.dart';

/// [import_] 呼び出しの結果サマリ。
class ImportResult {
  const ImportResult({
    required this.added,
    required this.skipped,
    required this.imagesRestored,
    required this.birthDateRestored,
    this.failed = 0,
  });

  /// 追加された標本数（未知 id）。
  final int added;

  /// スキップされた標本数（既存 id・重複）。
  final int skipped;

  /// 画像バイトを復元できた標本数。
  final int imagesRestored;

  /// 生年月日を manifest 値で補完したか（既存設定がなく manifest に値があった場合 true）。
  final bool birthDateRestored;

  /// DB 保存に失敗した標本数（容量不足・制約違反等）。失敗してもインポートは継続する。
  final int failed;
}

/// zip バイトからマージインポートを行うサービス（ADR-0014 決定3/4）。
///
/// 依存はすべてコンストラクタインジェクション。Fake で単体テスト可能。
class ImportService {
  const ImportService({
    required this.specimenRepo,
    required this.imageStore,
    required this.settingsRepo,
  });

  final SpecimenRepository specimenRepo;
  final ImageStore imageStore;
  final SettingsRepository settingsRepo;

  /// [zipBytes] を解析し、標本・画像・生年月日をマージインポートして [ImportResult] を返す。
  ///
  /// - 壊れた zip/manifest は [ExportManifestException] または [ExportVersionException] を
  ///   そのまま伝播させる（呼び出し側が UI でエラー提示できるよう）。
  Future<ImportResult> import(List<int> zipBytes) async {
    final data = parseExportArchive(zipBytes);

    // ── 既存 id の集合を取得（スキップ判定用）──
    // getAll() → id 抽出。標本数は通常数百件以内なので問題ない。
    final existingRows = await specimenRepo.getAll();
    final existingIds = {for (final r in existingRows) r.id};

    int added = 0;
    int skipped = 0;
    int imagesRestored = 0;
    int failed = 0;

    for (final s in data.specimens) {
      // 既存 id はスキップ。
      if (existingIds.contains(s.id)) {
        skipped++;
        continue;
      }

      // 画像バイトの保存（バイトがある場合のみ）。
      String? localPath;
      if (s.imageId != null && data.images.containsKey(s.imageId)) {
        final bytes = data.images[s.imageId]!;
        try {
          // format は imageFile パスから拡張子を推定する。
          final format = _extFromImageFile(s.imageFile ?? '');
          localPath = await imageStore.save(s.imageId!, bytes, format);
          imagesRestored++;
        } catch (_) {
          // 画像保存失敗は deferred のまま（localPath = null）。
        }
      }
      // imageId はあるが bytes がない場合: deferred（localPath = null）。

      try {
        await specimenRepo.save(
          id: s.id,
          date: s.date,
          questionId: s.questionId,
          questionText: s.questionText,
          answerText: s.answer,
          status: s.status,
          createdAt: s.createdAt,
          imageId: s.imageId,
          localPath: localPath,
          imageRarity: s.imageRarity,
          name: s.name,
        );
        added++;
      } catch (_) {
        // DB 保存失敗（容量不足・制約違反等）。後続標本のインポートは継続する。
        // 直前に保存した画像バイトは孤立しうるが無害（未参照ファイル）。
        failed++;
      }
    }

    // ── 生年月日の補完（未設定のときのみ）──
    bool birthDateRestored = false;
    if (data.birthDate != null) {
      final current = await settingsRepo.getBirthDate();
      if (current == null) {
        await settingsRepo.setBirthDate(data.birthDate!);
        birthDateRestored = true;
      }
    }

    return ImportResult(
      added: added,
      skipped: skipped,
      imagesRestored: imagesRestored,
      birthDateRestored: birthDateRestored,
      failed: failed,
    );
  }

  /// [imageFile]（例 `images/uuid.webp`）から拡張子を取り出す。
  /// なければ空文字列（ImageStore.save がフォールバックする）。
  static String _extFromImageFile(String imageFile) {
    final name = imageFile.split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot >= name.length - 1) return '';
    return name.substring(dot + 1);
  }
}
