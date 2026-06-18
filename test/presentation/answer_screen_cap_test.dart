// answer_screen_cap_test.dart — 1日の取得上限（kDailyDigLimit=3）の UI ゲート。
//
// - その日に既に 3 件掘っていれば、回答画面は「今日の発掘はおしまい」を表示し、
//   問い入力（TextField）を出さない（問いも取得しない）。
// - 2 件なら通常どおり問い入力が表示される。

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:specimen_box/data/db/app_database.dart';
import 'package:specimen_box/data/repositories/specimen_repository.dart';
import 'package:specimen_box/data/services/specimen_image_service.dart';
import 'package:specimen_box/platform/api/fake_specimen_api.dart';
import 'package:specimen_box/platform/image_store/fake_image_downloader.dart';
import 'package:specimen_box/platform/image_store/fake_image_store.dart';
import 'package:specimen_box/presentation/answer/answer_screen.dart';
import 'package:specimen_box/presentation/providers/providers.dart';

void main() {
  late AppDatabase testDb;

  setUp(() {
    testDb = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await testDb.close();
  });

  // ignore: prefer_function_declarations_over_variables
  final buildOverrides = (AppDatabase db) {
    final repo = SpecimenRepository(db.specimensDao);
    return [
      appDatabaseProvider.overrideWith((ref) {
        ref.onDispose(db.close);
        return db;
      }),
      specimenRepositoryProvider.overrideWithValue(repo),
      userSaltProvider.overrideWith((ref) async => 'test-salt-cap'),
      // 当日 = 2026-06-09。
      nowProvider.overrideWithValue(DateTime(2026, 6, 9, 12, 0, 0)),
      specimenApiProvider.overrideWith((ref) async => FakeSpecimenApi()),
      specimenImageServiceProvider.overrideWith(
        (ref) async => SpecimenImageService(
          api: FakeSpecimenApi(),
          store: FakeImageStore(),
          downloader: FakeImageDownloader(),
        ),
      ),
    ];
  };

  Future<void> seedDigs(AppDatabase db, int count, String date) async {
    final repo = SpecimenRepository(db.specimensDao);
    for (int i = 0; i < count; i++) {
      await repo.save(
        id: 'dig-$date-$i',
        date: date,
        questionId: 'q$i',
        questionText: '問い$i',
        answerText: '回答$i',
        status: 'alive',
        createdAt: DateTime(2026, 6, 9, 9, i),
      );
    }
  }

  Future<void> pumpAnswer(WidgetTester tester, AppDatabase db) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(db),
        child: const MaterialApp(home: AnswerScreen()),
      ),
    );
    // 非同期（標本リスト/問い取得）の解決を待つ。ローディング中は無限スピナーのため
    // pumpAndSettle は使わず固定 pump で進める。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('当日 3 件で上限 → 「今日の発掘はおしまい」表示・入力は出ない', (tester) async {
    await seedDigs(testDb, 3, '2026-06-09');
    await pumpAnswer(tester, testDb);

    expect(find.text('今日の発掘はおしまい'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('回答する'), findsNothing);
  });

  testWidgets('当日 2 件なら上限未満 → 通常どおり問い入力が出る', (tester) async {
    await seedDigs(testDb, 2, '2026-06-09');
    await pumpAnswer(tester, testDb);

    expect(find.text('今日の発掘はおしまい'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('別の日付の 3 件は当日に影響しない → 入力が出る', (tester) async {
    await seedDigs(testDb, 3, '2026-06-08'); // 前日に3件
    await pumpAnswer(tester, testDb);

    expect(find.text('今日の発掘はおしまい'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });
}
