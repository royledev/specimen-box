// resolveNextQuestion のユニットテスト（ADR-0013: 通知ごとに別のランダム問い）。
//
// - サーバー成功時はそれを返し、採用IDを recent に push する。
// - サーバー失敗時はローカルフォールバックを返し、そのIDも recent に push する。
// - push された ID は「次の取得」で除外でき、連続で同じ問いが出ない構図を担保する。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:specimen_box/data/questions/question_loader.dart'
    show QuestionData;
import 'package:specimen_box/domain/questions/next_question_resolver.dart';

void main() {
  group('resolveNextQuestion', () {
    test('サーバー成功: 取得した問いを返し、ID を recent に push する', () async {
      final pushed = <String>[];
      var localCalled = false;

      final q = await resolveNextQuestion(
        fetchRemote: () async => const RemoteQuestionData(
          id: 'q-remote-1',
          text: 'サーバーの問い',
          category: 'sound',
          condition: 'weekendOnly',
        ),
        pushRecent: (id) async => pushed.add(id),
        localFallback: () async {
          localCalled = true;
          return _local('q-local-x');
        },
      );

      expect(q.id, 'q-remote-1');
      expect(q.text, 'サーバーの問い');
      expect(q.category, 'sound');
      expect(q.condition, 'weekendOnly');
      expect(q.weight, 1.0); // weight はサーバー選定専用→表示既定 1.0。
      expect(pushed, ['q-remote-1']);
      expect(localCalled, isFalse,
          reason: 'サーバー成功時はローカルフォールバックを呼ばない');
    });

    test('サーバー失敗: ローカルフォールバックを返し、その ID を recent に push する',
        () async {
      final pushed = <String>[];

      final q = await resolveNextQuestion(
        fetchRemote: () async => throw Exception('offline'),
        pushRecent: (id) async => pushed.add(id),
        localFallback: () async => _local('q-local-7'),
      );

      expect(q.id, 'q-local-7');
      expect(pushed, ['q-local-7'],
          reason: 'オフライン選択も push して次回の重複を避ける');
    });

    test('サーバー成功＋push 失敗: 取得した問いを捨てずに返す（フォールバックしない）',
        () async {
      var localCalled = false;

      final q = await resolveNextQuestion(
        fetchRemote: () async => const RemoteQuestionData(
          id: 'q-remote-1',
          text: 'サーバーの問い',
          category: 'sound',
        ),
        // pushRecent（DB write 相当）が失敗するケース。
        pushRecent: (id) async => throw Exception('db write failed'),
        localFallback: () async {
          localCalled = true;
          return _local('q-local-x');
        },
      );

      expect(q.id, 'q-remote-1',
          reason: 'push 失敗はサーバー取得結果を捨てない（best-effort）');
      expect(localCalled, isFalse,
          reason: 'サーバー成功時は push が失敗してもフォールバックしない');
    });

    test('連続呼び出し: 直前の採用 ID が recent に積まれ、次の取得で除外できる',
        () async {
      final recent = <String>[];
      // fetchRemote は「recent に含まれない最初の候補」を返す Fake サーバー。
      const pool = ['q-1', 'q-2', 'q-3'];
      Future<RemoteQuestionData> fetch() async {
        final pick = pool.firstWhere((id) => !recent.contains(id));
        return RemoteQuestionData(
            id: pick, text: pick, category: 'c', condition: null);
      }

      final first = await resolveNextQuestion(
        fetchRemote: fetch,
        pushRecent: (id) async => recent.add(id),
        localFallback: () async => _local('unused'),
      );
      final second = await resolveNextQuestion(
        fetchRemote: fetch,
        pushRecent: (id) async => recent.add(id),
        localFallback: () async => _local('unused'),
      );

      expect(first.id, 'q-1');
      expect(second.id, 'q-2',
          reason: '直前の q-1 が recent に積まれ、次は別の問いになる');
    });
  });
}

QuestionData _local(String id) =>
    QuestionData(id: id, text: id, category: 'local', weight: 1.0, condition: null);
