// 次の問いの解決ロジック（ADR-0013: 通知ごとに別のランダム問い）。
//
// 問いは**画面を開くたびに新規取得**する（日替わり安定＝同日は同じ、という ADR-0011 決定2 は撤回）。
//
// 優先順:
//   1. サーバー取得（fetchRemote）→ recent 窓へ push（直近重複の回避）→ 返す。
//   2. サーバー失敗（ネット無/例外/出題不可）→ ローカルフォールバック（recent を避けた選択）→ push → 返す。
//
// 依存は関数注入（IF/Provider/IO に依存しない）→ Fake だけでユニットテスト可能。
library;

import 'package:specimen_box/data/questions/question_loader.dart' show QuestionData;

/// 次の問いを解決する。詳細はファイル冒頭のコメント参照。
///
/// - [fetchRemote]: サーバー取得（`{id,text,category,condition}` を返す）。失敗時は例外。
/// - [pushRecent]: 採用した問いIDを recent 窓へ push（直近重複回避）。
/// - [localFallback]: サーバー失敗時のローカル選択（recent を避けた選択経路）。
///
/// サーバー・ローカルとも採用した問いを recent に push する。これにより**次の取得で
/// 直前の問いが除外**され、連続で同じ問いが出ない（通知ごとに別問い）。
///
/// 注意（分岐の独立性）: サーバー取得（[fetchRemote]）の成否と recent への push（[pushRecent]）の
/// 成否は**独立に扱う**。push を取得と同じ try に入れると、サーバー取得に成功したのに push の
/// DB 例外でローカルフォールバックへ落ちてしまう。そこで取得結果を先に確定し、push は
/// **best-effort**（失敗しても採用した問いは捨てない）で最後に行う。
Future<QuestionData> resolveNextQuestion({
  required Future<RemoteQuestionData> Function() fetchRemote,
  required Future<void> Function(String questionId) pushRecent,
  required Future<QuestionData> Function() localFallback,
}) async {
  // 1. サーバー取得を試す。失敗（ネット無/例外/出題不可）なら remote=null。
  QuestionData? remote;
  try {
    final r = await fetchRemote();
    remote = QuestionData(
      id: r.id,
      text: r.text,
      category: r.category,
      // weight はサーバー選定専用。表示・保存に使わない既定値 1.0 を入れる。
      weight: 1.0,
      condition: r.condition,
    );
  } catch (_) {
    remote = null;
  }

  // 2. サーバー失敗時のみローカルフォールバック（recent を避けた選択）。
  //    localFallback が例外を投げた場合は呼び出し側（UI）で握る（既存挙動）。
  final QuestionData question = remote ?? await localFallback();

  // 3. 採用IDを recent に push（best-effort: 失敗しても採用した問いは返す）。
  try {
    await pushRecent(question.id);
  } catch (_) {
    // push 失敗は無視（次回 1 回だけ直近重複が起きうるのみ）。
  }

  return question;
}

/// サーバー取得結果の最小表現（platform 層の RemoteQuestion を domain に持ち込まないための DTO）。
class RemoteQuestionData {
  const RemoteQuestionData({
    required this.id,
    required this.text,
    required this.category,
    this.condition,
  });

  final String id;
  final String text;
  final String category;
  final String? condition;
}
