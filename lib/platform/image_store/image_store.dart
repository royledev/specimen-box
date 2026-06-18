// 標本画像のローカルバイト保存の抽象インターフェース（ADR-0011 決定4）。
//
// OS/IO 固有の型（File / path_provider）を露出させない。実装は `file_image_store.dart`、
// テスト・非対応環境用は `fake_image_store.dart`（`platform/api`・`platform/purchase` と同方針）。
//
// 取得画像をバイトでローカル保存することで、オフライン閲覧・永久保存（[[0003]] の精神）を維持する。
library;

/// 標本画像バイトのローカル保存層。
///
/// **パスは「ドキュメント領域からの相対パス」を保存・受理する**（例 `specimens/<id>.webp`）。
/// iOS はアプリ再インストール/再ビルドのたびにドキュメント領域の**絶対パス**（コンテナ UUID）が
/// 変わるため、絶対パスを DB に保存すると再ビルド後に解決できなくなる（バイト実体は残っているのに
/// 画像が出ない）。相対パスで持ち、読み取り時に**現在のコンテナ**へ解決することでこれを防ぐ。
abstract interface class ImageStore {
  /// 画像バイトを保存し、保存先の**ドキュメント領域からの相対パス**を返す。
  ///
  /// - [imageId] と [format]（例 'webp'/'png'）からファイル名を決める。
  /// - 既存の同一ファイルは上書きする（再取得・冪等）。
  Future<String> save(String imageId, List<int> bytes, String format);

  /// [localPath] のバイトを読む。存在しなければ null。
  ///
  /// [localPath] は相対パスを想定するが、過去に保存された**絶対パス**も受理し、
  /// ファイル名から現在のコンテナへ再解決する（再ビルド後の自己修復）。
  Future<List<int>?> read(String localPath);

  /// [localPath] が存在するか。[read] と同じ解決規則で判定する。
  Future<bool> exists(String localPath);
}
