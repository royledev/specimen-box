// 匿名端末トークンの生成（specimen-box-server ADR-0005）。
//
// - PII を含まない不透明トークン。サーバーのレート制限の鍵にのみ使われる。
// - 新規依存（uuid 等）を足さず、`Random.secure()` の乱数を 16 バイト hex（32 文字）で表現する。
//   server 側 `imagesDrawSchema` の image_id とは別物だが、上限 36 文字に収まる長さに留める。
library;

import 'dart:math';

/// 32 文字の hex 文字列（16 バイト）の匿名端末トークンを生成する。
///
/// [random] は注入可能（テストで決定論にできる）。本番は `Random.secure()` を渡す。
String generateDeviceToken(Random random) {
  const hex = '0123456789abcdef';
  final buf = StringBuffer();
  // 16 バイト = 32 hex 桁。
  for (var i = 0; i < 32; i++) {
    buf.write(hex[random.nextInt(16)]);
  }
  return buf.toString();
}
