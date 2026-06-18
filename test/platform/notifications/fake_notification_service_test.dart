import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/platform/notifications/fake_notification_service.dart';
import 'package:specimen_box/platform/notifications/notification_service.dart';

void main() {
  late FakeNotificationService svc;

  setUp(() {
    svc = FakeNotificationService();
  });

  // ---------------------------------------------------------------------------
  // scheduleAt → pending
  // ---------------------------------------------------------------------------
  group('scheduleAt / pending', () {
    test('scheduleAt した通知が pending に出る', () async {
      final when = DateTime(2026, 7, 1, 10, 30);
      await svc.scheduleAt(id: 1, when: when, payload: 'q42');

      final list = await svc.pending();
      expect(list, hasLength(1));
      expect(list.first.id, 1);
      expect(list.first.when, when);
      expect(list.first.payload, 'q42');
    });

    test('複数件スケジュールするとすべて pending に出る', () async {
      await svc.scheduleAt(id: 1, when: DateTime(2026, 7, 1, 9, 0));
      await svc.scheduleAt(id: 2, when: DateTime(2026, 7, 2, 10, 0));
      await svc.scheduleAt(id: 3, when: DateTime(2026, 7, 3, 11, 0));

      final list = await svc.pending();
      expect(list, hasLength(3));
    });

    test('同じ id で scheduleAt すると上書きされる', () async {
      await svc.scheduleAt(id: 5, when: DateTime(2026, 7, 1, 9, 0), payload: 'old');
      await svc.scheduleAt(id: 5, when: DateTime(2026, 7, 2, 9, 0), payload: 'new');

      final list = await svc.pending();
      expect(list, hasLength(1));
      expect(list.first.payload, 'new');
    });

    test('payload が null の通知も記録される', () async {
      await svc.scheduleAt(id: 10, when: DateTime(2026, 8, 1, 12, 0));

      final list = await svc.pending();
      expect(list.first.payload, isNull);
    });

    test('pending は変更不可ビューを返す（List 操作で元ストアに影響しない）', () async {
      await svc.scheduleAt(id: 1, when: DateTime(2026, 7, 1, 10, 0));
      final list = await svc.pending();

      // 返された List への追加がストアに影響しないことを確認
      expect(() => (list as dynamic).add(null), throwsA(anything));
    });
  });

  // ---------------------------------------------------------------------------
  // cancelAll
  // ---------------------------------------------------------------------------
  group('cancelAll', () {
    test('cancelAll で pending が空になる', () async {
      await svc.scheduleAt(id: 1, when: DateTime(2026, 7, 1, 9, 0));
      await svc.scheduleAt(id: 2, when: DateTime(2026, 7, 2, 10, 0));
      expect(await svc.pending(), hasLength(2));

      await svc.cancelAll();
      expect(await svc.pending(), isEmpty);
    });

    test('空の状態で cancelAll しても例外にならない', () async {
      await expectLater(svc.cancelAll(), completes);
    });

    test('cancelAll 後に再スケジュールできる', () async {
      await svc.scheduleAt(id: 1, when: DateTime(2026, 7, 1, 9, 0));
      await svc.cancelAll();
      await svc.scheduleAt(id: 2, when: DateTime(2026, 7, 5, 14, 0));

      final list = await svc.pending();
      expect(list, hasLength(1));
      expect(list.first.id, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // requestPermission の戻り値注入
  // ---------------------------------------------------------------------------
  group('requestPermission', () {
    test('デフォルトは true を返す', () async {
      expect(await svc.requestPermission(), isTrue);
    });

    test('コンストラクタで false を注入できる', () async {
      final denied = FakeNotificationService(permissionResult: false);
      expect(await denied.requestPermission(), isFalse);
    });

    test('permissionResult セッターで後から変更できる', () async {
      expect(await svc.requestPermission(), isTrue);
      svc.permissionResult = false;
      expect(await svc.requestPermission(), isFalse);
      svc.permissionResult = true;
      expect(await svc.requestPermission(), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // タップ発火（emitTap / onTap）
  // ---------------------------------------------------------------------------
  group('onTap / emitTap', () {
    test('onTap で登録したハンドラが emitTap で呼ばれる', () async {
      String? received;
      svc.onTap((p) => received = p);

      svc.emitTap('q99');
      expect(received, 'q99');
    });

    test('payload null のタップもハンドラに届く', () async {
      String? received = 'initial';
      svc.onTap((p) => received = p);

      svc.emitTap(null);
      expect(received, isNull);
    });

    test('ハンドラ未登録で emitTap しても例外にならない', () {
      expect(() => svc.emitTap('x'), returnsNormally);
    });

    test('複数回 onTap すると最後のハンドラだけが有効', () {
      final calls = <String>[];
      svc.onTap((_) => calls.add('first'));
      svc.onTap((_) => calls.add('second'));

      svc.emitTap('payload');
      expect(calls, ['second']);
    });

    test('hasTapHandler: ハンドラ登録前は false、登録後は true', () {
      expect(svc.hasTapHandler, isFalse);
      svc.onTap((_) {});
      expect(svc.hasTapHandler, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // scheduledNotifications ヘルパー
  // ---------------------------------------------------------------------------
  group('scheduledNotifications ヘルパー', () {
    test('スケジュール後に scheduledNotifications で確認できる', () async {
      await svc.scheduleAt(id: 1, when: DateTime(2026, 7, 1, 9, 0), payload: 'a');
      expect(svc.scheduledNotifications, hasLength(1));
      expect(svc.scheduledNotifications.first.payload, 'a');
    });

    test('hasNotification で id の存在確認ができる', () async {
      await svc.scheduleAt(id: 42, when: DateTime(2026, 7, 1, 9, 0));
      expect(svc.hasNotification(42), isTrue);
      expect(svc.hasNotification(99), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // initialPayload の注入
  // ---------------------------------------------------------------------------
  group('initialPayload', () {
    test('デフォルトは null を返す（通知起動でない）', () async {
      expect(await svc.initialPayload(), isNull);
    });

    test('コンストラクタで payload を注入できる', () async {
      final withPayload = FakeNotificationService(initialPayloadValue: '20260610');
      expect(await withPayload.initialPayload(), '20260610');
    });

    test('initialPayloadValue フィールドで後から変更できる', () async {
      expect(await svc.initialPayload(), isNull);
      svc.initialPayloadValue = '20260614';
      expect(await svc.initialPayload(), '20260614');
      svc.initialPayloadValue = null;
      expect(await svc.initialPayload(), isNull);
    });

    test('複数回呼んでも同じ値を返す（消費されない）', () async {
      svc.initialPayloadValue = '20260610';
      expect(await svc.initialPayload(), '20260610');
      expect(await svc.initialPayload(), '20260610');
    });
  });

  // ---------------------------------------------------------------------------
  // NoopNotificationService
  // ---------------------------------------------------------------------------
  group('NoopNotificationService', () {
    const noop = NoopNotificationService();

    test('requestPermission は true を返す', () async {
      expect(await noop.requestPermission(), isTrue);
    });

    test('scheduleAt しても pending は空', () async {
      await noop.scheduleAt(id: 1, when: DateTime(2026, 7, 1, 9, 0));
      expect(await noop.pending(), isEmpty);
    });

    test('cancelAll は例外なし', () async {
      await expectLater(noop.cancelAll(), completes);
    });

    test('onTap / emitTap 相当操作で例外なし', () {
      expect(() => noop.onTap((_) {}), returnsNormally);
    });

    test('initialPayload は null を返す', () async {
      expect(await noop.initialPayload(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // PendingNotification モデル
  // ---------------------------------------------------------------------------
  group('PendingNotification', () {
    test('equality: 同値なら等しい', () {
      final when = DateTime(2026, 7, 1, 10, 0);
      final a = PendingNotification(id: 1, when: when, payload: 'x');
      final b = PendingNotification(id: 1, when: when, payload: 'x');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality: id が異なれば不等', () {
      final when = DateTime(2026, 7, 1, 10, 0);
      final a = PendingNotification(id: 1, when: when, payload: 'x');
      final b = PendingNotification(id: 2, when: when, payload: 'x');
      expect(a, isNot(equals(b)));
    });

    test('toString に主要フィールドが含まれる', () {
      final n = PendingNotification(id: 7, when: DateTime(2026, 7, 1, 9, 0), payload: 'p');
      expect(n.toString(), contains('7'));
      expect(n.toString(), contains('p'));
    });
  });
}
