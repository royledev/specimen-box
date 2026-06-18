// 直近ID窓（recent window）の純粋ロジック。
//
// サーバー配信の反復回避（server ADR-0006）は端末供給の `recent`（直近問いID窓）で行う。
// 画像の所有集合（`owned`）も「重複なしのリスト」という点で同型なので、ここに純粋関数を集約する。
//
// いずれも IO/状態を持たず、現在のリストと入力から**新しいリストを返す**（イミュータブル）。
library;

/// 直近ID窓に [id] を「最新」として押し込んだ新しいリストを返す（FIFO・重複排除）。
///
/// - 既存の同一 [id] は取り除いてから末尾に積む（最新へ移動）。
/// - 末尾が最新・先頭が最古。長さが [maxLen] を超えたら先頭（最古）から落とす。
/// - [maxLen] が 0 以下なら空リストを返す（窓無効）。
List<String> pushRecent(List<String> current, String id, int maxLen) {
  if (maxLen <= 0) return const [];
  final next = [
    for (final e in current)
      if (e != id) e,
    id,
  ];
  if (next.length <= maxLen) return next;
  return next.sublist(next.length - maxLen);
}

/// 重複なし集合（リスト表現）に [id] を加えた新しいリストを返す。
///
/// - 既に含まれていれば変更しない（同一インスタンスではなくコピーを返す）。
/// - 追加順を保つ（末尾に追加）。所有集合（`owned`）に使う。
List<String> addUnique(List<String> current, String id) {
  if (current.contains(id)) return List.of(current);
  return [...current, id];
}
