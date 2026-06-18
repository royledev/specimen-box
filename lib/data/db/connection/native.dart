// ネイティブ（iOS / Android / Desktop）用 Drift 接続。
//
// テスト環境では `AppDatabase.forTesting(NativeDatabase.memory())` を
// 直接使うため、このファイルは本番ネイティブ実行時のみ呼ばれる。
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 本番ネイティブ用の DB 接続を返す。
/// [dbFileName] は例えば `'specimen_box.db'`。
DatabaseConnection openConnection(String dbFileName) {
  return DatabaseConnection.delayed(Future(() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, dbFileName);
    return DatabaseConnection(NativeDatabase(File(path)));
  }));
}
