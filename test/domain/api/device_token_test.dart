import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/domain/api/device_token.dart';

void main() {
  group('generateDeviceToken', () {
    test('32 文字の hex（16 バイト）を返す', () {
      final t = generateDeviceToken(Random(1));
      expect(t.length, 32);
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(t), isTrue);
      expect(t.length, lessThanOrEqualTo(36), reason: 'server schema 上限 36 に収まる');
    });

    test('同じ seed の Random なら決定論的（テスト用注入が効く）', () {
      expect(generateDeviceToken(Random(42)), generateDeviceToken(Random(42)));
    });

    test('異なる seed なら異なる（ほぼ確実に）', () {
      expect(generateDeviceToken(Random(1)),
          isNot(generateDeviceToken(Random(2))));
    });
  });
}
