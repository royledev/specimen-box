import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/domain/settings/birth_date.dart';

void main() {
  group('formatBirthDate', () {
    // ---- 基本整形 ----
    test('通常の日付を YYYY-MM-DD 形式に整形できる', () {
      expect(formatBirthDate(DateTime(1990, 6, 15)), '1990-06-15');
    });

    test('月・日が1桁の場合に2桁ゼロ埋めされる', () {
      expect(formatBirthDate(DateTime(1990, 1, 3)), '1990-01-03');
    });

    test('年が4桁未満の場合にゼロ埋めされる', () {
      expect(formatBirthDate(DateTime(5, 1, 3)), '0005-01-03');
    });

    test('月・日が2桁の場合はそのまま出力される', () {
      expect(formatBirthDate(DateTime(2024, 12, 31)), '2024-12-31');
    });

    test('時刻成分は無視され年月日のみが使用される', () {
      expect(
        formatBirthDate(DateTime(1990, 6, 15, 12, 30, 45)),
        '1990-06-15',
      );
    });
  });

  group('parseBirthDate', () {
    // ---- 正常系 ----
    test('有効な YYYY-MM-DD 文字列を DateTime に変換できる', () {
      final d = parseBirthDate('1990-06-15');
      expect(d, isNotNull);
      expect(d!.year, 1990);
      expect(d.month, 6);
      expect(d.day, 15);
    });

    test('返り値の時刻は 0:00:00', () {
      final d = parseBirthDate('1990-06-15');
      expect(d!.hour, 0);
      expect(d.minute, 0);
      expect(d.second, 0);
    });

    test('月初（1日）を正しく変換できる', () {
      final d = parseBirthDate('2026-01-01');
      expect(d, isNotNull);
      expect(d!.year, 2026);
      expect(d.month, 1);
      expect(d.day, 1);
    });

    test('年末（12月31日）を正しく変換できる', () {
      final d = parseBirthDate('2026-12-31');
      expect(d, isNotNull);
      expect(d!.year, 2026);
      expect(d.month, 12);
      expect(d.day, 31);
    });

    // ---- うるう年 ----
    test('うるう年の2月29日は有効（2024年はうるう年）', () {
      final d = parseBirthDate('2024-02-29');
      expect(d, isNotNull);
      expect(d!.month, 2);
      expect(d.day, 29);
    });

    test('非うるう年の2月29日は null を返す（2026年はうるう年でない）', () {
      expect(parseBirthDate('2026-02-29'), isNull);
    });

    // ---- null / 空文字 ----
    test('null を渡すと null を返す', () {
      expect(parseBirthDate(null), isNull);
    });

    test('空文字列を渡すと null を返す', () {
      expect(parseBirthDate(''), isNull);
    });

    // ---- フォーマット不一致 ----
    test('ゼロ埋め無し（1桁月日）は null を返す', () {
      expect(parseBirthDate('1990-1-3'), isNull);
    });

    test('スラッシュ区切りは null を返す', () {
      expect(parseBirthDate('1990/01/03'), isNull);
    });

    test('ハイフン無し（yyyymmdd 形式）は null を返す', () {
      expect(parseBirthDate('19900615'), isNull);
    });

    test('文字列 "abc" は null を返す', () {
      expect(parseBirthDate('abc'), isNull);
    });

    // ---- 月範囲外 ----
    test('月が 0 は null を返す', () {
      expect(parseBirthDate('1990-00-01'), isNull);
    });

    test('月が 13 は null を返す', () {
      expect(parseBirthDate('1990-13-01'), isNull);
    });

    // ---- 日範囲外（実在日チェック・ロールオーバー排除） ----
    test('2月30日は null を返す（ロールオーバーを許さない）', () {
      expect(parseBirthDate('2026-02-30'), isNull);
    });

    test('4月31日は null を返す（4月は30日まで）', () {
      expect(parseBirthDate('2026-04-31'), isNull);
    });

    test('1月32日は null を返す', () {
      expect(parseBirthDate('2026-01-32'), isNull);
    });

    test('日が 0 は null を返す', () {
      expect(parseBirthDate('2026-06-00'), isNull);
    });

    // ---- 負の年（high 差し戻し対応） ----
    test('負の年（-190-06-15）は null を返す', () {
      expect(parseBirthDate('-190-06-15'), isNull);
    });

    // ---- 年 0000（medium 差し戻し対応） ----
    test('年が 0000 は null を返す（非現実的な生年月日）', () {
      expect(parseBirthDate('0000-06-15'), isNull);
    });

    // ---- 年の境界値 ----
    test('年が 0001（西暦 1 年）は有効', () {
      final d = parseBirthDate('0001-06-15');
      expect(d, isNotNull);
      expect(d!.year, 1);
      expect(d.month, 6);
      expect(d.day, 15);
    });

    // ---- 余剰文字・前後空白（正規表現ガードの担保） ----
    test('余剰文字付き（"1990-01-03extra"）は null を返す', () {
      expect(parseBirthDate('1990-01-03extra'), isNull);
    });

    test('前後に空白がある（" 1990-01-03"）は null を返す', () {
      expect(parseBirthDate(' 1990-01-03'), isNull);
      expect(parseBirthDate('1990-01-03 '), isNull);
    });

    test('全角数字を含む場合は null を返す', () {
      // 全角の "１９９０-０１-０３" は \d にマッチしないため弾かれる。
      expect(parseBirthDate('１９９０-０１-０３'), isNull);
    });
  });

  group('formatBirthDate と parseBirthDate の往復', () {
    test('parseBirthDate(formatBirthDate(d)) == DateTime(d.year, d.month, d.day)', () {
      final dates = [
        DateTime(1990, 1, 3),
        DateTime(2000, 12, 31),
        DateTime(2024, 2, 29), // うるう年
        DateTime(1, 1, 1),
        DateTime(2026, 6, 10),
      ];
      for (final d in dates) {
        final formatted = formatBirthDate(d);
        final parsed = parseBirthDate(formatted);
        expect(
          parsed,
          equals(DateTime(d.year, d.month, d.day)),
          reason: 'failed for $formatted',
        );
      }
    });

    test('ゼロ埋め: DateTime(1990, 1, 3) → "1990-01-03"', () {
      expect(formatBirthDate(DateTime(1990, 1, 3)), '1990-01-03');
      expect(parseBirthDate('1990-01-03'), DateTime(1990, 1, 3));
    });
  });
}
