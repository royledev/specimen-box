import 'package:specimen_box/data/questions/question_loader.dart';
import 'package:specimen_box/domain/generation/seed.dart';

/// 日替わり問いの決定論的選択ロジック。
///
/// 設計: ADR-0006「当日の問いは (userSalt + 日付) の決定論で選ぶ」
///         ADR-0009「反復回避／カテゴリ偏り回避を「決定論的シャッフルデッキ」で実現する」
///
/// - 同じ (salt, yyyymmdd) を渡すと必ず同じ問いが返る（決定論）。
/// - 反復回避 / カテゴリ偏り回避は [buildDailyDeck] で実現（ADR-0009）。

/// yyyymmdd 形式の整数を 1970-01-01 からの経過日数に変換する純粋関数。
///
/// - `19700101` → `0`、`19700102` → `1`。
/// - 1970-01-01 より前の日付は自然に負の値を返す。
/// - `targetDate.difference(DateTime(1970,1,1)).inDays` を使うため、
///   うるう年・月跨ぎの連続性はカレンダーに従う（e.g. 20260228→20260301 は +1 日）。
/// - **注意: 不正 yyyymmdd（例: 20260230 = 2月30日）は Dart の `DateTime` が
///   オーバーフローして翌月に繰り越すため、サイレントに正規化される（例: 3月1日または2日）。
///   呼び出し側は実日付由来の妥当な yyyymmdd を渡す前提。**
int dayNumberFromYyyymmdd(int yyyymmdd) {
  final int year = yyyymmdd ~/ 10000;
  final int month = (yyyymmdd ~/ 100) % 100;
  final int day = yyyymmdd % 100;
  final DateTime targetDate = DateTime(year, month, day);
  return targetDate.difference(DateTime(1970, 1, 1)).inDays;
}

/// 入力リストのコピーに対して決定論的 Fisher-Yates シャッフルを行う内部ヘルパ。
///
/// - `i` を末尾インデックスから 0 まで動かし、
///   `j = fnv1a32('$keyPrefix|$i') % (i + 1)` で swap する。
/// - 元リストを破壊しない（コピーを返す）。
/// - 同じ `keyPrefix` と同じ入力リストからは常に同じ並びが得られる（決定論）。
List<T> _deterministicShuffle<T>(List<T> items, String keyPrefix) {
  final List<T> result = List<T>.of(items);
  for (int i = result.length - 1; i > 0; i--) {
    final int j = fnv1a32('$keyPrefix|$i') % (i + 1);
    final T tmp = result[i];
    result[i] = result[j];
    result[j] = tmp;
  }
  return result;
}

/// 核プール `core` からカテゴリ分散インターリーブ＋決定論シャッフルで
/// 「1サイクル分のデッキ」を生成する純粋関数。
///
/// ### 特性
/// - **決定論**: 同じ `(core, salt, cycleIndex)` を渡すと常に同じ並びが返る。
/// - **順列**: 返り値は `core` の各要素をちょうど1回含む（長さ = `core.length`）。
/// - **反復回避（1サイクル1回）**: デッキを `deck[pos]`（`pos = dayNumber % L`）で
///   取り出すことで、1サイクル（L 日）内に同じ問いが二度出ない。
/// - **カテゴリ分散**: カテゴリでグループ化 → 各グループ決定論シャッフル →
///   カテゴリ順も決定論シャッフル → ラウンドロビンで1問ずつ取り出す。
///   これにより同カテゴリの問いが隣接日に連続しにくくなる。
///
/// `core` が空の場合は空リストを返す。
List<QuestionData> buildDailyDeck(
  List<QuestionData> core,
  String salt,
  int cycleIndex,
) {
  if (core.isEmpty) return const [];

  // (a) カテゴリ別にグループ化（出現順を保持）。
  final Map<String, List<QuestionData>> grouped = {};
  for (final q in core) {
    grouped.putIfAbsent(q.category, () => []).add(q);
  }

  // カテゴリ名のリスト（出現順）。
  final List<String> categories = grouped.keys.toList();

  // (b) 各カテゴリ内を決定論シャッフル。
  final Map<String, List<QuestionData>> shuffledGroups = {};
  for (final category in categories) {
    shuffledGroups[category] = _deterministicShuffle(
      grouped[category]!,
      'qdeck-grp|$salt|$cycleIndex|$category',
    );
  }

  // (c) カテゴリの順序リストを決定論シャッフル。
  final List<String> shuffledCategories = _deterministicShuffle(
    categories,
    'qdeck-cat|$salt|$cycleIndex',
  );

  // (d) ラウンドロビン: 全グループが空になるまで
  //     カテゴリ順に各グループから先頭を1つずつ取り出して結果に追加。
  // shuffledGroups のポインタを管理するためインデックスを使う。
  final Map<String, int> pointers = {for (final c in shuffledCategories) c: 0};
  final List<QuestionData> deck = [];

  bool anyLeft = true;
  while (anyLeft) {
    anyLeft = false;
    for (final category in shuffledCategories) {
      final int ptr = pointers[category]!;
      final List<QuestionData> group = shuffledGroups[category]!;
      if (ptr < group.length) {
        deck.add(group[ptr]);
        pointers[category] = ptr + 1;
        anyLeft = true;
      }
    }
  }

  return deck;
}

