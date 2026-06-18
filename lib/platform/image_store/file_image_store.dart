// ImageStore の dart:io + path_provider 実装（本番ネイティブ）。
//
// アプリのドキュメント領域配下 `specimens/` にファイル保存する。
// テストでは FakeImageStore を使う（このファイルは本番ネイティブ実行時のみ呼ばれる）。
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:specimen_box/platform/image_store/image_store.dart';

/// ドキュメント領域 `specimens/<imageId>.<format>` に保存する [ImageStore] 実装。
///
/// 保存・読込ともに**ドキュメント領域からの相対パス**（例 `specimens/<id>.webp`）で扱う。
/// iOS は再インストール/再ビルドのたびにコンテナの絶対パスが変わるため、絶対パスを DB に
/// 保存すると再ビルド後に解決できなくなる。相対パスで持ち、読込時に現在のコンテナへ解決する。
class FileImageStore implements ImageStore {
  const FileImageStore();

  static const String _subdir = 'specimens';

  Future<Directory> _ensureDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _subdir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 保存パス（相対 or 旧・絶対）を**現在のコンテナ**の絶対パスへ解決する。
  ///
  /// - 相対パス（`specimens/<file>`）: 現在のドキュメント領域に結合する。
  /// - 旧・絶対パス: コンテナ UUID が変わって解決不能なので、**ファイル名だけ**を取り出して
  ///   現在の `specimens/` 配下へ再解決する（再ビルド後の自己修復。バイト実体は残っている）。
  Future<String> _resolve(String stored) async {
    final base = await getApplicationDocumentsDirectory();
    final rel = p.isAbsolute(stored)
        ? p.join(_subdir, p.basename(stored))
        : stored;
    return p.join(base.path, rel);
  }

  @override
  Future<String> save(String imageId, List<int> bytes, String format) async {
    final dir = await _ensureDir();
    // imageId はファイル名としてそのまま使われる。インポート zip 等の信頼できない
    // 入力源（manifest.json の imageId）が `../` や絶対パス・スラッシュを含むと
    // specimens/ 外への任意ファイル書き込み（パストラバーサル）になりうるため、
    // 末尾要素のみを取り出し英数字・ハイフンに正規化する（CWE-22 対策）。
    final safeId = p
        .basename(imageId)
        .replaceAll(RegExp(r'[^a-zA-Z0-9\-]'), '');
    if (safeId.isEmpty) {
      throw ArgumentError.value(imageId, 'imageId', 'invalid image id');
    }
    // format を拡張子としてファイル名に使うため、英数字のみに正規化する
    // （サーバーが 'image/webp' 等を返してもスラッシュ混入＝サブディレクトリ化を防ぐ）。
    final ext = format.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final fileName = ext.isEmpty ? safeId : '$safeId.$ext';
    await File(p.join(dir.path, fileName)).writeAsBytes(bytes, flush: true);
    // DB には**相対パス**を返す（絶対パスは再ビルドで無効化するため）。
    return p.join(_subdir, fileName);
  }

  @override
  Future<List<int>?> read(String localPath) async {
    final file = File(await _resolve(localPath));
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<bool> exists(String localPath) async =>
      File(await _resolve(localPath)).exists();
}
