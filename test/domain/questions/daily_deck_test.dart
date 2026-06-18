import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/data/questions/question_loader.dart';
import 'package:specimen_box/domain/questions/daily_question.dart';

// ---------------------------------------------------------------------------
// テストデータ生成ヘルパ
// ---------------------------------------------------------------------------

/// カテゴリ A/B/C それぞれ 3 問（計 9 問）の核プール。
List<QuestionData> _multiCategory() => const [
      QuestionData(id: 'a-1', text: 'A問1', category: 'catA', weight: 1.0, condition: null),
      QuestionData(id: 'a-2', text: 'A問2', category: 'catA', weight: 1.0, condition: null),
      QuestionData(id: 'a-3', text: 'A問3', category: 'catA', weight: 1.0, condition: null),
      QuestionData(id: 'b-1', text: 'B問1', category: 'catB', weight: 1.0, condition: null),
      QuestionData(id: 'b-2', text: 'B問2', category: 'catB', weight: 1.0, condition: null),
      QuestionData(id: 'b-3', text: 'B問3', category: 'catB', weight: 1.0, condition: null),
      QuestionData(id: 'c-1', text: 'C問1', category: 'catC', weight: 1.0, condition: null),
      QuestionData(id: 'c-2', text: 'C問2', category: 'catC', weight: 1.0, condition: null),
      QuestionData(id: 'c-3', text: 'C問3', category: 'catC', weight: 1.0, condition: null),
    ];

/// 単一カテゴリ 5 問。
List<QuestionData> _singleCategory() => const [
      QuestionData(id: 's-1', text: 'S問1', category: 'catS', weight: 1.0, condition: null),
      QuestionData(id: 's-2', text: 'S問2', category: 'catS', weight: 1.0, condition: null),
      QuestionData(id: 's-3', text: 'S問3', category: 'catS', weight: 1.0, condition: null),
      QuestionData(id: 's-4', text: 'S問4', category: 'catS', weight: 1.0, condition: null),
      QuestionData(id: 's-5', text: 'S問5', category: 'catS', weight: 1.0, condition: null),
    ];