/// 指定した条件（condition）が対象日（date）に有効かどうかを返す純粋関数。
///
/// - `null` → 常時候補（true）。
/// - `'weekendOnly'` → date.weekday が土(6)または日(7)のとき true。
/// - `'midnightOnly'` → 常に false（日替わりプールから除外。ADR-0006 決定2）。
/// - その他の未知の condition → true（既存 `_isAvailable` の挙動に合わせ寛容に）。
bool isAvailableOnDate(String? condition, DateTime date) {
  if (condition == null) return true;
  if (condition == 'weekendOnly') {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }
  if (condition == 'midnightOnly') {
    // 時刻依存条件は「終日安定」であるべき日替わりプールと相容れないため除外。
    // 深夜帯の特別出題は後続で別機構として設計する（ADR-0006 決定2）。
    return false;
  }
  // 未知の condition は寛容に通す（将来の condition 追加に備える）。
  return true;
}

/// 決定論的な重み付き抽選を行う内部ヘルパ。
///
/// - `fnv1a32(key)` を決定論シードとし、`r = (hash / 2^32) * totalWeight`
///   を累積重みと比較して1問選ぶ。
/// - `totalWeight <= 0` の場合は先頭を返す（0除算・範囲外を防ぐ）。
/// - 浮動小数点誤差でループを抜けた場合はリスト末尾を返す。
QuestionData _weightedPick(List<QuestionData> pool, String key) {
  // 重みがすべて 0 以下の異常値の場合は先頭を返す。
  final double totalWeight = pool.fold<double>(0, (sum, q) => sum + q.weight);
  if (totalWeight <= 0) return pool.first;

  // fnv1a32 は 0〜2^32-1 の整数を返すため、4294967296.0 (= 2^32) で割ると
  // [0, 1) の実数になり、totalWeight を掛けると [0, totalWeight) の値になる。
  final double r = (fnv1a32(key) / 4294967296.0) * totalWeight;

  double accum = 0;
  for (final q in pool) {
    accum += q.weight;
    if (r < accum) return q;
  }
  // 浮動小数点誤差でループを抜けた場合は最後の候補を返す。
  return pool.last;
}

