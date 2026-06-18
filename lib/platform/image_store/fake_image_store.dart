// ImageStore のインメモリ Fake（テスト・非対応環境用）。
//
// 実ファイルIOなしで save/read/exists を再現する。パスは `mem://<imageId>.<format>`。
library;

import 'package:specimen_box/platform/image_store/image_store.dart';

/// インメモリの [ImageStore] Fake。
class FakeImageStore implements ImageStore {
  final Map<String, List<int>> _files = {};

  /// 保存済みパス → バイトの読み取り（テスト検証用）。
  Map<String, List<int>> get files => Map.unmodifiable(_files);

  String _pathFor(String imageId, String format) => 'mem://$imageId.$format';

  @override
  Future<String> save(String imageId, List<int> bytes, String format) async {
    final path = _pathFor(imageId, format);
    _files[path] = List<int>.of(bytes);
    return path;
  }

  @override
  Future<List<int>?> read(String localPath) async => _files[localPath];

  @override
  Future<bool> exists(String localPath) async => _files.containsKey(localPath);
}
