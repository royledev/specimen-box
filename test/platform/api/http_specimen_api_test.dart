// HttpSpecimenApi の単体テスト（http/testing の MockClient で実HTTPなし）。
//
// 検証: リクエスト（path/headers/body）と レスポンス解析、エラー写像
// （400/401/429+Retry-After/503/exhausted）。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:specimen_box/platform/api/api_config.dart';
import 'package:specimen_box/platform/api/http_specimen_api.dart';
import 'package:specimen_box/platform/api/specimen_api.dart';

void main() {
  const config = ApiConfig(baseUrl: 'http://localhost:8787');

  HttpSpecimenApi apiWith(
    MockClient client, {
    ApiConfig cfg = config,
    String? token = 'tok-abc',
  }) =>
      HttpSpecimenApi(config: cfg, client: client, deviceToken: token);

  group('health', () {
    test('200 {ok:true} で true', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final ok = await apiWith(client).health();
      expect(ok, isTrue);
      expect(captured.url.toString(), 'http://localhost:8787/health');
      expect(captured.method, 'GET');
    });

    test('非200 で false', () async {
      final client = MockClient((req) async => http.Response('', 500));
      expect(await apiWith(client).health(), isFalse);
    });
  });

  group('fetchNextQuestion', () {
    test('リクエスト整形（path/headers/body）と 200 解析', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'question': {
              'id': 'q-sound-01',
              'text': '今いちばんどうでもいい音は？',
              'category': 'sound',
              'condition': null,
            },
            'broadcast': false,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final res = await apiWith(client).fetchNextQuestion(
        recent: ['q-a', 'q-b'],
        localTime: DateTime(2026, 6, 13, 23, 40, 5),
      );

      // path / method
      expect(captured.url.path, '/v1/questions/next');
      expect(captured.method, 'POST');
      // headers
      expect(captured.headers['Content-Type'], contains('application/json'));
      expect(captured.headers['X-Device-Token'], 'tok-abc');
      // body
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['recent'], ['q-a', 'q-b']);
      expect(body['localTime'], isA<String>());
      // ISO8601 + オフセット（端末ローカル時刻）。日付部分を確認。
      expect(body['localTime'], startsWith('2026-06-13T23:40:05'));
      expect(
        RegExp(r'[+\-]\d{2}:\d{2}$').hasMatch(body['localTime'] as String),
        isTrue,
        reason: 'タイムゾーンオフセットが付く',
      );
      // response
      expect(res.question.id, 'q-sound-01');
      expect(res.question.category, 'sound');
      expect(res.question.condition, isNull);
      expect(res.broadcast, isFalse);
    });

    test('broadcast:true を解析', () async {
      final client = MockClient((req) async => http.Response(
            jsonEncode({
              'question': {
                'id': 'q-x',
                'text': 't',
                'category': 'c',
                'condition': 'weekendOnly',
              },
              'broadcast': true,
            }),
            200,
          ));
      final res = await apiWith(client)
          .fetchNextQuestion(recent: [], localTime: DateTime(2026, 6, 13));
      expect(res.broadcast, isTrue);
      expect(res.question.condition, 'weekendOnly');
    });

    test('503 no_question_available → NoQuestionAvailableException', () async {
      final client = MockClient((req) async => http.Response(
            jsonEncode({'error': 'no_question_available'}),
            503,
          ));
      await expectLater(
        apiWith(client)
            .fetchNextQuestion(recent: [], localTime: DateTime(2026, 6, 13)),
        throwsA(isA<NoQuestionAvailableException>()
            .having((e) => e.errorCode, 'errorCode', 'no_question_available')),
      );
    });

    test('400 → ApiException(statusCode/errorCode)', () async {
      final client = MockClient((req) async => http.Response(
            jsonEncode({'error': 'invalid_request'}),
            400,
          ));
      await expectLater(
        apiWith(client)
            .fetchNextQuestion(recent: [], localTime: DateTime(2026, 6, 13)),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.errorCode, 'errorCode', 'invalid_request')),
      );
    });
  });

  group('drawImage', () {
    test('200 解析（owned を body に送る）', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'image': {
              'id': '9f1c0b2a-uuid',
              'url': 'http://localhost:8787/dev/img/img/9f1c.png',
              'format': 'png',
              'width': 768,
              'height': 768,
              'bytes': 152340,
            },
            'exhausted': false,
          }),
          200,
        );
      });

      final res = await apiWith(client).drawImage(owned: ['a-uuid', 'b-uuid']);

      expect(captured.url.path, '/v1/images/draw');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['owned'], ['a-uuid', 'b-uuid']);
      expect(res.exhausted, isFalse);
      expect(res.image, isNotNull);
      expect(res.image!.id, '9f1c0b2a-uuid');
      expect(res.image!.format, 'png');
      expect(res.image!.width, 768);
      expect(res.image!.bytes, 152340);
    });

    test('プール枯渇 {image:null, exhausted:true}', () async {
      final client = MockClient((req) async => http.Response(
            jsonEncode({'image': null, 'exhausted': true}),
            200,
          ));
      final res = await apiWith(client).drawImage(owned: []);
      expect(res.image, isNull);
      expect(res.exhausted, isTrue);
    });

    test('bytes 欠落でも解析できる', () async {
      final client = MockClient((req) async => http.Response(
            jsonEncode({
              'image': {
                'id': 'u',
                'url': 'http://x/y.webp',
                'format': 'webp',
                'width': 512,
                'height': 512,
              },
              'exhausted': false,
            }),
            200,
          ));
      final res = await apiWith(client).drawImage(owned: []);
      expect(res.image!.bytes, isNull);
    });
  });

  group('submitAnswer（ADR-0012・匿名）', () {
    test('X-Device-Token を付けず body は {questionId, answerText}・202 で true', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(jsonEncode({'ok': true}), 202);
      });

      final ok = await apiWith(client)
          .submitAnswer(questionId: 'q-1', answerText: 'しずかな朝');

      expect(ok, isTrue);
      expect(captured.url.path, '/v1/answers');
      expect(captured.method, 'POST');
      // 匿名・非連結: 端末トークンを送らない。
      expect(captured.headers.containsKey('X-Device-Token'), isFalse);
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body, {'questionId': 'q-1', 'answerText': 'しずかな朝'});
    });

    test('appKey 設定時は X-App-Key を付ける（端末トークンは付けない）', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('', 202);
      });
      await apiWith(
        client,
        cfg: const ApiConfig(baseUrl: 'http://localhost:8787', appKey: 'secret'),
      ).submitAnswer(questionId: 'q', answerText: 'a');
      expect(captured.headers['X-App-Key'], 'secret');
      expect(captured.headers.containsKey('X-Device-Token'), isFalse);
    });

    test('best-effort: 非2xx は false（例外を投げない）', () async {
      final client = MockClient((req) async =>
          http.Response(jsonEncode({'error': 'rate_limited'}), 429));
      expect(await apiWith(client).submitAnswer(questionId: 'q', answerText: 'a'),
          isFalse);
    });

    test('best-effort: ネット例外でも false（例外を投げない）', () async {
      final client = MockClient((req) async => throw Exception('boom'));
      expect(await apiWith(client).submitAnswer(questionId: 'q', answerText: 'a'),
          isFalse);
    });
  });

  group('共通エラー写像', () {
    test('401 → ApiException(statusCode:401)', () async {
      final client = MockClient((req) async =>
          http.Response(jsonEncode({'error': 'unauthorized'}), 401));
      await expectLater(
        apiWith(client).drawImage(owned: []),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('429 → RateLimitedException(Retry-After 秒)', () async {
      final client = MockClient((req) async => http.Response(
            jsonEncode({'error': 'rate_limited'}),
            429,
            headers: {'retry-after': '42'},
          ));
      try {
        await apiWith(client).drawImage(owned: []);
        fail('should throw');
      } on RateLimitedException catch (e) {
        expect(e.statusCode, 429);
        expect(e.retryAfter, const Duration(seconds: 42));
        expect(e.errorCode, 'rate_limited');
      }
    });

    test('429 Retry-After 無しでも RateLimited（retryAfter=null）', () async {
      final client = MockClient(
          (req) async => http.Response(jsonEncode({'error': 'rate_limited'}), 429));
      try {
        await apiWith(client).drawImage(owned: []);
        fail('should throw');
      } on RateLimitedException catch (e) {
        expect(e.retryAfter, isNull);
      }
    });

    test('ネットワーク例外 → ApiException にラップ', () async {
      final client = MockClient((req) async => throw Exception('boom'));
      await expectLater(
        apiWith(client).drawImage(owned: []),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', contains('network error'))),
      );
    });

    test('タイムアウト → ApiException(timed out)', () async {
      // MockClient で応答を遅延させ、短い timeout で TimeoutException を誘発。
      final client = MockClient((req) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response(jsonEncode({'image': null, 'exhausted': true}), 200);
      });
      final api = HttpSpecimenApi(
        config: config,
        client: client,
        deviceToken: 't',
        timeout: const Duration(milliseconds: 20),
      );
      await expectLater(
        api.drawImage(owned: []),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', contains('timed out'))),
      );
    });
  });

  group('ヘッダ', () {
    test('token 無し（null）なら X-Device-Token を付けない', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(jsonEncode({'image': null, 'exhausted': true}), 200);
      });
      await apiWith(client, token: null).drawImage(owned: []);
      expect(captured.headers.containsKey('X-Device-Token'), isFalse);
    });

    test('appKey 設定時は X-App-Key を付ける', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(jsonEncode({'image': null, 'exhausted': true}), 200);
      });
      await apiWith(
        client,
        cfg: const ApiConfig(baseUrl: 'http://localhost:8787', appKey: 'secret'),
      ).drawImage(owned: []);
      expect(captured.headers['X-App-Key'], 'secret');
    });
  });
}
