import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:specimen_box/presentation/theme/app_tokens.dart';

/// 標本（透過スプライト）の**背後**に敷くレア度別エフェクト背景。
///
/// サーバ ADR-0009 のレア度ビジュアル言語に対応:
/// - Lv1 Normal : エフェクトなし（[detailed] のときだけ淡い土埃ハロー）。
/// - Lv2 Rare   : 銀のリム光＋淡いスパークル。
/// - Lv3 SR     : 強い発光オーラ＋放射光条（レンズフレア）＋輝く粒子。
/// - Lv4 SSR    : ホログラム箔（虹色スイープ）＋プリズム光条＋クリスタル粒子。
/// - Lv5 UR     : 金の強い発光オーラ＋金の光条＋金粒子（スターダスト）。
///
/// 手続き描画（CustomPaint）・**静止**（Ticker を持たない）。グリッド/リストでも安全。
/// 標本スプライトは透過 RGBA（ADR-0009）なので、この背景が透けて見える。
class RarityBackdrop extends StatelessWidget {
  const RarityBackdrop({
    super.key,
    required this.rarity,
    this.detailed = false,
  });

  /// 画像レア度（1〜5）。null・範囲外は Lv1 として扱う。
  final int? rarity;

  /// 詳細画面など大きく見せる場面で true（光条・粒子を増やす）。
  /// グリッド/スロットでは false（軽量・Lv1 は何も描かない）。
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RarityBackdropPainter(
        level: (rarity != null && rarity! >= 1 && rarity! <= 5) ? rarity! : 1,
        detailed: detailed,
      ),
      // 親の制約いっぱいに広がる。
      child: const SizedBox.expand(),
    );
  }
}

class _RarityBackdropPainter extends CustomPainter {
  _RarityBackdropPainter({required this.level, required this.detailed});

  final int level;
  final bool detailed;

  // 決定論の擬似乱数（粒子・光条の配置に使う・静止）。
  double _h(int n) {
    final x = math.sin(n * 12.9898 + 7.13) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;
    if (r <= 0) return;

    // Lv1: グリッドでは何も描かない。詳細では従来の淡い土埃ハローを敷く。
    if (level <= 1) {
      if (detailed) {
        _aura(canvas, c, r, [
          AppColors.amber.withValues(alpha: 0.16),
          AppColors.moss.withValues(alpha: 0.10),
          AppColors.bg.withValues(alpha: 0.0),
        ], stops: const [0.0, 0.5, 1.0]);
      }
      return;
    }

    switch (level) {
      case 2: // Rare — 銀のリム光＋淡いスパークル
        _aura(canvas, c, r, [
          const Color(0xFFEAEFF5).withValues(alpha: 0.34),
          const Color(0xFFB9C2CE).withValues(alpha: 0.14),
          Colors.transparent,
        ]);
        _rimRing(canvas, c, r * 0.92, const Color(0xFFDDE4EC), 0.5);
        _particles(canvas, c, r, const Color(0xFFF2F5F9),
            count: detailed ? 14 : 6, maxSize: r * 0.018, star: true);
        break;

      case 3: // SR — 強い発光オーラ＋放射光条＋輝く粒子
        _rays(canvas, c, r, const Color(0xFFFFE7B0),
            count: detailed ? 18 : 10, alpha: 0.16, len: 1.15);
        _aura(canvas, c, r, [
          Colors.white.withValues(alpha: 0.45),
          AppColors.amber.withValues(alpha: 0.34),
          AppColors.mustard.withValues(alpha: 0.10),
          Colors.transparent,
        ], stops: const [0.0, 0.32, 0.62, 1.0]);
        _particles(canvas, c, r, const Color(0xFFFFF3D2),
            count: detailed ? 26 : 10, maxSize: r * 0.022, star: true);
        break;

      case 4: // SSR — ホログラム箔（虹色）＋プリズム光条＋クリスタル粒子
        _holographic(canvas, c, r);
        _rays(canvas, c, r, const Color(0xFFB9F0FF),
            count: detailed ? 14 : 8, alpha: 0.14, len: 1.2, prismatic: true);
        _aura(canvas, c, r, [
          Colors.white.withValues(alpha: 0.34),
          const Color(0xFF8FD3FF).withValues(alpha: 0.16),
          Colors.transparent,
        ], stops: const [0.0, 0.5, 1.0]);
        _particles(canvas, c, r, Colors.white,
            count: detailed ? 24 : 10, maxSize: r * 0.022, star: true);
        break;

      case 5: // UR — 金の強い発光オーラ＋金の光条＋金粒子（スターダスト）
        _rays(canvas, c, r, const Color(0xFFFFE08A),
            count: detailed ? 24 : 12, alpha: 0.20, len: 1.25);
        _aura(canvas, c, r, [
          const Color(0xFFFFF6D8).withValues(alpha: 0.6),
          const Color(0xFFFFD24A).withValues(alpha: 0.42),
          const Color(0xFFE0A24E).withValues(alpha: 0.14),
          Colors.transparent,
        ], stops: const [0.0, 0.3, 0.6, 1.0]);
        _particles(canvas, c, r, const Color(0xFFFFE9A8),
            count: detailed ? 34 : 14, maxSize: r * 0.026, star: true);
        break;
    }
  }

