// detail_screen_seal_test.dart — DetailScreen の封印 IAP フロー（ADR-0010）の widget テスト。
//
// 検証観点（T4）:
// - canSeal=true（クレジット保有）: 「封をする」タップで封印され、クレジットが1消費される。
// - canSeal=true（アンロック所有）: タップで封印され、クレジットは消費されない。
// - canSeal=false: タップで購入シートが開き、商品が表示される。
// - 購入成功（2段階・2026-06-13 仕様変更）: シートで商品タップ＝エンタイトルメント付与のみ
//   （この時点では封印しない）。もう一度「封をする」→確認ダイアログ→封印される。
// - 購入キャンセル/失敗: 付与も封印もされない。
// - 復元: 「購入を復元」で seal_unlocked が true になる。
// - 封印済み: 「封印済み」終端表示でタップ無効（解除導線なし）。
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:specimen_box/data/db/app_database.dart';
import 'package:specimen_box/data/repositories/settings_repository.dart';
import 'package:specimen_box/data/repositories/specimen_repository.dart';
import 'package:specimen_box/domain/purchase/seal_entitlement.dart';
import 'package:specimen_box/platform/purchase/fake_purchase_service.dart';
import 'package:specimen_box/platform/purchase/purchase_service.dart';
import 'package:specimen_box/presentation/detail/detail_screen.dart';
import 'package:specimen_box/presentation/providers/providers.dart';

