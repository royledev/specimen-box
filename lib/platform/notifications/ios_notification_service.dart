import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'notification_service.dart';

/// iOS 向け [NotificationService] 実装。
///
/// `flutter_local_notifications` と `timezone` を使い、OS固有の型を
/// このファイル内に完全に閉じ込める（IFシグネチャには漏らさない）。
///
/// ### 初期化
/// アプリ起動時に [init] を一度だけ呼ぶこと。
/// `tz.initializeTimeZones()` と端末TZ取得、`flutter_local_notifications` の
/// iOS 初期化設定をここで行う。
///
/// ### 通知本文
/// 汎用文言を使用する（決定事項(B)）。タイトル「標本箱」・本文「今日のひとつ」。
/// 問い文そのものは通知に載せず、タップ時に payload（yyyymmdd 文字列）を
/// アプリに渡して当日の問い画面を開く導線を設ける。
final class IosNotificationService implements NotificationService {
  IosNotificationService._();

  /// ファクトリ。初期化済みインスタンスを返す。
  ///
  /// アプリ起動時に一度だけ呼ぶ。複数回呼んでも安全（再初期化は無害）。
  static Future<IosNotificationService> init() async {
    final svc = IosNotificationService._();
    await svc._initialize();
    return svc;
  }

  // flutter_local_notifications の実体。このファイルの外に漏らさない。
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // タップハンドラ（onTap で登録）。
  void Function(String? payload)? _tapHandler;

  // ---------------------------------------------------------------------------
  // 初期化
  // ---------------------------------------------------------------------------

  Future<void> _initialize() async {
    // タイムゾーン DB の初期化（全タイムゾーン）。
    tz_data.initializeTimeZones();

    // 端末のタイムゾーン名を取得して設定する。
    // flutter_timezone が端末TZを返す。取得失敗時は UTC にフォールバック。
    String tzName;
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tzName = tzInfo.identifier;
    } catch (_) {
      tzName = 'UTC';
    }
    tz.setLocalLocation(tz.getLocation(tzName));

    // iOS の初期化設定。
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      // 権限要求は requestPermission() で明示的に行う。
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const InitializationSettings initSettings = InitializationSettings(
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
  }

  // 通知タップ時のコールバック（flutter_local_notifications から呼ばれる）。
  void _onNotificationResponse(NotificationResponse response) {
    _tapHandler?.call(response.payload);
  }

  // ---------------------------------------------------------------------------
  // NotificationService インターフェース実装
  // ---------------------------------------------------------------------------

  @override
  Future<bool> requestPermission() async {
    // iOS 専用の権限要求（alert / badge / sound）。
    final IOSFlutterLocalNotificationsPlugin? iosPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin == null) return false;
    final bool? granted = await iosPlugin.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return granted ?? false;
  }

  @override
  Future<void> scheduleAt({
    required int id,
    required DateTime when,
    String? payload,
  }) async {
    // DateTime → tz.TZDateTime（端末ローカルTZ）に変換。
    final tz.TZDateTime tzWhen = tz.TZDateTime(
      tz.local,
      when.year,
      when.month,
      when.day,
      when.hour,
      when.minute,
      when.second,
    );

    // iOS 通知詳細設定。
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const NotificationDetails details = NotificationDetails(iOS: iosDetails);

    await _plugin.zonedSchedule(
      id: id,
      title: '化石箱', // タイトル: 汎用文言（問い文は載せない）。
      body: '今日のひとつ', // 本文: 汎用文言。タップすると当日の問いが開く。
      scheduledDate: tzWhen,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  @override
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  @override
  Future<List<PendingNotification>> pending() async {
    final List<PendingNotificationRequest> requests =
        await _plugin.pendingNotificationRequests();

    return requests.map((req) {
      // flutter_local_notifications の PendingNotificationRequest は
      // スケジュール日時（when）を公開しない。
      // そのため when は DateTime(0)（エポック）をプレースホルダとして返す。
      // 呼び出し側はこの when を信頼せず、id による重複判定のみに使うこと。
      return PendingNotification(
        id: req.id,
        when: DateTime(0), // when 情報は取得不可のため番兵値を入れる。
        payload: req.payload,
      );
    }).toList();
  }

  @override
  void onTap(void Function(String? payload) handler) {
    _tapHandler = handler;
  }

  @override
  Future<String?> initialPayload() async {
    // cold start（終了状態からの通知タップ）で起動したかどうかを確認する。
    // OS 固有型（NotificationAppLaunchDetails 等）はこのメソッド内に完全に閉じ込め、
    // 戻り値は String? のみ（IF 契約維持）。
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      return details!.notificationResponse?.payload;
    }
    return null;
  }
}

/// 非 iOS プラットフォーム向けフォールバック（no-op）。
///
/// `notificationServiceProvider` がテスト環境や非iOS（web等）で
/// 通知副作用を一切出さないよう使用する。
/// 状態を持たないため [pending] は常に空リストを返す。
final class _NoopNotificationServiceInternal implements NotificationService {
  const _NoopNotificationServiceInternal();

  @override
  Future<bool> requestPermission() async => false;

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

/// 非 iOS 環境（テスト・web 等）で使う no-op インスタンス。
///
/// [notificationServiceProvider] のフォールバックとして使用する。
const NotificationService noopNotificationService =
    _NoopNotificationServiceInternal();
