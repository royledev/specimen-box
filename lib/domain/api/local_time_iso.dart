// ローカル時刻の ISO8601（タイムゾーンオフセット付き）整形。
//
// specimen-box-server の `questions/next` は `localTime` を condition 判定
// （midnightOnly / weekendOnly）に使うため、**端末のローカル時刻＋実オフセット**を要求する
// （server schema は zod `.datetime({offset:true})`）。
//
// Dart の `DateTime.toIso8601String()` はローカル時刻だとオフセットを付けず、UTC だと `Z` を付ける。
// condition 判定はローカル時刻が要るため、ここでオフセット（例 `+09:00`）を明示して整形する。
library;

/// [dt] を `2026-06-13T23:40:00+09:00` 形式（タイムゾーンオフセット付き ISO8601）で返す。
///
/// オフセットは [dt].timeZoneOffset から算出する（UTC は `+00:00`）。
/// 秒までを出力し、ミリ秒以下は切り捨てる（server 側判定に不要なため）。
String formatLocalIso8601(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');

  final date =
      '${dt.year.toString().padLeft(4, '0')}-${two(dt.month)}-${two(dt.day)}';
  final time = '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';

  final offset = dt.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final abs = offset.abs();
  final offStr = '$sign${two(abs.inHours)}:${two(abs.inMinutes % 60)}';

  return '${date}T$time$offStr';
}
