// SettingsRepository — Settings テーブルを使った設定値の永続化。
//
// 役割:
// - SettingsDao を直接公開せず、domain が必要とする型安全な操作のみを提供する。
// - DB キー名はこのファイル内の定数として管理し、DAO/presentation 層に漏らさない。
// - 生年月日の文字列↔DateTime 変換は domain 層の純粋関数（birth_date.dart）に委譲する。
// - 封印エンタイトルメントの bool/int 保存は '1'/'0' および数値文字列で行う。
// - 匿名端末トークンは初回に生成して永続化する（server ADR-0005・レート制限の鍵）。
// - 直近問いID窓 / 所有画像ID集合は Settings KV に JSON 配列で格納する（スキーマ追加なし）。
import 'dart:convert';
import 'dart:math';

import 'package:specimen_box/data/db/settings_dao.dart';
import 'package:specimen_box/domain/api/device_token.dart';
import 'package:specimen_box/domain/api/recent_window.dart';
import 'package:specimen_box/domain/purchase/seal_entitlement.dart';
import 'package:specimen_box/domain/settings/birth_date.dart';

/// Settings テーブルを使った設定値の永続化リポジトリ。
///
/// 依存: [SettingsDao]（コンストラクタインジェクション）。
class SettingsRepository {
  const SettingsRepository(this._dao);

  final SettingsDao _dao;

  /// 生年月日を Settings テーブルに保存する際のキー名。
  static const String kBirthDateKey = 'birth_date';

  /// 保存されている生年月日を返す。
  ///
  /// - 未設定の場合は null を返す。
  /// - 保存値が不正フォーマットの場合も null を返す（[parseBirthDate] に委譲）。
  Future<DateTime?> getBirthDate() async {
    final value = await _dao.getValue(kBirthDateKey);
    return parseBirthDate(value);
  }

  /// 生年月日を保存する。
  ///
  /// - [d] は正の年（1 以上）の [DateTime] でなければならない。
  /// - 既存の値がある場合は上書きされる（upsert）。
  Future<void> setBirthDate(DateTime d) =>
      _dao.setValue(kBirthDateKey, formatBirthDate(d));

  // ─────────────────────────────────────────────
  // 封印エンタイトルメント
  // ─────────────────────────────────────────────

  /// 封印アンロックフラグを Settings テーブルに保存する際のキー名。
  static const String kSealUnlockedKey = 'seal_unlocked';

  /// 封印クレジット残を Settings テーブルに保存する際のキー名。
  static const String kSealCreditsKey = 'seal_credits';

  /// 保存されている封印エンタイトルメントを返す。
  ///
  /// - [kSealUnlockedKey] が `'1'` または `'true'` の場合は `unlocked = true`。
  ///   未設定またはその他の値は `false`。
  /// - [kSealCreditsKey] は `int.tryParse` で解釈する（未設定 / 不正値は 0）。
  ///   負値は [SealEntitlement] コンストラクタ側で 0 へクランプされる。
  Future<SealEntitlement> getSealEntitlement() async {
    final unlockedRaw = await _dao.getValue(kSealUnlockedKey);
    final creditsRaw = await _dao.getValue(kSealCreditsKey);

    final unlocked =
        unlockedRaw == '1' || unlockedRaw == 'true';
    final credits = int.tryParse(creditsRaw ?? '') ?? 0;

    return SealEntitlement(unlocked: unlocked, credits: credits);
  }

  /// 封印エンタイトルメントを保存する。
  ///
  /// - [e.unlocked] は `'1'`（true）/ `'0'`（false）で保存する。
  /// - [e.credits] は数値文字列で保存する。
  /// - 既存の値がある場合は上書きされる（upsert）。
  Future<void> setSealEntitlement(SealEntitlement e) async {
    await _dao.setValue(kSealUnlockedKey, e.unlocked ? '1' : '0');
    await _dao.setValue(kSealCreditsKey, e.credits.toString());
  }

