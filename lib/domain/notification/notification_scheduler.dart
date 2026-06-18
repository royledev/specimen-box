import 'package:specimen_box/domain/notification/notify_time.dart';
import 'package:specimen_box/platform/notifications/notification_service.dart';

/// iOS の保留通知枠（64件）を超えないよう強制する上限定数。
///
/// iOS は保留通知を最大 64件まで保持でき、超過分は OS が自動破棄する。
/// アプリ側で常にこの上限以内に収めることでスケジュール漏れを防ぐ。
/// 安全マージンは設けず上限そのものを使用する（既存 pending との合計が
/// この値を超えないよう純粋算出部で制御する）。
const int kMaxPending = 64;

/// スケジュール対象の通知1件を表す純粋 Dart モデル。
///
/// 副作用を持たず、純粋算出部の返り値として使用する。
final class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.when,
    required this.payload,
  });

  /// 通知の一意識別子。`yyyymmdd * 10 + slot`（slot = その日の何件目か, 0..)。
  ///
  /// 例: 2026年6月10日の2件目（slot=1）なら `202606101`。
  /// 1日に複数件（[kNotificationsPerDay]）通知するため、日付だけでは一意にならず
  /// slot を下1桁に乗せる。これにより「同じ日・同じ slot は同じ id」が保証され、
  /// 既存 pending との重複判定が安定する。
  /// int は 32bit 安全範囲内（最大 99991231*10+9 = 999912319 < 2^31-1）。
  /// 日付は `id ~/ 10`、slot は `id % 10` で復元できる。
  final int id;

  /// 通知を発火させる日時（端末ローカル時刻）。
  final DateTime when;

  /// 通知タップ時に渡すペイロード。
  ///
  /// questionId が確定するロジックが未実装のため、当日の問いを引くキーとして
  /// yyyymmdd 文字列（例: "20260610"）を入れる最小実装とする。
  /// questionId 確定ロジック実装後にここを差し替える。
  final String payload;

  @override
  String toString() =>
      'PlannedNotification(id: $id, when: $when, payload: $payload)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannedNotification &&
          id == other.id &&
          when == other.when &&
          payload == other.payload;

  @override
  int get hashCode => Object.hash(id, when, payload);
}

/// スケジュールすべき通知一覧を算出する純粋関数。
///
/// 副作用を一切持たず、同じ引数からは常に同じ結果を返す（決定論）。
///
/// ### 算出ロジック
/// 1. `now` の当日から `horizonDays` 日先まで、各日の通知時刻を
///    [notifyTimesForDate] で `perDay` 件（デフォルト [kNotificationsPerDay]＝3）求める。
/// 2. **過去時刻スキップ**: `when <= now` は積まない（当日の早い時刻が `now` 以前でも、
///    同じ日の遅い時刻は積まれる）。
/// 3. **重複スキップ**: `alreadyScheduledIds` に含まれる id（= `yyyymmdd*10+slot`）は積まない。
/// 4. **上限制御**: `alreadyScheduledIds.length + 新規数 <= maxPending` になるよう
///    近い日・早い時刻から優先し、超過する分は打ち切る。
///
/// ### id / payload 設計
/// - id: `yyyymmdd * 10 + slot`（slot はその日の昇順時刻のインデックス 0..perDay-1）。
///   同じ日・同じ slot には常に同じ id が生成され、重複判定が安定する。
/// - payload: 当日を引くキーとして yyyymmdd 文字列（slot に依らず同一）。
///   どの通知をタップしても当日の問い導線に入る（問いはタップ毎にランダム＝ADR-0013）。
///
/// ### パラメータ
/// - [now]: 現在時刻（テストで固定値を注入できる）。
/// - [userSalt]: ユーザ固有ソルト（時刻決定論化に使用）。
/// - [alreadyScheduledIds]: 既に pending にある通知の id 集合。
/// - [horizonDays]: `now` から何日先まで積むか（デフォルト 30日）。
/// - [hourWeights]: 時間帯重み（デフォルト [kDefaultHourWeights]）。
/// - [maxPending]: 許容上限件数（デフォルト [kMaxPending]）。
/// - [perDay]: 1日あたりの通知件数（デフォルト [kNotificationsPerDay]）。
List<PlannedNotification> computeSchedule({
  required DateTime now,
  required String userSalt,
  required Set<int> alreadyScheduledIds,
  int horizonDays = 30,
  List<int> hourWeights = kDefaultHourWeights,
  int maxPending = kMaxPending,
  int perDay = kNotificationsPerDay,
}) {
  // 既存 pending 数が既に上限を超えている場合は何も追加しない。
  // alreadyScheduledIds.length が maxPending を超えていると remaining が負数になるが、
  // `<= 0` の条件で負数も空リストを返す安全側の挙動として統一する。
  final int remaining = maxPending - alreadyScheduledIds.length;
  if (remaining <= 0) return const [];

  final result = <PlannedNotification>[];

  // 当日（now.year, now.month, now.day）から horizonDays 日先までループ。
  // 各日 perDay 件のランダム時刻を昇順で取り、未来かつ未スケジュールのものを積む。
  for (int offset = 0; offset <= horizonDays; offset++) {
    if (result.length >= remaining) break;

    final DateTime targetDate = now.add(Duration(days: offset));
    final int yyyymmdd = dateToYyyymmdd(targetDate);

    final List<DateTime> times = notifyTimesForDate(
      userSalt: userSalt,
      yyyymmdd: yyyymmdd,
      hourWeights: hourWeights,
      count: perDay,
    );

    for (int slot = 0; slot < times.length; slot++) {
      // 上限に達したら打ち切る。
      if (result.length >= remaining) break;

      final int id = yyyymmdd * 10 + slot;

      // 重複スキップ: 同 id が既に pending にあればスキップ。
      if (alreadyScheduledIds.contains(id)) continue;

      final DateTime when = times[slot];

      // 過去時刻スキップ: now 以前の時刻は積まない。
      // （同じ日でも早い時刻だけ過去・遅い時刻は未来、というケースを正しく扱う）
      if (!when.isAfter(now)) continue;

      result.add(PlannedNotification(
        id: id,
        when: when,
        payload: yyyymmdd.toString(),
      ));
    }
  }

  return result;
}

