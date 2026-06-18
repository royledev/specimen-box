// SpecimenApi のインメモリ Fake（テスト・開発・非対応環境用）。
//
// ネットワークなしで決定論的に応答する。`platform/purchase/fake_purchase_service.dart` と同方針。
library;

import 'package:specimen_box/platform/api/specimen_api.dart';

/// 決定論的な [SpecimenApi] の Fake 実装。
class FakeSpecimenApi implements SpecimenApi {
  FakeSpecimenApi({
    this.healthy = true,
    NextQuestion? question,
    ImageDrawResult? image,
  })  : _question = question ??
            const NextQuestion(
              question: RemoteQuestion(
                id: 'q-fake-01',
                text: 'これはフェイクの問いです',
                category: 'fake',
                condition: null,
              ),
              broadcast: false,
            ),
        _image = image ??
            const ImageDrawResult(
              image: DrawnImage(
                id: '00000000-0000-0000-0000-000000000001',
                url: 'https://fake.local/img/1.webp',
                format: 'webp',
                width: 768,
                height: 768,
                bytes: 152340,
                rarity: 3,
                name: 'フェイク化石',
              ),
              exhausted: false,
            );

  /// health() の戻り値。
  bool healthy;

  final NextQuestion _question;
  final ImageDrawResult _image;

  /// submitAnswer の戻り値（テストで失敗を模擬できる）。
  bool answerAccepted = true;

  /// 最後に渡された引数（テストの検証用）。
  List<String>? lastRecent;
  DateTime? lastLocalTime;
  List<String>? lastOwned;
  ({String questionId, String answerText})? lastSubmittedAnswer;

  @override
  Future<bool> health() async => healthy;

  @override
  Future<NextQuestion> fetchNextQuestion({
    required List<String> recent,
    required DateTime localTime,
  }) async {
    lastRecent = recent;
    lastLocalTime = localTime;
    return _question;
  }

  @override
  Future<ImageDrawResult> drawImage({required List<String> owned}) async {
    lastOwned = owned;
    return _image;
  }

  @override
  Future<bool> submitAnswer({
    required String questionId,
    required String answerText,
  }) async {
    lastSubmittedAnswer = (questionId: questionId, answerText: answerText);
    return answerAccepted;
  }
}
