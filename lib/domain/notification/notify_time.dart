import 'package:specimen_box/domain/generation/seed.dart';

/// 深夜0–7時を重み0、8–23時を重み1とするデフォルト時間帯重み（長さ24）。
///
/// インデックス i が時刻 i 時に対応する。重み0の時間帯は通知時刻に選ばれない。
const List<int> kDefaultHourWeights = [
  0, 0, 0, 0, 0, 0, 0, 0, // 0–7時: 重み0
  1, 1, 1, 1, 1, 1, 1, 1, // 8–15時
  1, 1, 1, 1, 1, 1, 1, 1, // 16–23時
];

/// 1日に届く通知の回数（デフォルト）。
///
/// 「1日3回のランダム時刻」に通知する（旧仕様の 1日1回から変更）。
const int kNotificationsPerDay = 3;

/// [userSalt] と [yyyymmdd]（例: 20260610）から、その日の通知時刻（1件目=slot 0）を返す純粋関数。
///
/// - 同じ salt + 日付なら必ず同じ時刻（決定論）。
/// - [hourWeights] は長さ24のリスト。インデックス i が時刻 i 時の重みに対応。
///   重みが0の時間帯は決して選ばれない。すべて0の場合は [ArgumentError] を投げる。
/// - 分は0–59の範囲で決定論的に分散する。
/// - 返り値の年月日は [yyyymmdd] から復元した日付、秒・マイクロ秒は0。
/// - これは [notifyTimesForDate] の slot 0 と同一（後方互換のため slot をキーに含めない）。
DateTime notifyTimeForDate({
  required String userSalt,
  required int yyyymmdd,
  List<int> hourWeights = kDefaultHourWeights,
}) =>
    _notifyTimeForSlot(
      userSalt: userSalt,
      yyyymmdd: yyyymmdd,
      slot: 0,
      hourWeights: hourWeights,
    );

/// [userSalt] と [yyyymmdd] から、その日の通知時刻を [count] 件返す純粋関数。
///
/// 「1日 [count] 回（デフォルト [kNotificationsPerDay]＝3）のランダム時刻」を表す。
///
/// - 同じ salt + 日付なら必ず同じ時刻群（決定論）。
/// - slot ごとに独立したハッシュキーで抽選するため、3件は異なる時間帯に散らばる。
/// - 返り値は**昇順ソート済み・重複なし**。万一同一 (hour, minute) が出た場合は
///   分を1ずつ進めて（同じ時・同じ日内で）一意化する。
/// - slot 0 は [notifyTimeForDate] と完全一致する（後方互換）。
/// - [hourWeights] が不正な場合は [ArgumentError]（[notifyTimeForDate] と同仕様）。
List<DateTime> notifyTimesForDate({
  required String userSalt,
  required int yyyymmdd,
  List<int> hourWeights = kDefaultHourWeights,
  int count = kNotificationsPerDay,
}) {
  final times = <DateTime>[];
  final seen = <int>{}; // hour*60+minute で重複検知
  for (int slot = 0; slot < count; slot++) {
    final DateTime t = _notifyTimeForSlot(
      userSalt: userSalt,
      yyyymmdd: yyyymmdd,
      slot: slot,
      hourWeights: hourWeights,
    );
    int hour = t.hour;
    int minute = t.minute;
    int key = hour * 60 + minute;
    // 同一 (hour, minute) が既出なら同じ時の中で分を進めて一意化（日付はまたがない）。
    while (seen.contains(key)) {
      minute = (minute + 1) % 60;
      key = hour * 60 + minute;
    }
    seen.add(key);
    times.add(DateTime(t.year, t.month, t.day, hour, minute));
  }
  times.sort();
  return times;
}

/// 指定 [slot] の通知時刻を返す内部関数。
///
/// slot 0 はキーに slot を含めず、既存の [notifyTimeForDate] と同一のハッシュキーを使う
/// （後方互換）。slot >= 1 はキーに slot を含めて独立に抽選する。
DateTime _notifyTimeForSlot({
  required String userSalt,
  required int yyyymmdd,
  required int slot,
  List<int> hourWeights = kDefaultHourWeights,
}) {
  if (hourWeights.length != 24) {
    throw ArgumentError.value(
      hourWeights,
      'hourWeights',
      'must have exactly 24 elements, got ${hourWeights.length}',
    );
  }

  final totalWeight = hourWeights.fold(0, (sum, w) => sum + w);
  if (totalWeight <= 0) {
    throw ArgumentError('hourWeights must have at least one non-zero weight');
  }

  // slot 0 は後方互換のためキーに slot を含めない。
  final String slotKey = slot == 0 ? '' : '$slot|';

  // hour 選択用ハッシュ
  final int hashH = fnv1a32('notify|hour|$slotKey$userSalt|$yyyymmdd');

  // 重み付き抽選（決定論的）
  // totalWeight > 0 が保証されているためループは必ず break する。
  final int sel = hashH % totalWeight;
  int cursor = 0;
  late int selectedHour;
  for (int h = 0; h < 24; h++) {
    cursor += hourWeights[h];
    if (sel < cursor) {
      selectedHour = h;
      break;
    }
  }

  // minute 選択用ハッシュ（hour と独立したキーでハッシュ）
  final int hashM = fnv1a32('notify|minute|$slotKey$userSalt|$yyyymmdd');
  final int selectedMinute = hashM % 60;

  // yyyymmdd から年月日を復元
  final int year = yyyymmdd ~/ 10000;
  final int month = (yyyymmdd ~/ 100) % 100;
  final int day = yyyymmdd % 100;

  return DateTime(year, month, day, selectedHour, selectedMinute);
}

/// [DateTime] の年月日から yyyymmdd（int）を返すユーティリティ。
int dateToYyyymmdd(DateTime date) =>
    date.year * 10000 + date.month * 100 + date.day;

/// yyyymmdd 形式の文字列を [DateTime] に変換する純粋関数。
///
/// - [s] が null・空・8桁数字以外のとき null を返す。
/// - 月が 1〜12 の範囲外のとき null を返す。
/// - 日が 1〜その月の末日の範囲外のとき null を返す。
/// - 範囲内であれば `DateTime(year, month, day)` を返す（時刻は 0:00:00）。
DateTime? yyyymmddStringToDate(String? s) {
  if (s == null || s.length != 8) return null;
  final n = int.tryParse(s);
  if (n == null) return null;

  final int year = n ~/ 10000;
  final int month = (n ~/ 100) % 100;
  final int day = n % 100;

  if (year <= 0) return null;
  if (month < 1 || month > 12) return null;
  if (day < 1) return null;

  // 各月の末日チェック: DateTime の自動繰り越し（month+1 の day=0 で末日を得る）を利用。
  final int lastDay = DateTime(year, month + 1, 0).day;
  if (day > lastDay) return null;

  return DateTime(year, month, day);
}
