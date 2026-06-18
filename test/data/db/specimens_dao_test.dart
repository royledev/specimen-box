// ignore_for_file: lines_longer_than_80_chars

// Specimens DAO の CRUD テスト（NativeDatabase.memory 上で実行）。
//
// 設計意図（ADR-0011）:
// - 保存実体は最小メタ（answerText 等）＋画像参照（image_id / local_path）のみ。
// - ベクター生成（seed / generatorVersion / SpecimenParams）は廃止済み。
// - このテストのスキーマ検証（テーブルカラム確認）でそれを担保する。
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/data/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // ─────────────────────────────────────────────
  // 1. 挿入 → 全件取得（新しい順）
  // ─────────────────────────────────────────────
  group('SpecimensDao: 挿入と全件取得', () {
    test('1件挿入して全件取得すると1件返る', () async {
      await db.specimensDao.insertSpecimen(
        SpecimensCompanion(
          id: const Value('id-001'),
          date: const Value('2026-06-09'),
          questionId: const Value('q-test-01'),
          questionText: const Value('今日気になった音は？'),
          answerText: const Value('冷蔵庫のブーン'),
          status: const Value('alive'),
          createdAt: Value(DateTime(2026, 6, 9, 10, 0, 0)),
        ),
      );

      final all = await db.specimensDao.getAllSpecimens();
      expect(all.length, equals(1));
      expect(all.first.id, equals('id-001'));
      expect(all.first.answerText, equals('冷蔵庫のブーン'));
      expect(all.first.questionText, equals('今日気になった音は？'));
      expect(all.first.status, equals('alive'));
    });

    test('3件挿入すると createdAt 降順（新しい順）で返る', () async {
      final entries = [
        (
          id: 'id-001',
          created: DateTime(2026, 6, 9, 8, 0, 0),
        ),
        (
          id: 'id-002',
          created: DateTime(2026, 6, 9, 12, 0, 0),
        ),
        (
          id: 'id-003',
          created: DateTime(2026, 6, 9, 10, 0, 0),
        ),
      ];

      for (final e in entries) {
        await db.specimensDao.insertSpecimen(
          SpecimensCompanion(
            id: Value(e.id),
            date: const Value('2026-06-09'),
            questionId: const Value('q-test-01'),
            questionText: const Value('テスト質問'),
            answerText: const Value('テスト回答'),
            status: const Value('alive'),
            createdAt: Value(e.created),
          ),
        );
      }

      final all = await db.specimensDao.getAllSpecimens();
      expect(all.length, equals(3));
      // createdAt 降順 → 12:00 > 10:00 > 08:00
      expect(all[0].id, equals('id-002'));
      expect(all[1].id, equals('id-003'));
      expect(all[2].id, equals('id-001'));
    });
  });

  // ─────────────────────────────────────────────
  // 2. id 検索
  // ─────────────────────────────────────────────
  group('SpecimensDao: id 検索', () {
    test('存在する id で検索すると該当行を返す', () async {
      await db.specimensDao.insertSpecimen(
        SpecimensCompanion(
          id: const Value('id-abc'),
          date: const Value('2026-06-09'),
          questionId: const Value('q-x'),
          questionText: const Value('テスト'),
          answerText: const Value('回答テスト'),
          status: const Value('alive'),
          createdAt: Value(DateTime(2026, 6, 9)),
        ),
      );

      final found = await db.specimensDao.findById('id-abc');
      expect(found, isNotNull);
      expect(found!.id, equals('id-abc'));
    });

    test('存在しない id で検索すると null を返す', () async {
      final found = await db.specimensDao.findById('nonexistent-id');
      expect(found, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // 3. status 更新（汎用プリミティブ: 両方向に値を書ける）
  //    ※封印の「一方向」不変条件は上位の SpecimenRepository.seal が担う。
  //      DAO は status を書き換える低レベル操作なので双方向を検証する。
  // ─────────────────────────────────────────────
  group('SpecimensDao: status 更新', () {
    setUp(() async {
      await db.specimensDao.insertSpecimen(
        SpecimensCompanion(
          id: const Value('id-status-test'),
          date: const Value('2026-06-09'),
          questionId: const Value('q-y'),
          questionText: const Value('問い'),
          answerText: const Value('回答'),
          status: const Value('alive'),
          createdAt: Value(DateTime(2026, 6, 9)),
        ),
      );
    });

    test('alive → sealed に更新できる', () async {
      await db.specimensDao.updateStatus('id-status-test', 'sealed');
      final row = await db.specimensDao.findById('id-status-test');
      expect(row!.status, equals('sealed'));
    });

    test('sealed → alive に戻せる', () async {
      await db.specimensDao.updateStatus('id-status-test', 'sealed');
      await db.specimensDao.updateStatus('id-status-test', 'alive');
      final row = await db.specimensDao.findById('id-status-test');
      expect(row!.status, equals('alive'));
    });
  });

  // ─────────────────────────────────────────────
  // 4. スキーマ検証: 保存実体は最小メタ＋画像参照のみ（ADR-0011）
  //    ベクター生成（seed/generatorVersion/SpecimenParams）は廃止済み。
  // ─────────────────────────────────────────────
  group('SpecimensDao: 画像更新（updateImage・ADR-0017）', () {
    test('rarity 付きで image_id/local_path/image_rarity を更新できる', () async {
      await db.specimensDao.insertSpecimen(
        SpecimensCompanion(
          id: const Value('upd-1'),
          date: const Value('2026-06-13'),
          questionId: const Value('q'),
          questionText: const Value('問い'),
          answerText: const Value('回答'),
          status: const Value('alive'),
          createdAt: Value(DateTime(2026, 6, 13)),
        ),
      );

      await db.specimensDao
          .updateImage('upd-1', 'img-x', '/p/x.webp', rarity: 5);

      final row = await db.specimensDao.findById('upd-1');
      expect(row!.imageId, equals('img-x'));
      expect(row.localPath, equals('/p/x.webp'));
      expect(row.imageRarity, equals(5));
    });

    test('rarity 未指定では既存の image_rarity を上書きしない（M1）', () async {
      // 画像レア度 4 で保存済みの行。
      await db.specimensDao.insertSpecimen(
        SpecimensCompanion(
          id: const Value('upd-2'),
          date: const Value('2026-06-13'),
          questionId: const Value('q'),
          questionText: const Value('問い'),
          answerText: const Value('回答'),
          status: const Value('alive'),
          createdAt: Value(DateTime(2026, 6, 13)),
          imageRarity: const Value(4),
        ),
      );

      // rarity を渡さず updateImage → 既存の 4 が維持される（NULL 上書きしない）。
      await db.specimensDao.updateImage('upd-2', 'img-y', '/p/y.webp');

      final row = await db.specimensDao.findById('upd-2');
      expect(row!.imageId, equals('img-y'));
      expect(row.localPath, equals('/p/y.webp'));
      expect(row.imageRarity, equals(4));
    });

    test('name を保存・取得でき、updateImage の name で更新できる', () async {
      // 保存時に name（標本表示名）を持てる。
      await db.specimensDao.insertSpecimen(
        SpecimensCompanion(
          id: const Value('upd-3'),
          date: const Value('2026-06-13'),
          questionId: const Value('q'),
          questionText: const Value('問い'),
          answerText: const Value('回答'),
          status: const Value('alive'),
          createdAt: Value(DateTime(2026, 6, 13)),
          name: const Value('怒った扇風機'),
        ),
      );
      expect((await db.specimensDao.findById('upd-3'))!.name, equals('怒った扇風機'));

      // deferred 確定（updateImage）で name を後付けできる。
      await db.specimensDao.insertSpecimen(
        SpecimensCompanion(
          id: const Value('upd-4'),
          date: const Value('2026-06-13'),
          questionId: const Value('q'),
          questionText: const Value('問い'),
          answerText: const Value('回答'),
          status: const Value('alive'),
          createdAt: Value(DateTime(2026, 6, 13)),
        ),
      );
      await db.specimensDao
          .updateImage('upd-4', 'img-z', '/p/z.webp', name: '寝坊した目覚まし');
      final row = await db.specimensDao.findById('upd-4');
      expect(row!.name, equals('寝坊した目覚まし'));

      // name 未指定の updateImage は既存 name を上書きしない。
      await db.specimensDao.updateImage('upd-4', 'img-z2', '/p/z2.webp');
      expect((await db.specimensDao.findById('upd-4'))!.name, equals('寝坊した目覚まし'));
    });
  });

  group('スキーマ検証: 保存実体は最小メタ＋画像参照', () {
    test('Specimen 行は image_id / local_path を持つ（サーバー画像参照）', () async {
      await db.specimensDao.insertSpecimen(
        SpecimensCompanion(
          id: const Value('id-schema'),
          date: const Value('2026-06-09'),
          questionId: const Value('q-z'),
          questionText: const Value('スキーマテスト'),
          answerText: const Value('メタのみ'),
          status: const Value('alive'),
          createdAt: Value(DateTime(2026, 6, 9)),
          imageId: const Value('uuid-schema'),
          localPath: const Value('/docs/specimens/uuid-schema.webp'),
        ),
      );

      final row = await db.specimensDao.findById('id-schema');
      expect(row, isNotNull);
      expect(row!.imageId, equals('uuid-schema'));
      expect(row.localPath, equals('/docs/specimens/uuid-schema.webp'));

      // 旧ベクター生成カラム（seed / generator_version / baseHue 等）は存在しない。
      // Specimen クラスにそれらのフィールドが無いことはコンパイル時に担保される。
    });

    test('Specimen 行のカラム数は 11 (最小メタ + 画像参照 + 画像レア度 + 標本名)', () async {
      // カラム: id, date, questionId, questionText, answerText,
      //         status, createdAt, image_id, local_path, image_rarity, name
      // ベクター生成カラム（seed / generator_version）と見た目カラムは含まれない。
      // image_rarity は ADR-0017（画像レア度 1〜5）、name は標本表示名（schemaVersion 6）で追加。
      const expectedColumnCount = 11;

      // テーブルのカラム定義数を Drift の table.columnsByName で検証する。
      final columnNames = db.specimens.columnsByName.keys.toSet();
      expect(columnNames.length, equals(expectedColumnCount));

      // 想定カラムがすべて存在する
      expect(
        columnNames,
        containsAll(<String>[
          'id',
          'date',
          'question_id',
          'question_text',
          'answer_text',
          'status',
          'created_at',
          'image_id',
          'local_path',
          'image_rarity',
          'name',
        ]),
      );

      // ベクター生成カラムは存在しない（ADR-0011 で廃止）。
      expect(columnNames, isNot(contains('seed')));
      expect(columnNames, isNot(contains('generator_version')));

      // SpecimenParams 由来カラムが存在しない
      expect(columnNames, isNot(contains('base_hue')));
      expect(columnNames, isNot(contains('accent_hue')));
      expect(columnNames, isNot(contains('saturation')));
      expect(columnNames, isNot(contains('lightness')));
      expect(columnNames, isNot(contains('bg_lightness')));
      expect(columnNames, isNot(contains('lobes')));
      expect(columnNames, isNot(contains('irregularity')));
      expect(columnNames, isNot(contains('rotation')));
      expect(columnNames, isNot(contains('scale')));
      expect(columnNames, isNot(contains('grain')));
      expect(columnNames, isNot(contains('grain_scale')));
      expect(columnNames, isNot(contains('rings')));
    });
  });
}
