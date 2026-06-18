// rarity_display_test.dart — T7: レア表現の配線ウィジェットテスト
//
// rareMidnight な createdAt の標本 → home セル/詳細にレアマーク・詳細に「深夜の化石」ラベルが出る。
// normal な createdAt の標本 → マーク・ラベルが出ない。

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:specimen_box/data/db/app_database.dart';
import 'package:specimen_box/data/repositories/specimen_repository.dart';
import 'package:specimen_box/domain/specimen/specimen.dart' as domain;
import 'package:specimen_box/main.dart';
import 'package:specimen_box/presentation/detail/detail_screen.dart';
import 'package:specimen_box/presentation/home/home_screen.dart';
import 'package:specimen_box/presentation/providers/providers.dart';

void main() {
  late AppDatabase testDb;

  setUp(() {
    testDb = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await testDb.close();
  });

  /// テスト用 override リストを生成するヘルパ。
  // ignore: prefer_function_declarations_over_variables
  final buildOverrides = (AppDatabase db) {
    final repo = SpecimenRepository(db.specimensDao);
    return [
      appDatabaseProvider.overrideWith((ref) {
        ref.onDispose(db.close);
        return db;
      }),
      specimenRepositoryProvider.overrideWithValue(repo),
      userSaltProvider.overrideWith((ref) async => 'test-salt-rarity'),
      nowProvider.overrideWithValue(DateTime(2026, 6, 10, 12, 0, 0)),
      birthDateProvider.overrideWith((ref) async => DateTime(1990, 1, 1)),
    ];
  };

  // ---------------------------------------------------------------------------
  // Home セル: rareMidnight のとき月アイコンが表示される
  // ---------------------------------------------------------------------------

  group('T7: home セルのレアマーク', () {
    testWidgets('rareMidnight（hour=2）の標本 → home セルに bedtime アイコンが表示される',
        (tester) async {
      final db = testDb;
      final overrides = buildOverrides(db);

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const SpecimenBoxApp(skipSplash: true),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final homeElement = tester.element(find.byType(HomeScreen));
      final container = ProviderScope.containerOf(homeElement);

      // 深夜 2:00（rareMidnight）の標本を追加する。
      final midnightSpecimen = domain.Specimen(
        id: 'rarity-test-midnight-001',
        answer: '深夜の想い',
        questionId: 'q-rarity-01',
        questionText: '今感じることは？',
        date: '2026-06-10',
        createdAt: DateTime(2026, 6, 10, 2, 0, 0), // hour=2 → rareMidnight
      );

      await container.read(specimenListProvider.notifier).add(midnightSpecimen);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 🌙 タグが home スロットに表示されている。
      expect(
        find.text('🌙'),
        findsAtLeastNWidgets(1),
        reason: 'rareMidnight の標本は home スロットに 🌙 タグが表示される',
      );
    });

    testWidgets('normal（hour=12）の標本 → home セルに bedtime アイコンが表示されない',
        (tester) async {
      final db = testDb;
      final overrides = buildOverrides(db);

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const SpecimenBoxApp(skipSplash: true),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final homeElement = tester.element(find.byType(HomeScreen));
      final container = ProviderScope.containerOf(homeElement);

      // 昼 12:00（normal）の標本を追加する。
      final normalSpecimen = domain.Specimen(
        id: 'rarity-test-normal-001',
        answer: '昼の光',
        questionId: 'q-rarity-02',
        questionText: '今感じることは？',
        date: '2026-06-10',
        createdAt: DateTime(2026, 6, 10, 12, 0, 0), // hour=12 → normal
      );

      await container.read(specimenListProvider.notifier).add(normalSpecimen);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 🌙 タグが表示されていない。
      expect(
        find.text('🌙'),
        findsNothing,
        reason: 'normal の標本は home スロットに 🌙 タグが表示されない',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Detail: rareMidnight のときレアマーク＋「深夜の化石」ラベルが表示される
  // ---------------------------------------------------------------------------

  group('T7: detail 画面のレアマーク・ラベル', () {
    testWidgets('rareMidnight（hour=2）の標本 → 詳細に bedtime アイコン＋「深夜の化石」ラベルが表示される',
        (tester) async {
      final db = testDb;
      final overrides = buildOverrides(db);

      final repo = SpecimenRepository(db.specimensDao);
      await repo.save(
        id: 'rarity-detail-midnight-001',
        date: '2026-06-10',
        questionId: 'q-rarity-detail-01',
        questionText: '深夜の問い',
        answerText: '静かな夜',
        status: 'alive',
        createdAt: DateTime(2026, 6, 10, 2, 30, 0), // hour=2 → rareMidnight
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            home: DetailScreen(
              specimenId: 'rarity-detail-midnight-001',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 🌙 タグが表示されている（標本大表示エリアのレアマーク）。
      expect(
        find.text('🌙'),
        findsAtLeastNWidgets(1),
        reason: 'rareMidnight の標本は詳細に 🌙 タグが表示される',
      );

      // 「深夜の化石」ラベルが表示されている。
      expect(
        find.text('深夜の化石'),
        findsOneWidget,
        reason: 'rareMidnight の標本は詳細に「深夜の化石」ラベルが表示される',
      );
    });

    testWidgets('normal（hour=12）の標本 → 詳細にレアマーク・「深夜の化石」ラベルが表示されない',
        (tester) async {
      final db = testDb;
      final overrides = buildOverrides(db);

      final repo = SpecimenRepository(db.specimensDao);
      await repo.save(
        id: 'rarity-detail-normal-001',
        date: '2026-06-10',
        questionId: 'q-rarity-detail-02',
        questionText: '昼の問い',
        answerText: '明るい昼',
        status: 'alive',
        createdAt: DateTime(2026, 6, 10, 12, 0, 0), // hour=12 → normal
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            home: DetailScreen(
              specimenId: 'rarity-detail-normal-001',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 🌙 タグが表示されていない。
      expect(
        find.text('🌙'),
        findsNothing,
        reason: 'normal の標本は詳細に 🌙 タグが表示されない',
      );

      // 「深夜の化石」ラベルが表示されていない。
      expect(
        find.text('深夜の化石'),
        findsNothing,
        reason: 'normal の標本は詳細に「深夜の化石」ラベルが表示されない',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // T2: rareBirthday — 誕生日一致で cake アイコン＋「誕生日の化石」ラベルが表示される
  //
  // 注意: createdAt が nowProvider の日付から離れると weatherLevel > 0 になる。
  // weatherLevel > 0 の経路では _paintV2Body 内の `we > 0` ブランチで
  // `cellSize = size.width * 0.06 * factor` が計算され、制約なし CustomPaint 等で
  // size=0 が渡ると `(0/0).ceil()` → NaN.toInt() 例外が潜在する（T3 で paint 入口に
  // size=0 ガードを追加済み）。
  // このテスト群ではさらに、createdAt を `now=2026/6/5 12:00` と同日に揃え
  // weatherLevel=0.0 とすることで、誕生日レア表示の検証に集中させている。
  // birthDate=1990/6/5（月日=6/5）と now=2026/6/5 を同じ月日にすることで
  // rareBirthday の判定も成立させている。
  // ---------------------------------------------------------------------------

  /// T2 用の override: birthDate=1990/6/5（月日=6/5）, now=2026/6/5 12:00
  // ignore: prefer_function_declarations_over_variables
  final buildBirthdayOverrides = (AppDatabase db) {
    final repo = SpecimenRepository(db.specimensDao);
    return [
      appDatabaseProvider.overrideWith((ref) {
        ref.onDispose(db.close);
        return db;
      }),
      specimenRepositoryProvider.overrideWithValue(repo),
      userSaltProvider.overrideWith((ref) async => 'test-salt-birthday'),
      nowProvider.overrideWithValue(DateTime(2026, 6, 5, 12, 0, 0)),
      birthDateProvider.overrideWith((ref) async => DateTime(1990, 6, 5)),
    ];
  };

  group('T2: 誕生日レア（rareBirthday）の表示', () {
    testWidgets('誕生日一致（6/5 昼）の標本 → home セルに cake アイコンが表示され bedtime は出ない',
        (tester) async {
      final db = testDb;
      final overrides = buildBirthdayOverrides(db);

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const SpecimenBoxApp(skipSplash: true),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final homeElement = tester.element(find.byType(HomeScreen));
      final container = ProviderScope.containerOf(homeElement);

      // 6/5 12:00（月日が birthDate=1990/6/5 と一致 → rareBirthday）
      // now=6/5 から0日経過 → weatherLevel=0.0 → paint エラーなし
      final birthdaySpecimen = domain.Specimen(
        id: 'rarity-birthday-home-001',
        answer: '誕生日の想い',
        questionId: 'q-birthday-01',
        questionText: '今感じることは？',
        date: '2026-06-05',
        createdAt: DateTime(2026, 6, 5, 12, 0, 0), // 6/5 昼 → rareBirthday
      );

      await container.read(specimenListProvider.notifier).add(birthdaySpecimen);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 🎂 タグが表示されている。
      expect(
        find.text('🎂'),
        findsAtLeastNWidgets(1),
        reason: 'rareBirthday の標本は home スロットに 🎂 タグが表示される',
      );

      // 🌙 タグは表示されていない。
      expect(
        find.text('🌙'),
        findsNothing,
        reason: 'rareBirthday の標本は home スロットに 🌙 タグが表示されない',
      );
    });

    testWidgets('深夜かつ誕生日一致（6/5 02:00）の標本 → home セルに cake アイコンが表示され bedtime は出ない',
        (tester) async {
      final db = testDb;
      final overrides = buildBirthdayOverrides(db);

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const SpecimenBoxApp(skipSplash: true),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final homeElement = tester.element(find.byType(HomeScreen));
      final container = ProviderScope.containerOf(homeElement);

      // 6/5 02:00（深夜かつ誕生日一致 → rareBirthday が優先）
      // now=6/5 12:00 から 10時間前 → weatherLevel=0.0 → paint エラーなし
      final birthdayMidnightSpecimen = domain.Specimen(
        id: 'rarity-birthday-midnight-home-001',
        answer: '深夜の誕生日',
        questionId: 'q-birthday-midnight-01',
        questionText: '今感じることは？',
        date: '2026-06-05',
        createdAt: DateTime(2026, 6, 5, 2, 0, 0), // 6/5 02:00 → rareBirthday（誕生日優先）
      );

      await container.read(specimenListProvider.notifier).add(birthdayMidnightSpecimen);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 🎂 タグが表示されている（誕生日優先）。
      expect(
        find.text('🎂'),
        findsAtLeastNWidgets(1),
        reason: '深夜かつ誕生日の化石は誕生日優先で 🎂 タグが表示される',
      );

      // 🌙 タグは表示されていない。
      expect(
        find.text('🌙'),
        findsNothing,
        reason: '深夜かつ誕生日の化石は 🌙 タグが表示されない（誕生日優先）',
      );
    });

    testWidgets('誕生日一致（6/5 昼）の標本 → 詳細に cake アイコン＋「誕生日の化石」ラベルが表示される',
        (tester) async {
      final db = testDb;
      final overrides = buildBirthdayOverrides(db);

      final repo = SpecimenRepository(db.specimensDao);
      await repo.save(
        id: 'rarity-birthday-detail-001',
        date: '2026-06-05',
        questionId: 'q-birthday-detail-01',
        questionText: '誕生日の問い',
        answerText: '誕生日のよろこび',
        status: 'alive',
        createdAt: DateTime(2026, 6, 5, 12, 0, 0), // 6/5 昼 → rareBirthday
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            home: DetailScreen(
              specimenId: 'rarity-birthday-detail-001',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 🎂 タグが表示されている。
      expect(
        find.text('🎂'),
        findsAtLeastNWidgets(1),
        reason: 'rareBirthday の標本は詳細に 🎂 タグが表示される',
      );

      // 🌙 タグは表示されていない。
      expect(
        find.text('🌙'),
        findsNothing,
        reason: 'rareBirthday の標本は詳細に 🌙 タグが表示されない',
      );

      // 「誕生日の化石」ラベルが表示されている。
      expect(
        find.text('誕生日の化石'),
        findsOneWidget,
        reason: 'rareBirthday の標本は詳細に「誕生日の化石」ラベルが表示される',
      );
    });
  });
}
