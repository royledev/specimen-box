// Drift テーブル定義。
//
// 保存実体の設計方針（ADR-0011）:
// - 標本画像はサーバー配信＋ローカル保存（image_id / local_path）。旧ベクター生成
//   （seed / generatorVersion から都度再生成）は廃止した。
// - Settings テーブルは汎用 key-value（schemaVersion 2 で追加）。
import 'package:drift/drift.dart';

/// 標本テーブル。
///
/// カラム（全 9 列）:
///   id              - TEXT PK（microsecondsSinceEpoch ベースの一意ID）
///   date            - TEXT（YYYY-MM-DD、回答日）
///   question_id     - TEXT（問いの識別子）
///   question_text   - TEXT（問い文。詳細画面表示用）
///   answer_text     - TEXT（回答本文）
///   status          - TEXT（'alive' | 'sealed'）
///   created_at      - INTEGER（DateTime を epoch ms で保存）
///   image_id        - TEXT nullable（サーバー画像ID・ADR-0011）
///   local_path      - TEXT nullable（端末保存パス・ADR-0011）
///   image_rarity    - INTEGER nullable（画像レア度 1〜5・ADR-0017）
class Specimens extends Table {
  TextColumn get id => text()();
  TextColumn get date => text()();
  TextColumn get questionId => text()();
  TextColumn get questionText => text()();
  TextColumn get answerText => text()();
  TextColumn get status => text().withDefault(const Constant('alive'))();
  DateTimeColumn get createdAt => dateTime()();

  // ADR-0011: サーバー配信画像のローカル保存。
  //   image_id   - サーバー画像ID（UUID）。未取得（deferred）時は null。
  //   local_path - 端末ローカルの保存先パス。未取得（deferred）時は null。
  // schemaVersion 3 で追加。seed/generator_version は schemaVersion 4 で削除（ベクター生成廃止）。
  TextColumn get imageId => text().nullable()();
  TextColumn get localPath => text().nullable()();

  // ADR-0017: サーバー配信の画像レア度（1〜5）。未取得・旧データ・サーバー欠損時は null。
  // schemaVersion 5 で追加。
  IntColumn get imageRarity => integer().nullable()();

  // 標本の表示名（サーバー配信・例「怒った扇風機」）。未取得・旧データ・欠損時は null。
  // schemaVersion 6 で追加。
  TextColumn get name => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 設定テーブル（汎用 key-value）。
///
/// カラム（全 2 列）:
///   key   - TEXT PK（設定項目の識別子）
///   value - TEXT（設定値。型変換は呼び出し側が担う）
///
/// schemaVersion 2 で追加（ADR-0007）。
/// 既存インストールは onUpgrade で createTable する。
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
