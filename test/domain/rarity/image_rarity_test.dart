// 画像レア度ヘルパー（ADR-0017）の純粋ユニットテスト。
//
// 既存の Rarity（時刻/誕生日由来）とは別概念であることに注意（混同しない）。
import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/domain/rarity/image_rarity.dart';

void main() {
  group('isValidImageRarity', () {
    test('1〜5 は有効', () {
      for (var r = kMinImageRarity; r <= kMaxImageRarity; r++) {
        expect(isValidImageRarity(r), isTrue, reason: 'rarity=$r');
      }
    });

    test('null・範囲外は無効', () {
      expect(isValidImageRarity(null), isFalse);
      expect(isValidImageRarity(0), isFalse);
      expect(isValidImageRarity(6), isFalse);
      expect(isValidImageRarity(-1), isFalse);
    });
  });

  group('imageRarityStars', () {
    test('レア度ぶん★、残りは☆（合計5つ）', () {
      expect(imageRarityStars(1), '★☆☆☆☆');
      expect(imageRarityStars(2), '★★☆☆☆');
      expect(imageRarityStars(3), '★★★☆☆');
      expect(imageRarityStars(4), '★★★★☆');
      expect(imageRarityStars(5), '★★★★★');
    });

    test('範囲外は 1〜5 に clamp する', () {
      expect(imageRarityStars(0), '★☆☆☆☆');
      expect(imageRarityStars(-3), '★☆☆☆☆');
      expect(imageRarityStars(6), '★★★★★');
      expect(imageRarityStars(99), '★★★★★');
    });
  });
}
