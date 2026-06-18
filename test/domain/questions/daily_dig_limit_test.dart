// daily_dig_limit_test.dart — 1日の取得上限ロジック（純粋関数）。

import 'package:flutter_test/flutter_test.dart';

import 'package:specimen_box/domain/notification/notify_time.dart'
    show kNotificationsPerDay;
import 'package:specimen_box/domain/questions/daily_dig_limit.dart';
import 'package:specimen_box/domain/specimen/specimen.dart';

Specimen _s(String date) => Specimen(
      id: 'id-$date-${DateTime.now().microsecondsSinceEpoch}',
      answer: 'a',
      questionId: 'q',
      questionText: 'Q',
      date: date,
      createdAt: DateTime(2026, 6, 9),
    );

void main() {
  test('kDailyDigLimit は通知本数（1日3回）と一致する', () {
    expect(kDailyDigLimit, equals(kNotificationsPerDay));
    expect(kDailyDigLimit, equals(3));
  });

  test('digsOnDate はその日付の化石数を数える', () {
    final list = [
      _s('2026-06-09'),
      _s('2026-06-09'),
      _s('2026-06-08'),
    ];
    expect(digsOnDate(list, '2026-06-09'), 2);
    expect(digsOnDate(list, '2026-06-08'), 1);
    expect(digsOnDate(list, '2026-06-07'), 0);
  });

  test('canDigOnDate は上限未満で true、上限到達で false', () {
    final two = [_s('2026-06-09'), _s('2026-06-09')];
    final three = [...two, _s('2026-06-09')];
    final four = [...three, _s('2026-06-09')];

    expect(canDigOnDate(two, '2026-06-09'), isTrue); // 2 < 3
    expect(canDigOnDate(three, '2026-06-09'), isFalse); // 3 >= 3
    expect(canDigOnDate(four, '2026-06-09'), isFalse); // 4 >= 3
    // 別の日付は独立してカウントされる。
    expect(canDigOnDate(three, '2026-06-10'), isTrue);
  });

  test('limit を明示指定できる', () {
    final one = [_s('2026-06-09')];
    expect(canDigOnDate(one, '2026-06-09', limit: 1), isFalse);
    expect(canDigOnDate(one, '2026-06-09', limit: 2), isTrue);
  });
}
