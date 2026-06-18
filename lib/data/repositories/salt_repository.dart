// SaltRepository — userSalt の生成と永続化。
//
// 仕様:
// - 初回呼び出しで暗号的乱数（dart:math の Random.secure()）を使って
//   24バイト（48文字の hex 文字列）の salt を生成し SharedPreferences に保存する。
// - 2回目以降は保存済みの同じ値を返す（不変）。
// - キー名は kSaltKey 定数として外部から参照可能。
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// userSalt を SharedPreferences に永続化するリポジトリ。
///
/// 依存: [SharedPreferences]（コンストラクタインジェクション）。
class SaltRepository {
  const SaltRepository(this._prefs);

  final SharedPreferences _prefs;

  /// SharedPreferences に保存する際のキー名。
  static const String kSaltKey = 'user_salt';

  /// userSalt を返す。
  ///
  /// - 初回: 24バイトの暗号的乱数から生成した hex 文字列（48文字）を保存して返す。
  /// - 2回目以降: 保存済みの同値を返す（不変）。
  Future<String> getSalt() async {
    final existing = _prefs.getString(kSaltKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final salt = _generateSalt();
    await _prefs.setString(kSaltKey, salt);
    return salt;
  }

  /// 24バイトの暗号的乱数から hex 文字列（48文字）を生成する。
  ///
  /// [Random.secure()] は OS の暗号的乱数源を使用するため
  /// 十分なエントロピーが保証される。
  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
