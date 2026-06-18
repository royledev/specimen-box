// persistence_integration_test.dart — DB 永続の結合テスト
//
// 目的:
//   「保存 → DB を close → 同じファイルを再 open → データが残存する」
//   ことを検証することで、リロード/再起動後も標本が残る DB 永続を担保する。
//
// NativeDatabase.memory() はプロセス内インメモリなのでこの検証には不十分。
// NativeDatabase(File(...)) で一時ファイル DB に書き、close 後に再 open
// して残存を確認する形式を採用する（T5 決定）。
// 一時ファイルはテスト後に削除する。
//
// T5 open 指摘（T4 medium）の対処: 「保存→新しい DB 接続で再取得して残存」を担保。
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:specimen_box/data/db/app_database.dart';
import 'package:specimen_box/data/repositories/specimen_repository.dart';

void main() {
  group('DB 永続: 保存 → close → 再 open → データ残存', () {
    late Directory tempDir;
    late String dbPath;

    setUpAll(() async {
      // システムの一時ディレクトリにテスト用 DB ファイルを作成する。
      tempDir = await Directory.systemTemp.createTemp('specimen_test_');
      dbPath = p.join(tempDir.path, 'persistence_test.db');
    });

    tearDownAll(() async {
      // テスト後に一時ディレクトリを削除する。
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1件保存して DB を close し、同じファイルを再 open すると1件残存する', () async {
      // --- 第1フェーズ: DB に保存 ---
      {
        final db = AppDatabase.forTesting(
          NativeDatabase(File(dbPath)),
        );
        final repository = SpecimenRepository(db.specimensDao);

        await repository.save(
          id: 'persist-001',
          date: '2026-06-09',
          questionId: 'q-persist-01',
          questionText: '今日記憶に残ったものは？',
          answerText: '夕暮れの色',
          status: 'alive',
          createdAt: DateTime(2026, 6, 9, 18, 0, 0),
        );

        // DB を close して書き込みをフラッシュする。
        await db.close();
      }

      // --- 第2フェーズ: 同じファイルを再 open して残存を確認 ---
      {
        final db = AppDatabase.forTesting(
          NativeDatabase(File(dbPath)),
        );
        final repository = SpecimenRepository(db.specimensDao);

        final all = await repository.getAll();
        expect(all.length, equals(1), reason: 'close → 再 open 後も1件残存する');
        expect(all.first.id, equals('persist-001'));
        expect(all.first.answerText, equals('夕暮れの色'));
        expect(all.first.status, equals('alive'));

        await db.close();
      }
    });

    test('seal 後に close → 再 open すると sealed のまま残存する', () async {
      // 別ファイル DB でテスト（前テストと分離）。
      final db2Path = p.join(tempDir.path, 'persistence_seal_test.db');

      // --- 保存フェーズ ---
      {
        final db = AppDatabase.forTesting(NativeDatabase(File(db2Path)));
        final repository = SpecimenRepository(db.specimensDao);

        await repository.save(
          id: 'persist-seal-001',
          date: '2026-06-09',
          questionId: 'q-persist-seal',
          questionText: '封印テスト問い',
          answerText: '封印テスト回答',
          status: 'alive',
          createdAt: DateTime(2026, 6, 9, 10, 0, 0),
        );

        // seal を実施（alive → sealed・一方向）。
        final sealed = await repository.seal('persist-seal-001');
        expect(sealed, isTrue);

        await db.close();
      }

      // --- 再 open フェーズ: sealed が残存することを確認 ---
      {
        final db = AppDatabase.forTesting(NativeDatabase(File(db2Path)));
        final repository = SpecimenRepository(db.specimensDao);

        final row = await repository.findById('persist-seal-001');
        expect(row, isNotNull);
        expect(
          row!.status,
          equals('sealed'),
          reason: 'seal 後に close → 再 open しても sealed が残存する',
        );

        await db.close();
      }
    });

    test('3件保存後に close → 再 open するとすべて残存し createdAt 降順で返る', () async {
      final db3Path = p.join(tempDir.path, 'persistence_multi_test.db');

      // --- 保存フェーズ ---
      {
        final db = AppDatabase.forTesting(NativeDatabase(File(db3Path)));
        final repository = SpecimenRepository(db.specimensDao);

        final items = [
          (
            id: 'multi-a',
            created: DateTime(2026, 6, 9, 8, 0, 0),
          ),
          (
            id: 'multi-b',
            created: DateTime(2026, 6, 9, 12, 0, 0),
          ),
          (
            id: 'multi-c',
            created: DateTime(2026, 6, 9, 10, 0, 0),
          ),
        ];

        for (final item in items) {
          await repository.save(
            id: item.id,
            date: '2026-06-09',
            questionId: 'q-multi',
            questionText: '複数保存テスト',
            answerText: '回答 ${item.id}',
            status: 'alive',
            createdAt: item.created,
          );
        }

        await db.close();
      }

      // --- 再 open フェーズ ---
      {
        final db = AppDatabase.forTesting(NativeDatabase(File(db3Path)));
        final repository = SpecimenRepository(db.specimensDao);

        final all = await repository.getAll();
        expect(all.length, equals(3), reason: '3件すべて残存する');
        // createdAt 降順: 12:00 > 10:00 > 08:00
        expect(all[0].id, equals('multi-b'));
        expect(all[1].id, equals('multi-c'));
        expect(all[2].id, equals('multi-a'));

        await db.close();
      }
    });
  });
}
