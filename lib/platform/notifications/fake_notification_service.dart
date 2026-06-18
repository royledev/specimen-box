import 'notification_service.dart';

/// テスト・開発用のインメモリ [NotificationService] 実装。
///
/// スケジュール内容を [List] で記録し、[pending] で取り出せる。
/// 実際の OS 通知は一切発火しない。
///
/// ### テスト向けヘルパー API
/// - [scheduledNotifications]: スケジュール済み一覧への直接参照（変更不可ビュー）。
/// - [emitTap]: タップを手動発火してハンドラを呼び出す。
/// - [permissionResult]: [requestPermission] の戻り値を注入する（デフォルト `true`）。
/// - [initialPayloadValue]: [initialPayload] が返す値を注入する（デフォルト `null`）。
final class FakeNotificationService implements NotificationService {
  /// コンストラクタ。
  ///
  /// [permissionResult] で [requestPermission] の戻り値を設定できる（デフォルト `true`）。
  /// [initialPayloadValue] で [initialPayload] の戻り値を注入できる（デフォルト `null`）。
  FakeNotificationService({
    this.permissionResult = true,
    this.initialPayloadValue,
  });

  /// [requestPermission] が返す値。テストで直接差し替える。
  ///
  /// 例: `svc.permissionResult = false;`
  bool permissionResult;

  /// [initialPayload] が返す値。テストで注入する。
  ///
  /// null の場合は通知起動でないことを意味する。
  /// 例: `svc.initialPayloadValue = '20260610';`
  String? initialPayloadValue;

  /// スケジュール済み通知のインメモリストア。id をキーとして保持。
  final Map<int, PendingNotification> _store = {};

  /// 登録されたタップハンドラ。
  void Function(String? payload)? _tapHandler;

  // ---------------------------------------------------------------------------
  // NotificationService インターフェース実装
  // ---------------------------------------------------------------------------

  @override
  Future<bool> requestPermission() async => permissionResult;

  @override
  Future<void> scheduleAt({
    required int id,
    required DateTime when,
    String? payload,
  }) async {
    _store[id] = PendingNotification(id: id, when: when, payload: payload);
  }

  @override
  Future<void> cancelAll() async => _store.clear();

  @override
  Future<List<PendingNotification>> pending() async =>
      List.unmodifiable(_store.values.toList());

  @override
  void onTap(void Function(String? payload) handler) {
    _tapHandler = handler;
  }

  @override
  Future<String?> initialPayload() async => initialPayloadValue;

  // ---------------------------------------------------------------------------
  // テスト専用ヘルパー
  // ---------------------------------------------------------------------------

  /// スケジュール済み通知の変更不可ビュー。
  ///
  /// テストで `expect(svc.scheduledNotifications, ...)` のように使う。
  List<PendingNotification> get scheduledNotifications =>
      List.unmodifiable(_store.values.toList());

  /// 指定 [id] の通知が記録されているかを返す。
  bool hasNotification(int id) => _store.containsKey(id);

  /// タップイベントを手動発火する。
  ///
  /// 登録済みのハンドラ（[onTap] で登録したもの）を [payload] で呼び出す。
  /// ハンドラが未登録の場合は何もしない。
  void emitTap(String? payload) => _tapHandler?.call(payload);

  /// 現在登録されているタップハンドラが存在するかどうか。
  bool get hasTapHandler => _tapHandler != null;
}

/// 何もしない [NotificationService] 実装（no-op）。
///
/// 通知が不要な画面テスト・ウィジェットテスト等で
/// 実際のスケジュール副作用を完全に排除したい場合に使う。
/// 状態を持たないため、[pending] は常に空リストを返す。
final class NoopNotificationService implements NotificationService {
  const NoopNotificationService();

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> scheduleAt({
    required int id,
    required DateTime when,
    String? payload,
  }) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<List<PendingNotification>> pending() async => const [];

  @override
  void onTap(void Function(String? payload) handler) {}

  @override
  Future<String?> initialPayload() async => null;
}