/// 先行スケジュールのコーディネータ（薄い副作用部）。
///
/// [NotificationService] の `pending()` を読んで [computeSchedule] に渡し、
/// 算出結果を `scheduleAt` でループ投入する。
///
/// `pending()` の返却順序は未保証（[NotificationService] 仕様）のため、
/// id の集合として扱い順序に依存しない。
Future<void> reconcile(
  NotificationService svc, {
  required DateTime now,
  required String userSalt,
  int horizonDays = 30,
  List<int> hourWeights = kDefaultHourWeights,
  int maxPending = kMaxPending,
  int perDay = kNotificationsPerDay,
}) async {
  List<PendingNotification> pendingList = await svc.pending();

  // 旧スキーム移行: 1日1件・id=yyyymmdd（8桁）の通知が残っていれば一掃して積み直す。
  // 新スキームの id は yyyymmdd*10+slot（9桁以上）なので 8桁範囲なら旧スキームと判定できる。
  // （実機テスト用 id は kTestNotificationIdBase=9×10^8 以上で、この範囲には入らない。）
  final bool hasLegacy =
      pendingList.any((n) => n.id >= 10000000 && n.id < 100000000);
  if (hasLegacy) {
    await svc.cancelAll();
    pendingList = const [];
  }

  // pending() の返却順序は未保証。id の集合として扱い順序非依存にする。
  final Set<int> alreadyScheduledIds = {for (final n in pendingList) n.id};

  final List<PlannedNotification> planned = computeSchedule(
    now: now,
    userSalt: userSalt,
    alreadyScheduledIds: alreadyScheduledIds,
    horizonDays: horizonDays,
    hourWeights: hourWeights,
    maxPending: maxPending,
    perDay: perDay,
  );

  for (final item in planned) {
    await svc.scheduleAt(
      id: item.id,
      when: item.when,
      payload: item.payload,
    );
  }
}

// ---------------------------------------------------------------------------
// テスト用（実機検証）高頻度スケジュール
// ---------------------------------------------------------------------------

/// テスト用通知の id 基点。
///
/// 本番の通知 id は yyyymmdd（約 2×10^7）なので、それと衝突しない大きな値にする。
/// `9×10^8 + count` は 32bit 符号付き上限（2147483647）未満で安全。
const int kTestNotificationIdBase = 900000000;

/// **実機テスト用**: 直近に高頻度で発火する通知一覧を算出する純粋関数。
///
/// 本番の 1日1問スケジュール（[computeSchedule]）とは別物で、
/// 「通知が正しく届きタップで当日の問いが開くか」を実機で素早く確認するための仕組み。
///
/// - [now] から [intervalSeconds] 間隔で [count] 件、未来時刻に積む。
/// - id は [kTestNotificationIdBase] からの連番（本番 id と衝突しない）。
/// - payload は全件同じ [payload]（当日を引くキー＝yyyymmdd 文字列を想定）。
List<PlannedNotification> computeTestSchedule({
  required DateTime now,
  required String payload,
  int count = 5,
  int intervalSeconds = 30,
}) {
  return [
    for (int i = 0; i < count; i++)
      PlannedNotification(
        id: kTestNotificationIdBase + i,
        when: now.add(Duration(seconds: intervalSeconds * (i + 1))),
        payload: payload,
      ),
  ];
}
