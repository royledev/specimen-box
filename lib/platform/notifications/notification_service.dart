/// 通知の抽象インターフェース。
///
/// OS 固有の型（flutter_local_notifications 等）を一切露出させない。
/// シグネチャには [DateTime]、[PendingNotification]（自前モデル）、
/// 素の Dart 型のみを使用する。
///
/// iOS 実装は `ios_notification_service.dart`（T4 で追加）、
/// テスト用の記録インメモリ実装は `fake_notification_service.dart` で提供する。
library;

/// スケジュール済みで未発火の通知を表す軽量モデル。
///
/// OS 固有の型を含まない純粋 Dart クラス。
final class PendingNotification {
  const PendingNotification({
    required this.id,
    required this.when,
    this.payload,
  });

  /// 通知の一意識別子。同じ [id] でスケジュールすると上書きされる。
  final int id;

  /// 通知を発火させる日時（端末ローカル時刻）。
  final DateTime when;

  /// 通知タップ時に渡すペイロード（例: questionId）。null 可。
  final String? payload;

  @override
  String toString() =>
      'PendingNotification(id: $id, when: $when, payload: $payload)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingNotification &&
          id == other.id &&
          when == other.when &&
          payload == other.payload;

  @override
  int get hashCode => Object.hash(id, when, payload);
}

/// ローカル通知の抽象インターフェース。
///
/// 実装クラスはこのインターフェースを `implements` して提供する。
/// 依存注入（Riverpod provider.overrideWith 等）でテスト時に fake へ差し替える。
abstract interface class NotificationService {
  /// OS の通知許可を要求し、許可されたかどうかを返す。
  ///
  /// 既に許可済みの場合は即座に `true` を返す。
  /// ユーザが拒否した場合は `false` を返す（例外は投げない）。
  Future<bool> requestPermission();

  /// 指定日時に通知を1件スケジュールする。
  ///
  /// 同じ [id] が既にスケジュール済みの場合は上書きする。
  /// [when] が過去の場合の挙動は実装依存（fake は無条件に記録する）。
  Future<void> scheduleAt({
    required int id,
    required DateTime when,
    String? payload,
  });

  /// スケジュール済みの通知をすべてキャンセルする。
  Future<void> cancelAll();

  /// 現在スケジュール済みで未発火の通知一覧を返す。
  ///
  /// 発火済みまたはキャンセル済みのものは含まれない。
  Future<List<PendingNotification>> pending();

  /// 通知タップ時に呼ばれるハンドラを登録する。
  ///
  /// 通知タップで [payload] が渡される。
  /// 登録後は [handler] が呼ばれるまで保持される。
  /// 複数回呼んだ場合は最後に登録したハンドラだけが有効になる。
  void onTap(void Function(String? payload) handler);

  /// cold start（終了状態からの通知タップ）で起動した場合の payload を返す。
  ///
  /// 通知タップによってアプリが起動した場合は payload を返す。
  /// 通知起動でなければ null を返す。
  ///
  /// OS 固有の型（flutter_local_notifications 等）は外に出さない（String? のみ返す）。
  Future<String?> initialPayload();
}
