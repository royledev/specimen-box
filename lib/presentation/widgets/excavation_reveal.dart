import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 「発掘」演出ウィジェット。
///
/// 回答確定を起点に、封印 → 封が割れる → 砂を払う（溶解リビール）→ 箱が開く
/// → 棚へ収まる、までの一連のシーケンスを再生する自己完結ウィジェット。
///
/// - 背景: フラグメントシェーダ `shaders/excavation.frag` を [CustomPaint] で描画。
/// - 前景: 蓋 / 標本 / ラベル台紙を [Stack] で重ね、Transform・SlideTransition・Hero で動かす。
///
/// 外部アニメ素材（rive/lottie/画像）は使わず、すべて手続き生成。
///
/// 使い方:
/// ```dart
/// final key = GlobalKey<ExcavationRevealState>();
/// ExcavationReveal(
///   key: key,
///   heroTag: 'specimen-42',
///   autoPlay: true,
///   onFinished: () => Navigator.of(context).push(...),
///   specimen: MySpecimenArt(),
/// );
/// // 再生し直す:
/// key.currentState?.replay();
/// ```
class ExcavationReveal extends StatefulWidget {
  const ExcavationReveal({
    super.key,
    this.specimen,
    this.lid,
    this.label,
    this.heroTag,
    this.onFinished,
    this.autoPlay = true,
    this.reducedMotion,
    this.seed,
    this.config = const ExcavationConfig(),
    this.controller,
  });

  /// 外部から再生を駆動する [AnimationController]（省略時は内部生成）。
  ///
  /// 既存画面（例: DetailScreen の reveal）が自前の controller で 0→1 を駆動する場合に渡す。
  /// 渡したときは内部 controller を生成せず、アイドル用の連続 Ticker も回さない
  /// （uTime は controller.value から導出）。dispose や forward は呼び出し側の責務。
  final AnimationController? controller;

  /// 標本本体（前景中央）。null の場合は琥珀のプレースホルダを描く。
  final Widget? specimen;

  /// 蓋（上辺ヒンジで開く）。null の場合はテラコッタのプレースホルダ。
  final Widget? lid;

  /// セピアのラベル台紙（下からスライドイン）。null の場合は簡易カード。
  final Widget? label;

  /// 標本→棚セルの Hero 遷移に使うタグ。親が別ルートへ push する際に共有する。
  final Object? heroTag;

  /// シーケンス終了時（onFinished）。replay の度に呼ばれる。
  final VoidCallback? onFinished;

  /// マウント時に自動再生するか。
  final bool autoPlay;

  /// prefers-reduced-motion 相当の上書き。null なら
  /// `MediaQuery.disableAnimations` を参照する。
  final bool? reducedMotion;

  /// 乱数シード。未指定なら生成時にランダム。
  final double? seed;

  /// 各フェーズの尺・振幅・前景パラメータのまとめ。
  final ExcavationConfig config;

  @override
  State<ExcavationReveal> createState() => ExcavationRevealState();
}

/// シーケンス全体のチューニング定数。後から調整しやすいよう一箇所に集約。
///
/// 注: シェーダ側の FBM オクターブ数・配色は `excavation.frag` のコンパイル時
/// 定数（GLSL では実行時に変えられないため）。ここには Dart で駆動する値を置く。
class ExcavationConfig {
  const ExcavationConfig({
    this.totalDuration = const Duration(milliseconds: 2700),
    this.reducedDuration = const Duration(milliseconds: 450),
    // --- フェーズ境界（秒, t=0 起点）---
    this.crackStart = 0.00,
    this.crackEnd = 0.25,
    this.shakeStart = 0.00,
    this.shakeEnd = 0.20,
    this.dissolveStart = 0.20,
    this.dissolveEnd = 0.75,
    this.lidStart = 0.70,
    this.lidEnd = 1.45,
    this.bloomPeak = 1.10,
    this.labelStart = 1.40,
    this.labelEnd = 2.10,
    this.settleStart = 2.10,
    this.settleEnd = 2.70,
    // --- 振幅・前景 ---
    this.shakeAmplitude = 6.0, // 減衰シェイクの初期振幅(px)
    this.lidOpenDegrees = -110.0, // 蓋の開き角
    this.riseDistance = 64.0, // 標本が下から上がる距離(px)
    this.riseScaleFrom = 0.85, // rise 開始スケール
    this.bloomHold = 0.40, // ピーク後に保持するグロー値
    // --- 描画 ---
    this.maxDevicePixelRatio = 2.0, // シェーダ描画の解像度上限
  });

  final Duration totalDuration;
  final Duration reducedDuration;

