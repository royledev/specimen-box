/// Web 用 Drift 接続（WasmDatabase）。
///
/// WasmDatabase.open() はブラウザ機能を自動検出し
/// OPFS → IndexedDB → inMemory の順でフォールバックする（drift 2.33.0）。
/// `web/sqlite3.wasm` と `web/drift_worker.js` の配置は T5 で確認する。
library;

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Web 用の DB 接続を返す。
/// [dbFileName] はブラウザストレージ上の DB 識別名として使う。
DatabaseConnection openConnection(String dbFileName) {
  return DatabaseConnection.delayed(Future(() async {
    final result = await WasmDatabase.open(
      databaseName: dbFileName,
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  }));
}
