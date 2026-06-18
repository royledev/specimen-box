// FileImageStore の相対パス保存・再ビルド後の自己修復を検証する回帰テスト。
//
// 実機バグ（2026-06-13）: iOS はアプリ再ビルド/再インストールのたびにドキュメント領域の
// 絶対パス（コンテナ UUID）が変わるため、絶対パスを DB に保存すると再ビルド後に画像が
// 解決できず表示されなくなる（バイト実体は新コンテナに残っているのに出ない）。
// FileImageStore は**相対パス**で保存し、読込時に現在のコンテナへ解決する。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:specimen_box/platform/image_store/file_image_store.dart';

/// ドキュメント領域を差し替え可能にする path_provider のテスト用実装。
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.documentsPath);

  /// getApplicationDocumentsDirectory() が返すパス。再ビルド模擬で差し替える。
  String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late _FakePathProvider provider;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fimg_test');
    provider = _FakePathProvider(p.join(tmp.path, 'containerA', 'Documents'));
    PathProviderPlatform.instance = provider;
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('FileImageStore', () {
    test('save は絶対パスでなく specimens/ 配下の相対パスを返す', () async {
      const store = FileImageStore();
      final path = await store.save('img-1', [1, 2, 3], 'webp');
      expect(p.isAbsolute(path), isFalse);
      expect(path, p.join('specimens', 'img-1.webp'));
    });

    test('save → read 往復一致・exists=true（相対パスで解決）', () async {
      const store = FileImageStore();
      final path = await store.save('img-1', [1, 2, 3], 'webp');
      expect(await store.read(path), [1, 2, 3]);
      expect(await store.exists(path), isTrue);
    });

    test('format のスラッシュは除去されサブディレクトリ化しない', () async {
      const store = FileImageStore();
      final path = await store.save('img-2', [9], 'image/webp');
      expect(path, p.join('specimens', 'img-2.imagewebp'));
      expect(await store.read(path), [9]);
    });

    test('再ビルドでコンテナが変わっても相対パスなら読める（バグ再現の核）',
        () async {
      const store = FileImageStore();
      // 旧コンテナで保存。
      final path = await store.save('img-1', [1, 2, 3], 'webp');

      // 再ビルド模擬: ドキュメント領域を新コンテナへ。iOS では中身（specimens/）は
      // 引き継がれるので、旧コンテナの specimens/ を新コンテナへコピーする。
      final oldDocs = Directory(provider.documentsPath);
      final newDocs = Directory(p.join(tmp.path, 'containerB', 'Documents'));
      newDocs.createSync(recursive: true);
      final oldSpecimens = Directory(p.join(oldDocs.path, 'specimens'));
      final newSpecimens = Directory(p.join(newDocs.path, 'specimens'))
        ..createSync(recursive: true);
      for (final f in oldSpecimens.listSync().whereType<File>()) {
        f.copySync(p.join(newSpecimens.path, p.basename(f.path)));
      }
      provider.documentsPath = newDocs.path;

      // 相対パスは新コンテナへ解決され、引き継がれたバイトを読める。
      expect(await store.read(path), [1, 2, 3]);
      expect(await store.exists(path), isTrue);
    });

    test('旧・絶対パスは現在のコンテナへ自己修復して読める', () async {
      const store = FileImageStore();
      // 旧バージョンが保存していた「絶対パス」を模擬（コンテナはもう存在しない想定）。
      await store.save('img-1', [7, 8], 'png');
      final staleAbsolute = p.join(
        tmp.path,
        'containerOLD',
        'Documents',
        'specimens',
        'img-1.png',
      );
      expect(p.isAbsolute(staleAbsolute), isTrue);
      // ファイル名から現在のコンテナの specimens/ 配下へ再解決される。
      expect(await store.read(staleAbsolute), [7, 8]);
      expect(await store.exists(staleAbsolute), isTrue);
    });

    test('存在しないパスは read=null・exists=false', () async {
      const store = FileImageStore();
      expect(await store.read(p.join('specimens', 'none.webp')), isNull);
      expect(await store.exists(p.join('specimens', 'none.webp')), isFalse);
    });
  });
}
