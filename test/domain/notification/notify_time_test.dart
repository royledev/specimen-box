import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/domain/notification/notify_time.dart';

void main() {
  group('notifyTimeForDate', () {
    const salt = 'test-user-salt-abc123';
    const date1 = 20260610;

    // ---- 決定論テスト ----
    test('同 salt + 同日付なら同じ時刻を返す（複数回呼んで一致）', () {
      final t1 = notifyTimeForDate(userSalt: salt, yyyymmdd: date1);
      final t2 = notifyTimeForDate(userSalt: salt, yyyymmdd: date1);
      final t3 = notifyTimeForDate(userSalt: salt, yyyymmdd: date1);
      expect(t1, equals(t2));
      expect(t2, equals(t3));
    });

    test('同 salt + 同日付なら異なるインスタンスでも同一', () {
      final a = notifyTimeForDate(userSalt: salt, yyyymmdd: date1);
      final b = notifyTimeForDate(userSalt: salt, yyyymmdd: date1);
      expect(a.hour, b.hour);
      expect(a.minute, b.minute);
    });

    // ---- 日付変化テスト ----
    test('日付が変われば時刻が変化しうる（連続30日でばらつきが生じる）', () {
      final results = <String>{};
      for (int i = 0; i < 30; i++) {
        final dateInt = _addDays(20260601, i);
        final t = notifyTimeForDate(userSalt: salt, yyyymmdd: dateInt);
        results.add('${t.hour}:${t.minute}');
      }
      // 30日で少なくとも2種類以上の時刻があること（全部同じにはならない）
      expect(results.length, greaterThan(1));
    });

    // ---- 許可時間帯テスト ----
    test('全出力の hour がデフォルト重みの許可時間帯（8–23時）内', () {
      for (int i = 0; i < 365; i++) {
        final dateInt = _addDays(20260101, i);
        final t = notifyTimeForDate(userSalt: salt, yyyymmdd: dateInt);
        expect(t.hour, inInclusiveRange(8, 23),
            reason: 'date=$dateInt hour=${t.hour} should be in 8–23');
      }
    });

    test('デフォルト重みで 0–7時は決して選ばれない（365日サンプル）', () {
      for (int i = 0; i < 365; i++) {
        final dateInt = _addDays(20260101, i);
        final t = notifyTimeForDate(userSalt: salt, yyyymmdd: dateInt);
        expect(t.hour, isNot(inInclusiveRange(0, 7)),
            reason: 'date=$dateInt hour=${t.hour} must not be in 0–7');
      }
    });

    // ---- 重み0の時間帯テスト ----
    test('カスタム重みで重み0の時間帯は選ばれない', () {
      // 20時のみ許可
      final weights = List<int>.filled(24, 0);
      weights[20] = 1;

      for (int i = 0; i < 100; i++) {
        final dateInt = _addDays(20260101, i);
        final t = notifyTimeForDate(
            userSalt: salt, yyyymmdd: dateInt, hourWeights: weights);
        expect(t.hour, equals(20),
            reason: 'date=$dateInt hour=${t.hour} should be 20');
      }
    });

    test('重みの大きい時間帯は相対的に多く選ばれる', () {
      // 9時: 重み10, 22時: 重み1
      final weights = List<int>.filled(24, 0);
      weights[9] = 10;
      weights[22] = 1;

      int count9 = 0;
      int count22 = 0;
      for (int i = 0; i < 1100; i++) {
        final dateInt = _addDays(20260101, i);
        final t = notifyTimeForDate(
            userSalt: 'weight-test', yyyymmdd: dateInt, hourWeights: weights);
        if (t.hour == 9) count9++;
        if (t.hour == 22) count22++;
        // 9 または 22 以外は出ないはず
        expect(t.hour == 9 || t.hour == 22, isTrue,
            reason: 'hour ${t.hour} should be 9 or 22');
      }
      // 重み比が 10:1 なのでおおよそ 10倍の頻度になるはず（緩い閾値で確認）
      expect(count9, greaterThan(count22 * 2));
    });

    // ---- 異なる salt テスト ----
    test('異なる salt で分布が変わる（同日付でも時刻が異なりうる）', () {
      final salts = ['salt-A', 'salt-B', 'salt-C', 'salt-D', 'salt-E'];
      final hourSets = <String>{};
      for (final s in salts) {
        final t = notifyTimeForDate(userSalt: s, yyyymmdd: date1);
        hourSets.add('${t.hour}:${t.minute}');
      }
      // 5種類のsaltで少なくとも2通り以上の時刻が出ること
      expect(hourSets.length, greaterThan(1));
    });

    test('異なる salt で 365日の分布が異なる', () {
      final timesA = <String>[];
      final timesB = <String>[];
      for (int i = 0; i < 365; i++) {
        final d = _addDays(20260101, i);
        timesA.add(notifyTimeForDate(userSalt: 'saltA', yyyymmdd: d).toString());
        timesB.add(notifyTimeForDate(userSalt: 'saltB', yyyymmdd: d).toString());
      }
      // 全365日で全く同じ列になることはない
      expect(timesA, isNot(equals(timesB)));
    });

    // ---- 分のテスト ----
    test('minute が 0–59 の範囲内', () {
      for (int i = 0; i < 100; i++) {
        final dateInt = _addDays(20260101, i);
        final t = notifyTimeForDate(userSalt: salt, yyyymmdd: dateInt);
        expect(t.minute, inInclusiveRange(0, 59));
      }
    });

    test('minute も決定論的（同日付なら常に同じ minute）', () {
      final t1 = notifyTimeForDate(userSalt: salt, yyyymmdd: date1);
      final t2 = notifyTimeForDate(userSalt: salt, yyyymmdd: date1);
      expect(t1.minute, equals(t2.minute));
    });

    // ---- 返り値の年月日テスト ----
    test('返り値の年月日が入力の yyyymmdd と一致する', () {
      final t = notifyTimeForDate(userSalt: salt, yyyymmdd: 20260615);
      expect(t.year, 2026);
      expect(t.month, 6);
      expect(t.day, 15);
    });

    test('返り値の秒・マイクロ秒は0', () {
      final t = notifyTimeForDate(userSalt: salt, yyyymmdd: date1);
      expect(t.second, 0);
      expect(t.millisecond, 0);
      expect(t.microsecond, 0);
    });

    // ---- エラーケーステスト ----
    test('全重みが0のとき ArgumentError を投げる', () {
      expect(
        () => notifyTimeForDate(
          userSalt: salt,
          yyyymmdd: date1,
          hourWeights: List<int>.filled(24, 0),
        ),
        throwsArgumentError,
      );
    });

    test('hourWeights の長さが24以外のとき ArgumentError を投げる（release build でも有効）', () {
      expect(
        () => notifyTimeForDate(
          userSalt: salt,
          yyyymmdd: date1,
          hourWeights: List<int>.filled(23, 1),
        ),
        throwsA(isA<ArgumentError>()),
      );
      // 長すぎる場合も同様
      expect(
        () => notifyTimeForDate(
          userSalt: salt,
          yyyymmdd: date1,
          hourWeights: List<int>.filled(25, 1),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('notifyTimesForDate（1日3回）', () {
    const salt = 'test-user-salt-multi';
    const date1 = 20260610;

    test('デフォルトで kNotificationsPerDay 件を返す', () {
      final times = notifyTimesForDate(userSalt: salt, yyyymmdd: date1);
      expect(times.length, kNotificationsPerDay);
    });

    test('count を指定するとその件数を返す', () {
      expect(
        notifyTimesForDate(userSalt: salt, yyyymmdd: date1, count: 2).length,
        2,
      );
      expect(
        notifyTimesForDate(userSalt: salt, yyyymmdd: date1, count: 5).length,
        5,
      );
    });

    test('slot 0 は notifyTimeForDate と一致（後方互換）', () {
      final times = notifyTimesForDate(userSalt: salt, yyyymmdd: date1);
      final single = notifyTimeForDate(userSalt: salt, yyyymmdd: date1);
      // ソート後の先頭が single とは限らないので、集合に含まれることを確認する。
      expect(times.contains(single), isTrue);
    });

    test('昇順ソート済みで、互いに異なる時刻', () {
      final times = notifyTimesForDate(userSalt: salt, yyyymmdd: date1);
      for (var i = 1; i < times.length; i++) {
        expect(times[i].isAfter(times[i - 1]), isTrue);
      }
      expect(times.toSet().length, times.length, reason: '重複なし');
    });

    test('同 salt + 同日付なら必ず同じ時刻群（決定論）', () {
      final a = notifyTimesForDate(userSalt: salt, yyyymmdd: date1);
      final b = notifyTimesForDate(userSalt: salt, yyyymmdd: date1);
      expect(a, equals(b));
    });

    test('全件の hour がデフォルト重みの許可時間帯（8–23時）内', () {
      for (int i = 0; i < 60; i++) {
        final d = _addDays(20260101, i);
        for (final t in notifyTimesForDate(userSalt: salt, yyyymmdd: d)) {
          expect(t.hour, inInclusiveRange(8, 23));
        }
      }
    });

    test('各時刻の年月日が入力と一致し、秒以下は0', () {
      final times = notifyTimesForDate(userSalt: salt, yyyymmdd: 20260615);
      for (final t in times) {
        expect(t.year, 2026);
        expect(t.month, 6);
        expect(t.day, 15);
        expect(t.second, 0);
        expect(t.millisecond, 0);
      }
    });
  });

  group('dateToYyyymmdd', () {
    test('DateTime から yyyymmdd を正しく返す', () {
      expect(dateToYyyymmdd(DateTime(2026, 6, 10)), 20260610);
      expect(dateToYyyymmdd(DateTime(2026, 1, 1)), 20260101);
      expect(dateToYyyymmdd(DateTime(2026, 12, 31)), 20261231);
    });
  });

  group('yyyymmddStringToDate', () {
    // ---- 正常系 ----
    test('有効な yyyymmdd 文字列を DateTime に変換できる', () {
      final d = yyyymmddStringToDate('20260610');
      expect(d, isNotNull);
      expect(d!.year, 2026);
      expect(d.month, 6);
      expect(d.day, 10);
    });

    test('月初（1日）を正しく変換できる', () {
      final d = yyyymmddStringToDate('20260101');
      expect(d, isNotNull);
      expect(d!.year, 2026);
      expect(d.month, 1);
      expect(d.day, 1);
    });

    test('年末（12月31日）を正しく変換できる', () {
      final d = yyyymmddStringToDate('20261231');
      expect(d, isNotNull);
      expect(d!.year, 2026);
      expect(d.month, 12);
      expect(d.day, 31);
    });

    test('うるう年の2月29日を正しく変換できる', () {
      // 2024年はうるう年
      final d = yyyymmddStringToDate('20240229');
      expect(d, isNotNull);
      expect(d!.month, 2);
      expect(d.day, 29);
    });

    test('返り値の時刻は 0:00:00', () {
      final d = yyyymmddStringToDate('20260610');
      expect(d!.hour, 0);
      expect(d.minute, 0);
      expect(d.second, 0);
    });

    // ---- null / 空文字 ----
    test('null を渡すと null を返す', () {
      expect(yyyymmddStringToDate(null), isNull);
    });

    test('空文字列を渡すと null を返す', () {
      expect(yyyymmddStringToDate(''), isNull);
    });

    // ---- 桁数不正 ----
    test('7桁（1桁不足）は null を返す', () {
      expect(yyyymmddStringToDate('2026061'), isNull);
    });

    test('9桁（1桁超過）は null を返す', () {
      expect(yyyymmddStringToDate('202606101'), isNull);
    });

    // ---- 非数字 ----
    test('数字以外を含む文字列は null を返す', () {
      expect(yyyymmddStringToDate('2026061X'), isNull);
      expect(yyyymmddStringToDate('abcdefgh'), isNull);
      expect(yyyymmddStringToDate('2026-610'), isNull);
    });

    // ---- year 範囲外 ----
    test('year が 0 (文字列 "00000101") は null を返す', () {
      expect(yyyymmddStringToDate('00000101'), isNull);
    });

    // ---- 月範囲外 ----
    test('月が 0 は null を返す', () {
      expect(yyyymmddStringToDate('20260001'), isNull);
    });

    test('月が 13 は null を返す', () {
      expect(yyyymmddStringToDate('20261301'), isNull);
    });

    // ---- 日範囲外 ----
    test('日が 0 は null を返す', () {
      expect(yyyymmddStringToDate('20260600'), isNull);
    });

    test('日が各月の末日を超えると null を返す（4月30日まで / 5月31日はOK）', () {
      expect(yyyymmddStringToDate('20260431'), isNull); // 4月は30日まで
      expect(yyyymmddStringToDate('20260530'), isNotNull); // 5月30日はOK
      expect(yyyymmddStringToDate('20260531'), isNotNull); // 5月31日はOK
    });

    test('非うるう年の2月29日は null を返す', () {
      // 2026年はうるう年でない
      expect(yyyymmddStringToDate('20260229'), isNull);
    });

    test('32日は null を返す', () {
      expect(yyyymmddStringToDate('20260132'), isNull);
    });
  });
}

/// yyyymmdd に [days] 日を加算するユーティリティ（テスト専用）。
int _addDays(int yyyymmdd, int days) {
  final year = yyyymmdd ~/ 10000;
  final month = (yyyymmdd ~/ 100) % 100;
  final day = yyyymmdd % 100;
  final d = DateTime(year, month, day).add(Duration(days: days));
  return d.year * 10000 + d.month * 100 + d.day;
}
