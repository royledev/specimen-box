// 純 Dart エクスポート/インポートコア（IO/プラグイン非依存）。
//
// 依存: `archive`（zip・純Dart）/ `dart:convert`（JSON）のみ。
//
// buildExportArchive : ExportData → zip バイト（manifest.json + images/<imageId>.<ext>）。
// parseExportArchive : zip バイト → ExportData（壊れた入力に寛容）。
//
// ADR-0014 の形式定義:
//   manifest.json: { version, exportedAt, app, settings.birthDate, specimens[...] }
//   images/<imageId>.<ext>: 画像バイト（バイトがある標本のみ）。
library;

import 'dart:convert';

import 'package:archive/archive.dart';

// ──────────────────────────────────────────────
// 入力/出力 DTO
// ──────────────────────────────────────────────

/// エクスポートする標本1件の DTO。
class ExportSpecimen {
  const ExportSpecimen({
    required this.id,
    required this.answer,
    required this.questionId,
    required this.questionText,
    required this.date,
    required this.status,
    required this.createdAt,
    this.imageId,
    this.imageFile,
    this.imageRarity,
    this.name,
  });

  /// 標本 ID。
  final String id;

  /// 回答本文。
  final String answer;

  /// 問い ID。
  final String questionId;

  /// 問い文（詳細画面表示用）。
  final String questionText;

  /// 回答日（YYYY-MM-DD）。
  final String date;

  /// 'alive' または 'sealed'。
  final String status;

  /// 生成日時（ISO8601）。
  final DateTime createdAt;

  /// サーバー画像 ID（未取得は null）。
  final String? imageId;

  /// zip 内の画像ファイルパス（例 `images/uuid.webp`）。
  /// 対応バイトが images map に存在するときのみ設定される。
  final String? imageFile;

  /// 画像レア度（1〜5・ADR-0017）。未取得・旧データ・欠損時は null。
  final int? imageRarity;

  /// 標本の表示名（サーバー配信）。未取得・旧データ・欠損時は null。
  final String? name;
}

/// エクスポート/インポート全体の DTO。
class ExportData {
  const ExportData({
    required this.specimens,
    required this.images,
    this.birthDate,
  });

  /// 標本リスト。
  final List<ExportSpecimen> specimens;

  /// 画像バイトマップ（imageId → バイト列）。
  final Map<String, List<int>> images;

  /// 生年月日（null = 未設定）。
  final DateTime? birthDate;
}

// ──────────────────────────────────────────────
// 例外
// ──────────────────────────────────────────────

/// manifest.json が存在しない・不正な JSON のとき投げる。
class ExportManifestException implements Exception {
  const ExportManifestException(this.message);

  final String message;

  @override
  String toString() => 'ExportManifestException: $message';
}

/// manifest の `version` が未対応のとき投げる。
class ExportVersionException implements Exception {
  const ExportVersionException({required this.found, required this.supported});

  final int found;
  final int supported;

  @override
  String toString() =>
      'ExportVersionException: version $found は未対応（対応: $supported）';
}

// ──────────────────────────────────────────────
// 内部ヘルパ
// ──────────────────────────────────────────────

/// アーカイブ内のファイルパスから imageId を推定する（`images/` プレフィックス除去・拡張子除去）。
String _imageIdFromPath(String path) {
  // `images/<imageId>.<ext>` → `<imageId>`
  final name = path.split('/').last;
  final dotIdx = name.lastIndexOf('.');
  return dotIdx >= 0 ? name.substring(0, dotIdx) : name;
}

/// imageId が安全な形式（英数字・ハイフンのみ、空でない）かを判定する。
///
/// imageId は最終的にファイル名へ使われるため、`../`・スラッシュ・絶対パス等を
/// 含む値を弾くことでパストラバーサル（CWE-22）・Zip Slip の入力源を断つ。
/// 正規の imageId は UUID（英数字・ハイフン）想定。
bool _isSafeImageId(String id) =>
    id.isNotEmpty && RegExp(r'^[a-zA-Z0-9\-]+$').hasMatch(id);

