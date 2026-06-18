import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/platform/api/fake_specimen_api.dart';
import 'package:specimen_box/platform/api/specimen_api.dart';

void main() {
  group('FakeSpecimenApi', () {
    test('既定で health true・問い・画像を返し、引数を記録する', () async {
      final fake = FakeSpecimenApi();
      expect(await fake.health(), isTrue);

      final q = await fake.fetchNextQuestion(
        recent: ['q-a'],
        localTime: DateTime(2026, 6, 13),
      );
      expect(q.question.id, 'q-fake-01');
      expect(fake.lastRecent, ['q-a']);
      expect(fake.lastLocalTime, DateTime(2026, 6, 13));

      final img = await fake.drawImage(owned: ['x']);
      expect(img.exhausted, isFalse);
      expect(img.image, isNotNull);
      expect(fake.lastOwned, ['x']);
    });

    test('healthy=false / カスタム応答を注入できる', () async {
      final fake = FakeSpecimenApi(
        healthy: false,
        image: const ImageDrawResult(image: null, exhausted: true),
      );
      expect(await fake.health(), isFalse);
      final img = await fake.drawImage(owned: []);
      expect(img.exhausted, isTrue);
      expect(img.image, isNull);
    });
  });
}
