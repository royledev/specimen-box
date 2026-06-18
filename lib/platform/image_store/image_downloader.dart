// 画像URL→バイトのダウンロード抽象（ADR-0011 決定3/4）。
//
// `images/draw` は画像の `url`（短命署名URL / ローカルは dev 配信）を返すが、バイト実体は別途取得する
// （`DrawnImage.bytes` は数値のみ）。ここでその取得を IF で隔離し、Fake でユニットテスト可能にする。
library;

import 'dart:async';

import 'package:http/http.dart' as http;

/// 画像URLからバイトを取得する。
abstract interface class ImageDownloader {
  /// [url] のバイトを返す。失敗時は例外を投げる。
  Future<List<int>> download(String url);
}

/// http ベースの [ImageDownloader] 実装。
class HttpImageDownloader implements ImageDownloader {
  HttpImageDownloader({
    required this.client,
    this.timeout = const Duration(seconds: 20),
  });

  final http.Client client;
  final Duration timeout;

  @override
  Future<List<int>> download(String url) async {
    final uri = Uri.parse(url);
    // SSRF/ローカルファイル参照対策（CWE-918）: スキームを allowlist する。
    // 本番は短命署名 URL（https）、ローカル dev のみ http を許可する。
    final isLocalDev = uri.scheme == 'http' && _isLocalHost(uri.host);
    if (uri.scheme != 'https' && !isLocalDev) {
      throw Exception('disallowed image url scheme: $url');
    }
    final http.Response res;
    try {
      res = await client.get(uri).timeout(timeout);
    } on TimeoutException {
      throw Exception('image download timed out: $url');
    }
    if (res.statusCode != 200) {
      throw Exception('image download failed (${res.statusCode}): $url');
    }
    return res.bodyBytes;
  }

  /// ローカル開発配信に限り平文 http を許可するためのホスト判定。
  /// localhost / ループバック / プライベート IP（LAN 母艦）のみ true。
  static bool _isLocalHost(String host) {
    if (host == 'localhost') return true;
    if (host == '127.0.0.1' || host == '::1') return true;
    // RFC1918 プライベート IP（10/8, 172.16/12, 192.168/16）。
    return RegExp(
      r'^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)',
    ).hasMatch(host);
  }
}