  // ─────────────────────────────────────────────
  // 匿名端末トークン（server ADR-0005）
  // ─────────────────────────────────────────────

  /// 匿名端末トークンを保存する Settings テーブルのキー名。
  static const String kDeviceTokenKey = 'device_token';

  /// 端末トークンを返す。未生成なら生成して永続化してから返す（get-or-create）。
  ///
  /// - PII を含まない不透明トークン（[generateDeviceToken]）。
  /// - [random] は省略時 `Random.secure()`（テストで決定論にできる）。
  Future<String> getOrCreateDeviceToken([Random? random]) async {
    final existing = await _dao.getValue(kDeviceTokenKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final token = generateDeviceToken(random ?? Random.secure());
    await _dao.setValue(kDeviceTokenKey, token);
    return token;
  }

  // ─────────────────────────────────────────────
  // 直近問いID窓 / 所有画像ID集合（server ADR-0006/0004・反復回避/重複回避）
  //
  // いずれも Settings KV に JSON 配列の文字列として格納する（スキーマ追加なし）。
  // 窓の押し出し・集合追加は domain の純粋関数（recent_window.dart）に委譲する。
  // ─────────────────────────────────────────────

  /// 直近に出した問いID窓を保存する Settings キー名。
  static const String kRecentQuestionIdsKey = 'recent_question_ids';

  /// 所有（取得済み）画像ID集合を保存する Settings キー名。
  static const String kOwnedImageIdsKey = 'owned_image_ids';

  /// 直近問いID窓を返す（未設定/不正は空）。先頭=最古・末尾=最新。
  Future<List<String>> getRecentQuestionIds() =>
      _getStringList(kRecentQuestionIdsKey);

  /// 直近問いID窓に [id] を最新として押し込む（FIFO・重複排除・最大 [windowSize] 件）。
  ///
  /// 注意: read→write が `await` をまたぐため原子的ではない。現状は当日問い解決から
  /// 単発で呼ばれるため実害なし。将来並行呼び出しが生じる場合は lost-update に注意。
  Future<void> pushRecentQuestionId(String id, {int windowSize = 60}) async {
    final current = await getRecentQuestionIds();
    await _setStringList(
      kRecentQuestionIdsKey,
      pushRecent(current, id, windowSize),
    );
  }

  /// 所有画像ID集合を返す（未設定/不正は空）。
  Future<List<String>> getOwnedImageIds() =>
      _getStringList(kOwnedImageIdsKey);

  /// 所有画像ID集合に [id] を加える（重複なし・追加順保持）。
  Future<void> addOwnedImageId(String id) async {
    final current = await getOwnedImageIds();
    await _setStringList(kOwnedImageIdsKey, addUnique(current, id));
  }

  // ─────────────────────────────────────────────
  // アンケート回答送信のオプトイン（ADR-0012・既定オフ）
  // ─────────────────────────────────────────────

  /// アンケート回答送信のオプトインを保存する Settings キー名。
  static const String kSurveyOptInKey = 'survey_opt_in';

  /// アンケート送信に同意済みか（未設定は false＝既定オフ・ADR-0012 決定1）。
  Future<bool> getSurveyOptIn() async {
    final v = await _dao.getValue(kSurveyOptInKey);
    return v == '1' || v == 'true';
  }

  /// アンケート送信のオプトインを保存する（`'1'`/`'0'`）。
  Future<void> setSurveyOptIn(bool optedIn) =>
      _dao.setValue(kSurveyOptInKey, optedIn ? '1' : '0');

  // --- JSON 文字列リストの共通ヘルパ ---

  Future<List<String>> _getStringList(String key) async {
    final raw = await _dao.getValue(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return [for (final e in decoded) if (e is String) e];
      }
    } catch (_) {
      // 不正な JSON は空扱い（安全側）。
    }
    return [];
  }

  Future<void> _setStringList(String key, List<String> value) =>
      _dao.setValue(key, jsonEncode(value));
}
