import 'dart:math' as math;

/// 風化開始までの期間。確定値（B4・2026-06-10）。
const Duration kWeatheringT1 = Duration(days: 7);

/// 完全風化（消滅相当）までの期間。確定値（B4・2026-06-10）。T2 > T1 を維持すること。
const Duration kWeatheringT2 = Duration(days: 30);

/// 標本の風化度を返す純粋関数。戻り値は 0.0〜1.0。
///
/// - [createdAt]: 標本の生成日時。
/// - [now]: 現在時刻（`DateTime.now()` を直接呼ばない。必ず外から注入する）。
/// - [sealed]: 封印されている場合は `true`。封印は風化を止める（weatheringFrozen）。
/// - [t1]: 風化開始までの期間。省略時は [kWeatheringT1]。
/// - [t2]: 完全風化までの期間。省略時は [kWeatheringT2]。T2 > T1 であること。
///
/// 仕様:
/// - `sealed == true` → 常に 0.0。
/// - `elapsed <= 0` → 0.0（負の elapsed をクランプ）。
/// - `elapsed <= t1` → 0.0（風化開始前）。
/// - `t1 < elapsed < t2` → `(elapsed - t1) / (t2 - t1)`（線形単調増加）。
/// - `elapsed >= t2` → 1.0（完全風化）。
/// - 戻り値は常に 0.0〜1.0 にクランプ。
double weatherLevel({
  required DateTime createdAt,
  required DateTime now,
  required bool sealed,
  Duration t1 = kWeatheringT1,
  Duration t2 = kWeatheringT2,
}) {
  assert(t2 > t1, 'T2 は T1 より大きいこと');

  // t2 <= t1 のときはゼロ除算を防ぐため早期リターン（sealed 判定より先に確認）
  if (t2 <= t1) return 0.0;

  // 封印されていれば風化しない（weatheringFrozen）
  if (sealed) return 0.0;

  final elapsedMicros = now.difference(createdAt).inMicroseconds;

  // 負の elapsed（now < createdAt）はクランプ
  if (elapsedMicros <= 0) return 0.0;

  final t1Micros = t1.inMicroseconds;
  final t2Micros = t2.inMicroseconds;

  // T1 以前はまだ風化開始前
  if (elapsedMicros <= t1Micros) return 0.0;

  // T2 以降は完全風化
  if (elapsedMicros >= t2Micros) return 1.0;

  // T1〜T2 の線形補間（0→1）
  final level = (elapsedMicros - t1Micros) / (t2Micros - t1Micros);

  // 念のため 0..1 にクランプ
  return math.min(1.0, math.max(0.0, level));
}