/// 候補リストから (salt, yyyymmdd) の決定論で1問選ぶ純粋関数。
///
/// ### 決定論の保証
/// 同じ [salt] と [yyyymmdd] を渡すと、候補リストが同じである限り
/// 必ず同じ問いが返る。これが「今日のひとつ」の安定した根拠となる。
///
/// ### アルゴリズム（ADR-0009 決定1〜3）
/// 1. **核プール**（condition == null）を [buildDailyDeck] で決定論シャッフルし、
///    `deck[dayNumber % L]` を当日の基本問いとして選ぶ（反復回避: 1サイクル L 日内で各問いが1回）。
/// 2. **条件付きオーバーレイ**（condition != null かつ [isAvailableOnDate] が true）がある場合は、
///    `[deckPick] + conditionalAvailable` を重み抽選（キー `'qfinal|salt|yyyymmdd'`）して返す。
///    （土日は weekendOnly 問いが核デッキと重みで競合し、出うる。）
/// 3. `midnightOnly` は [isAvailableOnDate] が常に false のため自動除外。
///
/// ### フォールバック
/// - 核プール・条件付きともに空 → ハードコードの1問を返す。
/// - 核プール空・条件付き非空 → 条件付きのみで重み抽選。
/// - `totalWeight <= 0` → 先頭を返す。
///
/// ### dayNumber の計算
/// `dayNumber = targetDate.difference(DateTime(1970,1,1)).inDays`。
/// `cycleIndex = dayNumber ~/ L`、`pos = ((dayNumber % L) + L) % L`
/// （`%` 演算子は Dart では被除数が負のとき負になるため `+ L) % L` で正規化する。
/// yyyymmdd は実日付由来（1970-01-01 以降）を前提とするため、通常は正になる。）
QuestionData pickDailyQuestion(
  List<QuestionData> candidates,
  String salt,
  int yyyymmdd,
) {
  // yyyymmdd → DateTime 復元（時刻は不要なので 0:00:00 固定）。
  final int year = yyyymmdd ~/ 10000;
  final int month = (yyyymmdd ~/ 100) % 100;
  final int day = yyyymmdd % 100;
  final DateTime targetDate = DateTime(year, month, day);

  // dayNumber: 1970-01-01 からの経過日数。
  // yyyymmdd は実日付（1970以降）由来を前提とするため通常は非負。
  // 負の dayNumber も剰余計算（後述の pos 正規化）で安全に処理できる。
  final int dayNumber = dayNumberFromYyyymmdd(yyyymmdd);

  // 候補を核プールと条件付き（当日有効）に分離。
  // isAvailableOnDate が midnightOnly を false にするため midnightOnly は自動除外される。
  final List<QuestionData> core =
      candidates.where((q) => q.condition == null).toList();
  final List<QuestionData> conditionalAvailable = candidates
      .where((q) => q.condition != null && isAvailableOnDate(q.condition, targetDate))
      .toList();

  // フォールバック: 核プールも条件付きも空のとき。
  if (core.isEmpty && conditionalAvailable.isEmpty) {
    return const QuestionData(
      id: 'q-meaningless-01',
      text: '今日いちばん意味のなかった行動は？',
      category: 'meaningless',
      weight: 1.0,
      condition: null,
    );
  }

  // 核プールが空で条件付きのみある場合は条件付きを重み抽選。
  if (core.isEmpty) {
    return _weightedPick(conditionalAvailable, 'qfinal|$salt|$yyyymmdd');
  }

  // デッキ選択: 核プールから決定論シャッフルデッキを生成し、当日の位置を取り出す。
  // cycleIndex = dayNumber ~/ L（サイクル番号。各サイクルでシャッフルが変わる）。
  // pos = ((dayNumber % L) + L) % L（負の剰余を正に正規化して安全に）。
  // 注: dayNumber は通常非負（実日付前提）だが、負値でも pos が正になるよう正規化する。
  final int L = core.length;
  final int cycleIndex = dayNumber ~/ L;
  final int pos = ((dayNumber % L) + L) % L;
  final List<QuestionData> deck = buildDailyDeck(core, salt, cycleIndex);
  final QuestionData deckPick = deck[pos];

  // オーバーレイ: 条件付き問いがなければデッキ選択をそのまま返す。
  if (conditionalAvailable.isEmpty) {
    return deckPick;
  }

  // オーバーレイ: deckPick + conditionalAvailable を重み抽選（決定論キー使用）。
  // deckPick は自身の weight で参加する。
  final List<QuestionData> finalPool = [deckPick, ...conditionalAvailable];
  return _weightedPick(finalPool, 'qfinal|$salt|$yyyymmdd');
}

/// オフライン時の「次の問い」をローカル候補から選ぶ純粋関数（ADR-0013）。
///
/// サーバー取得が失敗したときのフォールバック。**recent（直近に出した問いID窓）を避けて**
/// 1問を返すことで、オフラインでも開くたびに別の問いが出る（通知ごとに別問い）。
///
/// - 核プール（`condition == null`）のうち、[recent] に**含まれない**問いを候補にする。
/// - 候補が空（recent が核プールを覆い尽くす）なら、recent を無視して核プール全体から選ぶ。
/// - 核プールが空なら固定の1問を返す（必ず1問返す）。
/// - 選択は決定論: 鍵に **recent 窓の末尾ID**（＝直前に採用された問い）を混ぜる。
///   呼び出し側が採用後に recent を push する運用なら、`recent.last` は毎回変わるため、
///   recent が核プールを覆い尽くして窓長が頭打ちになった後でも選択が回り続ける
///   （長さだけを鍵にすると窓長が安定した時点で同じ1問に固定される問題を避ける）。
QuestionData pickFreshLocalQuestion(
  List<QuestionData> candidates,
  String salt,
  List<String> recent,
) {
  // 時刻依存（midnightOnly 等）や曜日条件は安定供給に向かないため核プールのみ対象。
  final List<QuestionData> core =
      candidates.where((q) => q.condition == null).toList();
  if (core.isEmpty) {
    return const QuestionData(
      id: 'q-meaningless-01',
      text: '今日いちばん意味のなかった行動は？',
      category: 'meaningless',
      weight: 1.0,
      condition: null,
    );
  }

  final Set<String> recentSet = recent.toSet();
  final List<QuestionData> fresh =
      core.where((q) => !recentSet.contains(q.id)).toList();
  final List<QuestionData> usable = fresh.isNotEmpty ? fresh : core;

  // recent 窓の末尾（直前の採用ID）を鍵に混ぜて、push のたびに選択を回す。
  final String tail = recent.isEmpty ? '' : recent.last;
  final int idx =
      fnv1a32('localnext|$salt|${recent.length}|$tail') % usable.length;
  return usable[idx];
}
