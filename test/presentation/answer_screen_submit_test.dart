// answer_screen_submit_test.dart — AnswerScreen._submit() 遷移テスト
//
// T5: 回答送信後に DetailScreen(playReveal:true) へ pushReplacement されることを確認する。
//
// AnswerScreen は nextQuestionServiceProvider 経由でサーバーから問いを取得する
// （ADR-0013: サーバー専用）。本テストは specimenApiProvider を FakeSpecimenApi に
// override して問い取得を決定論化する。
// NavigatorObserver を使って pushReplacement 遷移先が DetailScreen であることを確認する。

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:specimen_box/data/db/app_database.dart';
import 'package:specimen_box/data/repositories/specimen_repository.dart';
import 'package:specimen_box/data/services/specimen_image_service.dart';
import 'package:specimen_box/platform/api/fake_specimen_api.dart';
import 'package:specimen_box/platform/api/specimen_api.dart';
import 'package:specimen_box/platform/image_store/fake_image_downloader.dart';
import 'package:specimen_box/platform/image_store/fake_image_store.dart';
import 'package:specimen_box/platform/image_store/image_downloader.dart';
import 'package:specimen_box/presentation/answer/answer_screen.dart';
import 'package:specimen_box/presentation/detail/detail_screen.dart';
import 'package:specimen_box/presentation/providers/providers.dart';

// ---------------------------------------------------------------------------
// NavigatorObserver: pushReplacement を検知してルート情報を記録する。
// ---------------------------------------------------------------------------

class _TestNavigatorObserver extends NavigatorObserver {
  Route<dynamic>? lastPushedRoute;
  Route<dynamic>? lastReplacedRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushedRoute = route;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    lastReplacedRoute = newRoute;
  }
}

/// 画像バイトのダウンロードが必ず失敗する [ImageDownloader]（画像取得失敗の模擬）。
/// acquire() は抽選成功後の DL 失敗を deferred として返すため、回答フローでは画像エラーになる。
class _ThrowingImageDownloader implements ImageDownloader {
  @override
  Future<List<int>> download(String url) async =>
      throw Exception('download failed (test)');
}

