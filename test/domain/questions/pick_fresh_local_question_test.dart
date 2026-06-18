// pickFreshLocalQuestion のユニットテスト（ADR-0013: オフライン時の recent 回避選択）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/data/questions/question_loader.dart'
    show QuestionData;
import 'package:specimen_box/domain/questions/daily_question.dart';

QuestionData _q(String id, {String? condition}) => QuestionData(
      id: id,
      text: id,
      category: 'c',
      weight: 1.0,
      condition: condition,
    );

void main() {
  group('pickFreshLocalQuestion', () {
    final core = [_q('q-1'), _q('q-2'), _q('q-3'), _q('q-4')];

    test('recent に含まれる問いは選ばない', () {
      // q-1,q-2,q-3 を除外 → 残るのは q-4 のみ。
      final picked = pickFreshLocalQuestion(core, 'salt', ['q-1', 'q-2', 'q-3']);
      expect(picked.id, 'q-4');
    });

    test('recent が空なら核プールから決定論的に1問選ぶ', () {
      final a = pickFreshLocalQuestion(core, 'salt', const []);
      final b = pickFreshLocalQuestion(core, 'salt', const []);
      expect(a.id, b.id, reason: '同じ (salt, recent長) は決定論');
      expect(core.map((q) => q.id), contains(a.id));
    });

    test('recent の長さが変わると選択が回る（開くたびに別問い）', () {
      // 採用後に recent が伸びる運用を模擬。recent 長が 0→1→2 と変わると別の問いになりうる。
      final ids = <String>{};
      final recent = <String>[];
      for (var i = 0; i < 3; i++) {
        final p = pickFreshLocalQuestion(core, 'salt', recent);
        ids.add(p.id);
        recent.add(p.id); // push を模擬
      }
      expect(ids.length, 3, reason: '3回とも別の問い（recent 回避＋長さ回し）');
    });

    test('recent が核プールを覆い尽くす場合は recent を無視して必ず1問返す', () {
      final picked =
          pickFreshLocalQuestion(core, 'salt', ['q-1', 'q-2', 'q-3', 'q-4']);
      expect(core.map((q) => q.id), contains(picked.id));
    });

    test('条件付き（condition != null）は対象外、核プール空なら固定問いを返す', () {
      final onlyConditional = [
        _q('w-1', condition: 'weekendOnly'),
        _q('m-1', condition: 'midnightOnly'),
      ];
      final picked = pickFreshLocalQuestion(onlyConditional, 'salt', const []);
      expect(picked.id, 'q-meaningless-01');
    });
  });
}
