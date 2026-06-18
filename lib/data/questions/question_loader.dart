/// 問い1件を表すモデル（サーバー `POST /v1/questions/next` のレスポンス由来）。
///
/// 問いはサーバーが配信する（ADR-0013: サーバー専用）。以前のローカルアセット
/// （assets/questions/questions.json）からの読み込み・選定は廃止した。
class QuestionData {
  final String id;
  final String text;
  final String category;
  final double weight;
  final String? condition; // null | 'midnightOnly' | 'weekendOnly'

  const QuestionData({
    required this.id,
    required this.text,
    required this.category,
    required this.weight,
    required this.condition,
  });

  factory QuestionData.fromJson(Map<String, dynamic> json) {
    return QuestionData(
      id: json['id'] as String,
      text: json['text'] as String,
      category: json['category'] as String,
      weight: (json['weight'] as num).toDouble(),
      condition: json['condition'] as String?,
    );
  }
}