void main() {
  late AppDatabase testDb;

  setUp(() {
    testDb = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await testDb.close();
  });

  // override リストを生成するヘルパ。
  // ignore: prefer_function_declarations_over_variables
  final buildOverrides = (AppDatabase db) {
    final repo = SpecimenRepository(db.specimensDao);
    return [
      appDatabaseProvider.overrideWith((ref) {
        ref.onDispose(db.close);
        return db;
      }),
      specimenRepositoryProvider.overrideWithValue(repo),
      userSaltProvider.overrideWith((ref) async => 'test-salt-answer'),
      nowProvider.overrideWithValue(DateTime(2026, 6, 9, 12, 0, 0)),
      // 問いはサーバー由来（ADR-0011）。テストは Fake API で決定論化し、
      // 隠れた実ネットワーク試行（localhost 拒否→フォールバック）に依存しない。
      specimenApiProvider.overrideWith((ref) async => FakeSpecimenApi()),
      // 画像取得もすべて Fake（実ネットワーク/ファイルIOなし）。
      specimenImageServiceProvider.overrideWith(
        (ref) async => SpecimenImageService(
          api: FakeSpecimenApi(),
          store: FakeImageStore(),
          downloader: FakeImageDownloader(),
        ),
      ),
    ];
  };

  // 画像取得が失敗する override（downloader が必ず例外を投げる＝deferred）。
  // ignore: prefer_function_declarations_over_variables
  final buildOverridesFailingImage = (AppDatabase db) {
    final repo = SpecimenRepository(db.specimensDao);
    return [
      appDatabaseProvider.overrideWith((ref) {
        ref.onDispose(db.close);
        return db;
      }),
      specimenRepositoryProvider.overrideWithValue(repo),
      userSaltProvider.overrideWith((ref) async => 'test-salt-answer'),
      nowProvider.overrideWithValue(DateTime(2026, 6, 9, 12, 0, 0)),
      specimenApiProvider.overrideWith((ref) async => FakeSpecimenApi()),
      specimenImageServiceProvider.overrideWith(
        (ref) async => SpecimenImageService(
          api: FakeSpecimenApi(),
          store: FakeImageStore(),
          downloader: _ThrowingImageDownloader(),
        ),
      ),
    ];
  };

  // ---------------------------------------------------------------------------
  // T5: _submit() → pushReplacement → DetailScreen(playReveal:true) 遷移確認
  // ---------------------------------------------------------------------------

  group('T5: AnswerScreen._submit() 遷移', () {
    testWidgets(
        '回答入力後に「回答する」ボタンをタップすると DetailScreen へ pushReplacement される',
        (tester) async {
      final db = testDb;
      final observer = _TestNavigatorObserver();

      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(db),
          child: MaterialApp(
            navigatorObservers: [observer],
            home: const AnswerScreen(),
          ),
        ),
      );

      // サーバー（Fake）からの問い取得と salt の取得を待つ。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      // ローディングが終わるまで追加で待つ。
      await tester.pump(const Duration(milliseconds: 500));

      // ローディングが完了して TextField が表示されているか確認する。
      // ローディング中は CircularProgressIndicator のみ表示される。
      final textFieldFinder = find.byType(TextField);
      if (textFieldFinder.evaluate().isEmpty) {
        // まだローディング中であれば追加で待つ。
        await tester.pump(const Duration(seconds: 2));
      }

      // TextField にテキストを入力する。
      await tester.enterText(find.byType(TextField), 'テストの回答');
      await tester.pump();

      // 「回答する」ボタンが有効化されていることを確認する。
      final submitButton = find.text('回答する');
      expect(submitButton, findsOneWidget,
          reason: '「回答する」ボタンが表示される');

      // ボタンをタップして submit を実行する。
      await tester.tap(submitButton);

      // add() の DB 保存と pushReplacement の非同期処理を待つ。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 500));

      // pushReplacement により DetailScreen に遷移したことを確認する。
      // observer.lastReplacedRoute にルートが記録されているはず。
      final replaced = observer.lastReplacedRoute;
      expect(replaced, isNotNull,
          reason: 'pushReplacement が呼ばれた');

      // 遷移先が DetailScreen を含む MaterialPageRoute であることを確認する。
      // 遷移完了後に DetailScreen が widget ツリーに存在するか確認する。
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DetailScreen), findsOneWidget,
          reason: 'pushReplacement 後に DetailScreen が表示される');

      // playReveal=true が DetailScreen に渡されていることを確認する。
      // _DetailScreenState.revealController（@visibleForTesting）が非 null であれば
      // playReveal=true が正しく渡された証拠になる。
      // アセットのロード成功を前提とせず、遷移後の state を直接検査するため
      // アセット依存の timeout 問題が生じない。
      final statefulElement =
          tester.element(find.byType(DetailScreen)) as StatefulElement;
      // ignore: invalid_use_of_visible_for_testing_member
      final controller =
          (statefulElement.state as dynamic).revealController as AnimationController?;
      expect(controller, isNotNull,
          reason: 'playReveal=true が渡されたため revealController が非 null になっている');
    });
  });

  // ---------------------------------------------------------------------------
  // 画像取得失敗: 回答を保存せず「画像の取得ができませんでした」を表示する
  // ---------------------------------------------------------------------------
  group('画像取得失敗', () {
    testWidgets(
        '画像取得が失敗したら回答を保存せず、画像エラー表示になり DetailScreen へ遷移しない',
        (tester) async {
      final db = testDb;
      final observer = _TestNavigatorObserver();

      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverridesFailingImage(db),
          child: MaterialApp(
            navigatorObservers: [observer],
            home: const AnswerScreen(),
          ),
        ),
      );

      // 問い取得（Fake）の完了を待つ。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(TextField).evaluate().isEmpty) {
        await tester.pump(const Duration(seconds: 2));
      }

      await tester.enterText(find.byType(TextField), 'テストの回答');
      await tester.pump();
      await tester.tap(find.text('回答する'));

      // 画像取得（DL 失敗）→ 保存せずエラー表示の非同期処理を待つ。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 500));

      // 「画像の取得ができませんでした」が表示される。
      expect(find.text('画像の取得ができませんでした'), findsOneWidget,
          reason: '画像取得失敗時はエラー表示にする');
      // DetailScreen へは遷移しない（pushReplacement されない）。
      expect(observer.lastReplacedRoute, isNull,
          reason: '画像取得失敗時は保存・遷移しない');
      expect(find.byType(DetailScreen), findsNothing);

      // 回答（標本）は保存されていない。
      final saved = await SpecimenRepository(db.specimensDao).getAll();
      expect(saved, isEmpty, reason: '画像取得失敗時は標本を保存しない');
    });
  });

  // ---------------------------------------------------------------------------
  // プール枯渇（全収集済み）: 案内メッセージを出し、記録すると保存して進む
  // ---------------------------------------------------------------------------
  group('画像プール枯渇', () {
    // drawImage が exhausted を返す Fake API。
    FakeSpecimenApi exhaustedApi() => FakeSpecimenApi(
          image: const ImageDrawResult(image: null, exhausted: true),
        );

    // ignore: prefer_function_declarations_over_variables
    final overridesExhausted = (AppDatabase db) {
      final repo = SpecimenRepository(db.specimensDao);
      return [
        appDatabaseProvider.overrideWith((ref) {
          ref.onDispose(db.close);
          return db;
        }),
        specimenRepositoryProvider.overrideWithValue(repo),
        userSaltProvider.overrideWith((ref) async => 'test-salt-answer'),
        nowProvider.overrideWithValue(DateTime(2026, 6, 9, 12, 0, 0)),
        specimenApiProvider.overrideWith((ref) async => FakeSpecimenApi()),
        specimenImageServiceProvider.overrideWith(
          (ref) async => SpecimenImageService(
            api: exhaustedApi(),
            store: FakeImageStore(),
            downloader: FakeImageDownloader(),
          ),
        ),
      ];
    };

    testWidgets('枯渇時は案内ダイアログを出し、「記録する」で画像なし保存して遷移する',
        (tester) async {
      final db = testDb;
      final observer = _TestNavigatorObserver();

      await tester.pumpWidget(
        ProviderScope(
          overrides: overridesExhausted(db),
          child: MaterialApp(
            navigatorObservers: [observer],
            home: const AnswerScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(TextField).evaluate().isEmpty) {
        await tester.pump(const Duration(seconds: 2));
      }

      await tester.enterText(find.byType(TextField), 'テストの回答');
      await tester.pump();
      await tester.tap(find.text('回答する'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 案内ダイアログが表示される。
      expect(find.text('化石を集めきりました'), findsOneWidget,
          reason: '枯渇時は案内メッセージを出す');

      // 「記録する」で保存して進む。
      await tester.tap(find.text('記録する'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(observer.lastReplacedRoute, isNotNull,
          reason: '記録するで DetailScreen へ遷移する');
      final saved = await SpecimenRepository(db.specimensDao).getAll();
      expect(saved, hasLength(1), reason: '枯渇でも回答は記録される');
      expect(saved.single.localPath, isNull,
          reason: '枯渇時は画像なし（プレースホルダ）で保存');
    });
  });

  // ---------------------------------------------------------------------------
  // 閉じる確認ダイアログ（問いは一度きり表示の警告）
  // ---------------------------------------------------------------------------
  group('問い画面の閉じる確認', () {
    Future<void> openAnswer(WidgetTester tester, AppDatabase db) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(db),
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AnswerScreen(),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      // 問いの非同期ロードを待つ（閉じるボタンはロード中でも表示される）。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    // ローディング中は CircularProgressIndicator（無限アニメ）が出るため
    // pumpAndSettle は使えない。固定 pump でダイアログ/遷移を進める。
    Future<void> settleDialog(WidgetTester tester) async {
      // ダイアログ表示/消去＋（閉じる時の）ページ pop 遷移を進める。
      // 2段（ダイアログ消去→onPopInvoked のコールバック→ページ pop）を吸収するため
      // 余裕を持って複数回 pump する。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('閉じるボタンで確認ダイアログが出る', (tester) async {
      await openAnswer(tester, testDb);

      await tester.tap(find.byIcon(Icons.close));
      await settleDialog(tester);

      expect(find.text('閉じますか？'), findsOneWidget);
      expect(find.textContaining('一度しか表示されません'), findsOneWidget);
    });

    testWidgets('「とどまる」で閉じない', (tester) async {
      await openAnswer(tester, testDb);

      await tester.tap(find.byIcon(Icons.close));
      await settleDialog(tester);
      await tester.tap(find.text('とどまる'));
      await settleDialog(tester);

      expect(find.byType(AnswerScreen), findsOneWidget);
      expect(find.text('閉じますか？'), findsNothing);
    });

    testWidgets('「閉じる」で前画面に戻る', (tester) async {
      await openAnswer(tester, testDb);

      await tester.tap(find.byIcon(Icons.close));
      await settleDialog(tester);
      await tester.tap(find.text('閉じる'));
      await settleDialog(tester);

      expect(find.byType(AnswerScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });
}