void main() {
  // =========================================================================
  // dayNumberFromYyyymmdd
  // =========================================================================
  group('dayNumberFromYyyymmdd', () {
    test('1970-01-01 → 0（エポック）', () {
      expect(dayNumberFromYyyymmdd(19700101), 0);
    });

    test('1970-01-02 → 1（エポック翌日）', () {
      expect(dayNumberFromYyyymmdd(19700102), 1);
    });

    test('既知日付の単調増加: 20260610 と 20260611 が連番', () {
      final d0 = dayNumberFromYyyymmdd(20260610);
      final d1 = dayNumberFromYyyymmdd(20260611);
      expect(d1, d0 + 1);
    });

    test('うるう年の月跨ぎ: 20240228 → 20240229 が +1（うるう年）', () {
      final d0 = dayNumberFromYyyymmdd(20240228);
      final d1 = dayNumberFromYyyymmdd(20240229);
      expect(d1, d0 + 1);
    });

    test('平年の月跨ぎ: 20260228 → 20260301 が +1', () {
      final d0 = dayNumberFromYyyymmdd(20260228);
      final d1 = dayNumberFromYyyymmdd(20260301);
      expect(d1, d0 + 1);
    });

    test('年跨ぎの連続性: 20251231 → 20260101 が +1', () {
      final d0 = dayNumberFromYyyymmdd(20251231);
      final d1 = dayNumberFromYyyymmdd(20260101);
      expect(d1, d0 + 1);
    });

    test('1970-01-01 より前の日付は負の値', () {
      // 1969-12-31 は -1 のはず。
      expect(dayNumberFromYyyymmdd(19691231), -1);
    });
  });

  // =========================================================================
  // buildDailyDeck
  // =========================================================================
  group('buildDailyDeck', () {
    // -----------------------------------------------------------------------
    // 空入力
    // -----------------------------------------------------------------------
    test('core が空なら空リストを返す', () {
      expect(buildDailyDeck([], 'salt', 0), isEmpty);
    });

    // -----------------------------------------------------------------------
    // 決定論
    // -----------------------------------------------------------------------
    test('同一 (core, salt, cycleIndex) で複数回呼んで常に同じ並び', () {
      final core = _multiCategory();
      final deck1 = buildDailyDeck(core, 'test-salt', 7);
      final deck2 = buildDailyDeck(core, 'test-salt', 7);
      expect(
        deck1.map((q) => q.id).toList(),
        deck2.map((q) => q.id).toList(),
        reason: '決定論: 同一入力で異なる並びが返った',
      );
    });

    // -----------------------------------------------------------------------
    // 順列（各要素ちょうど1回）
    // -----------------------------------------------------------------------
    test('出力の id 集合 == 入力の id 集合（過不足なし）', () {
      final core = _multiCategory();
      final deck = buildDailyDeck(core, 'test-salt', 3);
      final inputIds = core.map((q) => q.id).toSet();
      final outputIds = deck.map((q) => q.id).toSet();
      expect(outputIds, inputIds, reason: '順列: id 集合が一致しない');
    });

    test('出力の長さ == 入力の長さ', () {
      final core = _multiCategory();
      final deck = buildDailyDeck(core, 'test-salt', 3);
      expect(deck.length, core.length, reason: '順列: 長さが一致しない');
    });

    test('出力に重複 id がない（各問いちょうど1回）', () {
      final core = _multiCategory();
      final deck = buildDailyDeck(core, 'test-salt', 3);
      final ids = deck.map((q) => q.id).toList();
      expect(ids.toSet().length, ids.length, reason: '順列: 重複が存在する');
    });

    test('単一カテゴリでも順列（全問が出る）', () {
      final core = _singleCategory();
      final deck = buildDailyDeck(core, 'test-salt', 0);
      expect(deck.length, core.length);
      expect(deck.map((q) => q.id).toSet(), core.map((q) => q.id).toSet());
    });

    // -----------------------------------------------------------------------
    // cycleIndex が違えば並びが変わる
    // -----------------------------------------------------------------------
    test('cycleIndex 違いで並びが変わる（少なくとも一部の位置で id が異なる）', () {
      final core = _multiCategory();
      final deck0 = buildDailyDeck(core, 'test-salt', 0).map((q) => q.id).toList();
      final deck1 = buildDailyDeck(core, 'test-salt', 1).map((q) => q.id).toList();
      // id 集合は同じ（順列）だが、並び順が完全に一致してはならない。
      expect(deck0, isNot(equals(deck1)), reason: 'cycleIndex 違いで並びが変わらなかった');
    });

    // -----------------------------------------------------------------------
    // salt が違えば並びが変わる
    // -----------------------------------------------------------------------
    test('salt 違いで並びが変わる', () {
      final core = _multiCategory();
      final deckA = buildDailyDeck(core, 'salt-alpha', 0).map((q) => q.id).toList();
      final deckB = buildDailyDeck(core, 'salt-beta', 0).map((q) => q.id).toList();
      expect(deckA, isNot(equals(deckB)), reason: 'salt 違いで並びが変わらなかった');
    });

    // -----------------------------------------------------------------------
    // カテゴリ分散（インターリーブ）
    // -----------------------------------------------------------------------

    /// 隣接する要素のカテゴリが同じペア数を数える。
    int adjacentSameCategoryCount(List<QuestionData> deck) {
      int count = 0;
      for (int i = 0; i < deck.length - 1; i++) {
        if (deck[i].category == deck[i + 1].category) count++;
      }
      return count;
    }

    test('3カテゴリ×3問のデッキで隣接同カテゴリが最小（最良: 0 ペア）', () {
      // ラウンドロビンで A→B→C→A→B→C→A→B→C の理想パターンなら隣接同カテゴリ = 0。
      // 各カテゴリ内のシャッフルはあるが、ラウンドロビン構造により
      // 隣接する 8 ペアのうち同カテゴリになるのはカテゴリ間の境界なし = 0 が期待値。
      final core = _multiCategory();
      final deck = buildDailyDeck(core, 'test-salt', 0);
      final adjacentSame = adjacentSameCategoryCount(deck);
      // ラウンドロビンなら必ず 0 になる（カテゴリ数=3、各3問なので A,B,C,A,B,C,...）。
      expect(adjacentSame, 0,
          reason: '3カテゴリ均等でラウンドロビンなら隣接同カテゴリ=0 のはず。実際: $adjacentSame');
    });

    test('カテゴリ分散: 先頭 3 件が全カテゴリ異なる（ラウンドロビン循環確認）', () {
      // 3カテゴリ×3問の場合、先頭3要素は catA/catB/catC が1つずつ含まれるはず。
      final core = _multiCategory();
      final deck = buildDailyDeck(core, 'test-salt', 0);
      final topCategories = deck.take(3).map((q) => q.category).toSet();
      expect(topCategories.length, 3,
          reason: '先頭3件が全カテゴリ異なっていない: $topCategories');
    });

    test('カテゴリ分散: 複数の cycleIndex でも隣接同カテゴリが 0', () {
      // ラウンドロビン構造は cycleIndex が変わっても維持される。
      final core = _multiCategory();
      for (int ci = 0; ci < 5; ci++) {
        final deck = buildDailyDeck(core, 'deck-salt', ci);
        final adjacentSame = adjacentSameCategoryCount(deck);
        expect(adjacentSame, 0,
            reason: 'cycleIndex=$ci で隣接同カテゴリが 0 でない: $adjacentSame');
      }
    });

    test('カテゴリ分散: 決定論的な固定値検証（test-salt/cycleIndex=0）', () {
      // カテゴリ順シャッフルと各グループ内シャッフルは決定論なので、
      // 特定 (salt, cycleIndex) に対してカテゴリのパターンが固定できる。
      // 3カテゴリ×3問のラウンドロビンでは必ず
      // cat_X, cat_Y, cat_Z, cat_X, cat_Y, cat_Z, cat_X, cat_Y, cat_Z
      // の形になる（X/Y/Z はシャッフルで決まる順）。
      final core = _multiCategory();
      final deck = buildDailyDeck(core, 'test-salt', 0);
      // 同カテゴリのペアが連続しないことを確認。
      for (int i = 0; i < deck.length - 1; i++) {
        expect(deck[i].category, isNot(deck[i + 1].category),
            reason: 'position $i と ${i + 1} が同カテゴリ: ${deck[i].id} / ${deck[i + 1].id}');
      }
    });

    // -----------------------------------------------------------------------
    // 不均等カテゴリでも順列を維持
    // -----------------------------------------------------------------------
    test('不均等カテゴリ（A×4, B×2）でも順列（全問が出る）', () {
      final core = const [
        QuestionData(id: 'a-1', text: 'A1', category: 'catA', weight: 1.0, condition: null),
        QuestionData(id: 'a-2', text: 'A2', category: 'catA', weight: 1.0, condition: null),
        QuestionData(id: 'a-3', text: 'A3', category: 'catA', weight: 1.0, condition: null),
        QuestionData(id: 'a-4', text: 'A4', category: 'catA', weight: 1.0, condition: null),
        QuestionData(id: 'b-1', text: 'B1', category: 'catB', weight: 1.0, condition: null),
        QuestionData(id: 'b-2', text: 'B2', category: 'catB', weight: 1.0, condition: null),
      ];
      final deck = buildDailyDeck(core, 'test-salt', 0);
      expect(deck.length, core.length);
      expect(deck.map((q) => q.id).toSet(), core.map((q) => q.id).toSet());
      // 重複なし確認。
      final ids = deck.map((q) => q.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('不均等カテゴリでも隣接同カテゴリが少ない', () {
      // A×4, B×2 の場合、ラウンドロビンで A,B,A,B,A,A というパターンになるため
      // 末尾で A が連続する（A が多い分だけ末尾で連続）。
      // 「素朴にすべて A を先に並べる」場合の隣接同カテゴリ数（4-1=3）より少ないことを確認。
      final core = const [
        QuestionData(id: 'a-1', text: 'A1', category: 'catA', weight: 1.0, condition: null),
        QuestionData(id: 'a-2', text: 'A2', category: 'catA', weight: 1.0, condition: null),
        QuestionData(id: 'a-3', text: 'A3', category: 'catA', weight: 1.0, condition: null),
        QuestionData(id: 'a-4', text: 'A4', category: 'catA', weight: 1.0, condition: null),
        QuestionData(id: 'b-1', text: 'B1', category: 'catB', weight: 1.0, condition: null),
        QuestionData(id: 'b-2', text: 'B2', category: 'catB', weight: 1.0, condition: null),
      ];
      final deck = buildDailyDeck(core, 'test-salt', 0);
      final adjacentSame = adjacentSameCategoryCount(deck);
      // ラウンドロビン: A,B,A,B,A,A → 隣接同=1（末尾 A,A のみ）。
      // 素朴な並べ: A,A,A,A,B,B → 隣接同=4。
      // インターリーブ効果として 3 以下（素朴より良い）を確認。
      expect(adjacentSame, lessThan(3),
          reason: '不均等カテゴリでも隣接同カテゴリが素朴より少ないはず。実際: $adjacentSame');
    });

    // -----------------------------------------------------------------------
    // 1問のみ
    // -----------------------------------------------------------------------
    test('core が1問のみ → そのまま1問返す', () {
      const core = [
        QuestionData(id: 'solo', text: '1問だけ', category: 'cat', weight: 1.0, condition: null),
      ];
      final deck = buildDailyDeck(core, 'test-salt', 0);
      expect(deck.length, 1);
      expect(deck.first.id, 'solo');
    });
  });
}
