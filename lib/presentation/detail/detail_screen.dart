import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:specimen_box/domain/generation/seed.dart';
import 'package:specimen_box/domain/purchase/seal_entitlement.dart';
import 'package:specimen_box/domain/rarity/image_rarity.dart';
import 'package:specimen_box/domain/rarity/rarity.dart';
import 'package:specimen_box/domain/specimen/specimen.dart';
import 'package:specimen_box/domain/weathering/weathering.dart';
import 'package:specimen_box/platform/purchase/purchase_service.dart';
import 'package:specimen_box/presentation/providers/providers.dart';
import 'package:specimen_box/presentation/theme/app_tokens.dart';
import 'package:specimen_box/presentation/widgets/excavation_reveal.dart';
import 'package:specimen_box/presentation/widgets/rarity_backdrop.dart';
import 'package:specimen_box/presentation/widgets/seal_balance.dart';
import 'package:specimen_box/presentation/widgets/specimen_image.dart';

/// 標本詳細画面: 大きな標本表示 + 発掘記録 + 風化メーター + 封印導線（[[画面仕様]] §3.6）。
///
/// [playReveal] が true のとき、初回表示時に標本がフェードインする reveal アニメを再生する。
class DetailScreen extends ConsumerStatefulWidget {
  final String specimenId;

  /// true のとき生成アニメ（reveal 0→1）を initState で起動する。
  final bool playReveal;