  // 放射状オーラ（中心→外周のラジアルグラデを円に塗る）。
  void _aura(Canvas canvas, Offset c, double r, List<Color> colors,
      {List<double>? stops}) {
    final rect = Rect.fromCircle(center: c, radius: r);
    final paint = Paint()
      ..shader = RadialGradient(colors: colors, stops: stops).createShader(rect);
    canvas.drawCircle(c, r, paint);
  }

  // 細いリム（縁取りの光）。
  void _rimRing(Canvas canvas, Offset c, double radius, Color color, double a) {
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..color = color.withValues(alpha: a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.03
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.04),
    );
  }

  // 放射光条（中心から外周へ伸びる細い楔のサンバースト）。
  void _rays(Canvas canvas, Offset c, double r, Color color,
      {required int count,
      required double alpha,
      double len = 1.1,
      bool prismatic = false}) {
    const half = 0.022; // 楔の角度半幅（rad）
    for (int i = 0; i < count; i++) {
      final a = i / count * math.pi * 2 + _h(i) * 0.3;
      final tip = c + Offset(math.cos(a), math.sin(a)) * r * len;
      final p1 = c + Offset(math.cos(a - half), math.sin(a - half)) * r * len;
      final p2 = c + Offset(math.cos(a + half), math.sin(a + half)) * r * len;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();
      final col = prismatic
          ? HSVColor.fromAHSV(1.0, (i / count) * 360.0, 0.5, 1.0).toColor()
          : color;
      canvas.drawPath(path, Paint()..color = col.withValues(alpha: alpha));
    }
  }

  // ホログラム箔（虹色の円錐スイープ＋外周フェード）。
  void _holographic(Canvas canvas, Offset c, double r) {
    final rect = Rect.fromCircle(center: c, radius: r);
    const a = 0.18;
    final sweep = SweepGradient(
      colors: [
        const Color(0xFFFF6EC7).withValues(alpha: a),
        const Color(0xFF7AE7FF).withValues(alpha: a),
        const Color(0xFFB6FF8F).withValues(alpha: a),
        const Color(0xFFFFE57A).withValues(alpha: a),
        const Color(0xFFC58BFF).withValues(alpha: a),
        const Color(0xFFFF6EC7).withValues(alpha: a),
      ],
    ).createShader(rect);
    canvas.drawCircle(c, r, Paint()..shader = sweep);
    // 中心を白く抜いて外周ほど箔が効くようにする。
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: 0.22), Colors.transparent],
          stops: const [0.0, 0.7],
        ).createShader(rect),
    );
  }

  // 輝く粒子（4 点スター or 円）。配置は決定論。
  void _particles(Canvas canvas, Offset c, double r, Color color,
      {required int count, required double maxSize, bool star = false}) {
    for (int i = 0; i < count; i++) {
      final ang = _h(i * 2) * math.pi * 2;
      // sqrt で円内に面積一様分布。中心付近は標本に隠れるので 0.18r 以上に寄せる。
      final rad = (0.18 + 0.78 * math.sqrt(_h(i * 2 + 1))) * r;
      final p = c + Offset(math.cos(ang) * rad, math.sin(ang) * rad);
      final s = maxSize * (0.45 + 0.55 * _h(i * 3 + 5));
      final paint = Paint()
        ..color = color.withValues(alpha: 0.35 + 0.5 * _h(i * 5 + 11))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.35);
      if (star) {
        // 縦横の十字＝4 点スター。
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: p, width: s * 0.4, height: s * 2.0),
              Radius.circular(s * 0.2)),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: p, width: s * 2.0, height: s * 0.4),
              Radius.circular(s * 0.2)),
          paint,
        );
      } else {
        canvas.drawCircle(p, s, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RarityBackdropPainter old) =>
      old.level != level || old.detailed != detailed;
}
