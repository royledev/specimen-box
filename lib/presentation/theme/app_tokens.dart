import 'package:flutter/material.dart';

/// 標本箱 デザイントークン（「発掘 × アースポップ」）。
///
/// `prototype/ui-redesign/`（[[画面仕様]] §1）の CSS 変数を Flutter に移植したもの。
/// 旧ダークトーンを置き換え、砂色の明るい地に土色テキスト＋暖色アクセントで構成する。
abstract final class AppColors {
  // 背景・面
  static const bg = Color(0xFFFBF2E0); // 砂・発掘現場の紙
  static const bgAlt = Color(0xFFF6E8CF);
  static const card = Color(0xFFFFFDF7);
  static const card2 = Color(0xFFFBF1DF);

  // テキスト（土色）
  static const ink = Color(0xFF44352B); // 主要
  static const inkSoft = Color(0xFF917A66); // 副次
  static const inkFaint = Color(0xFFC3B29C); // 補助・プレースホルダ

  // 罫線
  static const line = Color(0x246E4B28); // rgba(110,75,40,.14)
  static const line2 = Color(0x3D6E4B28); // rgba(110,75,40,.24)

  // アクセント（青・紫は使わない）
  static const coral = Color(0xFFEA6A45); // 主要アクセント / 第1ボタン
  static const amber = Color(0xFFF0973A); // 琥珀・封印・強調
  static const mustard = Color(0xFFF2C24C); // レア★・ハイライト
  static const moss = Color(0xFF5BA67E); // 差し色（緑）
  static const sand = Color(0xFFE0A24E); // 見出しグラデ等
  static const clay = Color(0xFFC75B59); // 見出しグラデ・バッジ
  static const seal = amber;

  // 穴（未発掘）
  static const pitBorder = Color(0x4D966838); // rgba(150,104,58,.30)
}

/// 角丸・余白などの定数。
abstract final class AppRadii {
  static const card = 20.0;
  static const chip = 20.0;
  static const slot = 14.0;
}
