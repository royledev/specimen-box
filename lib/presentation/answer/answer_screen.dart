import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:specimen_box/data/questions/question_loader.dart'
    show QuestionData;
import 'package:specimen_box/data/services/specimen_image_service.dart'
    show AcquiredImage;
import 'package:specimen_box/domain/questions/daily_dig_limit.dart';
import 'package:specimen_box/domain/specimen/specimen.dart';
import 'package:specimen_box/presentation/detail/detail_screen.dart';
import 'package:specimen_box/presentation/providers/providers.dart';
import 'package:specimen_box/presentation/theme/app_tokens.dart';

/// 問い回答画面: 問い文表示 + 一行入力 + 「回答する」ボタン。
///
/// 問いは開くたびにサーバーから新規取得する（ADR-0013: 通知ごとに別のランダム問い / サーバー専用）。
/// 取得に失敗した場合はローカルへフォールバックせず、リトライ可能なエラー表示にする。
/// [targetDate] は生成される標本の日付にのみ使う。null = 当日（[nowProvider]）。
class AnswerScreen extends ConsumerStatefulWidget {
  const AnswerScreen({super.key, this.targetDate});

  final DateTime? targetDate;

  @override
  ConsumerState<AnswerScreen> createState() => _AnswerScreenState();
}

class _AnswerScreenState extends ConsumerState<AnswerScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = true;
  bool _submitting = false;

  /// サーバーからの問い取得に失敗した状態（サーバー専用＝フォールバックしない）。
  bool _error = false;

  /// 画像取得に失敗した状態（回答を保存せずリトライ表示。枯渇＝全収集済みは除く）。
  bool _imageError = false;
  QuestionData? _question;
  bool _surveyOptIn = false;

  /// その日の取得上限（[kDailyDigLimit]）に達していて、これ以上掘れない状態。
  bool _capped = false;

  @override
  void initState() {
    super.initState();
    _init();
    _loadSurveyOptIn();
  }

  /// 取得上限を判定してから問いを取得する。
  ///
  /// その日（[AnswerScreen.targetDate] ?? 当日）に既に [kDailyDigLimit] 件掘っていれば、
  /// 問いを取得（recent 消費）せずに打ち止め表示にする。
  Future<void> _init() async {
    try {
      final specimens = await ref.read(specimenListProvider.future);
      if (!mounted) return;
      final DateTime target = widget.targetDate ?? ref.read(nowProvider);
      if (!canDigOnDate(specimens, _ymd(target))) {
        setState(() {
          _capped = true;
          _loading = false;
        });
        return;
      }
    } catch (_) {
      // 標本リスト取得失敗時は上限判定をスキップ（安全側＝従来どおり問い取得へ）。
    }
    await _initQuestion();
  }

  /// DateTime → 'YYYY-MM-DD'（標本の date と同形式）。
  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadSurveyOptIn() async {
    final optedIn = await ref.read(settingsRepositoryProvider).getSurveyOptIn();
    if (mounted) setState(() => _surveyOptIn = optedIn);
  }

  Future<void> _setSurveyOptIn(bool value) async {
    setState(() => _surveyOptIn = value);
    await ref.read(settingsRepositoryProvider).setSurveyOptIn(value);
  }

  Future<void> _initQuestion() async {
    try {
      final q = await ref.read(nextQuestionServiceProvider).next();
      if (mounted) {
        setState(() {
          _question = q;
          _loading = false;
          _error = false;
        });
      }
    } catch (_) {
      // サーバー専用＝ローカルへフォールバックしない。失敗はリトライ可能なエラー表示にする。
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  /// 問い取得エラー表示の「もう一度」からの再取得。
  Future<void> _retryQuestion() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    await _initQuestion();
  }

  /// 画像取得エラー表示の「もう一度」からの再送信（入力済みの回答を保持したまま）。
  Future<void> _retrySubmit() async {
    setState(() => _imageError = false);
    await _submit();
  }

  /// プール枯渇（化石を全収集済み）を知らせる案内ダイアログ。
  /// 「記録する」で true（画像なし＝プレースホルダで回答を保存して進む）、「やめる」で false。
  Future<bool?> _showExhaustedDialog() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '化石を集めきりました',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        content: const Text(
          'すべての化石を発掘しました。\n新しい化石は出ませんが、この回答は記録できます。',
          style: TextStyle(
            color: AppColors.inkSoft,
            fontSize: 13,
            height: 1.7,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('やめる',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('記録する',
                style: TextStyle(
                    color: AppColors.amber,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<AcquiredImage?> _acquireImage() async {
    try {
      final settings = ref.read(settingsRepositoryProvider);
      final owned = await settings.getOwnedImageIds();
      final service = await ref.read(specimenImageServiceProvider.future);
      final acquired = await service.acquire(owned: owned);
      if (acquired.isFetched) {
        try {
          await settings.addOwnedImageId(acquired.imageId!);
        } catch (e) {
          debugPrint('addOwnedImageId failed for ${acquired.imageId}: $e');
        }
      }
      return acquired;
    } catch (_) {
      return null;
    }
  }

  void _submitSurveyAnswer(String questionId, String answerText) {
    final text =
        answerText.length > 500 ? answerText.substring(0, 500) : answerText;
    unawaited(() async {
      try {
        final api = await ref.read(specimenApiProvider.future);
        await api.submitAnswer(questionId: questionId, answerText: text);
      } catch (_) {
        // best-effort: 送信失敗は無視。
      }
    }());
  }

  Future<void> _submit() async {
    final answer = _controller.text.trim();
    if (answer.isEmpty || _question == null) return;
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await _runSubmit(answer);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _runSubmit(String answer) async {
    final DateTime targetDate = widget.targetDate ?? ref.read(nowProvider);
    final date = _ymd(targetDate);

    // 取得上限ガード（多重送信・競合対策）。開いた後に上限へ達していたら打ち止め表示にする。
    final existing = await ref.read(specimenListProvider.future);
    if (!mounted) return;
    if (!canDigOnDate(existing, date)) {
      setState(() => _capped = true);
      return;
    }

    final acquired = await _acquireImage();
    if (!mounted) return;

    // 画像取得の失敗（ネット無/サーバーエラー/DL失敗＝deferred、または例外で null）は
    // 回答を保存せずエラー表示＋リトライにする（問い取得と同じ方針。ADR-0011 決定6 の
    // deferred 保存＝後で再取得は回答フローでは行わない）。
    // 枯渇（全収集済み・exhausted）は失敗ではないため、画像なし（プレースホルダ）で保存して進む。
    final bool imageFailed =
        acquired == null || (!acquired.isFetched && !acquired.exhausted);
    if (imageFailed) {
      setState(() => _imageError = true);
      return;
    }

    // 枯渇（全収集済み・exhausted）は失敗ではない。新しい画像は出ないが、
    // 案内メッセージを出したうえで、記録するなら画像なし（プレースホルダ）で保存して進む。
    if (acquired.exhausted) {
      final proceed = await _showExhaustedDialog();
      if (!mounted || proceed != true) return;
    }

    final now = ref.read(nowProvider);
    final specimen = Specimen(
      id: Specimen.generateId(),
      answer: answer,
      questionId: _question!.id,
      questionText: _question!.text,
      date: date,
      createdAt: now,
      imageId: acquired.imageId,
      localPath: acquired.localPath,
      imageRarity: acquired.rarity,
      name: acquired.name,
    );

    await ref.read(specimenListProvider.notifier).add(specimen);

    if (_surveyOptIn) {
      _submitSurveyAnswer(_question!.id, answer);
    }

    if (mounted) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DetailScreen(
            specimenId: specimen.id,
            playReveal: true,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 問い画面を閉じてよいか確認するダイアログ。
  Future<bool?> _confirmLeave() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '閉じますか？',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        content: const Text(
          'この問いは一度しか表示されません。\n閉じると、同じ問いはもう表示できません。',
          style: TextStyle(
            color: AppColors.inkSoft,
            fontSize: 13,
            height: 1.7,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('とどまる',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('閉じる',
                style: TextStyle(
                    color: AppColors.amber,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 打ち止め・取得失敗時は確認なしでそのまま閉じてよい（問いを取得していない）。
      canPop: _capped || _error,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final ok = await _confirmLeave();
        if (ok == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            color: AppColors.inkSoft,
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        body: _loading
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: AppColors.amber),
                ),
              )
            : _capped
                ? _buildCapped(context)
                : _error
                    ? _buildErrorView(
                        context,
                        icon: '📡',
                        title: '問いを取得できませんでした',
                        onRetry: _retryQuestion,
                      )
                    : _imageError
                        ? _buildErrorView(
                            context,
                            icon: '🖼',
                            title: '画像の取得ができませんでした',
                            onRetry: _retrySubmit,
                          )
                        : _buildContent(context),
      ),
    );
  }

  /// 取得上限に達したときの打ち止め表示（問いは出さない）。
  Widget _buildCapped(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⛏', style: TextStyle(fontSize: 30)),
            const SizedBox(height: 20),
            const Text(
              '今日の発掘はおしまい',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '1日に掘れる化石は $kDailyDigLimit つまで。\nまた明日、掘りにきてください。',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.inkSoft, fontSize: 14, height: 1.8),
            ),
            const SizedBox(height: 28),
            TextButton(
              onPressed: () => Navigator.maybePop(context),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.amber,
                textStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }

  /// 取得失敗時の共通エラー表示（リトライ可能）。問い取得・画像取得の両方で使う。
  Widget _buildErrorView(
    BuildContext context, {
    required String icon,
    required String title,
    required Future<void> Function() onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '通信環境を確認して、もう一度お試しください。',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.inkSoft, fontSize: 14, height: 1.8),
            ),
            const SizedBox(height: 28),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.coral,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                textStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
              child: const Text('もう一度'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.maybePop(context),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.inkSoft,
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final question = _question;
    if (question == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: _buildForm(context),
            ),
          ),
        );
      },
    );
  }

  Widget _buildForm(BuildContext context) {
    final question = _question!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          // 「掘る」モチーフの小見出し
          Row(
            children: const [
              Text('⛏', style: TextStyle(fontSize: 14)),
              SizedBox(width: 8),
              Text('今日の発掘',
                  style: TextStyle(
                      color: AppColors.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2)),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            question.text,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 20,
              height: 1.6,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 1,
            cursorColor: AppColors.coral,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            decoration: const InputDecoration(
              hintText: '一言で掘り出す',
              hintStyle: TextStyle(color: AppColors.inkFaint, fontSize: 16),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.line2),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.coral, width: 2),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const Spacer(),
          // ADR-0012: アンケート集計への匿名送信オプトイン（既定オフ）。
          InkWell(
            onTap: () => _setSurveyOptIn(!_surveyOptIn),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _surveyOptIn,
                      onChanged: (v) => _setSurveyOptIn(v ?? false),
                      side: const BorderSide(color: AppColors.inkFaint),
                      checkColor: Colors.white,
                      activeColor: AppColors.coral,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'この回答を匿名で集計に送る（任意・端末とは結びつけません）',
                      style: TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final hasText = _controller.text.trim().isNotEmpty;
              return SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: (hasText && !_submitting) ? _submit : null,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.coral,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.line2,
                    disabledForegroundColor: AppColors.inkFaint,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                    textStyle: const TextStyle(
                        fontSize: 15,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700),
                  ),
                  child: const Text('回答する'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