// ──────────────────────────────────────────────
// Public API
// ──────────────────────────────────────────────

/// [data] を zip バイトとして返す。
///
/// - manifest.json: ADR-0014 の形式（version=2・ADR-0017 で imageRarity 追加）。
/// - `images/<imageId>.<ext>`: [data.images] に対応バイトがある標本のみ。
List<int> buildExportArchive(ExportData data) {
  final archive = Archive();

  // ── 各標本の imageFile パスを決定 ──
  // images map にバイトがある標本のみ imageFile を設定する。
  final specimenJsonList = <Map<String, Object?>>[];
  for (final s in data.specimens) {
    String? imageFilePath;
    if (s.imageId != null && data.images.containsKey(s.imageId)) {
      // ExportSpecimen.imageFile が設定されていればそちらを優先する。
      // 未設定の場合は imageId のみのパス（拡張子なし）を使う。
      imageFilePath = s.imageFile ?? 'images/${s.imageId}';
    }

    specimenJsonList.add({
      'id': s.id,
      'answer': s.answer,
      'questionId': s.questionId,
      'questionText': s.questionText,
      'date': s.date,
      'status': s.status,
      'createdAt': s.createdAt.toUtc().toIso8601String(),
      'imageId': s.imageId,
      'imageFile': imageFilePath,
      'imageRarity': s.imageRarity,
      'name': s.name,
    });

    // zip に画像を追加
    if (s.imageId != null && data.images.containsKey(s.imageId)) {
      final bytes = data.images[s.imageId]!;
      final zipPath = imageFilePath!;
      final file = ArchiveFile.noCompress(zipPath, bytes.length, bytes);
      archive.addFile(file);
    }
  }

  // ── manifest.json 組み立て ──
  final manifest = <String, Object?>{
    'version': 2,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'app': 'specimen-box',
    'settings': {
      'birthDate': data.birthDate != null ? _formatDate(data.birthDate!) : null,
    },
    'specimens': specimenJsonList,
  };

  final manifestBytes = utf8.encode(jsonEncode(manifest));
  archive.addFile(
    ArchiveFile.noCompress(
      'manifest.json',
      manifestBytes.length,
      manifestBytes,
    ),
  );

  // ── zip エンコード ──
  return ZipEncoder().encode(archive);
}

