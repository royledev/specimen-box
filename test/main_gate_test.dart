// main_gate_test.dart — _HomeGate の振り分けテスト
//
// birthDateProvider の override により、
//   - null   → OnboardingScreen が表示される
//   - DateTime → HomeScreen が表示される
// ことを検証する。

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:specimen_box/data/db/app_database.dart';
import 'package:specimen_box/data/repositories/specimen_repository.dart';
import 'package:specimen_box/main.dart';
import 'package:specimen_box/presentation/home/home_screen.dart';
import 'package:specimen_box/presentation/onboarding/onboarding_screen.dart';
import 'package:specimen_box/presentation/providers/providers.dart';

void main() {
  late AppDatabase testDb;

  setUp(() {
    testDb = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await testDb.close();
  });

  /// テスト用ベース override リスト（birthDateProvider を除く）。
  // ignore: prefer_function_declarations_over_variables
  final baseOverrides = (AppDatabase db) {
    final repo = SpecimenRepository(db.specimensDao);
    return [
      appDatabaseProvider.overrideWith((ref) {
        ref.onDispose(db.close);
        return db;
      }),
      specimenRepositoryProvider.overrideWithValue(repo),
      userSaltProvider.overrideWith((ref) async => 'test-salt-gate'),
    ];
  };

  // ---------------------------------------------------------------------------
  // birthDate == null → OnboardingScreen が表示される
  // ---------------------------------------------------------------------------

  testWidgets('birthDateProvider=null → OnboardingScreen が表示され HomeScreen は出ない',
      (WidgetTester tester) async {
    final overrides = [
      ...baseOverrides(testDb),
      birthDateProvider.overrideWith((ref) async => null),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const SpecimenBoxApp(skipSplash: true),
      ),
    );
    // FutureProvider が解決するまで pump する。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byType(OnboardingScreen),
      findsOneWidget,
      reason: '生年月日未設定のときオンボーディング画面が表示される',
    );
    expect(
      find.byType(HomeScreen),
      findsNothing,
      reason: '生年月日未設定のときホーム画面は表示されない',
    );
  });

  // ---------------------------------------------------------------------------
  // birthDate != null → HomeScreen が表示される
  // ---------------------------------------------------------------------------

  testWidgets('birthDateProvider=DateTime → HomeScreen が表示され OnboardingScreen は出ない',
      (WidgetTester tester) async {
    final overrides = [
      ...baseOverrides(testDb),
      birthDateProvider.overrideWith((ref) async => DateTime(1990, 1, 1)),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const SpecimenBoxApp(skipSplash: true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byType(HomeScreen),
      findsOneWidget,
      reason: '生年月日設定済みのときホーム画面が表示される',
    );
    expect(
      find.byType(OnboardingScreen),
      findsNothing,
      reason: '生年月日設定済みのときオンボーディング画面は表示されない',
    );
  });

  // ---------------------------------------------------------------------------
  // loading 初期フレームでスピナーが出る
  // ---------------------------------------------------------------------------

  testWidgets('birthDateProvider が解決前の loading フレームではスピナーが表示される',
      (WidgetTester tester) async {
    // Completer を使って FutureProvider を未解決のままにする。
    final completer = Completer<DateTime?>();

    final overrides = [
      ...baseOverrides(testDb),
      birthDateProvider.overrideWith(
        (ref) => completer.future,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const SpecimenBoxApp(skipSplash: true),
      ),
    );
    // pump() を1回だけ呼んで loading 状態を確認する（Completer は未完了）。
    await tester.pump();

    expect(
      find.byType(CircularProgressIndicator),
      findsOneWidget,
      reason: 'birthDateProvider が loading 中はスピナーが表示される',
    );

    // テスト終了前に Completer を完了させてタイマーリークを防ぐ。
    completer.complete(null);
    await tester.pump();
  });
}