  final double crackStart, crackEnd;
  final double shakeStart, shakeEnd;
  final double dissolveStart, dissolveEnd;
  final double lidStart, lidEnd;
  final double bloomPeak;
  final double labelStart, labelEnd;
  final double settleStart, settleEnd;

  final double shakeAmplitude;
  final double lidOpenDegrees;
  final double riseDistance;
  final double riseScaleFrom;
  final double bloomHold;

  final double maxDevicePixelRatio;
}

class ExcavationRevealState extends State<ExcavationReveal>
    with TickerProviderStateMixin {
  // シーケンス駆動（2.7s）。外部 controller 指定時はそれを使う。
  late final AnimationController _controller;
  bool _ownsController = true;
  // アイドルの連続時間（uTime）。内部 controller のときのみ回す。
  Ticker? _idleTicker;
  final ValueNotifier<double> _idleSeconds = ValueNotifier<double>(0.0);

  // シェーダのロード状態。
  ui.FragmentShader? _shader;
  bool _shaderFailed = false;

  late double _seed;
  bool _finishedSignaled = false;

  ExcavationConfig get _cfg => widget.config;

  bool get _reducedMotion =>
      widget.reducedMotion ?? MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  void initState() {
    super.initState();
    _seed = widget.seed ?? math.Random().nextDouble() * 100.0;

    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller =
          AnimationController(vsync: this, duration: _cfg.totalDuration);
      // アイドルの連続時間は内部 controller のときだけ回す（外部時は uTime を value から導出）。
      _idleTicker = createTicker((elapsed) {
        _idleSeconds.value = elapsed.inMicroseconds / 1e6;
      })..start();
    }
    _controller.addStatusListener(_onStatus);

    _loadShader();

    if (_ownsController && widget.autoPlay) {
      // 最初のフレーム後に再生（reducedMotion の MediaQuery 参照のため）。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) replay();
      });
    }
  }

  Future<void> _loadShader() async {
    try {
      final program =
          await ui.FragmentProgram.fromAsset('shaders/excavation.frag');
      if (!mounted) return;
      setState(() => _shader = program.fragmentShader());
    } catch (_) {
      if (!mounted) return;
      setState(() => _shaderFailed = true); // プレースホルダ（土の静止）にフォールバック
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_finishedSignaled) {
      _finishedSignaled = true;
      widget.onFinished?.call();
    }
  }

  /// 最初から再生し直す。
  void replay() {
    _finishedSignaled = false;
    _controller
      ..duration = _reducedMotion ? _cfg.reducedDuration : _cfg.totalDuration
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    if (_ownsController) _controller.dispose();
    _idleTicker?.dispose();
    _idleSeconds.dispose();
    _shader?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 進行度の算出: controller.value * 総尺(秒) を t として各フェーズ値を求める。
  // ---------------------------------------------------------------------------

  /// 区間 [a,b] の間で va→vb を curve 補間。範囲外はクランプ。
  double _seg(double t, double a, double b, double va, double vb, Curve c) {
    if (t <= a) return va;
    if (t >= b) return vb;
    final p = c.transform((t - a) / (b - a));
    return va + (vb - va) * p;
  }

  _Frame _computeFrame() {
    final reduced = _reducedMotion;
    final total = (reduced ? _cfg.reducedDuration : _cfg.totalDuration)
            .inMicroseconds /
        1e6;
    final t = _controller.value * total;

    if (reduced) {
      // 簡易版: 砂をかぶった状態→露出済み状態の短いクロスフェードのみ。
      final r = Curves.easeInOut.transform(_controller.value);
      return _Frame(
        time: _ownsController ? _idleSeconds.value : t,
        crack: r,
        dissolve: r,
        bloom: 0.0,
        lidAngleRad: (_seg(_controller.value, 0.6, 1.0, 0.0, _cfg.lidOpenDegrees,
                Curves.easeOut)) *
            math.pi /
            180.0,
        riseOffset: 0.0,
        riseScale: 1.0,
        specimenOpacity: r,
        labelSlide: 1.0 - r,
        settle: 0.0,
        shake: Offset.zero,
      );
    }

    // 通常版（フェーズ 2〜5）。
    final crack =
        _seg(t, _cfg.crackStart, _cfg.crackEnd, 0.0, 1.0, Curves.easeOut);
    final dissolve = _seg(
        t, _cfg.dissolveStart, _cfg.dissolveEnd, 0.0, 1.0, Curves.easeInOut);

    // bloom: 0 →(lidStart) 1 →(peak) bloomHold →(settleEnd) 0
    double bloom;
    if (t < _cfg.lidStart) {
      bloom = 0.0;
    } else if (t < _cfg.bloomPeak) {
      bloom = _seg(t, _cfg.lidStart, _cfg.bloomPeak, 0.0, 1.0, Curves.easeOut);
    } else if (t < _cfg.lidEnd) {
      bloom = _seg(
          t, _cfg.bloomPeak, _cfg.lidEnd, 1.0, _cfg.bloomHold, Curves.easeInOut);
    } else {
      bloom = _seg(
          t, _cfg.lidEnd, _cfg.settleEnd, _cfg.bloomHold, 0.0, Curves.easeInOut);
    }

    // 蓋: rotateX 0 → -110°, easeOutBack
    final lidDeg = _seg(t, _cfg.lidStart, _cfg.lidEnd, 0.0, _cfg.lidOpenDegrees,
        Curves.easeOutBack);

    // 標本: 下から rise（translateY + scale）、easeOutBack のオーバーシュート
    final riseOffset = _seg(t, _cfg.lidStart, _cfg.lidEnd, _cfg.riseDistance,
        0.0, Curves.easeOutBack);
    final riseScale = _seg(t, _cfg.lidStart, _cfg.lidEnd, _cfg.riseScaleFrom,
        1.0, Curves.easeOutBack);
    final specimenOpacity =
        _seg(t, _cfg.lidStart, _cfg.lidStart + 0.2, 0.0, 1.0, Curves.easeOut);

    // ラベル: 下からスライドイン（1=画面外, 0=定位置）
    final labelSlide = _seg(
        t, _cfg.labelStart, _cfg.labelEnd, 1.0, 0.0, Curves.easeOutCubic);

    // 棚へ収まる settle 0→1（Hero 相当の縮み）
    final settle = _seg(
        t, _cfg.settleStart, _cfg.settleEnd, 0.0, 1.0, Curves.easeInOut);

    // 減衰シェイク（0.00–0.20s, 振幅6px→0, ノイズ駆動）
    final shakeAmp =
        _seg(t, _cfg.shakeStart, _cfg.shakeEnd, _cfg.shakeAmplitude, 0.0,
            Curves.linear);
    final st = t * 60.0;
    final shake = Offset(
      shakeAmp * (math.sin(st * 1.7) * 0.6 + math.sin(st * 3.1 + 1.3) * 0.4),
      shakeAmp * (math.sin(st * 2.3 + 0.7) * 0.6 + math.sin(st * 4.7) * 0.4),
    );

    return _Frame(
      time: _ownsController ? _idleSeconds.value : t,
      crack: crack,
      dissolve: dissolve,
      bloom: bloom,
      lidAngleRad: lidDeg * math.pi / 180.0,
      riseOffset: riseOffset,
      riseScale: riseScale,
      specimenOpacity: specimenOpacity,
      labelSlide: labelSlide,
      settle: settle,
      shake: shake,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repaint = Listenable.merge([_controller, _idleSeconds]);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: repaint,
        builder: (context, _) {
          final f = _computeFrame();
          return Stack(
            fit: StackFit.expand,
            children: [
              // --- 背景レイヤー: シェーダ ---
              _buildShaderLayer(f),
              // --- 前景レイヤー: 蓋 / 標本 / ラベル ---
              _buildForeground(context, f),
            ],
          );
        },
      ),
    );
  }

  // 背景: devicePixelRatio が高すぎる端末向けに解像度をクランプして描画。
  Widget _buildShaderLayer(_Frame f) {
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    final scale =
        dpr > _cfg.maxDevicePixelRatio ? _cfg.maxDevicePixelRatio / dpr : 1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (w <= 0 || h <= 0) return const SizedBox.shrink();

        final painter = _ExcavationPainter(
          shader: _shader,
          failed: _shaderFailed,
          time: f.time,
          crack: f.crack,
          dissolve: f.dissolve,
          bloom: f.bloom,
          seed: _seed,
        );

        // scale<1 のときは小さく描いて拡大表示し、フラグメント負荷を下げる。
        if (scale >= 1.0) {
          return CustomPaint(size: Size(w, h), painter: painter);
        }
        return Transform.scale(
          scale: 1.0 / scale,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: w * scale,
            height: h * scale,
            child: CustomPaint(size: Size(w * scale, h * scale), painter: painter),
          ),
        );
      },
    );
  }

  Widget _buildForeground(BuildContext context, _Frame f) {
    final specimen = widget.specimen ?? const _DefaultSpecimen();
    final lid = widget.lid ?? const _DefaultLid();
    final label = widget.label ?? const _DefaultLabel();

    // 棚セルへの縮み（settle）: 中央やや下へ寄せつつ縮小。
    final settleScale = 1.0 - 0.55 * f.settle;
    final settleOffset = Offset(0, 40.0 * f.settle);

    Widget specimenWidget = Opacity(
      opacity: f.specimenOpacity,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..translateByDouble(
              settleOffset.dx, f.riseOffset + settleOffset.dy, 0.0, 1.0)
          ..scaleByDouble(f.riseScale * settleScale, f.riseScale * settleScale,
              1.0, 1.0),
        child: specimen,
      ),
    );
    if (widget.heroTag != null) {
      specimenWidget = Hero(tag: widget.heroTag!, child: specimenWidget);
    }

    // 蓋: 上辺ヒンジで rotateX。奥行きのため軽い透視変換を付与。
    final lidWidget = Transform(
      alignment: Alignment.topCenter,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0015)
        ..rotateX(f.lidAngleRad),
      child: lid,
    );

    // ラベル: 下からスライドイン。
    final labelWidget = FractionalTranslation(
      translation: Offset(0, f.labelSlide),
      child: Align(alignment: Alignment.bottomCenter, child: label),
    );

    // フェーズ2 のシェイクは前景全体に適用。
    return Transform.translate(
      offset: f.shake,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: specimenWidget),
          Align(alignment: Alignment.topCenter, child: lidWidget),
          labelWidget,
        ],
      ),
    );
  }
}

