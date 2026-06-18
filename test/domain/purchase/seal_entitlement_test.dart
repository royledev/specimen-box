import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/domain/purchase/seal_entitlement.dart';

void main() {
  group('canSeal', () {
    test('既定状態（unlocked=false, credits=0）は false を返す', () {
      expect(canSeal(SealEntitlement()), isFalse);
    });

    test('unlocked=true なら credits=0 でも true を返す', () {
      expect(canSeal(SealEntitlement(unlocked: true)), isTrue);
    });

    test('credits>0 なら true を返す', () {
      expect(canSeal(SealEntitlement(credits: 1)), isTrue);
      expect(canSeal(SealEntitlement(credits: 5)), isTrue);
    });

    test('unlocked=true かつ credits>0 でも true を返す', () {
      expect(canSeal(SealEntitlement(unlocked: true, credits: 3)), isTrue);
    });
  });

  group('applySeal', () {
    test('unlocked=true のとき credits を消費しない（不変返し）', () {
      final e = SealEntitlement(unlocked: true, credits: 3);
      final result = applySeal(e);
      expect(result.unlocked, isTrue);
      expect(result.credits, 3);
    });

    test('unlocked=true かつ credits=0 のとき不変返し', () {
      final e = SealEntitlement(unlocked: true);
      final result = applySeal(e);
      expect(result, equals(e));
    });

    test('credits=3 なら credits=2 になる', () {
      final e = SealEntitlement(credits: 3);
      final result = applySeal(e);
      expect(result.credits, 2);
      expect(result.unlocked, isFalse);
    });

    test('credits=1 なら credits=0 になる', () {
      final e = SealEntitlement(credits: 1);
      final result = applySeal(e);
      expect(result.credits, 0);
    });

    test('credits=0 かつ unlocked=false（canSeal false）なら不変返し（消費されない）', () {
      final e = SealEntitlement();
      final result = applySeal(e);
      expect(result, equals(e));
      expect(result.credits, 0);
    });
  });

  group('grant', () {
    test('single で credits が +1 される', () {
      final e = SealEntitlement();
      final result = grant(e, SealProductKind.single);
      expect(result.credits, 1);
      expect(result.unlocked, isFalse);
    });

    test('pack5 で credits が +5 される', () {
      final e = SealEntitlement();
      final result = grant(e, SealProductKind.pack5);
      expect(result.credits, 5);
      expect(result.unlocked, isFalse);
    });

    test('unlock で unlocked=true になる（credits は据え置き）', () {
      final e = SealEntitlement(credits: 2);
      final result = grant(e, SealProductKind.unlock);
      expect(result.unlocked, isTrue);
      expect(result.credits, 2);
    });

    test('credits=0 から unlock しても credits は 0 のまま', () {
      final e = SealEntitlement();
      final result = grant(e, SealProductKind.unlock);
      expect(result.unlocked, isTrue);
      expect(result.credits, 0);
    });

    test('single×3 で credits=3 になる', () {
      var e = SealEntitlement();
      e = grant(e, SealProductKind.single);
      e = grant(e, SealProductKind.single);
      e = grant(e, SealProductKind.single);
      expect(e.credits, 3);
    });

    test('single×3 後に unlock すると unlocked=true かつ credits=3 のまま', () {
      var e = SealEntitlement();
      e = grant(e, SealProductKind.single);
      e = grant(e, SealProductKind.single);
      e = grant(e, SealProductKind.single);
      e = grant(e, SealProductKind.unlock);
      expect(e.unlocked, isTrue);
      expect(e.credits, 3);
    });
  });

  group('credits 負値クランプ', () {
    test('credits=-5 を渡すと credits=0 になる', () {
      final e = SealEntitlement(credits: -5);
      expect(e.credits, 0);
    });

    test('credits=-1 を渡すと credits=0 になる', () {
      final e = SealEntitlement(credits: -1);
      expect(e.credits, 0);
    });

    test('credits=0 は 0 のまま', () {
      final e = SealEntitlement(credits: 0);
      expect(e.credits, 0);
    });

    test('copyWith で credits 負値を渡してもクランプされる', () {
      final e = SealEntitlement(credits: 3);
      final result = e.copyWith(credits: -10);
      expect(result.credits, 0);
    });
  });

  group('値等価（== / hashCode）', () {
    test('同じ値を持つ 2 インスタンスは等しい', () {
      final a = SealEntitlement(unlocked: true, credits: 3);
      final b = SealEntitlement(unlocked: true, credits: 3);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('unlocked が異なると等しくない', () {
      final a = SealEntitlement(unlocked: false, credits: 3);
      final b = SealEntitlement(unlocked: true, credits: 3);
      expect(a, isNot(equals(b)));
    });

    test('credits が異なると等しくない', () {
      final a = SealEntitlement(unlocked: false, credits: 1);
      final b = SealEntitlement(unlocked: false, credits: 2);
      expect(a, isNot(equals(b)));
    });
  });

  group('copyWith', () {
    test('unlocked を上書きできる', () {
      final e = SealEntitlement(unlocked: false, credits: 2);
      final result = e.copyWith(unlocked: true);
      expect(result.unlocked, isTrue);
      expect(result.credits, 2);
    });

    test('credits を上書きできる', () {
      final e = SealEntitlement(unlocked: true, credits: 2);
      final result = e.copyWith(credits: 5);
      expect(result.unlocked, isTrue);
      expect(result.credits, 5);
    });

    test('引数なしのとき元と等しい', () {
      final e = SealEntitlement(unlocked: true, credits: 3);
      expect(e.copyWith(), equals(e));
    });
  });
}
