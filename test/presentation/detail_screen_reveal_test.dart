// detail_screen_reveal_test.dart — DetailScreen reveal アニメのウィジェットテスト
//
// T3: playReveal=false で通常表示が壊れていないことを確認。
// T4: playReveal=true で AnimationController が 0→1 に進行し着地することを確認。

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:specimen_box/data/db/app_database.dart';
import 'package:specimen_box/data/repositories/specimen_repository.dart';
import 'package:specimen_box/presentation/detail/detail_screen.dart';
import 'package:specimen_box/presentation/providers/providers.dart';
import 'package:specimen_box/presentation/widgets/specimen_image.dart';

void main() {
  // テスト用のインメモリ DB と固定 salt を用意する。
  late AppDatabase testDb;

  setUp(() {
    testDb = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await testDb.close();
  });

  /// テスト用 override リストを生成するヘルパ。
  ///
  /// Riverpod 3.x では Override 型がエクスポートされていないため型推論を使う。
  // ignore: prefer_function_declarations_over_variables
  final buildOverrides = (AppDatabase db) {
    final repo = SpecimenRepository(db.specimensDao);
    return [
      appDatabaseProvider.overrideWith((ref) {
        ref.onDispose(db.close);
        return db;
      }),
      specimenRepositoryProvider.overrideWithValue(repo),
      // detail は salt を使わない（ADR-0011 で描画がローカル画像化）。salt override は不要。
      nowProvider.overrideWithValue(DateTime(2026, 6, 9, 12, 0, 0)),
    ];
  };

  // ---------------------------------------------------------------------------
  // T3: playReveal=false の通常表示テスト
  // ---------------------------------------------------------------------------

  group('T3: DetailScreen playReveal=false（通常表示）', () {
    testWidgets('playReveal=false でメタ情報・封印ボタンが通常表示される', (tester) async {
      final db = testDb;
      final overrides = buildOverrides(db);

      // DB に標本を直接追加する（リポジトリ経由）。
      final repo = SpecimenRepository(db.specimensDao);
      await repo.save(
        id: 'reveal-test-002',
        date: '2026-06-09',
        questionId: 'q-reveal-test-02',
        questionText: '今日の問い',
        answerText: '青空の白',
        status: 'alive',
        createdAt: DateTime(2026, 6, 9, 10, 0, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            home: DetailScreen(
              specimenId: 'reveal-test-002',
              // playReveal: false が既定。
            ),
          ),
        ),
      );

      // 非同期 Provider の初期化を待つ。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 標本画像（SpecimenImage）が表示されている。
      expect(find.byType(SpecimenImage), findsOneWidget);

      // メタ情報ラベルが表示されている。
      expect(find.text('問'), findsOneWidget);
      expect(find.text('答'), findsOneWidget);
      expect(find.text('発掘'), findsOneWidget);

      // 封印ボタンが表示されている。
      expect(find.text('封をする（永久保存）'), findsOneWidget);
    });

    testWidgets('playReveal=false のとき revealController が null', (tester) async {
      final db = testDb;
      final overrides = buildOverrides(db);

      final repo = SpecimenRepository(db.specimensDao);
      await repo.save(
        id: 'reveal-test-003',
        date: '2026-06-09',
        questionId: 'q-reveal-test-03',
        questionText: '今日の問い',
        answerText: '夜の深さ',
        status: 'alive',
        createdAt: DateTime(2026, 6, 9, 10, 0, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            home: DetailScreen(
              specimenId: 'reveal-test-003',
              playReveal: false,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // StatefulElement から state を取得し、revealController の getter を呼ぶ。
      final statefulElement =
          tester.element(find.byType(DetailScreen)) as StatefulElement;
      // ignore: invalid_use_of_visible_for_testing_member
      final controller =
          (statefulElement.state as dynamic).revealController as AnimationController?;

      expect(controller, isNull,
          reason: 'playReveal=false のとき AnimationController は生成されない');
    });

    testWidgets('標本キャンバスが 280×280 で描画される（Size.zero 回帰防止）',
        (tester) async {
      final db = testDb;
      final overrides = buildOverrides(db);

      final repo = SpecimenRepository(db.specimensDao);
      await repo.save(
        id: 'reveal-test-size',
        date: '2026-06-09',
        questionId: 'q-reveal-size',
        questionText: '今日の問い',
        answerText: 'サイズ確認',
        status: 'alive',
        createdAt: DateTime(2026, 6, 9, 10, 0, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            home: DetailScreen(specimenId: 'reveal-test-size'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // SpecimenImage（ローカル画像表示）が標本ステージ（230×230）で描画されていること。
      // （Positioned.fill を外すと Size.zero になり描画されない＝バグ2の回帰防止）
      final canvas = find.byType(SpecimenImage);
      expect(canvas, findsOneWidget);
      expect(tester.getSize(canvas), const Size(230, 230));
    });
  });

  // ---------------------------------------------------------------------------
  // T4: playReveal=true のアニメ進行・着地テスト
  // ---------------------------------------------------------------------------

  group('T4: DetailScreen playReveal=true（reveal アニメ）', () {
    testWidgets('playReveal=true で AnimationController が 0→1 に進行し 1.0 に着地する',
        (tester) async {
      final db = testDb;
      final overrides = buildOverrides(db);

      final repo = SpecimenRepository(db.specimensDao);
      await repo.save(
        id: 'reveal-anim-001',
        date: '2026-06-09',
        questionId: 'q-reveal-anim-01',
        questionText: '今日を一言で？',
        answerText: '朝の静けさ',
        status: 'alive',
        createdAt: DateTime(2026, 6, 9, 9, 0, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            home: DetailScreen(
              specimenId: 'reveal-anim-001',
              playReveal: true,
            ),
          ),
        ),
      );

      // 非同期 Provider の初期化。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // StatefulElement から revealController を取得する。
      final statefulElement =
          tester.element(find.byType(DetailScreen)) as StatefulElement;
      // ignore: invalid_use_of_visible_for_testing_member
      final controller =
          (statefulElement.state as dynamic).revealController as AnimationController?;

      // playReveal=true なので revealController が生成されているはず。
      expect(controller, isNotNull,
          reason: 'playReveal=true のとき AnimationController が生成される');

      // 初期値は 0 または forward 開始直後（未完了）。
      expect(controller!.value, lessThan(1.0),
          reason: 'アニメ開始直後は value < 1.0');

      // 途中フレーム（900ms 経過）: 進行中。
      await tester.pump(const Duration(milliseconds: 900));
      expect(controller.value, greaterThan(0.0),
          reason: '900ms 後は value > 0.0（進行している）');
      expect(controller.value, lessThan(1.0),
          reason: '900ms 後はまだ完了していない（duration=1800ms）');

      // 完了フレーム（さらに 2 秒進める: 合計 > 1800ms）。
      await tester.pump(const Duration(seconds: 2));
      expect(controller.value, equals(1.0),
          reason: 'アニメ完了後は value == 1.0 に着地する');

      // アニメ完了後に例外なく標本が表示されていること。
      expect(find.byType(SpecimenImage), findsOneWidget);
      expect(find.text('問'), findsOneWidget);
      expect(find.text('答'), findsOneWidget);
    });

    testWidgets('pumpAndSettle でアニメが正常完了する（無限アニメでない）', (tester) async {
      final db = testDb;
      final overrides = buildOverrides(db);

      final repo = SpecimenRepository(db.specimensDao);
      await repo.save(
        id: 'reveal-anim-002',
        date: '2026-06-09',
        questionId: 'q-reveal-anim-02',
        questionText: '今日の発見は？',
        answerText: '光の粒',
        status: 'alive',
        createdAt: DateTime(2026, 6, 9, 9, 0, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            home: DetailScreen(
              specimenId: 'reveal-anim-002',
              playReveal: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // pumpAndSettle でアニメが完了して正常に返ること（タイムアウトしない）。
      await tester.pumpAndSettle();

      // アニメ完了後に標本詳細が表示されている。
      expect(find.byType(SpecimenImage), findsOneWidget);
      expect(find.text('光の粒'), findsOneWidget,
          reason: 'アニメ完了後に回答テキストが表示される');

      // controller が 1.0 に着地している。
      final statefulElement =
          tester.element(find.byType(DetailScreen)) as StatefulElement;
      // ignore: invalid_use_of_visible_for_testing_member
      final controller =
          (statefulElement.state as dynamic).revealController as AnimationController?;
      expect(controller!.value, equals(1.0),
          reason: 'pumpAndSettle 後は controller.value == 1.0');
    });
  });

  // ---------------------------------------------------------------------------
  // T8: playReveal=true でアニメ途中にタップ → 即完了（スキップ）テスト
  // ---------------------------------------------------------------------------

  group('T8: 生成アニメのタップスキップ', () {
    testWidgets('playReveal=true でアニメ途中に標本領域を tap → controller.value == 1.0 に即完了する',
        (tester) async {
      final db = testDb;
      final overrides = buildOverrides(db);

      final repo = SpecimenRepository(db.specimensDao);
      await repo.save(
        id: 'reveal-skip-001',
        date: '2026-06-10',
        questionId: 'q-skip-01',
        questionText: 'スキップテスト用の問い',
        answerText: '瞬間の輝き',
        status: 'alive',
        createdAt: DateTime(2026, 6, 10, 10, 0, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            home: DetailScreen(
              specimenId: 'reveal-skip-001',
              playReveal: true,
            ),
          ),
        ),
      );

      // 非同期 Provider の初期化を待つ。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Controller を取得してアニメ途中であることを確認する。
      final statefulElement =
          tester.element(find.byType(DetailScreen)) as StatefulElement;
      // ignore: invalid_use_of_visible_for_testing_member
      final controller =
          (statefulElement.state as dynamic).revealController as AnimationController?;

      expect(controller, isNotNull,
          reason: 'playReveal=true のとき AnimationController が生成される');

      // 900ms 進める（アニメ途中: duration=1800ms）。
      await tester.pump(const Duration(milliseconds: 900));
      expect(controller!.value, greaterThan(0.0));
      expect(controller.value, lessThan(1.0),
          reason: 'タップ前はまだアニメ途中（value < 1.0）');

      // behavior: HitTestBehavior.opaque により、CustomPaint(hitTestSelf=false) や
      // SingleChildScrollView 内でも実タップ経路でヒットテストが通る。
      // tester.tap で実際にタップして onTap が呼ばれることを確認する。
      await tester.tap(find.byKey(const Key('specimenAreaGestureDetector')));
      await tester.pump();

      // タップ後に controller.value が 1.0 に即完了している。
      expect(
        controller.value,
        equals(1.0),
        reason: '標本領域タップでアニメが即完了し controller.value == 1.0 になる',
      );
    });

    testWidgets('アニメ完了後に再タップしても例外が出ない', (tester) async {
      final db = testDb;
      final overrides = buildOverrides(db);

      final repo = SpecimenRepository(db.specimensDao);
      await repo.save(
        id: 'reveal-skip-002',
        date: '2026-06-10',
        questionId: 'q-skip-02',
        questionText: 'スキップテスト用の問い2',
        answerText: '完了後タップ',
        status: 'alive',
        createdAt: DateTime(2026, 6, 10, 10, 0, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            home: DetailScreen(
              specimenId: 'reveal-skip-002',
              playReveal: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // アニメを完了させる。
      await tester.pumpAndSettle();

      final statefulElement =
          tester.element(find.byType(DetailScreen)) as StatefulElement;
      // ignore: invalid_use_of_visible_for_testing_member
      final controller =
          (statefulElement.state as dynamic).revealController as AnimationController?;
      expect(controller!.value, equals(1.0), reason: 'pumpAndSettle 後は完了済み');

      // 完了後に再タップしても例外が発生しないこと。
      // behavior: opaque で実タップが届くため tester.tap で確認する。
      await tester.tap(find.byKey(const Key('specimenAreaGestureDetector')));
      await tester.pump();

      // 状態が維持されている。
      expect(controller.value, equals(1.0),
          reason: '完了後タップ後も controller.value == 1.0 のまま');
      expect(find.text('完了後タップ'), findsOneWidget,
          reason: '完了後タップ後も回答テキストが表示されている');
    });

    testWidgets('playReveal=false のとき標本領域タップで例外が出ない', (tester) async {
      final db = testDb;
      final overrides = buildOverrides(db);

      final repo = SpecimenRepository(db.specimensDao);
      await repo.save(
        id: 'reveal-skip-003',
        date: '2026-06-10',
        questionId: 'q-skip-03',
        questionText: 'スキップテスト用の問い3',
        answerText: '通常表示タップ',
        status: 'alive',
        createdAt: DateTime(2026, 6, 10, 10, 0, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            home: DetailScreen(
              specimenId: 'reveal-skip-003',
              playReveal: false,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // playReveal=false のとき onTap は null（no-op）。
      // behavior: opaque でタップは拾うが onTap=null なので何も起きない。
      final gestureDetector = tester.widget<GestureDetector>(
        find.byKey(const Key('specimenAreaGestureDetector')),
      );
      expect(gestureDetector.onTap, isNull,
          reason: 'playReveal=false のとき onTap は null（悪さをしない）');
      // behavior: opaque でも実タップが例外なく no-op になることを確認。
      await tester.tap(find.byKey(const Key('specimenAreaGestureDetector')));
      await tester.pump();

      // 通常表示が維持されている。
      expect(find.text('通常表示タップ'), findsOneWidget,
          reason: 'playReveal=false のタップ後も通常表示が維持される');
    });
  });
}
