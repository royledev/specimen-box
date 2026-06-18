// export_archive.dart の単体テスト（純Dart・IO/プラグイン非依存）。
//
// 検証内容:
//   1. build→parse 往復一致（標本メタ・画像バイト・生年月日）。
//   2. 画像なし標本の往復。
//   3. 壊れた zip バイト: ExportManifestException。
//   4. manifest.json 欠如: ExportManifestException。
//   5. version 不一致: ExportVersionException。
//   6. 空エクスポート（標本ゼロ・画像なし・生年月日なし）の往復。
//   7. 欠けた画像（manifest に imageFile あり・実体は zip 未収録）→ 当該標本を deferred で返す。
library;

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/domain/export/export_archive.dart';

void main() {
  // ──────────────────────────────────────────────
  // テスト用ヘルパ
  // ──────────────────────────────────────────────

  ExportSpecimen makeSpecimen({
    String id = 'spec-001',
    String imageId = 'img-001',
    String? imageFile = 'images/img-001.webp',
  }) =>
      ExportSpecimen(
        id: id,
        answer: 'テスト回答',
        questionId: 'q-001',
        questionText: '今日の問い？',
        date: '2026-06-13',
        status: 'alive',
        createdAt: DateTime.utc(2026, 6, 13, 10, 0, 0),
        imageId: imageId,
        imageFile: imageFile,
      );

  // ──────────────────────────────────────────────
  // 1. 往復一致（標本メタ・画像・生年月日）
  // ──────────────────────────────────────────────
  group('build→parse 往復一致', () {
    test('標本メタ・画像バイト・生年月日が一致する', () {
      final imageBytes = [1, 2, 3, 4, 5];
      final birthDate = DateTime(1990, 4, 1);

      final data = ExportData(
        specimens: [makeSpecimen()],
        images: {'img-001': imageBytes},
        birthDate: birthDate,
      );

      final zipBytes = buildExportArchive(data);
      final restored = parseExportArchive(zipBytes);

      // 生年月日
      expect(restored.birthDate, equals(birthDate));

      // 標本メタ
      expect(restored.specimens.length, equals(1));
      final s = restored.specimens.first;
      expect(s.id, equals('spec-001'));
      expect(s.answer, equals('テスト回答'));
      expect(s.questionId, equals('q-001'));
      expect(s.questionText, equals('今日の問い？'));
      expect(s.date, equals('2026-06-13'));
      expect(s.status, equals('alive'));
      expect(s.createdAt.toUtc(), equals(DateTime.utc(2026, 6, 13, 10, 0, 0)));
      expect(s.imageId, equals('img-001'));
      expect(s.imageFile, isNotNull);

      // 画像バイト
      expect(restored.images.containsKey('img-001'), isTrue);
      expect(restored.images['img-001'], equals(imageBytes));
    });

    test('sealed 状態の標本が保持される', () {
      final data = ExportData(
        specimens: [
          ExportSpecimen(
            id: 'sealed-001',
            answer: '封印回答',
            questionId: 'q-002',
            questionText: '問い？',
            date: '2026-01-01',
            status: 'sealed',
            createdAt: DateTime.utc(2026, 1, 1),
            imageId: null,
          ),
        ],
        images: {},
        birthDate: null,
      );

      final restored = parseExportArchive(buildExportArchive(data));
      expect(restored.specimens.first.status, equals('sealed'));
    });

    test('複数標本を往復できる', () {
      final data = ExportData(
        specimens: [
          makeSpecimen(id: 'a', imageId: 'img-a', imageFile: 'images/img-a.webp'),
          makeSpecimen(id: 'b', imageId: 'img-b', imageFile: 'images/img-b.webp'),
        ],
        images: {
          'img-a': [10, 11],
          'img-b': [20, 21],
        },
        birthDate: DateTime(2000, 1, 1),
      );

      final restored = parseExportArchive(buildExportArchive(data));
      expect(restored.specimens.length, equals(2));
      expect(restored.images['img-a'], equals([10, 11]));
      expect(restored.images['img-b'], equals([20, 21]));
    });

    test('imageRarity（画像レア度）が往復で保持される（ADR-0017）', () {
      final data = ExportData(
        specimens: [
          ExportSpecimen(
            id: 'r5',
            answer: '回答',
            questionId: 'q',
            questionText: '問い',
            date: '2026-06-13',
            status: 'alive',
            createdAt: DateTime.utc(2026, 6, 13),
            imageId: 'img-r5',
            imageFile: 'images/img-r5.webp',
            imageRarity: 5,
          ),
          ExportSpecimen(
            id: 'rnull',
            answer: '回答',
            questionId: 'q',
            questionText: '問い',
            date: '2026-06-13',
            status: 'alive',
            createdAt: DateTime.utc(2026, 6, 13),
            imageRarity: null,
          ),
        ],
        images: {
          'img-r5': [9],
        },
        birthDate: null,
      );
      final restored = parseExportArchive(buildExportArchive(data));
      final byId = {for (final s in restored.specimens) s.id: s};
      expect(byId['r5']!.imageRarity, equals(5));
      expect(byId['rnull']!.imageRarity, isNull);
    });

    test('name（標本の表示名）が往復で保持される', () {
      final data = ExportData(
        specimens: [
          ExportSpecimen(
            id: 'named',
            answer: '回答',
            questionId: 'q',
            questionText: '問い',
            date: '2026-06-13',
            status: 'alive',
            createdAt: DateTime.utc(2026, 6, 13),
            imageId: 'img-named',
            imageFile: 'images/img-named.webp',
            name: '怒った扇風機',
          ),
          ExportSpecimen(
            id: 'nameless',
            answer: '回答',
            questionId: 'q',
            questionText: '問い',
            date: '2026-06-13',
            status: 'alive',
            createdAt: DateTime.utc(2026, 6, 13),
            name: null,
          ),
        ],
        images: {
          'img-named': [9],
        },
        birthDate: null,
      );
      final restored = parseExportArchive(buildExportArchive(data));
      final byId = {for (final s in restored.specimens) s.id: s};
      expect(byId['named']!.name, equals('怒った扇風機'));
      expect(byId['nameless']!.name, isNull);
    });

    test('manifest は version 2 で書き出される（ADR-0017）', () {
      final zip = buildExportArchive(
        const ExportData(specimens: [], images: {}, birthDate: null),
      );
      final archive = ZipDecoder().decodeBytes(zip);
      final manifest = jsonDecode(
        utf8.decode(archive.findFile('manifest.json')!.content),
      ) as Map<String, Object?>;
      expect(manifest['version'], equals(2));
    });
  });

  // ──────────────────────────────────────────────
  // 2. 画像なし標本
  // ──────────────────────────────────────────────
  group('画像なし標本', () {
    test('imageId=null・images 空の標本を往復できる', () {
      final data = ExportData(
        specimens: [
          ExportSpecimen(
            id: 'no-img',
            answer: '回答',
            questionId: 'q-x',
            questionText: '問い',
            date: '2026-06-01',
            status: 'alive',
            createdAt: DateTime.utc(2026, 6, 1),
          ),
        ],
        images: {},
        birthDate: null,
      );

      final restored = parseExportArchive(buildExportArchive(data));
      expect(restored.specimens.length, equals(1));
      expect(restored.specimens.first.imageId, isNull);
      expect(restored.images, isEmpty);
    });
  });

  // ──────────────────────────────────────────────
  // 3. 壊れた zip バイト
  // ──────────────────────────────────────────────
  group('壊れた zip', () {
    test('ランダムバイトは ExportManifestException', () {
      expect(
        () => parseExportArchive([0x00, 0x01, 0x02, 0xFF]),
        throwsA(isA<ExportManifestException>()),
      );
    });

    test('空バイト列は ExportManifestException', () {
      expect(
        () => parseExportArchive([]),
        throwsA(isA<ExportManifestException>()),
      );
    });
  });

  // ──────────────────────────────────────────────
  // 4. manifest.json 欠如
  // ──────────────────────────────────────────────
  group('manifest.json 欠如', () {
    test('manifest なし zip は ExportManifestException', () {
      // manifest.json を含まない zip を作る。
      final archive = Archive();
      archive.addFile(
        ArchiveFile.noCompress('images/dummy.txt', 3, [1, 2, 3]),
      );
      final zipBytes = ZipEncoder().encode(archive);

      expect(
        () => parseExportArchive(zipBytes),
        throwsA(isA<ExportManifestException>()),
      );
    });

    test('manifest が不正な JSON は ExportManifestException', () {
      final archive = Archive();
      final bad = 'not json at all'.codeUnits;
      archive.addFile(ArchiveFile.noCompress('manifest.json', bad.length, bad));
      final zipBytes = ZipEncoder().encode(archive);

      expect(
        () => parseExportArchive(zipBytes),
        throwsA(isA<ExportManifestException>()),
      );
    });
  });

  // ──────────────────────────────────────────────
  // 5. version 不一致
  // ──────────────────────────────────────────────
  group('version 不一致', () {
    test('version=99 は ExportVersionException', () {
      final manifest = '{"version":99,"app":"specimen-box",'
          '"settings":{"birthDate":null},"specimens":[]}';
      final archive = Archive();
      final bytes = manifest.codeUnits;
      archive.addFile(ArchiveFile.noCompress('manifest.json', bytes.length, bytes));
      final zipBytes = ZipEncoder().encode(archive);

      expect(
        () => parseExportArchive(zipBytes),
        throwsA(
          isA<ExportVersionException>().having((e) => e.found, 'found', 99),
        ),
      );
    });

    test('version=1 は後方互換で受理され imageRarity は null（ADR-0017）', () {
      final manifest = '{"version":1,"app":"specimen-box",'
          '"settings":{"birthDate":null},"specimens":[{'
          '"id":"old","answer":"a","questionId":"q","questionText":"t",'
          '"date":"2026-06-13","status":"alive",'
          '"createdAt":"2026-06-13T00:00:00.000Z","imageId":null}]}';
      final archive = Archive();
      final bytes = utf8.encode(manifest);
      archive.addFile(
        ArchiveFile.noCompress('manifest.json', bytes.length, bytes),
      );
      final zipBytes = ZipEncoder().encode(archive);

      final restored = parseExportArchive(zipBytes);
      expect(restored.specimens.length, equals(1));
      expect(restored.specimens.first.imageRarity, isNull);
    });
  });

  // ──────────────────────────────────────────────
  // 6. 空エクスポート
  // ──────────────────────────────────────────────
  group('空エクスポート', () {
    test('標本ゼロ・画像なし・生年月日なしの往復', () {
      const data = ExportData(specimens: [], images: {}, birthDate: null);
      final restored = parseExportArchive(buildExportArchive(data));

      expect(restored.specimens, isEmpty);
      expect(restored.images, isEmpty);
      expect(restored.birthDate, isNull);
    });
  });

  // ──────────────────────────────────────────────
  // 7. 欠けた画像（manifest に imageFile あるが zip 未収録）
  // ──────────────────────────────────────────────
  group('欠けた画像', () {
    test('manifest に imageFile があっても実体なし → images map に含まれない（deferred）', () {
      // 正常な zip を作ってから images エントリを除いた zip を手動構築する。
      // JSON 内は ASCII のみ（utf8.encode/codeUnits が同一になるよう）。
      final manifestJson = '{'
          '"version":1,'
          '"exportedAt":"2026-06-13T00:00:00.000Z",'
          '"app":"specimen-box",'
          '"settings":{"birthDate":null},'
          '"specimens":[{'
          '"id":"spec-001",'
          '"answer":"answer-text",'
          '"questionId":"q-1",'
          '"questionText":"question-text",'
          '"date":"2026-06-13",'
          '"status":"alive",'
          '"createdAt":"2026-06-13T00:00:00.000Z",'
          '"imageId":"img-missing",'
          '"imageFile":"images/img-missing.webp"'
          '}]}';

      final archive = Archive();
      final mBytes = utf8.encode(manifestJson);
      archive.addFile(
        ArchiveFile.noCompress('manifest.json', mBytes.length, mBytes),
      );
      // images/img-missing.webp は追加しない。
      final zipBytes = ZipEncoder().encode(archive);

      final restored = parseExportArchive(zipBytes);
      expect(restored.specimens.length, equals(1));
      expect(restored.specimens.first.imageId, equals('img-missing'));
      // 画像バイトは map に含まれない（deferred）。
      expect(restored.images.containsKey('img-missing'), isFalse);
    });
  });
}
