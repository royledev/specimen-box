import 'package:flutter/material.dart';

import 'package:specimen_box/domain/purchase/seal_entitlement.dart';
import 'package:specimen_box/presentation/theme/app_tokens.dart';

/// 封印残数の表示文字列を返す純粋関数。
///
/// - アンロック所有（無制限）: `'∞'`。
/// - それ以外: クレジット残数の整数文字列（例: `'4'`）。
///
/// 詳細画面・ホームのチップなど複数箇所で同一表記にするための共通ロジック。
String sealBalanceText(SealEntitlement e) => e.unlocked ? '∞' : '${e.credits}';

/// 封印残数を表す説明文（詳細画面の封印セクション用）。
///
/// - アンロック: `'封印し放題（残り ∞）'`。
/// - クレジットあり/0: `'封印できる残り N個'`。
String sealBalanceLabel(SealEntitlement e) =>
    e.unlocked ? '封印し放題（残り ∞）' : '封印できる残り ${e.credits}個';

/// 封印残数を表示する小さなチップ（鍵アイコン＋残数）。
///
/// ホーム AppBar 等の常時表示に使う。アンロック時は `∞`。
class SealBalanceChip extends StatelessWidget {
  const SealBalanceChip({super.key, required this.entitlement});

  final SealEntitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final unlocked = entitlement.unlocked;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.10),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(unlocked ? '❖' : '◆',
              style: const TextStyle(color: AppColors.amber, fontSize: 11)),
          const SizedBox(width: 5),
          Text(
            sealBalanceText(entitlement),
            style: const TextStyle(
              color: AppColors.amber,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
