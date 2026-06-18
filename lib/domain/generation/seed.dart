import 'dart:convert';

/// FNV-1a 32bit ハッシュ。UTF-8 バイト列に対して計算する。
///
/// 決定論ユーティリティ。問い選択（ADR-0006/ADR-0009 の決定論デッキ）と
/// 通知時刻（notify_time）の決定論計算に使う。
/// ※ ベクター生成（specimenSeed/SpecimenParams 等）は ADR-0011 で廃止済み。
int fnv1a32(String s) {
  const int prime = 0x01000193;
  int h = 0x811c9dc5;
  for (final b in utf8.encode(s)) {
    h ^= b;
    h = (h * prime) & 0xFFFFFFFF;
  }
  return h & 0xFFFFFFFF;
}
