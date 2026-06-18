import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

/// questions.json の1件を表すモデル。
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

/// questions.json をアセットから読み込み、現在の時刻/曜日に合致する候補を返す。
///
/// - condition == null: 常時候補
/// - condition == 'midnightOnly': 0〜5時のみ候補
/// - condition == 'weekendOnly': 土日のみ候補
class QuestionLoader {
  static Future<List<QuestionData>> loadCandidates() async {
    final raw = await rootBundle.loadString('assets/questions/questions.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final all = (json['questions'] as List<dynamic>)
        .map((e) => QuestionData.fromJson(e as Map<String, dynamic>))
        .toList();

    final now = DateTime.now();
    return all.where((q) => _isAvailable(q.condition, now)).toList();
  }

  /// questions.json をアセットから読み込み、**全件**を返す（フィルタなし）。
  ///
  /// 決定論的な日替わり選択（[pickDailyQuestion]）向けに使う。
  /// フィルタは呼び出し側（[pickDailyQuestion] 内の [isAvailableOnDate]）が
  /// 対象日基準で行うため、ここでは時刻/曜日フィルタを適用しない。
  static Future<List<QuestionData>> loadAll() async {
    final raw = await rootBundle.loadString('assets/questions/questions.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return (json['questions'] as List<dynamic>)
        .map((e) => QuestionData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static bool _isAvailable(String? condition, DateTime now) {
    if (condition == null) return true;
    if (condition == 'midnightOnly') {
      return now.hour >= 0 && now.hour < 6;
    }
    if (condition == 'weekendOnly') {
      return now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    }
    return true;
  }
}

/// 候補リストから重み付きランダムで1問選ぶ。
/// 問い選択は決定論不要のため未シード Random（時刻＋OS エントロピー）を使う。
/// 単純な重み付き選択（本格的な反復回避は後続）。
QuestionData pickQuestion(List<QuestionData> candidates) {
  if (candidates.isEmpty) {
    // フォールバック: condition を無視した全件が空になることはないが、
    // assets が読めない等の異常系に備えてハードコードの1問を返す。
    return const QuestionData(
      id: 'q-meaningless-01',
      text: '今日いちばん意味のなかった行動は？',
      category: 'meaningless',
      weight: 1.0,
      condition: null,
    );
  }

  // 重みの合計を計算
  final totalWeight =
      candidates.fold<double>(0, (sum, q) => sum + q.weight);

  if (totalWeight <= 0) {
    // 重みがすべて 0 以下の異常値の場合は先頭を返す（0除算・範囲外を防ぐ）。
    return candidates.first;
  }

  // 未シード Random: OS のエントロピーを含むため同一秒内でも一様に分布する。
  final r = math.Random().nextDouble() * totalWeight;
  double accum = 0;
  for (final q in candidates) {
    accum += q.weight;
    if (r < accum) return q;
  }
  return candidates.last;
}