/// 1 フレーム分の駆動値。
class _Frame {
  const _Frame({
    required this.time,
    required this.crack,
    required this.dissolve,
    required this.bloom,
    required this.lidAngleRad,
    required this.riseOffset,
    required this.riseScale,
    required this.specimenOpacity,
    required this.labelSlide,
    required this.settle,
    required this.shake,
  });

  final double time;
  final double crack;
  final double dissolve;
  final double bloom;
  final double lidAngleRad;
  final double riseOffset;
  final double riseScale;
  final double specimenOpacity;
  final double labelSlide; // 1=画面外下, 0=定位置
  final double settle; // 0..1 棚へ縮む
  final Offset shake;
}

/// シェーダ描画。未ロード時は土の静止プレースホルダを描く。
class _ExcavationPainter extends CustomPainter {
  _ExcavationPainter({
    required this.shader,
    required this.failed,
    required this.time,
    required this.crack,
    required this.dissolve,
    required this.bloom,
    required this.seed,
  });

  final ui.FragmentShader? shader;
  final bool failed;
  final double time;
  final double crack;
  final double dissolve;
  final double bloom;
  final double seed;

  @override
  void paint(Canvas canvas, Size size) {
    final s = shader;
    if (s == null || failed) {
      _paintPlaceholder(canvas, size);
      return;
    }
    // uniform を宣言順に設定（vec2 は float 2 つ）。
    s.setFloat(0, size.width); // uSize.x
    s.setFloat(1, size.height); // uSize.y
    s.setFloat(2, time); // uTime
    s.setFloat(3, crack); // uCrack
    s.setFloat(4, dissolve); // uDissolve
    s.setFloat(5, bloom); // uBloom
    s.setFloat(6, seed); // uSeed

    final paint = Paint()..shader = s;
    canvas.drawRect(Offset.zero & size, paint);
  }

