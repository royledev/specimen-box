// API 接続設定（base URL・任意の App キー）。
//
// 値はビルド時に `--dart-define` で注入する（本番無害・ハードコードしない）:
//   --dart-define=API_BASE_URL=https://<本番>            （既定: http://localhost:8787）
//   --dart-define=APP_API_KEY=<server APP_API_KEY と一致>  （未設定なら X-App-Key を送らない）
//
// ローカルE2E（server README）:
//   iOS シミュレータ → http://localhost:8787
//   iOS 実機         → http://<母艦LAN IP>:8787
library;

import 'package:flutter/foundation.dart';

/// API 接続設定。
class ApiConfig {
  const ApiConfig({required this.baseUrl, this.appKey});

  /// 末尾スラッシュ無しの base URL（例 `http://localhost:8787`）。
  final String baseUrl;

  /// App キー（任意）。非 null かつ非空のとき `X-App-Key` ヘッダを送る。
  final String? appKey;

  /// `--dart-define` から構築する（既定はローカル開発向け）。
  factory ApiConfig.fromEnvironment() {
    const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8787',
    );
    const appKey = String.fromEnvironment('APP_API_KEY', defaultValue: '');
    final stripped = _stripTrailingSlash(baseUrl);
    // 平文送信対策（CWE-319）: リリースビルドでは公開網への http を拒否する。
    // X-Device-Token / X-App-Key / 回答本文が平文で流れる設定ミスを起動時に弾く。
    // ローカル開発（localhost / プライベート IP）の http は許可する。
    if (kReleaseMode) {
      final uri = Uri.tryParse(stripped);
      final isLocal = uri != null && _isLocalHost(uri.host);
      if (uri == null || (uri.scheme != 'https' && !isLocal)) {
        throw StateError(
          'API_BASE_URL must use https in release builds: $stripped',
        );
      }
    }
    return ApiConfig(
      baseUrl: stripped,
      appKey: appKey.isEmpty ? null : appKey,
    );
  }

  static String _stripTrailingSlash(String s) =>
      s.replaceFirst(RegExp(r'/+$'), '');

  static bool _isLocalHost(String host) {
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
      return true;
    }
    return RegExp(
      r'^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)',
    ).hasMatch(host);
  }
}
