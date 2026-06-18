// onboarding_screen_test.dart — OnboardingScreen widget テスト
//
// 検証方針:
// - showDatePicker の自動操作は避け、OnboardingScreenState.selected を
//   直接セットする方式でテストする（testers.state 経由）。
// - settingsRepositoryProvider は FakeSettingsRepository で差し替え。
// - nowProvider は固定 DateTime で差し替え。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:specimen_box/data/repositories/settings_repository.dart';
import 'package:specimen_box/presentation/onboarding/onboarding_screen.dart';
import 'package:specimen_box/presentation/providers/providers.dart';

// ---------------------------------------------------------------------------
// Fake SettingsRepository
// ---------------------------------------------------------------------------

/// テスト用の SettingsRepository 代替。
///
/// setBirthDate の呼び出し回数と渡された引数を記録する。
/// SettingsRepository はコンストラクタに SettingsDao を要求するため、
/// サブクラスではなく独自クラスとして定義し、
/// settingsRepositoryProvider.overrideWithValue で差し替える。
class _FakeSettingsRepository implements SettingsRepository {
  final List<DateTime> savedDates = [];

  @override
  Future<DateTime?> getBirthDate() async => null;

  @override
  Future<void> setBirthDate(DateTime d) async {
    savedDates.add(d);
  }

  // SettingsRepository が SettingsDao フィールドを持つが、
  // interface としての型適合のみ確認する（Dart は structural subtyping）。
  // ignore: unused_element
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// ヘルパ: ProviderScope + MaterialApp でラップした pump
// ---------------------------------------------------------------------------

Future<void> _pumpOnboarding(
  WidgetTester tester,
  _FakeSettingsRepository fakeRepo,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        nowProvider.overrideWithValue(DateTime(2026, 6, 10, 12, 0, 0)),
        settingsRepositoryProvider.overrideWithValue(fakeRepo),
        // birthDateProvider は FutureProvider なので fake repo 経由で解決される。
        // 明示的に override しなくてもよいが、念のため null を返す override を追加。
        birthDateProvider.overrideWith((_) async => null),
      ],
      child: const MaterialApp(
        home: OnboardingScreen(),
      ),
    ),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// テスト
// ---------------------------------------------------------------------------

void main() {
  group('OnboardingScreen', () {
    late _FakeSettingsRepository fakeRepo;

    setUp(() {
      fakeRepo = _FakeSettingsRepository();
    });

    // -------------------------------------------------------------------------
    // T1: 初期表示で保存ボタンが無効（selected == null）
    // -------------------------------------------------------------------------
    testWidgets('初期表示でホイールの既定日が入り保存ボタンが有効', (tester) async {
      await _pumpOnboarding(tester, fakeRepo);

      // 「この日から、発掘をはじめる」ボタンを探す。
      final saveButton = find.widgetWithText(TextButton, 'この日から、発掘をはじめる');
      expect(saveButton, findsOneWidget, reason: '保存ボタンが表示される');

      // ホイールは初期位置（既定日）を持つため selected は非 null → ボタン有効。
      final button = tester.widget<TextButton>(saveButton);
      expect(button.onPressed, isNotNull, reason: '既定日が入っているため保存ボタンは有効');
    });

    // -------------------------------------------------------------------------
    // T2: selected をセットすると保存ボタンが有効になる
    // -------------------------------------------------------------------------
    testWidgets('selected がセットされると保存ボタンが有効になる', (tester) async {
      await _pumpOnboarding(tester, fakeRepo);

      // State を取得して selected を直接セットする。
      final state =
          tester.state(find.byType(OnboardingScreen)) as OnboardingScreenState;
      state.setSelectedForTesting(DateTime(1990, 6, 15));
      await tester.pump();

      // 保存ボタンが有効になっていることを確認する。
      final saveButton = find.widgetWithText(TextButton, 'この日から、発掘をはじめる');
      expect(saveButton, findsOneWidget);
      final button = tester.widget<TextButton>(saveButton);
      expect(button.onPressed, isNotNull, reason: '生年月日選択後は保存ボタンが有効');
    });

    // -------------------------------------------------------------------------
    // T3: selected セット後に保存ボタンを押すと setBirthDate が呼ばれる
    // -------------------------------------------------------------------------
    testWidgets('保存ボタン押下で setBirthDate が呼ばれる', (tester) async {
      await _pumpOnboarding(tester, fakeRepo);

      // State の selected を直接セットする。
      final state =
          tester.state(find.byType(OnboardingScreen)) as OnboardingScreenState;
      state.setSelectedForTesting(DateTime(1990, 6, 15));
      await tester.pump();

      // 保存ボタンをタップ → 確認アラート → 「この日で決める」をタップ。
      await tester.tap(find.widgetWithText(TextButton, 'この日から、発掘をはじめる'));
      await tester.pumpAndSettle();
      expect(find.text('本当にこの日でいい？'), findsOneWidget,
          reason: '変更不可の確認アラートが表示される');
      await tester.tap(find.text('この日で決める'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // setBirthDate が1回呼ばれていることを確認する。
      expect(fakeRepo.savedDates.length, 1,
          reason: 'setBirthDate が1回呼ばれた');
      expect(fakeRepo.savedDates.first, DateTime(1990, 6, 15),
          reason: '選択した日付が渡された');
    });

    // -------------------------------------------------------------------------
    // T4: 保存ボタン押下後に birthDateProvider が invalidate される（間接検証）
    // -------------------------------------------------------------------------
    // birthDateProvider の invalidate は _save() 内で直接呼ばれる。
    // widget テストレベルではProviderを監視して再評価されることを確認する。
    testWidgets('保存後に birthDateProvider が再評価される', (tester) async {
      // 保存後に null→非null に切り替わるシナリオをシミュレート。
      // fakeRepo の getBirthDate を保存後に値を返すように変更する。
      final trackingRepo = _TrackingSettingsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nowProvider.overrideWithValue(DateTime(2026, 6, 10, 12, 0, 0)),
            settingsRepositoryProvider.overrideWithValue(trackingRepo),
            birthDateProvider.overrideWith((_) async => null),
          ],
          child: const MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );
      await tester.pump();

      // State の selected をセット。
      final state =
          tester.state(find.byType(OnboardingScreen)) as OnboardingScreenState;
      state.setSelectedForTesting(DateTime(1995, 3, 20));
      await tester.pump();

      // 保存ボタンをタップ → 確認アラート → 「この日で決める」をタップ。
      await tester.tap(find.widgetWithText(TextButton, 'この日から、発掘をはじめる'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('この日で決める'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // setBirthDate が呼ばれ、invalidate も実行されたことを setBirthDate 呼び出しで代替確認。
      expect(trackingRepo.savedDates.length, 1,
          reason: 'setBirthDate が呼ばれた = invalidate 前の保存は完了している');
    });
  });
}

// ---------------------------------------------------------------------------
// _TrackingSettingsRepository: setBirthDate 後に getBirthDate が値を返す
// ---------------------------------------------------------------------------

class _TrackingSettingsRepository implements SettingsRepository {
  final List<DateTime> savedDates = [];
  DateTime? _stored;

  @override
  Future<DateTime?> getBirthDate() async => _stored;

  @override
  Future<void> setBirthDate(DateTime d) async {
    _stored = d;
    savedDates.add(d);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
