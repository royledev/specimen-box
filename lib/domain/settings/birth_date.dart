// 生年月日の解析/整形を行う純粋関数群。
//
// 保存形式は ISO8601 の `YYYY-MM-DD`（年4桁ゼロ埋め・月日2桁ゼロ埋め）。
// ハイフン無し yyyymmdd 形式の [yyyymmddStringToDate] とは別形式なので独立関数として定義する。

/// [DateTime] を `YYYY-MM-DD` 形式の文字列に整形する純粋関数。
///
/// - 年は4桁ゼロ埋め、月・日は2桁ゼロ埋め。
/// - 時刻成分は無視し、年月日のみを使用する。
/// - **前提条件**: [d] の年は 1 以上（西暦 1 年以降）でなければならない。
///   負の年や 0 年は仕様外。この前提が満たされない場合、デバッグビルドでは [AssertionError] を投げる。
///   呼び出し側は必ず正の年の [DateTime] を渡すこと。
///   これにより往復契約（`parseBirthDate(formatBirthDate(d))` が同値を返す）が保証される。
String formatBirthDate(DateTime d) {
  assert(d.year >= 1, 'formatBirthDate: 年は 1 以上でなければなりません（受け取った値: ${d.year}）');
  final year = d.year.toString().padLeft(4, '0');
  final month = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// `YYYY-MM-DD` 形式の文字列を [DateTime] に変換する純粋関数。
///
/// - [s] が null・空・`YYYY-MM-DD` 形式以外のとき null を返す。
/// - 年が 1 未満（0 以下・負の年）のとき null を返す。
/// - 月が 1〜12 の範囲外のとき null を返す。
/// - 日が 1〜その月の末日の範囲外のとき null を返す（実在日チェック）。
///   `DateTime` のロールオーバー（例: 2026-02-30 → 2026-03-02 になる挙動）は許さず厳密に弾く。
/// - 範囲内であれば `DateTime(year, month, day)` を返す（時刻は 0:00:00）。
DateTime? parseBirthDate(String? s) {
  if (s == null || s.isEmpty) return null;

  // 形式チェック: `YYYY-MM-DD`（10文字、各パートが ASCII 数字のみ、ハイフン区切り）。
  // 正規表現で全体を先に検証し、負符号・全角文字・余剰文字・桁不足を一括排除する。
  final formatRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  if (!formatRegex.hasMatch(s)) return null;

  final yearStr = s.substring(0, 4);
  final monthStr = s.substring(5, 7);
  final dayStr = s.substring(8, 10);

  // 正規表現で数字のみを保証済みのため tryParse は必ず成功するが、
  // null 安全のため tryParse を使用する。
  final year = int.tryParse(yearStr);
  final month = int.tryParse(monthStr);
  final day = int.tryParse(dayStr);
  if (year == null || month == null || day == null) return null;

  // 年の範囲チェック: 0 以下（0 年・負の年）は非現実的な生年月日として弾く。
  // notify_time.dart の yyyymmddStringToDate と一貫した方針（year <= 0 をガード）。
  if (year < 1) return null;

  // 月範囲チェック
  if (month < 1 || month > 12) return null;

  // 日範囲チェック（1以上）
  if (day < 1) return null;

  // 実在日チェック（ロールオーバー排除）:
  // `DateTime(year, month + 1, 0).day` で当月の末日を取得し、day がその範囲内か確認する。
  final lastDay = DateTime(year, month + 1, 0).day;
  if (day > lastDay) return null;

  return DateTime(year, month, day);
}
