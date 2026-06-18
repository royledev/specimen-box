// ExportService / ImportService の往復統合テスト（インメモリ DB + FakeImageStore）。
//
// テスト方針:
//   - 「数件保存 → export → 別 DB / 別 ImageStore に import」でメタ・画像・生年月日を検証。
//   - IO / ネイティブプラグイン不要（NativeDatabase.memory + FakeImageStore）。
//   - 既存のテスト作法（AppDatabase.forTesting / SettingsRepository）を踏襲。
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/data/db/app_database.dart';
import 'package:specimen_box/data/repositories/settings_repository.dart';
import 'package:specimen_box/data/repositories/specimen_repository.dart';
import 'package:specimen_box/data/services/export_service.dart';
import 'package:specimen_box/data/services/import_service.dart';
import 'package:specimen_box/platform/image_store/fake_image_store.dart';

void main() {
  // ──────────────────────────────────────────────
  // ヘルパ: DB / リポジトリ一式を生成
  // ──────────────────────────────────────────────
  ({
    AppDatabase db,
    SpecimenRepository specimenRepo,
    SettingsRepository settingsRepo,
  }) makeRepos() {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    return (
      db: db,
      specimenRepo: SpecimenRepository(db.specimensDao),
      settingsRepo: SettingsRepository(db.settingsDao),
    );
  }

  // ──────────────────────────────────────────────
  // 1. 基本 roundtrip（標本メタ・画像・生年月日）
  // ──────────────────────────────────────────────
  group('ExportService / ImportService: 基本 roundtrip', () {
    test('標本メタ・画像バイト・生年月日が別 DB に復元される', () async {
      // ─ エクスポート元セットアップ ─
      final src = makeRepos();
      final srcStore = FakeImageStore();

      await src.specimenRepo.save(
        id: 'spec-001',
        date: '2026-06-13',
        questionId: 'q-001',
        questionText: '問い１',
        answerText: '回答１',
        status: 'alive',
        createdAt: DateTime.utc(2026, 6, 13, 10, 0, 0),
        imageId: 'img-001',
        localPath: null, // まず localPath なしで保存
        imageRarity: 4, // ADR-0017: 画像レア度も往復で保持されることを検証
      );
      // 画像を FakeImageStore に保存し localPath を DB に設定。
      // setImage は rarity を渡さない → 既存の image_rarity(=4) が消えないことも兼ねて検証（M1）。
      final localPath = await srcStore.save('img-001', [1, 2, 3], 'webp');
      await src.specimenRepo.setImage('spec-001', 'img-001', localPath);

      await src.settingsRepo.setBirthDate(DateTime(1990, 4, 1));

      // ─ エクスポート ─
      final exportSvc = ExportService(
        specimenRepo: src.specimenRepo,
        imageStore: srcStore,
        settingsRepo: src.settingsRepo,
      );
      final zipBytes = await exportSvc.export();

      await src.db.close();

      // ─ インポート先セットアップ ─
      final dst = makeRepos();
      final dstStore = FakeImageStore();

      final importSvc = ImportService(
        specimenRepo: dst.specimenRepo,
        imageStore: dstStore,
        settingsRepo: dst.settingsRepo,
      );
      final result = await importSvc.import(zipBytes);

      // ─ 検証 ─
      expect(result.added, equals(1));
      expect(result.skipped, equals(0));
      expect(result.imagesRestored, equals(1));
      expect(result.birthDateRestored, isTrue);

      final rows = await dst.specimenRepo.getAll();
      expect(rows.length, equals(1));
      final row = rows.first;
      expect(row.id, equals('spec-001'));
      expect(row.answerText, equals('回答１'));
      expect(row.questionId, equals('q-001'));
      expect(row.questionText, equals('問い１'));
      expect(row.date, equals('2026-06-13'));
      expect(row.status, equals('alive'));
      expect(row.imageId, equals('img-001'));
      expect(row.localPath, isNotNull);
      // ADR-0017: 画像レア度が別 DB に往復復元される。
      expect(row.imageRarity, equals(4));

      // 画像バイトが dstStore に保存されているか
      final restoredBytes = await dstStore.read(row.localPath!);
      expect(restoredBytes, equals([1, 2, 3]));

      // 生年月日
      final bd = await dst.settingsRepo.getBirthDate();
      expect(bd, equals(DateTime(1990, 4, 1)));

      await dst.db.close();
    });
  });

  // ──────────────────────────────────────────────
  // 2. id 衝突スキップ（冪等）
  // ──────────────────────────────────────────────
  group('id 衝突スキップ', () {
    test('既存 id はスキップされ added=0・skipped=1', () async {
      final src = makeRepos();
      final srcStore = FakeImageStore();

      await src.specimenRepo.save(
        id: 'dup-001',
        date: '2026-06-01',
        questionId: 'q-dup',
        questionText: '重複テスト',
        answerText: '重複回答',
        status: 'alive',
        createdAt: DateTime.utc(2026, 6, 1),
      );

      final exportSvc = ExportService(
        specimenRepo: src.specimenRepo,
        imageStore: srcStore,
        settingsRepo: src.settingsRepo,
      );
      final zipBytes = await exportSvc.export();
      await src.db.close();

      // インポート先に既に同じ id を保存しておく。
      final dst = makeRepos();
      final dstStore = FakeImageStore();

      await dst.specimenRepo.save(
        id: 'dup-001',
        date: '2026-06-01',
        questionId: 'q-dup',
        questionText: '既存',
        answerText: '既存回答',
        status: 'alive',
        createdAt: DateTime.utc(2026, 6, 1),
      );

      final importSvc = ImportService(
        specimenRepo: dst.specimenRepo,
        imageStore: dstStore,
        settingsRepo: dst.settingsRepo,
      );
      final result = await importSvc.import(zipBytes);

      expect(result.added, equals(0));
      expect(result.skipped, equals(1));

      // 既存の answerText が上書きされていないか確認。
      final rows = await dst.specimenRepo.getAll();
      expect(rows.first.answerText, equals('既存回答'));

      await dst.db.close();
    });

    test('二重 import は2回目が全スキップ', () async {
      final src = makeRepos();
      final srcStore = FakeImageStore();

      await src.specimenRepo.save(
        id: 'spec-x',
        date: '2026-06-13',
        questionId: 'q-x',
        questionText: '問い',
        answerText: '回答',
        status: 'alive',
        createdAt: DateTime.utc(2026, 6, 13),
      );

      final exportSvc = ExportService(
        specimenRepo: src.specimenRepo,
        imageStore: srcStore,
        settingsRepo: src.settingsRepo,
      );
      final zipBytes = await exportSvc.export();
      await src.db.close();

      final dst = makeRepos();
      final dstStore = FakeImageStore();
      final importSvc = ImportService(
        specimenRepo: dst.specimenRepo,
        imageStore: dstStore,
        settingsRepo: dst.settingsRepo,
      );

      final r1 = await importSvc.import(zipBytes);
      final r2 = await importSvc.import(zipBytes);

      expect(r1.added, equals(1));
      expect(r2.added, equals(0));
      expect(r2.skipped, equals(1));

      await dst.db.close();
    });
  });

  // ──────────────────────────────────────────────
  // 3. 画像なし標本（deferred）
  // ──────────────────────────────────────────────
  group('deferred 標本', () {
    test('imageId はあるが bytes なし → localPath=null でインポートされる', () async {
      final src = makeRepos();
      final srcStore = FakeImageStore(); // バイト保存なし

      // imageId はあるが localPath=null（deferred）で保存。
      await src.specimenRepo.save(
        id: 'deferred-001',
        date: '2026-06-13',
        questionId: 'q-d',
        questionText: 'deferred 問い',
        answerText: 'deferred 回答',
        status: 'alive',
        createdAt: DateTime.utc(2026, 6, 13),
        imageId: 'img-deferred',
        localPath: null, // 画像バイト未取得
      );

      final exportSvc = ExportService(
        specimenRepo: src.specimenRepo,
        imageStore: srcStore,
        settingsRepo: src.settingsRepo,
      );
      final zipBytes = await exportSvc.export();
      await src.db.close();

      final dst = makeRepos();
      final dstStore = FakeImageStore();
      final importSvc = ImportService(
        specimenRepo: dst.specimenRepo,
        imageStore: dstStore,
        settingsRepo: dst.settingsRepo,
      );
      final result = await importSvc.import(zipBytes);

      expect(result.added, equals(1));
      expect(result.imagesRestored, equals(0)); // 画像バイトなし

      final rows = await dst.specimenRepo.getAll();
      expect(rows.first.imageId, equals('img-deferred'));
      expect(rows.first.localPath, isNull); // deferred のまま

      await dst.db.close();
    });
  });

  // ──────────────────────────────────────────────
  // 4. 生年月日補完: 既存設定がある場合は上書きしない
  // ──────────────────────────────────────────────
  group('生年月日補完', () {
    test('既存設定があれば manifest 値で上書きしない', () async {
      final src = makeRepos();
      final srcStore = FakeImageStore();
      await src.settingsRepo.setBirthDate(DateTime(1980, 1, 1));

      final exportSvc = ExportService(
        specimenRepo: src.specimenRepo,
        imageStore: srcStore,
        settingsRepo: src.settingsRepo,
      );
      final zipBytes = await exportSvc.export();
      await src.db.close();

      final dst = makeRepos();
      final dstStore = FakeImageStore();
      // インポート先に別の生年月日を設定済み
      await dst.settingsRepo.setBirthDate(DateTime(2000, 12, 31));

      final importSvc = ImportService(
        specimenRepo: dst.specimenRepo,
        imageStore: dstStore,
        settingsRepo: dst.settingsRepo,
      );
      final result = await importSvc.import(zipBytes);

      expect(result.birthDateRestored, isFalse);
      // 既存設定が維持されているか
      final bd = await dst.settingsRepo.getBirthDate();
      expect(bd, equals(DateTime(2000, 12, 31)));

      await dst.db.close();
    });

    test('未設定のときのみ補完される', () async {
      final src = makeRepos();
      final srcStore = FakeImageStore();
      await src.settingsRepo.setBirthDate(DateTime(1990, 6, 15));

      final exportSvc = ExportService(
        specimenRepo: src.specimenRepo,
        imageStore: srcStore,
        settingsRepo: src.settingsRepo,
      );
      final zipBytes = await exportSvc.export();
      await src.db.close();

      final dst = makeRepos();
      // 生年月日未設定
      final importSvc = ImportService(
        specimenRepo: dst.specimenRepo,
        imageStore: FakeImageStore(),
        settingsRepo: dst.settingsRepo,
      );
      final result = await importSvc.import(zipBytes);

      expect(result.birthDateRestored, isTrue);
      final bd = await dst.settingsRepo.getBirthDate();
      expect(bd, equals(DateTime(1990, 6, 15)));

      await dst.db.close();
    });
  });

  // ──────────────────────────────────────────────
  // 5. 複数標本の混合（画像あり・なし・既存）
  // ──────────────────────────────────────────────
  group('複数標本の混合', () {
    test('画像あり・なし・既存 id 混合でそれぞれ正しく処理される', () async {
      final src = makeRepos();
      final srcStore = FakeImageStore();

      // 標本A: 画像あり
      await src.specimenRepo.save(
        id: 'mix-a',
        date: '2026-06-11',
        questionId: 'q-a',
        questionText: '問いA',
        answerText: '回答A',
        status: 'alive',
        createdAt: DateTime.utc(2026, 6, 11),
        imageId: 'img-a',
        localPath: null,
      );
      final pathA = await srcStore.save('img-a', [10, 20], 'webp');
      await src.specimenRepo.setImage('mix-a', 'img-a', pathA);

      // 標本B: 画像なし（imageId=null）
      await src.specimenRepo.save(
        id: 'mix-b',
        date: '2026-06-12',
        questionId: 'q-b',
        questionText: '問いB',
        answerText: '回答B',
        status: 'alive',
        createdAt: DateTime.utc(2026, 6, 12),
      );

      final exportSvc = ExportService(
        specimenRepo: src.specimenRepo,
        imageStore: srcStore,
        settingsRepo: src.settingsRepo,
      );
      final zipBytes = await exportSvc.export();
      await src.db.close();

      // インポート先: 標本B は既存
      final dst = makeRepos();
      final dstStore = FakeImageStore();

      await dst.specimenRepo.save(
        id: 'mix-b',
        date: '2026-06-12',
        questionId: 'q-b',
        questionText: '既存問いB',
        answerText: '既存回答B',
        status: 'alive',
        createdAt: DateTime.utc(2026, 6, 12),
      );

      final importSvc = ImportService(
        specimenRepo: dst.specimenRepo,
        imageStore: dstStore,
        settingsRepo: dst.settingsRepo,
      );
      final result = await importSvc.import(zipBytes);

      // mix-a が追加、mix-b がスキップ
      expect(result.added, equals(1));
      expect(result.skipped, equals(1));
      expect(result.imagesRestored, equals(1));

      // mix-a の画像が復元されているか
      final rows = await dst.specimenRepo.getAll();
      final rowA = rows.firstWhere((r) => r.id == 'mix-a');
      expect(rowA.localPath, isNotNull);
      final bytes = await dstStore.read(rowA.localPath!);
      expect(bytes, equals([10, 20]));

      // mix-b の既存データが保持されているか
      final rowB = rows.firstWhere((r) => r.id == 'mix-b');
      expect(rowB.answerText, equals('既存回答B'));

      await dst.db.close();
    });
  });
}
