// SpecimenImageService の取得＋保存ロジックテスト（Fake のみ・IO/ネット非依存）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/data/services/specimen_image_service.dart';
import 'package:specimen_box/platform/api/fake_specimen_api.dart';
import 'package:specimen_box/platform/api/specimen_api.dart';
import 'package:specimen_box/platform/image_store/fake_image_downloader.dart';
import 'package:specimen_box/platform/image_store/fake_image_store.dart';

void main() {
  group('SpecimenImageService.acquire', () {
    test('成功: draw → DL → save で imageId/localPath を返し owned が url DL に渡る', () async {
      final api = FakeSpecimenApi();
      final store = FakeImageStore();
      final downloader = FakeImageDownloader(bytes: [7, 7, 7]);
      final svc =
          SpecimenImageService(api: api, store: store, downloader: downloader);

      final r = await svc.acquire(owned: ['o-1']);

      expect(r.isFetched, isTrue);
      expect(r.exhausted, isFalse);
      // FakeSpecimenApi の既定画像 id/format で保存される。
      expect(r.imageId, '00000000-0000-0000-0000-000000000001');
      expect(r.localPath, 'mem://00000000-0000-0000-0000-000000000001.webp');
      expect(await store.read(r.localPath!), [7, 7, 7]);
      // owned が draw に渡る。
      expect(api.lastOwned, ['o-1']);
      // url がダウンローダに渡る。
      expect(downloader.lastUrl, 'https://fake.local/img/1.webp');
      // ADR-0017: サーバー配信の画像レア度が AcquiredImage に運ばれる。
      expect(r.rarity, 3);
    });

    test('プール枯渇: exhausted=true・未取得', () async {
      final api = FakeSpecimenApi(
        image: const ImageDrawResult(image: null, exhausted: true),
      );
      final svc = SpecimenImageService(
        api: api,
        store: FakeImageStore(),
        downloader: FakeImageDownloader(),
      );

      final r = await svc.acquire(owned: []);
      expect(r.exhausted, isTrue);
      expect(r.isFetched, isFalse);
      expect(r.localPath, isNull);
    });

    test('DL 失敗: deferred（未取得・exhausted=false・保存もされない）', () async {
      final store = FakeImageStore();
      final svc = SpecimenImageService(
        api: FakeSpecimenApi(),
        store: store,
        downloader: FakeImageDownloader(fail: true),
      );

      final r = await svc.acquire(owned: []);
      expect(r.isFetched, isFalse);
      expect(r.exhausted, isFalse);
      expect(r.imageId, isNull);
      expect(store.files, isEmpty);
    });

    test('API 失敗（例外）: deferred', () async {
      final svc = SpecimenImageService(
        api: _ThrowingApi(),
        store: FakeImageStore(),
        downloader: FakeImageDownloader(),
      );
      final r = await svc.acquire(owned: []);
      expect(r.isFetched, isFalse);
      expect(r.exhausted, isFalse);
    });
  });
}

/// drawImage が例外を投げる Fake。
class _ThrowingApi implements SpecimenApi {
  @override
  Future<bool> health() async => false;

  @override
  Future<NextQuestion> fetchNextQuestion({
    required List<String> recent,
    required DateTime localTime,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ImageDrawResult> drawImage({required List<String> owned}) async =>
      throw const ApiException('boom');

  @override
  Future<bool> submitAnswer({
    required String questionId,
    required String answerText,
  }) async =>
      throw UnimplementedError();
}
