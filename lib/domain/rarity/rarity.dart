/// 標本のレアリティを表す enum。
///
/// - [normal]: 通常レアリティ。
/// - [rareMidnight]: 深夜帯（0:00〜4:59）に生成された標本。
/// - [rareBirthday]: 生成日（[rarityOf] の `createdAt` の月日）が
///   ユーザーの生年月日（月日）と一致する標本。
enum Rarity {
  normal,
  rareMidnight,
  rareBirthday;

  /// このレアリティが通常（[normal]）以外かどうか。
  bool get isRare => this != Rarity.normal;

  /// 表示ラベル。通常は null、深夜は「深夜の化石」、誕生日は「誕生日の化石」。
  /// presentation 層でのラベル表示に使用する（アプリ内の表示語彙は「化石」で統一）。
  String? get label => switch (this) {
        Rarity.normal => null,
        Rarity.rareMidnight => '深夜の化石',
        Rarity.rareBirthday => '誕生日の化石',
      };
}

/// [createdAt] のレアリティを返す純粋関数。副作用なし。
///
/// 優先順位: **誕生日 > 深夜 > 通常**。
///
/// 1. [birthDate] が非 null かつ `createdAt` の月日と `birthDate` の月日が一致する場合は
///    [Rarity.rareBirthday] を返す（深夜帯であっても誕生日を優先）。
/// 2. `createdAt.hour` が **0〜4** の場合は [Rarity.rareMidnight] を返す。
/// 3. それ以外は [Rarity.normal] を返す。
///
/// [birthDate] は省略可能（既定 null）。null のとき（未登録・読み込み中）は
/// 従来どおり深夜 / 通常のみ判定する（後方互換）。
/// 年は問わず、月と日のみで一致判定する（2/29 生まれは厳密月日一致のため平年は非該当）。
Rarity rarityOf({required DateTime createdAt, DateTime? birthDate}) {
  if (birthDate != null &&
      createdAt.month == birthDate.month &&
      createdAt.day == birthDate.day) {
    return Rarity.rareBirthday;
  }
  final hour = createdAt.hour;
  return (hour >= 0 && hour <= 4) ? Rarity.rareMidnight : Rarity.normal;
}
