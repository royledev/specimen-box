// ExportService — 全標本＋画像バイト＋生年月日を zip に収める（ADR-0014）。
//
// 純 Dart コア（buildExportArchive）を呼ぶだけで IO/プラグイン非依存。
// 実機共有や UI 結線は後続タスクで追加する（ADR-0014 ネイティブ配線フェーズ）。
library;

import 'package:specimen_box/data/repositories/settings_repository.dart';
import 'package:specimen_box/data/repositories/specimen_repository.dart';
import 'package:specimen_box/domain/export/export_archive.dart';
import 'package:specimen_box/platform/image_store/image_store.dart';

/// 全標本・画像バイト・生年月日を zip バイトとして返すサービス（ADR-0014 決定4）。
///
/// 依存はすべてコンストラクタインジェクション。Fake で単体テスト可能。
class ExportService {
  const ExportService({
    required this.specimenRepo,
    required this.imageStore,
    required this.settingsRepo,
  });

  final SpecimenRepository specimenRepo;
  final ImageStore imageStore;
  final SettingsRepository settingsRepo;

  /// 全標本をエクスポートして zip バイトを返す。
  ///
  /// - 各標本の `localPath` を [ImageStore.read] で読む。読めない/null の標本は
  ///   images map に含めない（deferred 状態のまま）。
  /// - 生年月日は [SettingsRepository.getBirthDate] で取得する（未設定は null）。
  Future<List<int>> export() async {
    final rows = await specimenRepo.getAll();

    final images = <String, List<int>>{};
    final exportSpecimens = <ExportSpecimen>[];

    for (final row in rows) {
      // 画像バイトを収集（読めない/未取得はスキップ）。
      List<int>? bytes;
      if (row.localPath != null && row.imageId != null) {
        try {
          bytes = await imageStore.read(row.localPath!);
        } catch (_) {
          // 読み取り失敗は無視してスキップ。
        }
      }

      // bytes がある場合のみ images map に追加し、imageFile を設定する。
      String? imageFile;
      if (row.imageId != null && bytes != null) {
        images[row.imageId!] = bytes;
        // localPath から拡張子を取り出して zip 内パスを組む。
        final ext = _extFromPath(row.localPath ?? '');
        imageFile = ext.isEmpty
            ? 'images/${row.imageId}'
            : 'images/${row.imageId}.$ext';
      }

      exportSpecimens.add(
        ExportSpecimen(
          id: row.id,
          answer: row.answerText,
          questionId: row.questionId,
          questionText: row.questionText,
          date: row.date,
          status: row.status,
          createdAt: row.createdAt,
          imageId: row.imageId,
          imageFile: imageFile,
          imageRarity: row.imageRarity,
          name: row.name,
        ),
      );
    }

    final birthDate = await settingsRepo.getBirthDate();

    return buildExportArchive(
      ExportData(specimens: exportSpecimens, images: images, birthDate: birthDate),
    );
  }

  /// [localPath] から拡張子を取り出す（例 `specimens/abc.webp` → `webp`）。
  /// 拡張子がなければ空文字列。
  static String _extFromPath(String localPath) {
    final name = localPath.split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot >= name.length - 1) return '';
    return name.substring(dot + 1);
  }
}
