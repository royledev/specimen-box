import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/domain/generation/seed.dart';

void main() {
  group('fnv1a32', () {
    test('決定論: 同じ入力は常に同じハッシュ', () {
      expect(fnv1a32('hello'), fnv1a32('hello'));
      expect(fnv1a32('a|b|c'), fnv1a32('a|b|c'));
    });

    test('異なる入力は（ほぼ確実に）異なる', () {
      expect(fnv1a32('foo'), isNot(fnv1a32('bar')));
    });

    test('32bit 範囲（0 以上 2^32 未満）', () {
      final h = fnv1a32('specimen-box');
      expect(h, greaterThanOrEqualTo(0));
      expect(h, lessThan(0x100000000));
    });

    test('空文字は FNV-1a オフセット基底 0x811c9dc5', () {
      expect(fnv1a32(''), 0x811c9dc5);
    });
  });
}
