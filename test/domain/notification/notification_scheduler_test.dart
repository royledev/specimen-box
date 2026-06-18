import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/domain/notification/notification_scheduler.dart';
import 'package:specimen_box/domain/notification/notify_time.dart';
import 'package:specimen_box/platform/notifications/fake_notification_service.dart';

void main() {
  const String salt = 'test-salt-scheduler';

  // now を通知時刻より必ず前になるよう深夜0時に固定。
  // kDefaultHourWeights で 8–23時が選ばれるため、0時01分 now なら当日分も積まれる。
  final DateTime now = DateTime(2026, 6, 10, 0, 1, 0);

  // ---------------------------------------------------------------------------
  // computeSchedule 純粋関数テスト
  // ---------------------------------------------------------------------------

  group('computeSchedule - 純粋算出部', () {
    test('horizonDays 日先まで × 1日 kNotificationsPerDay 件 生成される（重複・過去なし前提）', () {
      const int horizon = 7;
      final result = computeSchedule(
        now: now,
        userSalt: salt,
        alreadyScheduledIds: {},
        horizonDays: horizon,
      );
      // 当日（offset=0）から horizon 日先まで（horizon+1 日）× 1日 kNotificationsPerDay 件。
      // 当日 0時01分 → 通知時刻は 8–23 時 → now(0:01) より後なので当日3件も含まれる。
      expect(result.length, (horizon + 1) * kNotificationsPerDay);
    });

    test('1日に最大 kNotificationsPerDay 件・同日の id は連番 slot で一意', () {
      final result = computeSchedule(
        now: now,
        userSalt: salt,
        alreadyScheduledIds: {},
        horizonDays: 3,
      );
      // 日付（id ~/ 10）ごとに件数 <= kNotificationsPerDay、id は全件ユニーク。
      final byDay = <int, List<int>>{};
      for (final n in result) {
        byDay.putIfAbsent(n.id ~/ 10, () => []).add(n.id % 10);
      }
      for (final slots in byDay.values) {
        expect(slots.length, lessThanOrEqualTo(kNotificationsPerDay));
        expect(slots.toSet().length, slots.length, reason: 'slot は重複しない');
      }
      final allIds = result.map((n) => n.id).toList();
      expect(allIds.toSet().length, allIds.length, reason: 'id は全件ユニーク');
    });

    test('同日の3件は昇順時刻で、互いに異なる時刻', () {
      final result = computeSchedule(
        now: now,
        userSalt: salt,
        alreadyScheduledIds: {},
        horizonDays: 0,
      );
      expect(result.length, kNotificationsPerDay);
      for (var i = 1; i < result.length; i++) {
        expect(result[i].when.isAfter(result[i - 1].when), isTrue,
            reason: '時刻は昇順かつ相異なる');
      }
    });

    test('合計が kMaxPending(64) を超えない（horizon を大きくしても上限で打ち切り）', () {
      // horizon を 200 にしても kMaxPending=64 で打ち切られる。
      // 既存 pending が 0 件・horizon が十分大きければ「ちょうど 64件」になる。
      final result = computeSchedule(
        now: now,
        userSalt: salt,
        alreadyScheduledIds: {},
        horizonDays: 200,
      );
      expect(result.length, equals(kMaxPending));
    });

    test('maxPending カスタム値でも上限が守られる（ちょうどカスタム値になる）', () {
      const int custom = 10;
      // 既存 pending が 0 件・horizon が十分大きければ「ちょうど custom 件」になる。
      final result = computeSchedule(
        now: now,
        userSalt: salt,
        alreadyScheduledIds: {},
        horizonDays: 200,
        maxPending: custom,
      );
      expect(result.length, equals(custom));
    });

    test('既存 pending と合算して maxPending を超えない', () {
      // 既に 60件 pending の想定。残り 4件しか積めない。
      // id は重複判定に使う整数値（yyyymmdd 形式）。
      // ここでは 2020年1月1日 〜 3月1日の実在日付を使用する（過去日なので future 候補と重複しない）。
      final existing = <int>{};
      for (int i = 0; i < 60; i++) {
        // 20200101, 20200102, ... 20200301 の実在日（重複判定は整数一致のみ）。
        existing.add(20200101 + i);
      }
      final result = computeSchedule(
        now: now,
        userSalt: salt,
        alreadyScheduledIds: existing,
        horizonDays: 200,
        maxPending: kMaxPending, // 64
      );
      // 64 - 60 = 4 件になる（ちょうど残り枠が埋まる）。
      expect(result.length, equals(kMaxPending - 60));
    });

    test('既存 pending にある slot id（yyyymmdd*10+slot）は二重化しない', () {
      // 当日の全 slot id を既存 pending に入れておく。
      final int ymd = dateToYyyymmdd(now);
      final existing = {
        for (int slot = 0; slot < kNotificationsPerDay; slot++) ymd * 10 + slot,
      };
      final result = computeSchedule(
        now: now,
        userSalt: salt,
        alreadyScheduledIds: existing,
        horizonDays: 7,
      );
      // 当日分（どの slot も）含まれない。
      expect(result.any((n) => n.id ~/ 10 == ymd), isFalse);
    });

    test('過去時刻（now 以前）は積まれない', () {
      // now を23時59分に設定して、当日の通知時刻（8–23時）が now 以前になるようにする。
      final DateTime lateNow = DateTime(2026, 6, 10, 23, 59, 0);
      final result = computeSchedule(
        now: lateNow,
        userSalt: salt,
        alreadyScheduledIds: {},
        horizonDays: 7,
      );
      // すべての when が lateNow より後であること。
      for (final n in result) {
        expect(n.when.isAfter(lateNow), isTrue,
            reason: 'when=${n.when} は now=$lateNow より後であるべき');
      }
      // 当日（2026-06-10）の通知時刻は lateNow(23:59) より前なので含まれない。
      final int ymd = dateToYyyymmdd(lateNow);
      expect(result.any((n) => n.id ~/ 10 == ymd), isFalse);
    });

    test('同 now + salt なら結果が決定論的に一致', () {
      final result1 = computeSchedule(
        now: now,
        userSalt: salt,
        alreadyScheduledIds: {},
        horizonDays: 10,
      );
      final result2 = computeSchedule(
        now: now,
        userSalt: salt,
        alreadyScheduledIds: {},
        horizonDays: 10,
      );
      expect(result1, equals(result2));
    });

    test('salt が異なると結果が変わる（決定論性の確認）', () {
      final result1 = computeSchedule(
        now: now,
        userSalt: 'salt-A',
        alreadyScheduledIds: {},
        horizonDays: 5,
      );
      final result2 = computeSchedule(
        now: now,
        userSalt: 'salt-B',
        alreadyScheduledIds: {},
        horizonDays: 5,
      );
      // id（日付）は同じでも when が異なるはず。
      final times1 = result1.map((n) => n.when).toList();
      final times2 = result2.map((n) => n.when).toList();
      expect(times1, isNot(equals(times2)));
    });

    test('id は yyyymmdd*10+slot、payload は当日の yyyymmdd 文字列', () {
      final result = computeSchedule(
        now: now,
        userSalt: salt,
        alreadyScheduledIds: {},
        horizonDays: 3,
      );
      for (final n in result) {
        final int ymd = n.id ~/ 10;
        final int slot = n.id % 10;
        // 日付部が yyyymmdd 形式（8桁数字）、slot は 0..perDay-1。
        expect(ymd.toString().length, 8);
        expect(slot, inInclusiveRange(0, kNotificationsPerDay - 1));
        // payload は slot に依らず当日の yyyymmdd 文字列。
        expect(n.payload, ymd.toString());
      }
    });

    test('当日の通知時刻が now より後なら当日分（全 slot）が含まれる', () {
      // now を早朝 0時01分に設定 → 通知時刻は 8–23 時 → now より後なので含まれる。
      final int ymd = dateToYyyymmdd(now);
      final result = computeSchedule(
        now: now,
        userSalt: salt,
        alreadyScheduledIds: {},
        horizonDays: 0,
      );
      expect(result.where((n) => n.id ~/ 10 == ymd).length,
          kNotificationsPerDay);
    });

    test('既存 pending が maxPending を満たしている場合は空リストを返す', () {
      // 64件 pending の場合は何も追加しない。
      final existing = <int>{for (int i = 1; i <= 64; i++) 20200101 + i};
      final result = computeSchedule(
        now: now,
        userSalt: salt,
        alreadyScheduledIds: existing,
        horizonDays: 30,
      );
      expect(result, isEmpty);
    });

    test('既存 pending が maxPending を超えている場合も空リストを返す（負数 remaining 対応）', () {
      // alreadyScheduledIds.length > maxPending の場合、remaining が負数になるが
      // <= 0 の条件で安全に空リストを返す挙動を検証する。
      const int customMax = 5;
      final existing = <int>{for (int i = 1; i <= 10; i++) 20200101 + i}; // 10件 > 5件
      final result = computeSchedule(
        now: now,
        userSalt: salt,
        alreadyScheduledIds: existing,
        horizonDays: 30,
        maxPending: customMax,
      );
      expect(result, isEmpty);
    });

    test('horizonDays=0 は当日分のみ（最大 kNotificationsPerDay 件）', () {
      final result = computeSchedule(
        now: now, // 0:01 → 当日通知時刻は 8–23 時で now より後
        userSalt: salt,
        alreadyScheduledIds: {},
        horizonDays: 0,
      );
      expect(result.length, kNotificationsPerDay);
    });

    test('perDay を指定すると1日あたりの件数が変わる', () {
      final result = computeSchedule(
        now: now,
        userSalt: salt,
        alreadyScheduledIds: {},
        horizonDays: 0,
        perDay: 2,
      );
      expect(result.length, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // reconcile コーディネータテスト（FakeNotificationService 使用）
  // ---------------------------------------------------------------------------

  group('reconcile - コーディネータ（副作用部）', () {
    test('FakeNotificationService に指定件数が積まれる', () async {
      final svc = FakeNotificationService();
      const int horizon = 5;
      await reconcile(
        svc,
        now: now,
        userSalt: salt,
        horizonDays: horizon,
      );
      final pending = await svc.pending();
      // (horizon+1) 日 × 1日 kNotificationsPerDay 件スケジュールされる（当日分含む）。
      expect(pending.length, (horizon + 1) * kNotificationsPerDay);
    });

    test('旧スキーム（1日1件 id=yyyymmdd 8桁）が残っていれば一掃して積み直す', () async {
      final svc = FakeNotificationService();
      // 旧スキームの pending を直接仕込む（id=yyyymmdd の8桁・未来時刻）。
      await svc.scheduleAt(
        id: 20260611,
        when: DateTime(2026, 6, 11, 10, 0),
        payload: '20260611',
      );
      await reconcile(svc, now: now, userSalt: salt, horizonDays: 5);
      final pending = await svc.pending();
      // 旧スキーム id（8桁）は残っていない。
      expect(pending.any((n) => n.id >= 10000000 && n.id < 100000000), isFalse);
      // 新スキーム（9桁以上）だけが積まれている。
      expect(pending.every((n) => n.id >= 100000000), isTrue);
      expect(pending.length, (5 + 1) * kNotificationsPerDay);
    });

    test('reconcile 後の pending id が computeSchedule の結果と id ソートで一致', () async {
      final svc = FakeNotificationService();
      const int horizon = 7;
      await reconcile(
        svc,
        now: now,
        userSalt: salt,
        horizonDays: horizon,
      );

      final pending = await svc.pending();
      final planned = computeSchedule(
        now: now,
        userSalt: salt,
        alreadyScheduledIds: {},
        horizonDays: horizon,
      );

      // pending() の返却順序は未保証のため id ソートして比較する（T2 low 指摘吸収）。
      final pendingIds = (pending.map((n) => n.id).toList()..sort());
      final plannedIds = (planned.map((n) => n.id).toList()..sort());
      expect(pendingIds, equals(plannedIds));
    });

    test('二回 reconcile しても重複しない（既存 pending をスキップ）', () async {
      final svc = FakeNotificationService();
      const int horizon = 5;

      // 1回目。
      await reconcile(svc, now: now, userSalt: salt, horizonDays: horizon);
      final afterFirst = await svc.pending();
      final countAfterFirst = afterFirst.length;

      // 2回目（同じ引数）。既存 pending があるのでスキップされ増えない。
      await reconcile(svc, now: now, userSalt: salt, horizonDays: horizon);
      final afterSecond = await svc.pending();

      expect(afterSecond.length, countAfterFirst);
    });

    test('reconcile は maxPending を超えてスケジュールしない（ちょうど maxPending 件になる）', () async {
      final svc = FakeNotificationService();
      // 既存 pending が 0 件・horizon が十分大きければ「ちょうど maxPending 件」になる。
      await reconcile(
        svc,
        now: now,
        userSalt: salt,
        horizonDays: 200,
        maxPending: 5,
      );
      final pending = await svc.pending();
      expect(pending.length, equals(5));
    });

    test('reconcile は過去時刻をスケジュールしない', () async {
      final svc = FakeNotificationService();
      final DateTime lateNow = DateTime(2026, 6, 10, 23, 59, 0);
      await reconcile(svc, now: lateNow, userSalt: salt, horizonDays: 7);
      final pending = await svc.pending();
      for (final n in pending) {
        expect(n.when.isAfter(lateNow), isTrue);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // computeTestSchedule（実機テスト用高頻度）
  // ---------------------------------------------------------------------------
  group('computeTestSchedule', () {
    final testNow = DateTime(2026, 6, 12, 9, 0, 0);

    test('count 件を intervalSeconds 間隔で未来に積む', () {
      final planned = computeTestSchedule(
        now: testNow,
        payload: '20260612',
        count: 5,
        intervalSeconds: 30,
      );
      expect(planned, hasLength(5));
      for (var i = 0; i < planned.length; i++) {
        expect(planned[i].when, testNow.add(Duration(seconds: 30 * (i + 1))));
        expect(planned[i].when.isAfter(testNow), isTrue);
        expect(planned[i].payload, '20260612');
      }
    });

    test('id は本番 yyyymmdd と衝突しない基点からの連番', () {
      final planned =
          computeTestSchedule(now: testNow, payload: '20260612', count: 3);
      expect(planned.map((p) => p.id), [
        kTestNotificationIdBase,
        kTestNotificationIdBase + 1,
        kTestNotificationIdBase + 2,
      ]);
      for (final p in planned) {
        expect(p.id, greaterThan(99999999)); // 8桁 yyyymmdd より大
        expect(p.id, lessThan(2147483647)); // 32bit 符号付き上限未満
      }
    });

    test('既定は 5 件・30 秒間隔', () {
      final planned = computeTestSchedule(now: testNow, payload: '20260612');
      expect(planned, hasLength(5));
      expect(planned.first.when, testNow.add(const Duration(seconds: 30)));
    });
  });
}