  const DetailScreen({
    super.key,
    required this.specimenId,
    this.playReveal = false,
  });

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen>
    with TickerProviderStateMixin {
  AnimationController? _revealController;

  /// 封印成功時に再生する「結晶に封じ込める」演出のコントローラ。
  late final AnimationController _sealController;

  @override
  void initState() {
    super.initState();
    _sealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );
    if (widget.playReveal) {
      // 発掘シェーダ（excavation.frag）のタイムライン（約2.7s）を駆動する。
      _revealController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2700),
      );
      _revealController!.forward();
    }
  }

  /// 発掘演出をスキップして即完了させる（タップ）。
  void _skipReveal() {
    if (widget.playReveal) {
      _revealController?.animateTo(1.0, duration: Duration.zero);
    }
  }

  /// 標本 id から決定論シードを作る（封印演出と種を揃えるための値域）。
  double _revealSeed(String id) => (fnv1a32(id) % 1000) / 10.0;

  /// reveal 中にせり上がる標本の前景。ローカル画像があれば表示、無ければ既定オーブ。
  /// （SpecimenImage は使わず、詳細本体の SpecimenImage と二重カウントしない。）
  Widget? _revealSpecimen(Specimen s) {
    final p = s.localPath;
    if (p == null || p.isEmpty) return null;
    return Image.file(
      File(p),
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }

  @override
  void dispose() {
    _revealController?.dispose();
    _sealController.dispose();
    super.dispose();
  }

  /// テスト用: reveal アニメの AnimationController を公開する。
  @visibleForTesting
  AnimationController? get revealController => _revealController;

  // ---------------------------------------------------------------------------
  // 封印フロー（ADR-0010）: 封印可否 → 封印 or 購入シート
  // ---------------------------------------------------------------------------

  /// 封印導線タップ。権利は**永続値から確実に読んで**判定する。
  ///
  /// バグ修正: 以前は `ref.read(sealEntitlementProvider).value` を使っていたため、
  /// 購入直後（`invalidate` 後の非同期再取得が完了する前）に再タップすると古い権利
  /// （credits=0）を読み、せっかく購入したのに封印できず購入シートが再表示されていた。
  /// リポジトリから awaited で読むことでこのレースを解消する。
  Future<void> _beginSeal() async {
    final ent = await ref.read(settingsRepositoryProvider).getSealEntitlement();
    if (!mounted) return;
    await _handleSealTap(ent);
  }

  Future<void> _handleSealTap(SealEntitlement ent) async {
    if (canSeal(ent)) {
      final confirmed = await _confirmSeal(ent);
      if (confirmed != true || !mounted) return;
      await _consumeAndSeal(ent);
    } else {
      await _showPurchaseSheet();
    }
  }

  Future<bool?> _confirmSeal(SealEntitlement ent) {
    final consumeNote = ent.unlocked
        ? '封印アンロック中のため、クレジットは消費しません。'
        : '封印クレジットを1つ消費します（残り ${ent.credits} → ${ent.credits - 1}）。';
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '封印しますか？',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        content: Text(
          '封印すると永久保存され、あとから解除できません。\n$consumeNote',
          style: const TextStyle(
            color: AppColors.inkSoft,
            fontSize: 13,
            height: 1.7,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('封印する',
                style: TextStyle(
                    color: AppColors.amber,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _consumeAndSeal(SealEntitlement ent) async {
    await ref.read(specimenListProvider.notifier).seal(widget.specimenId);
    if (!mounted) return;
    // 「結晶に封じ込める」演出を再生（装飾オーバーレイ・状態は即時に封印済みへ）。
    _sealController.forward(from: 0);
    final after = applySeal(ent);
    if (after != ent) {
      await ref.read(settingsRepositoryProvider).setSealEntitlement(after);
      if (!mounted) return;
      ref.invalidate(sealEntitlementProvider);
    }
  }

  Future<void> _showPurchaseSheet() async {
    final svc = ref.read(purchaseServiceProvider);
    final products = await svc.products();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => _PurchaseSheet(
        products: products,
        onBuy: (product) async {
          Navigator.of(sheetContext).pop();
          await _purchase(product.id);
        },
        onRestore: () async {
          Navigator.of(sheetContext).pop();
          await _restore();
        },
      ),
    );
  }

  Future<void> _purchase(String productId) async {
    final svc = ref.read(purchaseServiceProvider);
    // リポジトリは await を跨いで使う。購入完了後に画面が unmount されていても
    // 付与を確実に永続化できるよう、買う前にローカル変数へ取得しておく。
    final repo = ref.read(settingsRepositoryProvider);

    final result = await svc.buy(productId);

    if (!result.isSuccess) {
      // キャンセルは無言。失敗はメッセージ（画面が生きている場合のみ）。
      if (mounted && result.status != PurchaseStatus.canceled) {
        _showSnack(
          result.message != null && result.message!.isNotEmpty
              ? '購入を完了できませんでした：${result.message}'
              : '購入を完了できませんでした',
        );
      }
      return;
    }

    // バグ修正: 以前は付与の前に `if (!mounted) return;` があり、StoreKit のやり取り中に
    // 画面が再構築/破棄されると「購入は完了したのにクレジットが加算されない」状態になっていた。
    // 付与は mounted に依存せず必ず行い、かつ**最新の永続値**に対して grant する
    // （取りこぼし・二重適用を防ぐ）。
    final current = await repo.getSealEntitlement();
    final granted = grant(current, result.kind!);
    await repo.setSealEntitlement(granted);

    if (!mounted) return;
    ref.invalidate(sealEntitlementProvider);
    // 購入と封印は分離（付与のみ）。封印は利用者が「封をする」を押して別途行う。
    // 注意: 以前はここで floating SnackBar を出していたが、それが封印ボタンに重なって
    // タップを奪い「買ったのに封印できない」状態を生んでいたため撤去した。
    // 付与の結果は封印導線下の残数表示（「封印できる残り N個」）に反映される。
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(fontSize: 13, color: Colors.white)),
        backgroundColor: AppColors.ink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _restore() async {
    final svc = ref.read(purchaseServiceProvider);
    final result = await svc.restore();
    if (!mounted) return;
    if (!result.unlockRestored) {
      _showSnack('復元できる購入が見つかりませんでした');
      return;
    }
    final repo = ref.read(settingsRepositoryProvider);
    final current = await repo.getSealEntitlement();
    if (!mounted) return;
    await repo.setSealEntitlement(current.copyWith(unlocked: true));
    if (!mounted) return;
    ref.invalidate(sealEntitlementProvider);
    _showSnack('封印アンロックを復元しました');
  }

  @override
  Widget build(BuildContext context) {
    final specimenList = ref.watch(specimenListProvider);
    final sealEntitlement = ref.watch(sealEntitlementProvider).value;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: AppColors.inkSoft,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: specimenList.when(
        loading: () => const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: AppColors.amber),
          ),
        ),
        error: (e, st) => Center(
          child: Text(
            'エラーが発生しました\n$e',
            style: const TextStyle(color: AppColors.inkFaint, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
        data: (specimens) {
          Specimen? specimen;
          try {
            specimen = specimens.firstWhere((s) => s.id == widget.specimenId);
          } catch (_) {
            specimen = null;
          }

          if (specimen == null) {
            return const Center(
              child: Text(
                'この化石は見つかりません',
                style: TextStyle(
                    color: AppColors.inkFaint, fontSize: 13, letterSpacing: 1),
              ),
            );
          }

          final now = ref.watch(nowProvider);
          final birthDate = ref.watch(birthDateProvider).value;
          final weather = weatherLevel(
            createdAt: specimen.createdAt,
            now: now,
            sealed: specimen.sealed,
          );
          final rarity =
              rarityOf(createdAt: specimen.createdAt, birthDate: birthDate);
          final tag = rarity == Rarity.rareBirthday
              ? '🎂'
              : rarity == Rarity.rareMidnight
                  ? '🌙'
                  : null;

          final elapsedDays = now.difference(specimen.createdAt).inDays;
          final remainingDays =
              (kWeatheringT2.inDays - elapsedDays).clamp(0, kWeatheringT2.inDays);

          final Widget specimenCanvas = SpecimenImage(
            localPath: specimen.localPath,
            weather: weather,
            fit: BoxFit.contain,
          );

          // 封印済みは結晶（琥珀）の中に収めた見た目、未封印は角丸枠。
          final Widget framedSpecimen = specimen.sealed
              ? _CrystalCase(size: 230, specimen: specimenCanvas, rareTag: tag)
              : SizedBox(
                  width: 230,
                  height: 230,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(child: specimenCanvas),
                        if (tag != null)
                          Positioned(
                            top: 0,
                            right: 0,
                            child:
                                Text(tag, style: const TextStyle(fontSize: 22)),
                          ),
                      ],
                    ),
                  ),
                );

          // 標本本体は静止表示。発掘演出は前面の ExcavationReveal（excavation.frag）が担当する。
          final Widget specimenArea = GestureDetector(
            key: const Key('specimenAreaGestureDetector'),
            behavior: HitTestBehavior.opaque,
            onTap: widget.playReveal ? _skipReveal : null,
            child: framedSpecimen,
          );

          final Widget content = SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                // 標本ステージ（ハロー＋本体）。封印済みは結晶に収まったデザイン。
                Center(
                  child: SizedBox(
                    height: 268,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // レア度別エフェクト背景（透過スプライトの背後）。
                        SizedBox(
                          width: 250,
                          height: 250,
                          child: RarityBackdrop(
                            rarity: specimen.imageRarity,
                            detailed: true,
                          ),
                        ),
                        // 封印済みは結晶ケース、未封印は角丸枠（framedSpecimen 内で分岐）。
                        specimenArea,
                        // 封印演出（結晶＋スパーク）。通常時は何も描かない。
                        IgnorePointer(
                          child: _SealCrystal(controller: _sealController),
                        ),
                      ],
                    ),
                  ),
                ),
                // 標本名（サーバー配信の表示名）。未取得・旧データは非表示。
                if (specimen.name != null && specimen.name!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      specimen.name!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                // レアバッジ（画像レア★）
                if (isValidImageRarity(specimen.imageRarity))
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.mustard.withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        imageRarityStars(specimen.imageRarity!),
                        style: const TextStyle(
                            color: AppColors.mustard,
                            fontSize: 14,
                            letterSpacing: 2),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                // 発掘記録カード
                _RecordCard(rows: [
                  if (specimen.name != null && specimen.name!.isNotEmpty)
                    _RecRow(k: '名', v: specimen.name!),
                  _RecRow(k: '問', v: specimen.questionText),
                  _RecRow(k: '答', v: specimen.answer),
                  _RecRow(
                      k: '発掘',
                      v: '${specimen.date} · ${_hhmm(specimen.createdAt)}'),
                  if (rarity.label != null)
                    _RecRow(k: '分類', v: rarity.label!, highlight: true),
                ]),
                const SizedBox(height: 18),
                // 風化メーター
                _WeatherMeter(
                  weather: weather,
                  remainingDays: remainingDays,
                  sealed: specimen.sealed,
                ),
                const SizedBox(height: 18),
                // 封印導線
                _SealToggle(
                  sealed: specimen.sealed,
                  onSeal: specimen.sealed ? null : _beginSeal,
                ),
                if (sealEntitlement != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        sealEntitlement.unlocked
                            ? Icons.all_inclusive
                            : Icons.lock_outline,
                        size: 13,
                        color: AppColors.inkSoft,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        sealBalanceLabel(sealEntitlement),
                        style: const TextStyle(
                            color: AppColors.inkSoft,
                            fontSize: 11,
                            letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          );

          return Stack(
            children: [
              content,
              if (widget.playReveal && _revealController != null)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _revealController!,
                    builder: (context, _) {
                      final v = _revealController!.value;
                      if (v >= 1.0) {
                        return const IgnorePointer(child: SizedBox.expand());
                      }
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _skipReveal,
                        child: Opacity(
                          // 終盤で発掘演出をフェードし、下の標本詳細を見せる。
                          opacity: 1.0 -
                              ((v - 0.88) / 0.12).clamp(0.0, 1.0).toDouble(),
                          child: ExcavationReveal(
                            controller: _revealController,
                            autoPlay: false,
                            seed: _revealSeed(specimen!.id),
                            specimen: _revealSpecimen(specimen),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

String _hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// 発掘記録カード（問/答/発掘/分類）。
class _RecordCard extends StatelessWidget {
  final List<_RecRow> rows;
  const _RecordCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++)
            Container(
              decoration: BoxDecoration(
                border: i == rows.length - 1
                    ? null
                    : const Border(
                        bottom: BorderSide(color: AppColors.line)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: rows[i],
            ),
        ],
      ),
    );
  }
}

class _RecRow extends StatelessWidget {
  final String k;
  final String v;
  final bool highlight;
  const _RecRow({required this.k, required this.v, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            color: AppColors.sand.withValues(alpha: 0.18),
          ),
          child: Text(k,
              style: const TextStyle(
                  color: AppColors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              v,
              style: TextStyle(
                color: highlight ? AppColors.clay : AppColors.ink,
                fontSize: 14,
                height: 1.6,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 風化メーター。封印済みは「風化しない」を示す。
class _WeatherMeter extends StatelessWidget {
  final double weather;
  final int remainingDays;
  final bool sealed;
  const _WeatherMeter({
    required this.weather,
    required this.remainingDays,
    required this.sealed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('風化',
                style: TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 11,
                    letterSpacing: 1)),
            Text(
              sealed ? '封印済み・風化しない' : 'あと $remainingDays 日で消失',
              style: TextStyle(
                color: sealed ? AppColors.amber : AppColors.clay,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 8,
            color: AppColors.line,
            child: sealed
                ? Container(color: AppColors.amber.withValues(alpha: 0.5))
                : FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: weather.clamp(0.0, 1.0),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppColors.moss,
                          AppColors.mustard,
                          AppColors.amber,
                        ]),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// 封印演出: 「結晶に封じ込める」（拡散リング＋琥珀の結晶＋スパーク）。
///
/// [controller] の value が 0 のときは何も描画しない（通常表示を妨げない）。
class _SealCrystal extends StatelessWidget {
  final AnimationController controller;
  const _SealCrystal({required this.controller});

  double _seg(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final double v = controller.value;
        if (v == 0) return const SizedBox.shrink();
        final double out = 1 - _seg(v, 0.85, 1.0);
        final double flash =
            (1.0 - ((v - 0.42).abs() / 0.10)).clamp(0.0, 1.0);
        final double gem = Curves.easeOutBack.transform(_seg(v, 0.12, 0.6));
        final double spark = Curves.easeOutBack.transform(_seg(v, 0.45, 0.9));
        final double glow = _seg(v, 0.3, 0.7);
        final double ringT = _seg(v, 0.0, 0.55);
        return Opacity(
          opacity: out,
          child: SizedBox(
            width: 250,
            height: 250,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 中心グロー
                Container(
                  width: 60 + 160 * glow,
                  height: 60 + 160 * glow,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.amber.withValues(alpha: 0.35 * glow),
                      AppColors.amber.withValues(alpha: 0.0),
                    ]),
                  ),
                ),
                // 拡散リング x2
                for (int i = 0; i < 2; i++) _ring(i, ringT),
                // フラッシュ
                if (flash > 0)
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.6 * flash),
                    ),
                  ),
                // 中心の結晶（琥珀のジェム・プロトタイプ準拠の多面カット）
                Opacity(
                  opacity: gem.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: gem.clamp(0.0, 1.25),
                    child: Transform.rotate(
                      angle: (1 - gem) * 0.5,
                      child: SizedBox(
                        width: 128,
                        height: 128,
                        child: CustomPaint(painter: _GemPainter()),
                      ),
                    ),
                  ),
                ),
                // スパーク x6
                for (final off in const [
                  Offset(-72, -58),
                  Offset(74, -50),
                  Offset(-58, 64),
                  Offset(66, 60),
                  Offset(0, -88),
                  Offset(0, 86),
                ])
                  Transform.translate(
                    offset: off,
                    child: Opacity(
                      opacity: spark.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: spark.clamp(0.0, 1.3),
                        child: const Text('✦',
                            style: TextStyle(
                                fontSize: 20, color: AppColors.mustard)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _ring(int i, double t0) {
    final double t = (t0 - i * 0.2).clamp(0.0, 1.0);
    if (t <= 0) return const SizedBox.shrink();
    final double size = 50 + 200 * t;
    return Opacity(
      opacity: 1 - t,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: AppColors.amber.withValues(alpha: 0.6 * (1 - t)),
              width: 2),
        ),
      ),
    );
  }
}

/// 琥珀の多面カット結晶を描く CustomPainter（封印演出用・プロトタイプ準拠）。
class _GemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2 - 4;
    List<Offset> hex(double radius) => [
          for (int i = 0; i < 6; i++)
            Offset(
              c.dx + radius * math.cos(-math.pi / 2 + i * math.pi / 3),
              c.dy + radius * math.sin(-math.pi / 2 + i * math.pi / 3),
            ),
        ];

    Path poly(List<Offset> pts) {
      final p = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < pts.length; i++) {
        p.lineTo(pts[i].dx, pts[i].dy);
      }
      return p..close();
    }

    final outer = hex(r);
    final inner = hex(r * 0.5);

    // 本体：琥珀のラジアルグラデで充填。
    final fill = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.2, -0.3),
        colors: [Color(0xFFFFF1D6), Color(0xFFF6C66B), Color(0xFFE08A2E)],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawPath(poly(outer), fill);

    // テーブル面（内側の六角・明るい）。
    canvas.drawPath(
        poly(inner), Paint()..color = Colors.white.withValues(alpha: 0.22));

    // ファセット線（中心の内六角から外周頂点へ）。
    final facet = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 6; i++) {
      canvas.drawLine(inner[i], outer[i], facet);
    }
    canvas.drawPath(poly(inner), facet);

    // 外周の太い白フチ（プロトタイプのステッカー風）。
    canvas.drawPath(
      poly(outer),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _GemPainter oldDelegate) => false;
}

/// 封印済み標本の「結晶に収まった」表示。
///
/// 標本を六角形（結晶）にクリップし、前面に琥珀の被り・ファセット・縁・外周グローを
/// 重ねて、まるで琥珀結晶の中に標本が封じ込められているように見せる。
class _CrystalCase extends StatelessWidget {
  final double size;
  final Widget specimen;
  final String? rareTag;
  const _CrystalCase({
    required this.size,
    required this.specimen,
    this.rareTag,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 外周グロー（琥珀）。
          Container(
            width: size * 0.9,
            height: size * 0.9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.amber.withValues(alpha: 0.35),
                  blurRadius: 34,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          // 標本を六角形（結晶）にクリップ。
          ClipPath(
            clipper: _HexClipper(),
            child: SizedBox(width: size, height: size, child: specimen),
          ),
          // 結晶のファセット＋琥珀の被り＋縁（半透明で標本が透ける）。
          IgnorePointer(
            child: CustomPaint(
              size: Size.square(size),
              painter: _CrystalFramePainter(),
            ),
          ),
          // レアタグ（クリップ外・前面）。
          if (rareTag != null)
            Positioned(
              top: 4,
              right: size * 0.16,
              child: Text(rareTag!, style: const TextStyle(fontSize: 22)),
            ),
        ],
      ),
    );
  }
}

/// 六角形クリップ（pointy-top）。[_GemPainter] と同じ頂点配置。
class _HexClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3;
      final pt = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  @override
  bool shouldReclip(covariant _HexClipper oldClipper) => false;
}

/// 結晶の縁・ファセット・琥珀の被りを描く（標本の前面に半透明で重ねる）。
class _CrystalFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    List<Offset> hex(double radius) => [
          for (int i = 0; i < 6; i++)
            Offset(
              c.dx + radius * math.cos(-math.pi / 2 + i * math.pi / 3),
              c.dy + radius * math.sin(-math.pi / 2 + i * math.pi / 3),
            ),
        ];
    Path poly(List<Offset> pts) {
      final p = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < pts.length; i++) {
        p.lineTo(pts[i].dx, pts[i].dy);
      }
      return p..close();
    }

    final outer = hex(r);
    final inner = hex(r * 0.5);

    // 琥珀の被り（中央は透け、縁ほど濃い）。標本が琥珀に封じられた質感。
    final wash = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.amber.withValues(alpha: 0.0),
          AppColors.amber.withValues(alpha: 0.28),
        ],
        stops: const [0.45, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawPath(poly(outer), wash);

    // テーブル面（内側六角・わずかな白み）。
    canvas.drawPath(
        poly(inner), Paint()..color = Colors.white.withValues(alpha: 0.10));

    // ファセット線（内六角→外周頂点）。
    final facet = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 6; i++) {
      canvas.drawLine(inner[i], outer[i], facet);
    }
    canvas.drawPath(poly(inner), facet);

    // 縁（琥珀の太線＋白の細線でカット面のきらめき）。
    canvas.drawPath(
      poly(outer),
      Paint()
        ..color = AppColors.amber
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      poly(outer),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CrystalFramePainter oldDelegate) => false;
}

/// 封印導線。
///
/// - 未封印: タップで [onSeal]。ラベル「封をする（永久保存）」。
/// - 封印済み: 終端表示「封印済み」（解除導線なし・ADR-0010）。
class _SealToggle extends StatelessWidget {
  final bool sealed;
  final VoidCallback? onSeal;
  const _SealToggle({required this.sealed, this.onSeal});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: sealed ? null : onSeal,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: [
            AppColors.mustard.withValues(alpha: 0.16),
            AppColors.amber.withValues(alpha: 0.10),
          ]),
          border: Border.all(
            color: sealed
                ? AppColors.amber
                : AppColors.amber.withValues(alpha: 0.4),
            width: sealed ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Text('❖',
                style: TextStyle(
                    color: AppColors.amber,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sealed ? '封印済み' : '封をする（永久保存）',
                    style: TextStyle(
                      color: sealed ? AppColors.amber : AppColors.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sealed ? '風化が止まっています' : '風化を止め、結晶に永久保管する',
                    style: const TextStyle(
                        color: AppColors.inkSoft, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(
              sealed ? Icons.lock : Icons.chevron_right,
              color: sealed ? AppColors.amber : AppColors.inkFaint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// 購入シート（単品/パック/アンロックの一覧 + 復元導線）。
class _PurchaseSheet extends StatelessWidget {
  final List<SealProduct> products;
  final void Function(SealProduct product) onBuy;
  final VoidCallback onRestore;

  const _PurchaseSheet({
    required this.products,
    required this.onBuy,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '封をする',
              style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2),
            ),
            const SizedBox(height: 4),
            const Text(
              '封印には購入が必要です',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 11),
            ),
            const SizedBox(height: 20),
            if (products.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('現在購入できません',
                    style:
                        TextStyle(color: AppColors.inkSoft, fontSize: 13)),
              )
            else
              ...products.map(
                (p) => _ProductRow(product: p, onTap: () => onBuy(p)),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: onRestore,
                child: const Text('購入を復元',
                    style:
                        TextStyle(color: AppColors.inkSoft, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 購入シート内の商品1行。
class _ProductRow extends StatelessWidget {
  final SealProduct product;
  final VoidCallback onTap;

  const _ProductRow({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.bgAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.description,
                    style: const TextStyle(
                        color: AppColors.inkSoft, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text(
              product.price,
              style: const TextStyle(
                  color: AppColors.amber,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
