// 標本画像の取得＋ローカル保存サービス（ADR-0011 決定3/4/6）。
//
// 回答時に「ランダム画像を1枚」取得し、URL からバイトをDL → ImageStore に保存して
// `image_id`/`local_path` を返す。プール枯渇・取得失敗は **deferred**（local_path=null）として返し、
// 呼び出し側は回答を先に保存して後で再取得する（決定6）。
library;

import 'package:specimen_box/platform/api/specimen_api.dart';
import 'package:specimen_box/platform/image_store/image_downloader.dart';
import 'package:specimen_box/platform/image_store/image_store.dart';

/// 画像取得の結果。
///
/// - [isFetched]（[localPath] と [imageId] が揃う）: 取得・保存成功。
/// - [exhausted]: プール枯渇（全所有済み）。
/// - いずれでもない（全 null・exhausted=false）: deferred（ネット無/取得失敗。後で再取得）。
class AcquiredImage {
  const AcquiredImage({
    this.imageId,
    this.localPath,
    this.rarity,
    this.name,
    this.exhausted = false,
  });

  final String? imageId;
  final String? localPath;

  /// 画像レア度（1〜5・ADR-0017）。サーバー欠損時は null。
  final int? rarity;

  /// 標本の表示名。サーバー欠損時は null。
  final String? name;
  final bool exhausted;

  bool get isFetched => imageId != null && localPath != null;

  /// deferred（未取得・後で再取得）。
  static const AcquiredImage deferred = AcquiredImage();
}

/// `images/draw` → バイトDL → ローカル保存 を束ねるサービス。
class SpecimenImageService {
  const SpecimenImageService({
    required this.api,
    required this.store,
    required this.downloader,
  });

  final SpecimenApi api;
  final ImageStore store;
  final ImageDownloader downloader;

  /// ランダム画像を1枚取得して保存する。[owned] は所有 image_id 集合（除外集合）。
  Future<AcquiredImage> acquire({required List<String> owned}) async {
    final ImageDrawResult result;
    try {
      result = await api.drawImage(owned: owned);
    } catch (_) {
      // ネット無/API失敗 → deferred（回答は呼び出し側で先に保存される）。
      return AcquiredImage.deferred;
    }

    if (result.exhausted || result.image == null) {
      return const AcquiredImage(exhausted: true);
    }

    final img = result.image!;
    try {
      final bytes = await downloader.download(img.url);
      final localPath = await store.save(img.id, bytes, img.format);
      return AcquiredImage(
        imageId: img.id,
        localPath: localPath,
        rarity: img.rarity,
        name: img.name,
      );
    } catch (_) {
      // 抽選はできたが DL/保存に失敗 → deferred（imageId は持ち越さず次回新規抽選）。
      return AcquiredImage.deferred;
    }
  }
}
