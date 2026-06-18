// SpecimenApi の http 実装（specimen-box-server ADR-0004）。
//
// - `package:http` の Client を注入（テストは http/testing の MockClient を渡せる）。
// - ヘッダ: Content-Type JSON / X-Device-Token（あれば）/ X-App-Key（設定時）。
// - エラー写像: 非2xx の `{"error":"..."}` を ApiException 系へ。429→RateLimited（Retry-After）、
//   503 no_question_available→NoQuestionAvailable。
// - localTime は端末ローカル時刻＋実オフセットで送る（domain/api/local_time_iso）。
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:specimen_box/domain/api/local_time_iso.dart';
import 'package:specimen_box/platform/api/api_config.dart';
import 'package:specimen_box/platform/api/specimen_api.dart';

/// http ベースの [SpecimenApi] 実装。
class HttpSpecimenApi implements SpecimenApi {
  HttpSpecimenApi({
    required this.config,
    required this.client,
    this.deviceToken,
    this.timeout = const Duration(seconds: 15),
  });

  final ApiConfig config;
  final http.Client client;

  /// 匿名端末トークン（あれば X-Device-Token に付与）。null なら付けない。
  final String? deviceToken;

  /// 1リクエストのタイムアウト。超過時は [ApiException] にラップする
  /// （無応答で Future が永遠に保留＝UI が loading から抜けないのを防ぐ）。
  final Duration timeout;

  Map<String, String> get _headers => _buildHeaders();

  /// 共通ヘッダ。[includeDeviceToken] が false のときは X-Device-Token を付けない
  /// （ADR-0012 の匿名・非連結送信＝`/v1/answers` 用）。
  Map<String, String> _buildHeaders({bool includeDeviceToken = true}) {
    final h = <String, String>{'Content-Type': 'application/json'};
    final token = deviceToken;
    if (includeDeviceToken && token != null && token.isNotEmpty) {
      h['X-Device-Token'] = token;
    }
    final appKey = config.appKey;
    if (appKey != null && appKey.isNotEmpty) {
      h['X-App-Key'] = appKey;
    }
    return h;
  }

  Uri _uri(String path) => Uri.parse('${config.baseUrl}$path');

  @override
  Future<bool> health() async {
    final http.Response res;
    try {
      res = await client.get(_uri('/health'), headers: _headers).timeout(timeout);
    } on TimeoutException {
      throw ApiException('request timed out');
    } catch (e) {
      throw ApiException('network error: $e');
    }
    if (res.statusCode != 200) return false;
    final body = _decodeObject(res);
    return body['ok'] == true;
  }

  @override
  Future<NextQuestion> fetchNextQuestion({
    required List<String> recent,
    required DateTime localTime,
  }) async {
    final body = jsonEncode({
      'recent': recent,
      'localTime': formatLocalIso8601(localTime),
    });
    final res = await _post('/v1/questions/next', body);

    if (res.statusCode == 503) {
      throw NoQuestionAvailableException(errorCode: _errorCodeOf(res));
    }
    _ensureOk(res);

    final json = _decodeObject(res);
    return NextQuestion(
      question:
          RemoteQuestion.fromJson(json['question'] as Map<String, dynamic>),
      broadcast: json['broadcast'] == true,
    );
  }

  @override
  Future<ImageDrawResult> drawImage({required List<String> owned}) async {
    final body = jsonEncode({'owned': owned});
    final res = await _post('/v1/images/draw', body);
    _ensureOk(res);

    final json = _decodeObject(res);
    final imageJson = json['image'];
    return ImageDrawResult(
      image: imageJson == null
          ? null
          : DrawnImage.fromJson(imageJson as Map<String, dynamic>),
      exhausted: json['exhausted'] == true,
    );
  }

  @override
  Future<bool> submitAnswer({
    required String questionId,
    required String answerText,
  }) async {
    final body = jsonEncode({
      'questionId': questionId,
      'answerText': answerText,
    });
    try {
      // ADR-0012: 匿名・非連結 → X-Device-Token を付けない。best-effort（例外を投げない）。
      final res = await client
          .post(
            _uri('/v1/answers'),
            headers: _buildHeaders(includeDeviceToken: false),
            body: body,
          )
          .timeout(timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  // --- 内部ヘルパ ---------------------------------------------------------

  Future<http.Response> _post(String path, String body) async {
    try {
      return await client
          .post(_uri(path), headers: _headers, body: body)
          .timeout(timeout);
    } on TimeoutException {
      throw ApiException('request timed out');
    } catch (e) {
      throw ApiException('network error: $e');
    }
  }

  /// 2xx を保証。違えばステータスに応じた例外を投げる。
  void _ensureOk(http.Response res) {
    final code = res.statusCode;
    if (code >= 200 && code < 300) return;

    final errorCode = _errorCodeOf(res);
    if (code == 429) {
      throw RateLimitedException(
        retryAfter: _retryAfter(res),
        errorCode: errorCode,
      );
    }
    throw ApiException(
      'request failed',
      statusCode: code,
      errorCode: errorCode,
    );
  }

  /// `Retry-After`（秒）を Duration に。無ければ null。
  Duration? _retryAfter(http.Response res) {
    final raw = res.headers['retry-after'];
    if (raw == null) return null;
    final secs = int.tryParse(raw.trim());
    return secs == null ? null : Duration(seconds: secs);
  }

  /// レスポンス body の `error` フィールド（snake_case）を取り出す。失敗時 null。
  String? _errorCodeOf(http.Response res) {
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        final e = decoded['error'];
        return e is String ? e : null;
      }
    } catch (_) {
      // body が JSON でない場合は無視。
    }
    return null;
  }

  /// body を JSON オブジェクトとしてデコード。オブジェクトでなければ例外。
  Map<String, dynamic> _decodeObject(http.Response res) {
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        'unexpected response shape',
        statusCode: res.statusCode,
      );
    }
    return decoded;
  }
}
