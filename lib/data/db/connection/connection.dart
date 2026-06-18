// Drift DB 接続のエントリポイント。
//
// 条件付き import で環境別実装を切り替える:
// - dart.library.ffi（ネイティブ/テスト）: native.dart
// - dart.library.js_interop（Web / dart2wasm 含む）: web.dart
// - その他: unsupported.dart（スタブ）
//
// dart.library.html（旧 dart2js 専用）は dart2wasm では true にならないため
// dart.library.js_interop を使用する（drift 2.33.0 の wasm.dart に準拠）。
//
// 使い方:
// ```dart
// import 'package:specimen_box/data/db/connection/connection.dart';
//
// final conn = openConnection('specimen_box.db');
// final db = AppDatabase(conn);
// ```
export 'unsupported.dart'
    if (dart.library.ffi) 'native.dart'
    if (dart.library.js_interop) 'web.dart';
