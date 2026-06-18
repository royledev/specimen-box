/// サポートされていないプラットフォーム用のスタブ。
///
/// dart.library.ffi（ネイティブ）でも dart.library.html（Web）でもない
/// 環境で条件付き import のフォールバックとして使われる。
library;

import 'package:drift/drift.dart';

DatabaseConnection openConnection(String dbFileName) {
  throw UnsupportedError(
    'このプラットフォームでは Drift DB 接続はサポートされていません。'
    'ネイティブまたは Web 環境で実行してください。',
  );
}
