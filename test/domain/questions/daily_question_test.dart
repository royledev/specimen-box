import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/data/questions/question_loader.dart';
import 'package:specimen_box/domain/questions/daily_question.dart';

/// テストで使う標準的な3問（condition: null）。
List<QuestionData> _std3() => const [
      QuestionData(id: 'q-a', text: 'Aの問い', category: 'cat', weight: 1.0, condition: null),
      QuestionData(id: 'q-b', text: 'Bの問い', category: 'cat', weight: 1.0, condition: null),
      QuestionData(id: 'q-c', text: 'Cの問い', category: 'cat', weight: 1.0, condition: null),
    ];

/// 10問のリスト（インデックスが変わるケースの検証用）。
List<QuestionData> _ten() => List.generate(
      10,
      (i) => QuestionData(
        id: 'q-$i',
        text: '問い$i',
        category: 'cat',
        weight: 1.0,
        condition: null,
      ),
    );

void main() {
  // ---------------------------------------------------------------------------
  // isAvailableOnDate
  // ---------------------------------------------------------------------------
  group('isAvailableOnDate', () {
    test('condition null は常時 true', () {
      expect(isAvailableOnDate(null, DateTime(2026, 6, 10)), isTrue); // 平日
      expect(isAvailableOnDate(null, DateTime(2026, 6, 13)), isTrue); // 土
      expect(isAvailableOnDate(null, DateTime(2026, 6, 14)), isTrue); // 日
    });

    test('weekendOnly は土・日のみ true', () {
      // 平日（水: weekday=3）
      expect(isAvailableOnDate('weekendOnly', DateTime(2026, 6, 10)), isFalse);
      // 金曜日（weekday=5）
      expect(isAvailableOnDate('weekendOnly', DateTime(2026, 6, 12)), isFalse);
      // 土曜日（weekday=6）
      expect(isAvailableOnDate('weekendOnly', DateTime(2026, 6, 13)), isTrue);
      // 日曜日（weekday=7）
      expect(isAvailableOnDate('weekendOnly', DateTime(2026, 6, 14)), isTrue);
    });

    test('midnightOnly は曜日・時刻に関わらず常に false（日替わりプール除外）', () {
      expect(isAvailableOnDate('midnightOnly', DateTime(2026, 6, 10)), isFalse);
      expect(isAvailableOnDate('midnightOnly', DateTime(2026, 6, 13)), isFalse); // 土
      expect(isAvailableOnDate('midnightOnly', DateTime(2026, 6, 14)), isFalse); // 日
    });

    test('未知の condition は寛容に true を返す', () {
      expect(isAvailableOnDate('unknownCondition', DateTime(2026, 6, 10)), isTrue);
      expect(isAvailableOnDate('someOther', DateTime(2026, 6, 13)), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // pickDailyQuestion: 決定論
  // ---------------------------------------------------------------------------
  group('pickDailyQuestion / 決定論', () {
    test('同一 (salt, yyyymmdd) で複数回呼んで常に同一 id', () {
      final candidates = _std3();
      const salt = 'test-salt';
      const yyyymmdd = 20260610;

      final first = pickDailyQuestion(candidates, salt, yyyymmdd);
      for (var i = 0; i < 10; i++) {
        final q = pickDailyQuestion(candidates, salt, yyyymmdd);
        expect(q.id, first.id, reason: '${i + 1}回目が異なる');
      }
    });

    test('10問候補: test-salt/20260610 は q-1 を選ぶ（固定値検証・新デッキアルゴリズム）', () {
      // 新アルゴリズム（ADR-0009）: デッキ選択。
      // dayNumber(20260610)=20614, L=10, cycleIndex=2061, pos=4。
      // buildDailyDeck(_ten, 'test-salt', 2061)[4] = q-1（決定論）。
      final q = pickDailyQuestion(_ten(), 'test-salt', 20260610);
      expect(q.id, 'q-1');
    });

    test('日付違い (20260614=日) で選ばれる id が変わる', () {
      // 新アルゴリズム（ADR-0009）: 日付が変わると pos が変わり、別の問いが返る。
      // 20260610(水) → q-1, 20260614(日) → q-2（決定論固定値）。
      // 20260614(日) は weekendOnly 条件付きなし（_ten は全 condition:null）のため
      // デッキ選択のみでオーバーレイなし。
      final q1 = pickDailyQuestion(_ten(), 'test-salt', 20260610);
      final q2 = pickDailyQuestion(_ten(), 'test-salt', 20260614);
      expect(q1.id, 'q-1');
      expect(q2.id, 'q-2');
      expect(q1.id, isNot(equals(q2.id)));
    });

    test('salt 違いで選ばれる id が変わる', () {
      // 新アルゴリズム（ADR-0009）: salt が変わるとデッキのシャッフルが変わり、別の問いが返る。
      // test-salt/20260610 → q-1, salt-0/20260610 → q-0（決定論固定値）。
      final q1 = pickDailyQuestion(_ten(), 'test-salt', 20260610);
      final q2 = pickDailyQuestion(_ten(), 'salt-0', 20260610);
      expect(q1.id, 'q-1');
      expect(q2.id, 'q-0');
      expect(q1.id, isNot(equals(q2.id)));
    });
  });

  // ---------------------------------------------------------------------------
  // pickDailyQuestion: weekendOnly フィルタ
  // ---------------------------------------------------------------------------
  group('pickDailyQuestion / weekendOnly', () {
    // 標準3問 + weekendOnly1問
    List<QuestionData> candidatesWithWeekend() => [
          ..._std3(),
          const QuestionData(
            id: 'q-weekend',
            text: '週末の問い',
            category: 'weekend',
            weight: 1.0,
            condition: 'weekendOnly',
          ),
        ];

    test('weekendOnly 問いは平日(20260610=水) の候補から除外される', () {
      // 20260610 は水曜日（weekday=3）。weekendOnly は除外され核3問（q-a,q-b,q-c）のみ。
      // 新アルゴリズム（ADR-0009）: core=[q-a,q-b,q-c], L=3,
      // dayNumber(20260610)=20614, cycleIndex=6871, pos=1 → buildDailyDeck(...)[1] = q-b。
      final q = pickDailyQuestion(candidatesWithWeekend(), 'test-salt', 20260610);
      expect(q.id, 'q-b');
      // q-weekend が選ばれていないことを確認。
      expect(q.id, isNot('q-weekend'));
    });

    test('weekendOnly 問いは土曜日(20260613) の候補に含まれ、実際に出る', () {
      // 20260613 は土曜日（weekday=6）。weekendOnly を含む4候補から選ぶ。
      // 新アルゴリズム（ADR-0009）: core=[q-a,q-b,q-c] + conditionalAvailable=[q-weekend]。
      // deckPick + conditionalAvailable を qfinal キーで重み抽選。
      // test-salt/20260613(土) → q-weekend が返る（固定値。決定論で確定）。
      final q = pickDailyQuestion(candidatesWithWeekend(), 'test-salt', 20260613);
      expect(q.id, 'q-weekend'); // 土曜日に実際に q-weekend が選ばれることを確認。
    });

    test('weekendOnly 問いは日曜日(20260614) の候補に含まれ、実際に出る', () {
      // 20260614 は日曜日（weekday=7）。weekendOnly を含む4候補から選ぶ。
      // 新アルゴリズム（ADR-0009）: core=[q-a,q-b,q-c] + conditionalAvailable=[q-weekend]。
      // deckPick + conditionalAvailable を qfinal キーで重み抽選。
      // test-salt/20260614(日) → q-weekend が返る（固定値。決定論で確定）。
      final q = pickDailyQuestion(candidatesWithWeekend(), 'test-salt', 20260614);
      expect(q.id, 'q-weekend'); // 日曜日でも実際に q-weekend が選ばれることを確認。
    });

    test('weekendOnly 問いは月曜日(20260615) の候補から除外される', () {
      // 20260615 は月曜日（weekday=1）。weekendOnly は平日では候補に入らない。
      // 新アルゴリズム（ADR-0009）: core=[q-a,q-b,q-c], conditionalAvailable=[]。
      // デッキ選択のみ → test-salt/20260615(月) → q-a が返る（固定値）。
      final q = pickDailyQuestion(candidatesWithWeekend(), 'test-salt', 20260615);
      expect(q.id, 'q-a'); // 月曜日にはデッキ選択のみで q-a が返る（決定論固定値）。
      // 月曜日では weekendOnly が除外されていること（候補に含まれない）を確認。
      expect(q.id, isNot('q-weekend'));
    });

    test('平日に weekendOnly 問いが実際に選択されないことを、異なる salt でも確認', () {
      // 平日では weekendOnly は常に除外されるため候補にならない。
      // いくつかの salt で検証して q-weekend が絶対に出ないことを確認。
      final candidates = candidatesWithWeekend();
      const weekday = 20260610; // 水曜日
      for (final s in ['test-salt', 'salt-0', 'salt-1', 'salt-2', 'abc', 'xyz']) {
        final q = pickDailyQuestion(candidates, s, weekday);
        expect(q.id, isNot('q-weekend'),
            reason: 'salt=$s の平日で q-weekend が選ばれた');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // pickDailyQuestion: midnightOnly は常に除外
  // ---------------------------------------------------------------------------
  group('pickDailyQuestion / midnightOnly', () {
    test('midnightOnly 問いは平日でも除外される', () {
      // weight=100.0 という極端に高い重みを付けても midnightOnly は除外。
      final candidates = [
        ..._std3(),
        const QuestionData(
          id: 'q-midnight',
          text: '深夜の問い',
          category: 'midnight',
          weight: 100.0,
          condition: 'midnightOnly',
        ),
      ];
      final q = pickDailyQuestion(candidates, 'test-salt', 20260610);
      expect(q.id, isNot('q-midnight'));
    });

    test('midnightOnly 問いは土曜日(20260613) でも除外される', () {
      final candidates = [
        ..._std3(),
        const QuestionData(
          id: 'q-midnight',
          text: '深夜の問い',
          category: 'midnight',
          weight: 100.0,
          condition: 'midnightOnly',
        ),
      ];
      final q = pickDailyQuestion(candidates, 'test-salt', 20260613);
      expect(q.id, isNot('q-midnight'));
    });

    test('midnightOnly のみの候補はフォールバックが返る', () {
      // midnightOnly だけのリスト → フィルタ後空 → フォールバック。
      final candidates = [
        const QuestionData(
          id: 'q-midnight',
          text: '深夜の問い',
          category: 'midnight',
          weight: 1.0,
          condition: 'midnightOnly',
        ),
      ];
      final q = pickDailyQuestion(candidates, 'test-salt', 20260610);
      expect(q.id, 'q-meaningless-01');
    });
  });

  // ---------------------------------------------------------------------------
  // pickDailyQuestion: フォールバック
  // ---------------------------------------------------------------------------
  group('pickDailyQuestion / フォールバック', () {
    test('空リストを渡すとハードコードのフォールバック問いが返る', () {
      final q = pickDailyQuestion([], 'test-salt', 20260610);
      expect(q.id, 'q-meaningless-01');
      expect(q.text, '今日いちばん意味のなかった行動は？');
      expect(q.category, 'meaningless');
    });

    test('フォールバック問いは同一入力で決定論的に返る', () {
      // 空リストでも同じ結果が返ることを確認。
      final q1 = pickDailyQuestion([], 'any-salt', 20260610);
      final q2 = pickDailyQuestion([], 'any-salt', 20260610);
      expect(q1.id, q2.id);
    });

    test('全件 midnightOnly でフィルタ後空 → フォールバック', () {
      final candidates = List.generate(
        5,
        (i) => QuestionData(
          id: 'q-midnight-$i',
          text: '深夜$i',
          category: 'midnight',
          weight: 1.0,
          condition: 'midnightOnly',
        ),
      );
      final q = pickDailyQuestion(candidates, 'test-salt', 20260610);
      expect(q.id, 'q-meaningless-01');
    });
  });

  // ---------------------------------------------------------------------------
  // pickDailyQuestion: weight=0・負 weight
  // ---------------------------------------------------------------------------
  group('pickDailyQuestion / weight=0・負weight', () {
    test('weight=0 の核プールのみのとき、デッキ選択で決定論的に1問返す', () {
      // 新アルゴリズム（ADR-0009）: condition:null の問いは weight にかかわらず核プールに入り、
      // デッキ選択（buildDailyDeck + pos）で確定的に返る。
      // _weightedPick は weight=0 の核プールでは呼ばれない（デッキ選択のパス）。
      // test-salt/20260610: core=[q-zero-a,q-zero-b], L=2,
      // dayNumber=20614, cycleIndex=10307, pos=0。
      // buildDailyDeck のシャッフルで pos=0 に来る問いが決定論的に選ばれる。
      final candidates = const [
        QuestionData(id: 'q-zero-a', text: 'ゼロA', category: 'cat', weight: 0.0, condition: null),
        QuestionData(id: 'q-zero-b', text: 'ゼロB', category: 'cat', weight: 0.0, condition: null),
      ];
      final q = pickDailyQuestion(candidates, 'test-salt', 20260610);
      // 決定論: 同一入力では常に同じ問いが返る（固定値）。
      expect(q.id, 'q-zero-b'); // デッキ選択の決定論結果。
    });

    test('負の weight の核プールのみのとき、デッキ選択で決定論的に1問返す', () {
      // 新アルゴリズム（ADR-0009）: 負 weight も核プールに入りデッキ選択される。
      final candidates = const [
        QuestionData(id: 'q-neg-a', text: '負A', category: 'cat', weight: -1.0, condition: null),
        QuestionData(id: 'q-neg-b', text: '負B', category: 'cat', weight: -2.0, condition: null),
      ];
      final q = pickDailyQuestion(candidates, 'test-salt', 20260610);
      expect(q.id, 'q-neg-b'); // デッキ選択の決定論結果。
    });

    test('weight=0 のみの条件付きオーバーレイ: _weightedPick は先頭フォールバックを返す', () {
      // conditionalAvailable が weight=0 のみの場合 → _weightedPick(conditionalAvailable)
      // では totalWeight<=0 で先頭フォールバックが呼ばれる（core 空のケース）。
      // core が空で conditionalAvailable に weight=0 の問いのみを渡す。
      final candidates = const [
        QuestionData(
          id: 'q-cond-zero',
          text: '条件ゼロ',
          category: 'cat',
          weight: 0.0,
          condition: 'weekendOnly',
        ),
      ];
      // 土曜日(20260613): weekendOnly が有効 → core 空 + conditionalAvailable=[q-cond-zero]
      // → _weightedPick(conditionalAvailable, key): totalWeight=0 → 先頭を返す。
      final q = pickDailyQuestion(candidates, 'test-salt', 20260613);
      expect(q.id, 'q-cond-zero'); // totalWeight<=0 フォールバック: 先頭を返す。
    });
  });

  // ---------------------------------------------------------------------------
  // pickDailyQuestion: 反復回避（ADR-0009 決定1）
  // ---------------------------------------------------------------------------
  group('pickDailyQuestion / 反復回避', () {
    test('核のみ候補で連続 L 日の選択 id に重複がない（1サイクル一巡）', () {
      // 核プールのみ（condition:null）の候補 5問を使って、
      // 連続 L=5 日（dayNumber の連番）で選ばれる id に重複がないことを確認する。
      // これが「1サイクル（L日）内に各問いがちょうど1回」の保証。
      const L = 5;
      final candidates = List.generate(
        L,
        (i) => QuestionData(
          id: 'r-$i',
          text: '反復回避$i',
          category: 'cat',
          weight: 1.0,
          condition: null,
        ),
      );

      // dayNumber(20260610) = 20614。20614 % 5 = 4 なので、
      // dayNumber = 20610〜20614 (pos = 0,1,2,3,4) で1サイクルを一巡できる。
      // 20610 は 2026-06-06 (土), ... 20614 は 2026-06-10 (水)。
      // yyyymmdd で指定: 20260606〜20260610 の5日間（cycleIndex=4122 固定）。
      final selectedIds = <String>[];
      for (int offset = 0; offset < L; offset++) {
        // yyyymmdd を offset 日分ずらす: DateTime 演算で正確に計算する。
        final date = DateTime(2026, 6, 6).add(Duration(days: offset));
        final yyyymmdd =
            date.year * 10000 + date.month * 100 + date.day;
        final q = pickDailyQuestion(candidates, 'repeat-test-salt', yyyymmdd);
        selectedIds.add(q.id);
      }

      // L 日間で選ばれた id の集合 == 全 id の集合（過不足なし・重複なし）。
      expect(selectedIds.toSet().length, L,
          reason: '1サイクル内に重複がある: $selectedIds');
      expect(
        selectedIds.toSet(),
        candidates.map((q) => q.id).toSet(),
        reason: '1サイクル内で出なかった問いがある: $selectedIds',
      );
    });

    test('10問核プールで連続 10 日の id に重複がない（同サイクル内）', () {
      // _ten() の 10問で 10連日の反復回避を検証する。
      // 同一サイクル内を確保するため 2026-06-06〜15（dayNumber=20610..20619, cycleIndex=2061）を使う。
      // 注: サイクル境界をまたぐ場合（例 20260601〜10）はサイクルが変わりデッキが切り替わるため
      //     境界付近で重複が発生しうる（ADR-0009「サイクル境界をまたぐと〜弱い」の説明どおり）。
      //     本テストは同一サイクル内の反復回避（L 日で全問1回）を検証する。
      const L = 10;
      final candidates = _ten();

      final selectedIds = <String>[];
      for (int offset = 0; offset < L; offset++) {
        // 2026-06-06 + offset 日（cycleIndex=2061 の1サイクル）。
        final date = DateTime(2026, 6, 6).add(Duration(days: offset));
        final yyyymmdd =
            date.year * 10000 + date.month * 100 + date.day;
        final q = pickDailyQuestion(candidates, 'repeat-10-salt', yyyymmdd);
        selectedIds.add(q.id);
      }

      expect(selectedIds.toSet().length, L,
          reason: '10日サイクル（同一cycleIndex）で重複: $selectedIds');
      expect(
        selectedIds.toSet(),
        candidates.map((q) => q.id).toSet(),
        reason: '10日サイクルで出なかった問い: $selectedIds',
      );
    });

    test('核+条件付き候補でも平日の核 id は L 日間で重複しない（同サイクル内）', () {
      // weekendOnly を混ぜても平日のデッキ選択の反復回避は維持される。
      // 同一サイクル内の3平日で確認: 2026-06-09(火)〜11(木)。
      // core L=3, dayNumber(20260609)=20613, cycleIndex=6871, pos=0。
      //           dayNumber(20260610)=20614, cycleIndex=6871, pos=1。
      //           dayNumber(20260611)=20615, cycleIndex=6871, pos=2。
      const L = 3; // 核プール3問
      final candidates = [
        ..._std3(), // q-a,q-b,q-c (condition:null)
        const QuestionData(
          id: 'q-weekend',
          text: '週末',
          category: 'weekend',
          weight: 1.0,
          condition: 'weekendOnly',
        ),
      ];

      // 火〜木（全て平日: weekendOnly 除外）。同一サイクル cycleIndex=6871 の pos=0,1,2。
      final weekdays = [20260609, 20260610, 20260611]; // 火・水・木
      final selectedIds = <String>[];
      for (final yyyymmdd in weekdays) {
        final q = pickDailyQuestion(candidates, 'mixed-salt', yyyymmdd);
        // 平日なら conditionalAvailable 空 → デッキ選択のみ。
        selectedIds.add(q.id);
      }

      // 3日間で選ばれた核 id が全て異なること（同一サイクル内の反復回避）。
      expect(selectedIds.toSet().length, L,
          reason: '平日3日間で核の反復: $selectedIds');
    });
  });

  // ---------------------------------------------------------------------------
  // pickDailyQuestion: カテゴリ偏り（ADR-0009 決定2）
  // ---------------------------------------------------------------------------
  group('pickDailyQuestion / カテゴリ偏り回避', () {
    test('複数カテゴリ核プールで連続日のカテゴリが分散している', () {
      // 3カテゴリ×3問（計9問）の核プールで、9連日のカテゴリパターンを確認する。
      // buildDailyDeck のラウンドロビンにより隣接日の同カテゴリが0になるはず。
      const L = 9;
      final candidates = const [
        QuestionData(id: 'a-1', text: 'A1', category: 'catA', weight: 1.0, condition: null),
        QuestionData(id: 'a-2', text: 'A2', category: 'catA', weight: 1.0, condition: null),
        QuestionData(id: 'a-3', text: 'A3', category: 'catA', weight: 1.0, condition: null),
        QuestionData(id: 'b-1', text: 'B1', category: 'catB', weight: 1.0, condition: null),
        QuestionData(id: 'b-2', text: 'B2', category: 'catB', weight: 1.0, condition: null),
        QuestionData(id: 'b-3', text: 'B3', category: 'catB', weight: 1.0, condition: null),
        QuestionData(id: 'c-1', text: 'C1', category: 'catC', weight: 1.0, condition: null),
        QuestionData(id: 'c-2', text: 'C2', category: 'catC', weight: 1.0, condition: null),
        QuestionData(id: 'c-3', text: 'C3', category: 'catC', weight: 1.0, condition: null),
      ];

      // 同一サイクル内の L=9 日間のカテゴリを集める。
      // dayNumber(20260606)=20610, cycleIndex=2290, pos=0 からの9日間（〜20260614）。
      final selectedCategories = <String>[];
      for (int offset = 0; offset < L; offset++) {
        final date = DateTime(2026, 6, 6).add(Duration(days: offset));
        final yyyymmdd = date.year * 10000 + date.month * 100 + date.day;
        final q = pickDailyQuestion(candidates, 'category-test-salt', yyyymmdd);
        selectedCategories.add(q.category);
      }

      // 隣接日の同カテゴリを数える。
      int adjacentSame = 0;
      for (int i = 0; i < selectedCategories.length - 1; i++) {
        if (selectedCategories[i] == selectedCategories[i + 1]) adjacentSame++;
      }

      // 3カテゴリ均等ラウンドロビンの場合、理想的には隣接同カテゴリ = 0。
      // サイクル内では buildDailyDeck のカテゴリ分散が効くため、
      // 「単純に全問同カテゴリで並べた場合（= L-1 = 8）」より圧倒的に少ないはず。
      expect(adjacentSame, lessThan(3),
          reason: 'カテゴリ偏りが大きすぎる: categories=$selectedCategories, adjacentSame=$adjacentSame');
    });
  });
}
