// ignore_for_file: lines_longer_than_80_chars

// SpecimenRepository のテスト（NativeDatabase.memory 上で実行）。
//
// 設計意図:
// - リポジトリはDAOの上のレイヤとして save/getAll/findById/seal を提供する。
// - domain↔DB行のマッピングは data 層（リポジトリ内）に置く。
// - SpecimenParams は保存しない（seed/generatorVersion 等メタのみ）。
// - seal は findById で事前確認し、存在しない id の場合は false を返す（一方向・ADR-0010 決定3）。
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/data/db/app_database.dart';
import 'package:specimen_box/data/repositories/specimen_repository.dart';

void main() {
  late AppDatabase db;
  late SpecimenRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = SpecimenRepository(db.specimensDao);
  });

  tearDown(() async {
    await db.close();
  });

  // ─────────────────────────────────────────────
  // 1. save → getAll
  // ─────────────────────────────────────────────
  group('SpecimenRepository: save と getAll', () {
    test('1件保存して getAll すると1件返る', () async {
      await repository.save(
        id: 'repo-001',
        date: '2026-06-09',
        questionId: 'q-test-01',
        questionText: '今日気になった音は？',
        answerText: '冷蔵庫のブーン',
        status: 'alive',
        createdAt: DateTime(2026, 6, 9, 10, 0, 0),
      );

      final all = await repository.getAll();
      expect(all.length, equals(1));
      expect(all.first.id, equals('repo-001'));
      expect(all.first.answerText, equals('冷蔵庫のブーン'));
      expect(all.first.status, equals('alive'));
    });

    test('3件保存すると createdAt 降順（新しい順）で返る', () async {
      final items = [
        (
          id: 'repo-a',
          created: DateTime(2026, 6, 9, 8, 0, 0),
        ),
        (
          id: 'repo-b',
          created: DateTime(2026, 6, 9, 12, 0, 0),
        ),
        (
          id: 'repo-c',
          created: DateTime(2026, 6, 9, 10, 0, 0),
        ),
      ];

      for (final item in items) {
        await repository.save(
          id: item.id,
          date: '2026-06-09',
          questionId: 'q-x',
          questionText: 'テスト質問',
          answerText: 'テスト回答',
          status: 'alive',
          createdAt: item.created,
        );
      }

      final all = await repository.getAll();
      expect(all.length, equals(3));
      // createdAt 降順 → 12:00 > 10:00 > 08:00
      expect(all[0].id, equals('repo-b'));
      expect(all[1].id, equals('repo-c'));
      expect(all[2].id, equals('repo-a'));
    });

    test('保存→再取得で seed 等メタが同値', () async {
      await repository.save(
        id: 'repo-meta',
        date: '2026-06-09',
        questionId: 'q-meta',
        questionText: 'メタテスト',
        answerText: 'メタ回答',
        status: 'alive',
        createdAt: DateTime(2026, 6, 9, 9, 0, 0),
      );

      final all = await repository.getAll();
      final row = all.first;
      expect(row.answerText, equals('メタ回答'));
      expect(row.questionId, equals('q-meta'));
      expect(row.questionText, equals('メタテスト'));
      expect(row.date, equals('2026-06-09'));
    });
  });

  // ─────────────────────────────────────────────
  // 2. findById
  // ─────────────────────────────────────────────
  group('SpecimenRepository: findById', () {
    test('存在する id で検索すると該当行を返す', () async {
      await repository.save(
        id: 'repo-find-me',
        date: '2026-06-09',
        questionId: 'q-f',
        questionText: '探す問い',
        answerText: '見つかる回答',
        status: 'alive',
        createdAt: DateTime(2026, 6, 9),
      );

      final found = await repository.findById('repo-find-me');
      expect(found, isNotNull);
      expect(found!.id, equals('repo-find-me'));
    });

    test('存在しない id で検索すると null を返す', () async {
      final found = await repository.findById('nonexistent-id');
      expect(found, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // 2.5 画像参照カラム（ADR-0011・schemaVersion 3）
  // ─────────────────────────────────────────────
  group('SpecimenRepository: image_id / local_path', () {
    test('imageId/localPath を保存して取得できる', () async {
      await repository.save(
        id: 'repo-img',
        date: '2026-06-13',
        questionId: 'q-i',
        questionText: '画像テスト',
        answerText: '回答',
        status: 'alive',
        createdAt: DateTime(2026, 6, 13),
        imageId: 'uuid-123',
        localPath: '/docs/specimens/uuid-123.webp',
      );
      final row = await repository.findById('repo-img');
      expect(row!.imageId, 'uuid-123');
      expect(row.localPath, '/docs/specimens/uuid-123.webp');
    });

    test('未指定（deferred）は image_id / local_path が null', () async {
      await repository.save(
        id: 'repo-deferred',
        date: '2026-06-13',
        questionId: 'q-d',
        questionText: '未取得テスト',
        answerText: '回答',
        status: 'alive',
        createdAt: DateTime(2026, 6, 13),
      );
      final row = await repository.findById('repo-deferred');
      expect(row!.imageId, isNull);
      expect(row.localPath, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // 2.6 deferred 再取得（findDeferred / setImage・ADR-0011 決定6）
  // ─────────────────────────────────────────────
  group('SpecimenRepository: findDeferred / setImage', () {
    test('local_path が null の行だけ findDeferred が返す', () async {
      await repository.save(
        id: 'has-image',
        date: '2026-06-13',
        questionId: 'q',
        questionText: 't',
        answerText: 'a',
        status: 'alive',
        createdAt: DateTime(2026, 6, 13, 9),
        imageId: 'uuid-a',
        localPath: '/p/a.webp',
      );
      await repository.save(
        id: 'deferred-1',
        date: '2026-06-13',
        questionId: 'q',
        questionText: 't',
        answerText: 'a',
        status: 'alive',
        createdAt: DateTime(2026, 6, 13, 10),
      );

      final deferred = await repository.findDeferred();
      expect(deferred.map((s) => s.id), ['deferred-1']);
    });

    test('setImage で image_id/local_path を確定でき findDeferred から外れる', () async {
      await repository.save(
        id: 'deferred-2',
        date: '2026-06-13',
        questionId: 'q',
        questionText: 't',
        answerText: 'a',
        status: 'alive',
        createdAt: DateTime(2026, 6, 13),
      );

      await repository.setImage('deferred-2', 'uuid-x', '/p/x.webp');

      final row = await repository.findById('deferred-2');
      expect(row!.imageId, 'uuid-x');
      expect(row.localPath, '/p/x.webp');
      expect(await repository.findDeferred(), isEmpty);
    });
  });

  // ─────────────────────────────────────────────
  // 3. seal（一方向・ADR-0010 決定3）
  // ─────────────────────────────────────────────
  group('SpecimenRepository: seal（一方向）', () {
    setUp(() async {
      await repository.save(
        id: 'repo-seal',
        date: '2026-06-09',
        questionId: 'q-s',
        questionText: '封印テスト',
        answerText: '封印回答',
        status: 'alive',
        createdAt: DateTime(2026, 6, 9),
      );
    });

    test('alive → sealed に封印できる（true を返す）', () async {
      final result = await repository.seal('repo-seal');
      expect(result, isTrue);

      final row = await repository.findById('repo-seal');
      expect(row!.status, equals('sealed'));
    });

    test('既に sealed でも冪等に true を返し sealed のまま', () async {
      await repository.seal('repo-seal');
      final result = await repository.seal('repo-seal');
      expect(result, isTrue);

      final row = await repository.findById('repo-seal');
      expect(row!.status, equals('sealed'));
    });

    test('seal は alive に戻す手段を持たない（sealed は終端）', () async {
      await repository.seal('repo-seal');
      await repository.seal('repo-seal');

      final row = await repository.findById('repo-seal');
      expect(row!.status, equals('sealed'));
    });

    test('存在しない id の seal は false を返す（silent no-op）', () async {
      final result = await repository.seal('nonexistent-id');
      expect(result, isFalse);
    });
  });

  // ─────────────────────────────────────────────
  // 4. upsert: 同一 id の再 save は後勝ちで上書き
  // ─────────────────────────────────────────────
  group('SpecimenRepository: upsert（同一 id の再 save）', () {
    test('同一 id を 2 回 save すると最新値（後勝ち）に上書きされる', () async {
      await repository.save(
        id: 'repo-upsert',
        date: '2026-06-09',
        questionId: 'q-u',
        questionText: '最初の質問',
        answerText: '最初の回答',
        status: 'alive',
        createdAt: DateTime(2026, 6, 9, 10, 0, 0),
      );

      // 同一 id で内容を変えて再 save（upsert）
      await repository.save(
        id: 'repo-upsert',
        date: '2026-06-09',
        questionId: 'q-u',
        questionText: '更新後の質問',
        answerText: '更新後の回答',
        status: 'sealed',
        createdAt: DateTime(2026, 6, 9, 10, 0, 0),
      );

      final all = await repository.getAll();
      expect(all.length, equals(1), reason: '同一 id は1件のまま');
      final row = all.first;
      expect(row.answerText, equals('更新後の回答'), reason: '後勝ちで上書き');
      expect(row.status, equals('sealed'), reason: 'status も後勝ち');
    });
  });

  // ─────────────────────────────────────────────
  // 6. 保存実体は最小メタ＋画像参照のみ（リポジトリ経路での確認・ADR-0011）
  // ─────────────────────────────────────────────
  group('スキーマ検証: 保存実体は最小メタ＋画像参照', () {
    test('getAll で返る行はメタ＋画像参照のみ（ベクター生成カラムを持たない）', () async {
      await repository.save(
        id: 'repo-schema',
        date: '2026-06-09',
        questionId: 'q-s',
        questionText: 'スキーマ確認',
        answerText: 'スキーマ回答',
        status: 'alive',
        createdAt: DateTime(2026, 6, 9),
      );

      final all = await repository.getAll();
      expect(all.length, equals(1));
      final row = all.first;
      expect(row.answerText, equals('スキーマ回答'));
      // 未取得（deferred）なので画像参照は null。
      expect(row.imageId, isNull);
      expect(row.localPath, isNull);

      // Specimen（Drift生成クラス）に seed / generatorVersion / SpecimenParams 由来
      // フィールドがないことはコンパイル時に担保される（ADR-0011 で廃止）。
    });
  });
}
