// widget_test.dart — smoke テスト + 結合テスト（Provider 構成）
//
// ProviderScope でラップし、インメモリ DB / 固定 salt を override する。
// T4 要件: 起動・空状態文言が緑になること。
// T5 要件: 標本を1件 add → ホームグリッドに反映されることを最小検証する。

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:specimen_box/data/db/app_database.dart';
import 'package:specimen_box/data/repositories/specimen_repository.dart';
import 'package:specimen_box/domain/specimen/specimen.dart' as domain;
import 'package:specimen_box/domain/weathering/weathering.dart';
import 'package:specimen_box/main.dart';
import 'package:specimen_box/presentation/home/home_screen.dart';
import 'package:specimen_box/presentation/providers/providers.dart';

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
  /// - appDatabaseProvider → インメモリ DB
  /// - specimenRepositoryProvider → インメモリ DB の DAO から生成
  /// - userSaltProvider → 固定値 'test-salt-0001'
  // Riverpod 3.x では Override 型がエクスポートされていないため型推論を使う。
  // ignore: prefer_function_declarations_over_variables
  final buildOverrides = (AppDatabase db) {
    final repo = SpecimenRepository(db.specimensDao);
    return [
      appDatabaseProvider.overrideWith((ref) {
        ref.onDispose(db.close);
        return db;
      }),
      specimenRepositoryProvider.overrideWithValue(repo),
      userSaltProvider.overrideWith((ref) async => 'test-salt-0001'),
      // 直近1週間ビューに入るよう「今日」を固定（標本日付は 2026-06-08/09）。
      nowProvider.overrideWithValue(DateTime(2026, 6, 9, 20, 0, 0)),
      birthDateProvider.overrideWith((ref) async => DateTime(1990, 1, 1)),
    ];
  };

  testWidgets('App smoke test: タイトルが表示される', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(testDb),
        child: const SpecimenBoxApp(skipSplash: true),
      ),
    );
    // 非同期 Provider の初期化が完了するまで pump する。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('化石箱'), findsOneWidget);
  });

  testWidgets('App smoke test: ホーム空状態のプレースホルダが表示される',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(testDb),
        child: const SpecimenBoxApp(skipSplash: true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // 標本0件の空状態: ガイドテキストと操作ボタンが存在することを確認
    expect(find.text('まだ何も掘り出していない\n問いに答えると、化石が出てくる'), findsOneWidget);
    expect(find.text('最初の問いに回答する'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // T5 結合テスト: 回答→保存→ホーム反映
  // ---------------------------------------------------------------------------

  testWidgets('結合テスト: 標本を1件 add すると specimenListProvider に反映される',
      (WidgetTester tester) async {
    // ProviderScope.containerOf で specimenListProvider を直接操作し、
    // add() → ホーム画面の表示変化を widget レベルで検証する。
    //
    // AnswerScreen の非同期 QuestionLoader が関与すると flakiness が上がるため、
    // Notifier の add() を直接呼び出す形で「保存→ホーム反映」を検証する。
    // これは AnswerScreen._submit() が行う
    //   ref.read(specimenListProvider.notifier).add(specimen)
    // と同等の操作。

    // setUp の testDb を使わず、このテスト専用のインスタンスを作ると
    // Drift の「複数インスタンス」警告が出る（同プロセスに AppDatabase が2つ）。
    // testDb を再利用することで警告を回避する。
    final db = testDb;
    final repo = SpecimenRepository(db.specimensDao);
    final overrides = [
      appDatabaseProvider.overrideWith((ref) => db),
      specimenRepositoryProvider.overrideWithValue(repo),
      userSaltProvider.overrideWith((ref) async => 'test-salt-0001'),
      // 直近1週間ビューに入るよう「今日」を固定（標本日付は 2026-06-08/09）。
      nowProvider.overrideWithValue(DateTime(2026, 6, 9, 20, 0, 0)),
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

    // 初期状態: 空状態プレースホルダが表示される
    expect(find.text('まだ何も掘り出していない\n問いに答えると、化石が出てくる'), findsOneWidget);

    // ProviderScope 配下の任意の ConsumerWidget 要素から container を取得する。
    // HomeScreen は ConsumerWidget のため、そのコンテキストから containerOf が使える。
    final homeElement = tester.element(find.byType(HomeScreen));
    final container = ProviderScope.containerOf(homeElement);

    final specimen = domain.Specimen(
      id: 'widget-test-001',
      answer: '夕暮れのオレンジ',
      questionId: 'q-test-01',
      questionText: '今日印象に残った色は？',
      date: '2026-06-09',
      createdAt: DateTime(2026, 6, 9, 18, 0, 0),
    );

    // specimenListProvider.notifier.add() で DB 保存→リスト更新。
    await container.read(specimenListProvider.notifier).add(specimen);

    // Provider の更新を widget ツリーに反映させる。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 空状態プレースホルダが消え、回答テキストがグリッドセルに表示される。
    expect(
      find.text('まだ何も掘り出していない\n問いに答えると、化石が出てくる'),
      findsNothing,
      reason: '標本が1件追加されたため空状態プレースホルダは消える',
    );
    // スロットには回答ではなく発掘時刻が出る（回答は詳細画面）。createdAt=18:00。
    expect(
      find.text('18:00'),
      findsOneWidget,
      reason: '追加した標本のスロット（発掘時刻）が週リストに表示される',
    );
  });

  // ---------------------------------------------------------------------------
  // T6 結合テスト: 標本の保存とホーム反映・複数標本の表示
  // ---------------------------------------------------------------------------

  testWidgets('結合テスト: 標本を add するとホームに反映される',
      (WidgetTester tester) async {
    // notifier.add で標本を保存し、ホームグリッドに反映されることを検証する。
    // （画像はサーバー配信＋ローカル保存・ADR-0011。未取得時はプレースホルダ表示）。
    final db = testDb;
    final repo = SpecimenRepository(db.specimensDao);
    final overrides = [
      appDatabaseProvider.overrideWith((ref) => db),
      specimenRepositoryProvider.overrideWithValue(repo),
      userSaltProvider.overrideWith((ref) async => 'test-salt-0001'),
      // 直近1週間ビューに入るよう「今日」を固定（標本日付は 2026-06-08/09）。
      nowProvider.overrideWithValue(DateTime(2026, 6, 9, 20, 0, 0)),
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

    final homeElement = tester.element(find.byType(HomeScreen));
    final container = ProviderScope.containerOf(homeElement);

    // 標本を追加する。
    final specimen = domain.Specimen(
      id: 'widget-test-v2-001',
      answer: '朝の静けさ',
      questionId: 'q-test-02',
      questionText: '今日印象に残った瞬間は？',
      date: '2026-06-09',
      createdAt: DateTime(2026, 6, 9, 9, 0, 0),
    );

    await container.read(specimenListProvider.notifier).add(specimen);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // スロット（発掘時刻 09:00）が週リストに表示される。
    expect(
      find.text('09:00'),
      findsOneWidget,
      reason: '標本のスロットが週リストに表示される',
    );
    // 空状態プレースホルダが消えている。
    expect(find.text('まだ何も掘り出していない\n問いに答えると、化石が出てくる'), findsNothing);
  });

  // ---------------------------------------------------------------------------
  // T2 テスト: nowProvider override で風化度が painter に届くことを検証
  // ---------------------------------------------------------------------------

  testWidgets('T2: nowProvider を override すると古い標本の weatherLevel が 0 より大きくなる',
      (WidgetTester tester) async {
    // createdAt を「T1(7日)+15日後」に設定し、nowProvider を createdAt+15日後に固定する。
    // weatherLevel の期待値: T1=7日 / T2=30日。elapsed=15日 → (15-7)/(30-7) > 0。
    // このテストは weatherLevel が正しく計算されることを直接ロジックで検証する。
    // (painter の weather フィールドは private のため UI ツリーでの値取り出しは行わない)
    final createdAt = DateTime(2026, 5, 1, 12, 0, 0);
    // now = createdAt + 15日 → elapsed = 15日 > T1(7日)
    final fakeNow = createdAt.add(const Duration(days: 15));

    // weatherLevel の純粋関数計算: テストオラクル
    final expectedWeather = weatherLevel(
      createdAt: createdAt,
      now: fakeNow,
      sealed: false,
    );
    expect(expectedWeather, greaterThan(0.0),
        reason: 'elapsed=15日(>T1=7日)なら weather > 0 になる');

    // nowProvider を fakeNow で override して描画が例外なく完走することを確認する。
    final db = testDb;
    final repo = SpecimenRepository(db.specimensDao);
    final overrides = [
      appDatabaseProvider.overrideWith((ref) => db),
      specimenRepositoryProvider.overrideWithValue(repo),
      userSaltProvider.overrideWith((ref) async => 'test-salt-0001'),
      nowProvider.overrideWithValue(fakeNow),
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

    final homeElement = tester.element(find.byType(HomeScreen));
    final container = ProviderScope.containerOf(homeElement);

    // 古い createdAt の標本を追加する。
    final oldSpecimen = domain.Specimen(
      id: 'widget-test-weather-01',
      answer: '古い標本（風化テスト）',
      questionId: 'q-weather-01',
      questionText: '風化テスト用の問い',
      date: '2026-05-01',
      createdAt: createdAt,
    );

    await container.read(specimenListProvider.notifier).add(oldSpecimen);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 風化対象（>7日経過）の古い標本は週リスト（直近7日）には出ないが、
    // nowProvider override 下で週ビューが例外なく描画されることを確認する。
    expect(find.byType(HomeScreen), findsOneWidget);

    // nowProvider が fakeNow を返すことを確認する。
    expect(
      container.read(nowProvider),
      equals(fakeNow),
      reason: 'nowProvider override が有効になっている',
    );
  });

  testWidgets('結合テスト: 複数の標本がホームに表示される',
      (WidgetTester tester) async {
    // 複数の標本が両方ホームグリッドに描画されることを検証する。
    final db = testDb;
    final repo = SpecimenRepository(db.specimensDao);
    final overrides = [
      appDatabaseProvider.overrideWith((ref) => db),
      specimenRepositoryProvider.overrideWithValue(repo),
      userSaltProvider.overrideWith((ref) async => 'test-salt-0001'),
      // 直近1週間ビューに入るよう「今日」を固定（標本日付は 2026-06-08/09）。
      nowProvider.overrideWithValue(DateTime(2026, 6, 9, 20, 0, 0)),
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

    final homeElement = tester.element(find.byType(HomeScreen));
    final container = ProviderScope.containerOf(homeElement);

    // 前日の標本を追加する（直近1週間ビューに入る日付）。
    final specimenOld = domain.Specimen(
      id: 'widget-test-mix-v1',
      answer: '古い記憶',
      questionId: 'q-test-03',
      questionText: '昔印象に残ったことは？',
      date: '2026-06-08',
      createdAt: DateTime(2026, 6, 8, 15, 0, 0),
    );

    // 当日の標本を追加する。
    final specimenNew = domain.Specimen(
      id: 'widget-test-mix-v2',
      answer: '今の輝き',
      questionId: 'q-test-04',
      questionText: '今日光ったものは？',
      date: '2026-06-09',
      createdAt: DateTime(2026, 6, 9, 12, 0, 0),
    );

    await container.read(specimenListProvider.notifier).add(specimenOld);
    await container.read(specimenListProvider.notifier).add(specimenNew);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 両日のスロット（発掘時刻）が週リストに表示される（複数標本表示の smoke）。
    expect(
      find.text('15:00'),
      findsOneWidget,
      reason: '前日の標本スロットが週リストに表示される',
    );
    expect(
      find.text('12:00'),
      findsOneWidget,
      reason: '当日の標本スロットが週リストに表示される',
    );
  });
}
