// home_screen_seal_chip_test.dart — ホーム AppBar の封印残数チップ。

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:specimen_box/data/db/app_database.dart';
import 'package:specimen_box/data/repositories/settings_repository.dart';
import 'package:specimen_box/domain/purchase/seal_entitlement.dart';
import 'package:specimen_box/presentation/home/home_screen.dart';
import 'package:specimen_box/presentation/providers/providers.dart';
import 'package:specimen_box/presentation/widgets/seal_balance.dart';

void main() {
  late AppDatabase testDb;

  setUp(() {
    testDb = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await testDb.close();
  });

  buildOverrides(AppDatabase db) => [
        appDatabaseProvider.overrideWith((ref) {
          ref.onDispose(db.close);
          return db;
        }),
        userSaltProvider.overrideWith((ref) async => 'test-salt-home-chip'),
        nowProvider.overrideWithValue(DateTime(2026, 6, 12, 12, 0, 0)),
      ];

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(testDb),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    // 空状態の封印（待機）演出が常時ループするため pumpAndSettle は使えない。
    // チップは provider 解決後に表示されるので固定 pump で進める。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('クレジット保有時、チップに残数が出る', (tester) async {
    await SettingsRepository(testDb.settingsDao)
        .setSealEntitlement(SealEntitlement(credits: 4));
    await pumpHome(tester);

    expect(find.byType(SealBalanceChip), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('アンロック時、チップに ∞ が出る', (tester) async {
    await SettingsRepository(testDb.settingsDao)
        .setSealEntitlement(SealEntitlement(unlocked: true));
    await pumpHome(tester);

    expect(find.byType(SealBalanceChip), findsOneWidget);
    expect(find.text('∞'), findsOneWidget);
  });
}
