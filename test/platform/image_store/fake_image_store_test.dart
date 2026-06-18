import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/platform/image_store/fake_image_store.dart';

void main() {
  group('FakeImageStore', () {
    test('save → read 往復一致、パスを返す', () async {
      final store = FakeImageStore();
      final path = await store.save('img-1', [1, 2, 3], 'webp');
      expect(path, 'mem://img-1.webp');
      expect(await store.read(path), [1, 2, 3]);
      expect(await store.exists(path), isTrue);
    });

    test('未保存パスは read=null・exists=false', () async {
      final store = FakeImageStore();
      expect(await store.read('mem://none.webp'), isNull);
      expect(await store.exists('mem://none.webp'), isFalse);
    });

    test('同一 id+format の再保存は上書き', () async {
      final store = FakeImageStore();
      await store.save('img-1', [1], 'png');
      final path = await store.save('img-1', [9, 9], 'png');
      expect(await store.read(path), [9, 9]);
    });
  });
}
