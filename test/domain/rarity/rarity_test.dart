import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/domain/rarity/rarity.dart';

void main() {
  DateTime dtAt(int hour) => DateTime(2026, 6, 10, hour, 30, 0);

  group('rarityOf: 深夜帯（0〜4時台）→ rareMidnight', () {
    test('hour=0 → rareMidnight', () {
      expect(rarityOf(createdAt: dtAt(0)), Rarity.rareMidnight);
    });

    test('hour=1 → rareMidnight', () {
      expect(rarityOf(createdAt: dtAt(1)), Rarity.rareMidnight);
    });

    test('hour=2 → rareMidnight', () {
      expect(rarityOf(createdAt: dtAt(2)), Rarity.rareMidnight);
    });

    test('hour=3 → rareMidnight', () {
      expect(rarityOf(createdAt: dtAt(3)), Rarity.rareMidnight);
    });

    test('hour=4（4:59 相当） → rareMidnight', () {
      // DateTime(year,month,day,4,59,59) でも hour は 4
      final dt = DateTime(2026, 6, 10, 4, 59, 59);
      expect(rarityOf(createdAt: dt), Rarity.rareMidnight);
    });
  });

  group('rarityOf: 通常時間帯 → normal', () {
    test('5:00:00 ちょうど → normal（深夜帯の終端は含まない）', () {
      // hour=4（4:59:59）は rareMidnight・hour=5（5:00:00）は normal。
      // 境界を秒単位で明示する。
      final dt = DateTime(2026, 6, 10, 5, 0, 0);
      expect(rarityOf(createdAt: dt), Rarity.normal);
    });

    test('hour=5 → normal', () {
      expect(rarityOf(createdAt: dtAt(5)), Rarity.normal);
    });

    test('hour=12（正午） → normal', () {
      expect(rarityOf(createdAt: dtAt(12)), Rarity.normal);
    });

    test('hour=23 → normal', () {
      expect(rarityOf(createdAt: dtAt(23)), Rarity.normal);
    });
  });

  group('Rarity.isRare', () {
    test('rareMidnight.isRare → true', () {
      expect(Rarity.rareMidnight.isRare, isTrue);
    });

    test('normal.isRare → false', () {
      expect(Rarity.normal.isRare, isFalse);
    });
  });

  // ── 誕生日レア追加分 ──────────────────────────────────────────────────────

  group('rarityOf: 誕生日判定 → rareBirthday', () {
    final birthDate = DateTime(1990, 6, 10);

    test('誕生日一致（昼12時）→ rareBirthday', () {
      final createdAt = DateTime(2026, 6, 10, 12);
      expect(rarityOf(createdAt: createdAt, birthDate: birthDate),
          Rarity.rareBirthday);
    });

    test('誕生日かつ深夜（hour=2）→ rareBirthday（誕生日優先）', () {
      final createdAt = DateTime(2026, 6, 10, 2);
      expect(rarityOf(createdAt: createdAt, birthDate: birthDate),
          Rarity.rareBirthday);
    });

    test('誕生日不一致かつ深夜（翌日 hour=2）→ rareMidnight', () {
      final createdAt = DateTime(2026, 6, 11, 2);
      expect(rarityOf(createdAt: createdAt, birthDate: birthDate),
          Rarity.rareMidnight);
    });

    test('年違いでも月日一致なら rareBirthday（birthDate 1990・createdAt 2026）', () {
      final createdAt = DateTime(2026, 6, 10, 15);
      expect(rarityOf(createdAt: createdAt, birthDate: birthDate),
          Rarity.rareBirthday);
    });

    test('月一致・日違い（6/11）→ normal', () {
      final createdAt = DateTime(2026, 6, 11, 12);
      expect(rarityOf(createdAt: createdAt, birthDate: birthDate),
          Rarity.normal);
    });

    test('日一致・月違い（7/10）→ normal', () {
      final createdAt = DateTime(2026, 7, 10, 12);
      expect(rarityOf(createdAt: createdAt, birthDate: birthDate),
          Rarity.normal);
    });
  });

  group('rarityOf: birthDate=null → 従来挙動', () {
    test('birthDate=null・createdAt 6/10 昼12時 → normal', () {
      final createdAt = DateTime(2026, 6, 10, 12);
      expect(rarityOf(createdAt: createdAt), Rarity.normal);
    });

    test('birthDate=null・createdAt 6/10 hour=2 → rareMidnight', () {
      final createdAt = DateTime(2026, 6, 10, 2);
      expect(rarityOf(createdAt: createdAt), Rarity.rareMidnight);
    });
  });

  group('rarityOf: 2/29 誕生日の境界', () {
    final birthDate229 = DateTime(2000, 2, 29);

    test('2/29 生まれ・うるう年 2/29 createdAt → rareBirthday', () {
      final createdAt = DateTime(2024, 2, 29, 12);
      expect(rarityOf(createdAt: createdAt, birthDate: birthDate229),
          Rarity.rareBirthday);
    });

    test('2/29 生まれ・平年 2/28 createdAt → normal', () {
      final createdAt = DateTime(2026, 2, 28, 12);
      expect(rarityOf(createdAt: createdAt, birthDate: birthDate229),
          Rarity.normal);
    });

    test('2/29 生まれ・平年 3/1 createdAt → normal', () {
      final createdAt = DateTime(2026, 3, 1, 12);
      expect(rarityOf(createdAt: createdAt, birthDate: birthDate229),
          Rarity.normal);
    });
  });

  group('Rarity.rareBirthday のプロパティ', () {
    test('rareBirthday.label == "誕生日の化石"', () {
      expect(Rarity.rareBirthday.label, '誕生日の化石');
    });

    test('rareBirthday.isRare == true', () {
      expect(Rarity.rareBirthday.isRare, isTrue);
    });
  });
}
