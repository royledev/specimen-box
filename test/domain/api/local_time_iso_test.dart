import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/domain/api/local_time_iso.dart';

void main() {
  group('formatLocalIso8601', () {
    test('オフセット付き ISO8601（秒まで）を返す', () {
      // ローカル時刻で構築。オフセットは実行環境依存なので形だけ検証する。
      final s = formatLocalIso8601(DateTime(2026, 6, 13, 23, 40, 5));
      expect(s, startsWith('2026-06-13T23:40:05'));
      expect(
        RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+\-]\d{2}:\d{2}$')
            .hasMatch(s),
        isTrue,
        reason: 'YYYY-MM-DDTHH:MM:SS±HH:MM 形式',
      );
    });

    test('UTC は +00:00', () {
      final s = formatLocalIso8601(DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(s, '2026-01-02T03:04:05+00:00');
    });

    test('ゼロ埋め（1桁の月日時分秒）', () {
      final s = formatLocalIso8601(DateTime.utc(2026, 3, 7, 9, 8, 1));
      expect(s, '2026-03-07T09:08:01+00:00');
    });

    test('server の zod .datetime({offset:true}) を満たす形（offset 必須）', () {
      final s = formatLocalIso8601(DateTime.utc(2026, 12, 31, 0, 0, 0));
      // 末尾に Z ではなくオフセットが付く（UTC は +00:00）。
      expect(s.endsWith('Z'), isFalse);
      expect(s.endsWith('+00:00'), isTrue);
    });
  });
}