  // 土の静止状態（シェーダ未ロード / 失敗時）。
  void _paintPlaceholder(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.16),
        radius: 1.1,
        colors: [
          Color(0xFFB5623C), // テラコッタ
          Color(0xFF6E4A2C), // 焼けた土
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _ExcavationPainter old) {
    return old.shader != shader ||
        old.failed != failed ||
        old.time != time ||
        old.crack != crack ||
        old.dissolve != dissolve ||
        old.bloom != bloom ||
        old.seed != seed;
  }
}

// =============================================================================
// 既定の前景プレースホルダ（差し替え可能）。
// =============================================================================

class _DefaultLid extends StatelessWidget {
  const _DefaultLid();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB5623C), Color(0xFF8A4C2E)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: const Color(0xFF5E3A22), width: 2),
      ),
    );
  }
}

class _DefaultSpecimen extends StatelessWidget {
  const _DefaultSpecimen();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFF2C04A), Color(0xFFC9923E)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x88F2C04A), blurRadius: 28, spreadRadius: 4),
        ],
      ),
    );
  }
}

class _DefaultLabel extends StatelessWidget {
  const _DefaultLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8DCC0), // セピア
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB9A77E)),
      ),
      child: const Text(
        'No.000  —  Specimen',
        style: TextStyle(color: Color(0xFF6E4A2C), fontSize: 14),
      ),
    );
  }
}
