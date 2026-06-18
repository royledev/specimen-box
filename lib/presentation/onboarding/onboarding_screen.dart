import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:specimen_box/presentation/providers/providers.dart';
import 'package:specimen_box/presentation/theme/app_tokens.dart';

/// 初回オンボーディング画面: 生年月日の必須入力（[[画面仕様]] §3.2）。
///
/// 生年月日は**一度だけ**設定でき、あとから変更できない（誕生日レアの不正取得防止）。
/// 設定後は [birthDateProvider] が非 null になり、ゲートが二度とこの画面を出さない。
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => OnboardingScreenState();
}

class OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  /// 選択中の生年月日。ホイールの初期位置に合わせて初期値を入れる。
  DateTime? selected;

  /// テスト専用: [selected] を直接セットする。
  @visibleForTesting
  void setSelectedForTesting(DateTime? date) {
    setState(() {
      selected = date;
    });
  }

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = ref.read(nowProvider);
    // ホイールの初期位置＝20歳相当。selected も同値で初期化（既定で保存可能）。
    selected = DateTime(now.year - 20, now.month, now.day);
  }

  /// 「一度だけ設定・変更不可」を明示する確認アラートを出してから保存する。
  Future<void> _confirmAndSave() async {
    final date = selected;
    if (date == null || _saving) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '本当にこの日でいい？',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        content: Text(
          '誕生日は一度だけ設定でき、あとから変更できません。\n'
          '（${_formatDate(date)}）',
          style: const TextStyle(
            color: AppColors.inkSoft,
            fontSize: 13,
            height: 1.7,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('選びなおす',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('この日で決める',
                style: TextStyle(
                    color: AppColors.coral,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      await _doSave(date);
    }
  }

  Future<void> _doSave(DateTime date) async {
    if (_saving) return;
    setState(() {
      _saving = true;
    });

    try {
      await ref.read(settingsRepositoryProvider).setBirthDate(date);
      ref.invalidate(birthDateProvider);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSelected = selected != null;
    final now = ref.watch(nowProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                      colors: [AppColors.coral, AppColors.amber]),
                ),
                child: const Text('はじめに',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3)),
              ),
              const SizedBox(height: 20),
              const Text(
                'あなたの誕生日を\n教えてください',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  height: 1.5,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'その日は、特別な化石が掘れる日になる',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 15.5,
                    height: 1.7,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.clay.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.clay.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  '⚠ 一度だけ設定でき、あとから変更できません',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.clay,
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const Spacer(),
              // 年・月・日のホイール（プロトタイプ準拠）
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.line2),
                ),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  height: 196,
                  child: Stack(
                    children: [
                      // 中央のハイライト帯
                      Center(
                        child: Container(
                          height: 42,
                          margin:
                              const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: AppColors.amber.withValues(alpha: 0.12),
                            border: Border.all(
                                color:
                                    AppColors.amber.withValues(alpha: 0.4)),
                          ),
                        ),
                      ),
                      CupertinoTheme(
                        data: const CupertinoThemeData(
                          brightness: Brightness.light,
                          textTheme: CupertinoTextThemeData(
                            dateTimePickerTextStyle: TextStyle(
                              color: AppColors.ink,
                              fontFamily: 'ZenMaruGothic',
                              fontWeight: FontWeight.w700,
                              fontSize: 19,
                            ),
                          ),
                        ),
                        child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.date,
                          backgroundColor: Colors.transparent,
                          initialDateTime: selected,
                          minimumDate: DateTime(1900),
                          maximumDate: now,
                          onDateTimeChanged: (d) =>
                              setState(() => selected = d),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: (hasSelected && !_saving) ? _confirmAndSave : null,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.coral,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.line2,
                    disabledForegroundColor: AppColors.inkFaint,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                    textStyle: const TextStyle(
                        fontSize: 15,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: Colors.white),
                        )
                      : const Text('この日から、発掘をはじめる'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y年$m月$day日';
  }
}