void main() {
  late AppDatabase testDb;

  setUp(() {
    testDb = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await testDb.close();
  });

  /// 標本を1件保存する。
  Future<void> seedSpecimen(AppDatabase db, {String status = 'alive'}) async {
    final repo = SpecimenRepository(db.specimensDao);
    await repo.save(
      id: 'seal-test-001',
      date: '2026-06-09',
      questionId: 'q-seal-01',
      questionText: '今日の問い',
      answerText: '封印テスト回答',
      status: status,
      createdAt: DateTime(2026, 6, 9, 10, 0, 0),
    );
  }

  /// エンタイトルメントを Settings に保存する。
  Future<void> seedEntitlement(AppDatabase db, SealEntitlement e) async {
    await SettingsRepository(db.settingsDao).setSealEntitlement(e);
  }

  // Riverpod 3.x では Override 型が未エクスポートのため型推論を使う。
  buildOverrides(AppDatabase db, PurchaseService purchase) {
    return [
      appDatabaseProvider.overrideWith((ref) {
        ref.onDispose(db.close);
        return db;
      }),
      userSaltProvider.overrideWith((ref) async => 'test-salt-seal'),
      nowProvider.overrideWithValue(DateTime(2026, 6, 9, 12, 0, 0)),
      purchaseServiceProvider.overrideWithValue(purchase),
    ];
  }

  Future<void> pumpDetail(
    WidgetTester tester, {
    required AppDatabase db,
    required PurchaseService purchase,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(db, purchase),
        child: const MaterialApp(
          home: DetailScreen(specimenId: 'seal-test-001'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 封印ボタンはスクロールビュー下部にあり 600px ビューポート外になるため、
  /// 可視化してからタップする。
  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// 表示中の SnackBar（購入完了通知など）を時間経過で消す。
  ///
  /// floating SnackBar が封印ボタンに重なってタップを奪うのを避けるため、
  /// 2段階フロー（購入 → 再タップ封印）の間に呼ぶ。
  Future<void> dismissSnackBars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5)); // 既定 4 秒で自動消去。
    await tester.pumpAndSettle();
  }

  /// 購入後の「もう一度封をする → 確認 → 封印」を行う。
  Future<void> tapSealAgainAndConfirm(WidgetTester tester) async {
    await dismissSnackBars(tester);
    await tapText(tester, '封をする（永久保存）');
    expect(find.text('封印しますか？'), findsOneWidget);
    await tester.tap(find.text('封印する'));
    await tester.pumpAndSettle();
  }

  // ---------------------------------------------------------------------------
  // canSeal=true: そのまま封印
  // ---------------------------------------------------------------------------
  group('canSeal=true: 即封印', () {
    testWidgets('クレジット保有時、封をするでクレジットが1消費され封印される',
        (tester) async {
      await seedSpecimen(testDb);
      await seedEntitlement(testDb, SealEntitlement(credits: 2));
      await pumpDetail(tester, db: testDb, purchase: FakePurchaseService());

      await tapText(tester, '封をする（永久保存）');
      // 確認ダイアログが出る → 「封印する」を承認。
      expect(find.text('封印しますか？'), findsOneWidget);
      await tester.tap(find.text('封印する'));
      await tester.pumpAndSettle();

      // 標本が封印された。
      final row = await SpecimenRepository(testDb.specimensDao)
          .findById('seal-test-001');
      expect(row!.status, 'sealed');

      // クレジットが 2 → 1 に減った。
      final ent =
          await SettingsRepository(testDb.settingsDao).getSealEntitlement();
      expect(ent.credits, 1);
      expect(ent.unlocked, isFalse);

      // 封印済み表示に切り替わる（購入シートは出ない）。
      expect(find.text('封印済み'), findsOneWidget);
    });

    testWidgets('確認ダイアログでキャンセルすると封印されずクレジットも減らない',
        (tester) async {
      await seedSpecimen(testDb);
      await seedEntitlement(testDb, SealEntitlement(credits: 2));
      await pumpDetail(tester, db: testDb, purchase: FakePurchaseService());

      await tapText(tester, '封をする（永久保存）');
      expect(find.text('封印しますか？'), findsOneWidget);
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      // 封印されず、クレジットも不変。
      final row = await SpecimenRepository(testDb.specimensDao)
          .findById('seal-test-001');
      expect(row!.status, 'alive');
      final ent =
          await SettingsRepository(testDb.settingsDao).getSealEntitlement();
      expect(ent.credits, 2);
      expect(find.text('封をする（永久保存）'), findsOneWidget);
    });

    testWidgets('アンロック所有時、封印してもクレジットは消費されない',
        (tester) async {
      await seedSpecimen(testDb);
      await seedEntitlement(testDb, SealEntitlement(unlocked: true, credits: 3));
      await pumpDetail(tester, db: testDb, purchase: FakePurchaseService());

      await tapText(tester, '封をする（永久保存）');
      // アンロック時も確認ダイアログを挟む。
      expect(find.text('封印しますか？'), findsOneWidget);
      await tester.tap(find.text('封印する'));
      await tester.pumpAndSettle();

      final row = await SpecimenRepository(testDb.specimensDao)
          .findById('seal-test-001');
      expect(row!.status, 'sealed');

      final ent =
          await SettingsRepository(testDb.settingsDao).getSealEntitlement();
      expect(ent.credits, 3); // 不変
      expect(ent.unlocked, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // canSeal=false: 購入シート
  // ---------------------------------------------------------------------------
  group('canSeal=false: 購入シート', () {
    testWidgets('権利なしで封をするを押すと購入シートが開く', (tester) async {
      await seedSpecimen(testDb);
      // エンタイトルメント未設定（unlocked=false, credits=0）。
      await pumpDetail(tester, db: testDb, purchase: FakePurchaseService());

      await tapText(tester, '封をする（永久保存）');

      // 3商品が並ぶ。
      expect(find.text('封印（1個）'), findsOneWidget);
      expect(find.text('封印パック（5個）'), findsOneWidget);
      expect(find.text('封印アンロック'), findsOneWidget);
      expect(find.text('購入を復元'), findsOneWidget);

      // まだ封印されていない。
      final row = await SpecimenRepository(testDb.specimensDao)
          .findById('seal-test-001');
      expect(row!.status, 'alive');
    });

    testWidgets('単品購入は付与のみ（封印しない）→再タップ確認で封印され残0',
        (tester) async {
      await seedSpecimen(testDb);
      await pumpDetail(
        tester,
        db: testDb,
        purchase: FakePurchaseService(), // 既定 success
      );

      await tapText(tester, '封をする（永久保存）');
      await tester.tap(find.text('封印（1個）'));
      await tester.pumpAndSettle();

      final repo = SpecimenRepository(testDb.specimensDao);
      final settings = SettingsRepository(testDb.settingsDao);

      // 購入時点: 封印されておらず、single 付与(+1)で credits=1。
      expect((await repo.findById('seal-test-001'))!.status, 'alive');
      expect((await settings.getSealEntitlement()).credits, 1);

      // 再タップ→確認→封印。封印で1消費 → credits 0。
      await tapSealAgainAndConfirm(tester);
      expect((await repo.findById('seal-test-001'))!.status, 'sealed');
      final ent = await settings.getSealEntitlement();
      expect(ent.credits, 0);
      expect(ent.unlocked, isFalse);
    });

    testWidgets('アンロック購入は付与のみ→再タップ確認で封印・credits不変',
        (tester) async {
      await seedSpecimen(testDb);
      await pumpDetail(tester, db: testDb, purchase: FakePurchaseService());

      await tapText(tester, '封をする（永久保存）');
      await tester.tap(find.text('封印アンロック'));
      await tester.pumpAndSettle();

      final repo = SpecimenRepository(testDb.specimensDao);
      final settings = SettingsRepository(testDb.settingsDao);

      // 購入時点: unlocked=true だがまだ封印しない。
      expect((await repo.findById('seal-test-001'))!.status, 'alive');
      expect((await settings.getSealEntitlement()).unlocked, isTrue);

      // 再タップ→確認→封印。unlock は消費なし。
      await tapSealAgainAndConfirm(tester);
      expect((await repo.findById('seal-test-001'))!.status, 'sealed');
      final ent = await settings.getSealEntitlement();
      expect(ent.unlocked, isTrue);
      expect(ent.credits, 0);
    });

    testWidgets('パック購入は付与のみ（+5）→再タップ確認で封印され残4',
        (tester) async {
      await seedSpecimen(testDb);
      await pumpDetail(tester, db: testDb, purchase: FakePurchaseService());

      await tapText(tester, '封をする（永久保存）');
      await tester.tap(find.text('封印パック（5個）'));
      await tester.pumpAndSettle();

      final repo = SpecimenRepository(testDb.specimensDao);
      final settings = SettingsRepository(testDb.settingsDao);

      // 購入時点: 未封印・pack5 付与(+5)で credits=5。
      expect((await repo.findById('seal-test-001'))!.status, 'alive');
      expect((await settings.getSealEntitlement()).credits, 5);

      // 再タップ→確認→封印。封印で1消費 → credits 4。
      await tapSealAgainAndConfirm(tester);
      expect((await repo.findById('seal-test-001'))!.status, 'sealed');
      final ent = await settings.getSealEntitlement();
      expect(ent.credits, 4);
      expect(ent.unlocked, isFalse);
    });

    testWidgets('購入エラー時は封印されずクレジットも増えない', (tester) async {
      await seedSpecimen(testDb);
      await pumpDetail(
        tester,
        db: testDb,
        purchase:
            FakePurchaseService(nextPurchaseStatus: PurchaseStatus.error),
      );

      await tapText(tester, '封をする（永久保存）');
      await tester.tap(find.text('封印（1個）'));
      await tester.pumpAndSettle();

      final row = await SpecimenRepository(testDb.specimensDao)
          .findById('seal-test-001');
      expect(row!.status, 'alive');

      final ent =
          await SettingsRepository(testDb.settingsDao).getSealEntitlement();
      expect(ent.credits, 0);
      expect(ent.unlocked, isFalse);
    });

    testWidgets('購入キャンセル時は封印されない', (tester) async {
      await seedSpecimen(testDb);
      await pumpDetail(
        tester,
        db: testDb,
        purchase:
            FakePurchaseService(nextPurchaseStatus: PurchaseStatus.canceled),
      );

      await tapText(tester, '封をする（永久保存）');
      await tester.tap(find.text('封印（1個）'));
      await tester.pumpAndSettle();

      final row = await SpecimenRepository(testDb.specimensDao)
          .findById('seal-test-001');
      expect(row!.status, 'alive');

      final ent =
          await SettingsRepository(testDb.settingsDao).getSealEntitlement();
      expect(ent.credits, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // 復元
  // ---------------------------------------------------------------------------
  group('復元', () {
    testWidgets('購入を復元でアンロックが復元される（封印自体はしない）',
        (tester) async {
      await seedSpecimen(testDb);
      await pumpDetail(
        tester,
        db: testDb,
        purchase: FakePurchaseService(restoreUnlock: true),
      );

      await tapText(tester, '封をする（永久保存）');
      await tapText(tester, '購入を復元');

      final ent =
          await SettingsRepository(testDb.settingsDao).getSealEntitlement();
      expect(ent.unlocked, isTrue);

      // 復元のみ。標本は封印されない。
      final row = await SpecimenRepository(testDb.specimensDao)
          .findById('seal-test-001');
      expect(row!.status, 'alive');
    });
  });

  // ---------------------------------------------------------------------------
  // 封印済み: 終端表示・解除不可
  // ---------------------------------------------------------------------------
  group('封印済みは終端', () {
    testWidgets('封印済み標本は「封印済み」表示でタップしても解除されない',
        (tester) async {
      await seedSpecimen(testDb, status: 'sealed');
      await pumpDetail(tester, db: testDb, purchase: FakePurchaseService());

      expect(find.text('封印済み'), findsOneWidget);
      expect(find.text('封をする（永久保存）'), findsNothing);

      // タップしても解除されない（購入シートも出ない）。
      await tapText(tester, '封印済み');

      final row = await SpecimenRepository(testDb.specimensDao)
          .findById('seal-test-001');
      expect(row!.status, 'sealed');
      expect(find.text('封印（1個）'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // 封印残数の表示
  // ---------------------------------------------------------------------------
  group('封印残数の表示', () {
    testWidgets('クレジット保有時は「封印できる残り N個」を表示', (tester) async {
      await seedSpecimen(testDb);
      await seedEntitlement(testDb, SealEntitlement(credits: 4));
      await pumpDetail(tester, db: testDb, purchase: FakePurchaseService());

      expect(find.text('封印できる残り 4個'), findsOneWidget);
    });

    testWidgets('アンロック時は「封印し放題（残り ∞）」を表示', (tester) async {
      await seedSpecimen(testDb);
      await seedEntitlement(testDb, SealEntitlement(unlocked: true));
      await pumpDetail(tester, db: testDb, purchase: FakePurchaseService());

      expect(find.text('封印し放題（残り ∞）'), findsOneWidget);
    });

    testWidgets('パック購入で +5 表示→封印後に 4個 へ更新される', (tester) async {
      await seedSpecimen(testDb);
      await pumpDetail(tester, db: testDb, purchase: FakePurchaseService());

      // 権利なし → 残り 0個。
      expect(find.text('封印できる残り 0個'), findsOneWidget);

      await tapText(tester, '封をする（永久保存）');
      await tester.tap(find.text('封印パック（5個）'));
      await tester.pumpAndSettle();

      // 購入時点では封印せず +5 のみ → 残り 5個。
      expect(find.text('封印できる残り 5個'), findsOneWidget);

      // 再タップ→確認→封印で1消費 → 残り 4個。
      await tapSealAgainAndConfirm(tester);
      expect(find.text('封印できる残り 4個'), findsOneWidget);
    });
  });
}