/// [zipBytes] を解析し [ExportData] を返す。
///
/// 壊れた入力への方針:
/// - manifest.json が存在しない・不正な JSON: [ExportManifestException] を投げる。
/// - version が未対応: [ExportVersionException] を投げる。
/// - 欠けた画像: 当該標本の bytes を images map から除外（deferred 相当で返す）。
/// - 欠けた標本フィールド: 復元不能なら当該標本をスキップ。
ExportData parseExportArchive(List<int> zipBytes) {
  // ── zip 解凍 ──
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(zipBytes);
  } catch (e) {
    throw ExportManifestException('zip の解析に失敗しました: $e');
  }

  // ── manifest.json 取得 ──
  final manifestFile = archive.findFile('manifest.json');
  if (manifestFile == null) {
    throw const ExportManifestException('manifest.json が見つかりません');
  }

  final Map<String, Object?> manifest;
  try {
    final content = utf8.decode(manifestFile.content);
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, Object?>) {
      throw const ExportManifestException(
        'manifest.json のルートがオブジェクトではありません',
      );
    }
    manifest = decoded;
  } catch (e) {
    if (e is ExportManifestException) rethrow;
    throw ExportManifestException('manifest.json の JSON 解析に失敗しました: $e');
  }

  // ── version チェック（ADR-0017: v2 で imageRarity 追加。v1 も後方互換で読む）──
  const supportedVersion = 2;
  final version = manifest['version'];
  if (version is! int || version < 1 || version > supportedVersion) {
    throw ExportVersionException(
      found: version is int ? version : -1,
      supported: supportedVersion,
    );
  }

  // ── 画像バイト収集 ──
  final imageBytes = <String, List<int>>{};
  for (final file in archive.files) {
    final path = file.name;
    if (!path.startsWith('images/')) continue;
    // Zip Slip 対策: `images/../evil` のような細工エントリを拒否する。
    if (path.contains('..')) continue;
    final imageId = _imageIdFromPath(path);
    // 不正な imageId（パス区切り・空など）はスキップ（パストラバーサル入力源を断つ）。
    if (!_isSafeImageId(imageId)) continue;
    imageBytes[imageId] = file.content;
  }

  // ── settings ──
  DateTime? birthDate;
  final settings = manifest['settings'];
  if (settings is Map) {
    final bd = settings['birthDate'];
    if (bd is String && bd.isNotEmpty) {
      birthDate = _parseDate(bd);
    }
  }

  // ── specimens ──
  final specimenList = <ExportSpecimen>[];
  final rawSpecimens = manifest['specimens'];
  if (rawSpecimens is List) {
    for (final raw in rawSpecimens) {
      if (raw is! Map) continue;
      final id = raw['id'];
      final answer = raw['answer'];
      final questionId = raw['questionId'];
      final questionText = raw['questionText'];
      final date = raw['date'];
      final status = raw['status'];
      final createdAtRaw = raw['createdAt'];

      // 必須フィールドが欠けている標本はスキップ。
      if (id is! String ||
          answer is! String ||
          questionId is! String ||
          questionText is! String ||
          date is! String ||
          status is! String ||
          createdAtRaw is! String) {
        continue;
      }

      final createdAt = DateTime.tryParse(createdAtRaw);
      if (createdAt == null) continue;

      // imageId は最終的にファイル名へ使われるため、安全な形式のみ採用する
      // （不正値は null = 画像 deferred として扱い、パストラバーサル入力源を断つ）。
      final rawImageId = raw['imageId'];
      final imageId =
          rawImageId is String && _isSafeImageId(rawImageId) ? rawImageId : null;
      final imageFile =
          raw['imageFile'] is String ? raw['imageFile'] as String : null;
      // ADR-0017: v2 で追加。v1・欠損・不正値は null。
      final imageRarity =
          raw['imageRarity'] is num ? (raw['imageRarity'] as num).toInt() : null;
      // 標本の表示名（後方互換: 欠損・旧形式は null）。
      final name = raw['name'] is String ? raw['name'] as String : null;

      specimenList.add(
        ExportSpecimen(
          id: id,
          answer: answer,
          questionId: questionId,
          questionText: questionText,
          date: date,
          status: status,
          createdAt: createdAt,
          imageId: imageId,
          imageFile: imageFile,
          imageRarity: imageRarity,
          name: name,
        ),
      );
    }
  }

  // ── ExportData 組み立て ──
  // images map は imageId → バイト。imageId がある標本のうちバイトが取得できたものだけ含む。
  return ExportData(
    specimens: specimenList,
    images: imageBytes,
    birthDate: birthDate,
  );
}

// ──────────────────────────────────────────────
// 日付ヘルパ（birth_date.dart に依存しないよう最小複製）
// ──────────────────────────────────────────────

String _formatDate(DateTime d) {
  final year = d.year.toString().padLeft(4, '0');
  final month = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime? _parseDate(String s) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return null;
  final year = int.tryParse(s.substring(0, 4));
  final month = int.tryParse(s.substring(5, 7));
  final day = int.tryParse(s.substring(8, 10));
  if (year == null || month == null || day == null) return null;
  if (year < 1 || month < 1 || month > 12 || day < 1) return null;
  final lastDay = DateTime(year, month + 1, 0).day;
  if (day > lastDay) return null;
  return DateTime(year, month, day);
}
