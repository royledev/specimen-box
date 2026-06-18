import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/domain/api/recent_window.dart';

void main() {
  group('pushRecent', () {
    test('空に積むと1件', () {
      expect(pushRecent([], 'a', 3), ['a']);
    });

    test('末尾が最新・先頭が最古', () {
      var w = <String>[];
      w = pushRecent(w, 'a', 3);
      w = pushRecent(w, 'b', 3);
      w = pushRecent(w, 'c', 3);
      expect(w, ['a', 'b', 'c']);
    });

    test('maxLen を超えたら先頭（最古）から落ちる', () {
      var w = ['a', 'b', 'c'];
      w = pushRecent(w, 'd', 3);
      expect(w, ['b', 'c', 'd']);
    });

    test('既存IDは取り除いてから末尾へ（最新へ移動・重複しない）', () {
      final w = pushRecent(['a', 'b', 'c'], 'a', 3);
      expect(w, ['b', 'c', 'a']);
    });

    test('重複移動でも長さは増えない', () {
      final w = pushRecent(['a', 'b', 'c'], 'b', 3);
      expect(w, ['a', 'c', 'b']);
      expect(w.length, 3);
    });

    test('maxLen=0 は窓無効＝空', () {
      expect(pushRecent(['a', 'b'], 'c', 0), isEmpty);
    });

    test('入力リストを破壊しない（イミュータブル）', () {
      final original = ['a', 'b'];
      pushRecent(original, 'c', 5);
      expect(original, ['a', 'b']);
    });
  });

  group('addUnique', () {
    test('新規は末尾に追加', () {
      expect(addUnique(['a', 'b'], 'c'), ['a', 'b', 'c']);
    });

    test('既存は変化なし（コピーを返す）', () {
      final original = ['a', 'b'];
      final result = addUnique(original, 'a');
      expect(result, ['a', 'b']);
      expect(identical(result, original), isFalse);
    });

    test('空に追加', () {
      expect(addUnique([], 'x'), ['x']);
    });
  });
}
