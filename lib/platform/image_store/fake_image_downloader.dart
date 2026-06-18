// ImageDownloader のテスト用 Fake。
library;

import 'package:specimen_box/platform/image_store/image_downloader.dart';

/// 決定論的な [ImageDownloader] Fake。[fail] で失敗を、[bytes] で返却内容を制御する。
class FakeImageDownloader implements ImageDownloader {
  FakeImageDownloader({this.bytes = const [1, 2, 3, 4], this.fail = false});

  List<int> bytes;
  bool fail;

  /// 最後に要求された URL（テスト検証用）。
  String? lastUrl;

  @override
  Future<List<int>> download(String url) async {
    lastUrl = url;
    if (fail) throw Exception('fake download failure');
    return bytes;
  }
}
