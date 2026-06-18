// specimen-box-server の読み取り専用 API クライアントの抽象インターフェース。
//
// OS 固有・ネットワーク固有の型（http.Client 等）を一切露出させない。
// シグネチャには自前モデル（[RemoteQuestion]/[DrawnImage]/[NextQuestion]/[ImageDrawResult]）と
// 素の Dart 型のみを使用する（`platform/purchase`・`platform/notifications` と同じ方針）。
//
// http 実装は `http_specimen_api.dart`、テスト・開発/非対応環境用は `fake_specimen_api.dart`。
// 契約は specimen-box-server ADR-0004（API）/ ADR-0005（識別・レート）/ ADR-0006（問い配信）。
// クライアント側の方針はクライアント ADR-0011。
library;

// ---------------------------------------------------------------------------
// 値型（サーバーレスポンスの自前モデル）
// ---------------------------------------------------------------------------

/// サーバーが返す「今日のひとつ」の問い（`POST /v1/questions/next`）。
class RemoteQuestion {
  const RemoteQuestion({
    required this.id,
    required this.text,
    required this.category,
    this.condition,
  });

  /// 不変の問いID（標本の questionId スナップショットに使う）。
  final String id;
  final String text;
  final String category;

  /// 出題条件（`midnightOnly` / `weekendOnly` 等）。無条件は null。
  final String? condition;

  factory RemoteQuestion.fromJson(Map<String, dynamic> json) => RemoteQuestion(
        id: json['id'] as String,
        text: json['text'] as String,
        category: json['category'] as String,
        condition: json['condition'] as String?,
      );
}

/// `questions/next` のレスポンス（問い＋一斉配信フラグ）。
class NextQuestion {
  const NextQuestion({required this.question, required this.broadcast});

  final RemoteQuestion question;

  /// true のとき一斉配信問い（server ADR-0006 決定4・将来拡張）。
  final bool broadcast;
}

/// サーバーが返すランダム標本画像の参照（`POST /v1/images/draw`）。
class DrawnImage {
  const DrawnImage({
    required this.id,
    required this.url,
    required this.format,
    required this.width,
    required this.height,
    this.bytes,
    this.rarity,
    this.name,
  });

  /// 画像ID（UUID・不変・推測不可）。端末の所有集合（除外集合）に使う。
  final String id;

  /// 画像バイト取得用 URL（本番は短命署名URL / ローカルは dev 配信ルート）。
  final String url;
  final String format;
  final int width;
  final int height;

  /// バイト数（サーバーが返せば設定。未設定もあり得る）。
  final int? bytes;

  /// 画像レア度（1〜5・ADR-0017）。サーバーが返さない/古い場合は null（欠損許容）。
  final int? rarity;

  /// 標本の表示名（例: 「怒った扇風機」）。サーバーが返さない/古い場合は null（欠損許容）。
  final String? name;

  factory DrawnImage.fromJson(Map<String, dynamic> json) => DrawnImage(
        id: json['id'] as String,
        url: json['url'] as String,
        format: json['format'] as String,
        width: (json['width'] as num).toInt(),
        height: (json['height'] as num).toInt(),
        bytes: json['bytes'] == null ? null : (json['bytes'] as num).toInt(),
        rarity:
            json['rarity'] == null ? null : (json['rarity'] as num).toInt(),
        name: json['name'] as String?,
      );
}

/// `images/draw` のレスポンス。
///
/// - [image] が非 null: 取得成功。
/// - [exhausted] が true（かつ [image] が null）: プール枯渇（全所有済み）。
///   端末は「画像未取得（プレースホルダ）」で保存し、後日 deferred fetch する（ADR-0011 決定6）。
class ImageDrawResult {
  const ImageDrawResult({required this.image, required this.exhausted});

  final DrawnImage? image;
  final bool exhausted;
}

// ---------------------------------------------------------------------------
// 例外（エラー写像）
// ---------------------------------------------------------------------------

/// API 呼び出しの失敗を表す例外。
///
/// [statusCode] は HTTP ステータス（ネットワーク到達前の失敗は null）。
/// [errorCode] はサーバーの `{"error": "..."}`（snake_case）。
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.errorCode});

  final String message;
  final int? statusCode;
  final String? errorCode;

  @override
  String toString() =>
      'ApiException($message, status=$statusCode, error=$errorCode)';
}

/// 429 Too Many Requests。`Retry-After` を [retryAfter] に持つ（あれば）。
class RateLimitedException extends ApiException {
  const RateLimitedException({this.retryAfter, String? errorCode})
      : super('rate limited', statusCode: 429, errorCode: errorCode);

  final Duration? retryAfter;
}

/// 503 no_question_available（出題可能な問いが無い）。
class NoQuestionAvailableException extends ApiException {
  const NoQuestionAvailableException({String? errorCode})
      : super('no question available',
            statusCode: 503, errorCode: errorCode);
}

// ---------------------------------------------------------------------------
// インターフェース
// ---------------------------------------------------------------------------

/// specimen-box-server の読み取り専用 API クライアント。
abstract interface class SpecimenApi {
  /// `GET /health` の疎通確認。到達して `{ok:true}` なら true。
  Future<bool> health();

  /// `POST /v1/questions/next`。
  ///
  /// - [recent]: 直近に出した問いID窓（反復回避・カテゴリ偏り回避にサーバーが使う）。
  /// - [localTime]: 端末ローカル時刻（オフセット付きで送る。condition 判定用）。
  ///
  /// 出題可能な問いが無い場合は [NoQuestionAvailableException]。
  Future<NextQuestion> fetchNextQuestion({
    required List<String> recent,
    required DateTime localTime,
  });

  /// `POST /v1/images/draw`。
  ///
  /// - [owned]: 端末が所有する image_id 群（除外集合）。
  ///
  /// プール枯渇時は例外ではなく `exhausted: true`・`image: null` を返す。
  Future<ImageDrawResult> drawImage({required List<String> owned});

  /// `POST /v1/answers`（ADR-0012: 匿名・非連結なアンケート集計送信）。
  ///
  /// - **X-Device-Token を付けない**（端末と回答を紐付けない）。回答本文・問いIDのみ送る。
  /// - best-effort: 成功（2xx）で true、失敗（非2xx/ネット例外）で false を返し**例外を投げない**
  ///   （呼び出しは fire-and-forget でよい。失敗は「集計に1件届かない」だけ）。
  Future<bool> submitAnswer({
    required String questionId,
    required String answerText,
  });
}
