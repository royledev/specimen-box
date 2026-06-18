// 実疎通スモーク: 実クライアント（HttpSpecimenApi）で specimen-box-server を叩く。
//
// 使い方（server をローカル起動した状態で）:
//   cd ~/Develop/specimen-box-server && npm run seed:local && npm run dev   # 別ターミナルで常駐
//   cd ~/Develop/specimen-box && dart run tool/api_smoke.dart [baseUrl]
//
// 既定 baseUrl は http://localhost:8787。終了コード 0=全成功 / 1=失敗。
// 検証: /health → questions/next（question 取得）→ images/draw（image または exhausted）
//       → 返却 URL から画像バイト取得（200）。
library;

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:specimen_box/platform/api/api_config.dart';
import 'package:specimen_box/platform/api/http_specimen_api.dart';
import 'package:specimen_box/platform/api/specimen_api.dart';

Future<int> main(List<String> args) async {
  final baseUrl = args.isNotEmpty ? args.first : 'http://localhost:8787';
  final client = http.Client();
  final api = HttpSpecimenApi(
    config: ApiConfig(baseUrl: baseUrl),
    client: client,
    deviceToken: 'smoke-${DateTime.now().millisecondsSinceEpoch}',
  );

  var ok = true;
  try {
    // 1. health
    final healthy = await api.health();
    _line('health', healthy, healthy ? 'ok:true' : 'health failed');
    ok &= healthy;

    // 2. questions/next
    try {
      final q = await api.fetchNextQuestion(
        recent: const [],
        localTime: DateTime.now(),
      );
      _line('questions/next', true,
          'id=${q.question.id} category=${q.question.category} broadcast=${q.broadcast}');
    } catch (e) {
      _line('questions/next', false, '$e');
      ok = false;
    }

    // 3. images/draw（＋画像バイト取得）
    try {
      final ImageDrawResult r = await api.drawImage(owned: const []);
      if (r.exhausted || r.image == null) {
        _line('images/draw', false, 'exhausted（seed:local 未実行の可能性）');
        ok = false;
      } else {
        final img = r.image!;
        _line('images/draw', true,
            'id=${img.id} ${img.format} ${img.width}x${img.height}');
        // 4. 画像バイト取得
        final res = await client.get(Uri.parse(img.url));
        final imgOk = res.statusCode == 200 && res.bodyBytes.isNotEmpty;
        _line('image bytes', imgOk,
            'status=${res.statusCode} bytes=${res.bodyBytes.length} url=${img.url}');
        ok &= imgOk;
      }
    } catch (e) {
      _line('images/draw', false, '$e');
      ok = false;
    }
  } finally {
    client.close();
  }

  stdout.writeln(ok ? '\n✅ 疎通成功（全項目 PASS）' : '\n❌ 疎通失敗（上記を確認）');
  return ok ? 0 : 1;
}

void _line(String name, bool pass, String detail) {
  stdout.writeln('${pass ? "PASS" : "FAIL"}  $name  — $detail');
}
