import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:specimen_box/domain/rarity/rarity.dart';
import 'package:specimen_box/domain/specimen/specimen.dart';
import 'package:specimen_box/domain/weathering/weathering.dart';
import 'package:specimen_box/presentation/detail/detail_screen.dart';
import 'package:specimen_box/presentation/providers/providers.dart';
import 'package:specimen_box/presentation/theme/app_tokens.dart';
import 'package:specimen_box/presentation/widgets/rarity_backdrop.dart';
import 'package:specimen_box/presentation/widgets/specimen_image.dart';

const List<String> _kMonthEn = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// 全標本一覧（コレクション）: 月日に関わらず、これまで獲得した標本を年／月で並べる。
class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final specimenList = ref.watch(specimenListProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.inkSoft),
        title: Text('化石一覧', style: Theme.of(context).textTheme.displaySmall),
        centerTitle: false,
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
          child: Text('エラーが発生しました\n$e',
              style: const TextStyle(color: AppColors.inkFaint, fontSize: 13),
              textAlign: TextAlign.center),
        ),
        data: (specimens) {
          if (specimens.isEmpty) {
            return const Center(
              child: Text('まだ化石がない',
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 14)),
            );
          }
          return _CollectionGrid(specimens: specimens);
        },
      ),
    );
  }
}

/// 年／月でグルーピングしたグリッド（新しい順）。
class _CollectionGrid extends StatelessWidget {
  final List<Specimen> specimens;
  const _CollectionGrid({required this.specimens});

  @override
  Widget build(BuildContext context) {
    // date(YYYY-MM-DD) の YYYY-MM でグルーピングし、新しい順に並べる。
    final groups = <String, List<Specimen>>{};
    for (final s in specimens) {
      final key = s.date.length >= 7 ? s.date.substring(0, 7) : s.date;
      (groups[key] ??= []).add(s);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // 新しい年月が先頭

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${specimens.length}',
                  style: const TextStyle(
                      color: AppColors.coral,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1)),
              const SizedBox(width: 8),
              const Text('点の化石',
                  style:
                      TextStyle(color: AppColors.inkSoft, fontSize: 12)),
            ],
          ),
        ),
        for (final key in keys) ...[
          _GroupHeader(yearMonth: key, count: groups[key]!.length),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            childAspectRatio: 0.82,
            children: [
              for (final s in groups[key]!) _CollectionCell(specimen: s),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String yearMonth; // 'YYYY-MM'
  final int count;
  const _GroupHeader({required this.yearMonth, required this.count});

  @override
  Widget build(BuildContext context) {
    final parts = yearMonth.split('-');
    final year = parts.isNotEmpty ? parts[0] : yearMonth;
    final month = parts.length > 1 ? int.tryParse(parts[1]) : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      child: Row(
        children: [
          Text(year,
              style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          if (month != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$month月 · ${_kMonthEn[month - 1]}',
                  style: const TextStyle(
                      color: AppColors.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 2, color: AppColors.line2)),
          const SizedBox(width: 10),
          Text('$count',
              style:
                  const TextStyle(color: AppColors.inkFaint, fontSize: 11)),
        ],
      ),
    );
  }
}

/// グリッドの1セル。
class _CollectionCell extends ConsumerWidget {
  final Specimen specimen;
  const _CollectionCell({required this.specimen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final day = specimen.date.length >= 10 ? specimen.date.substring(8, 10) : '';
    final month =
        specimen.date.length >= 7 ? specimen.date.substring(5, 7) : '';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetailScreen(specimenId: specimen.id),
        ),
      ),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: specimen.sealed
                          ? AppColors.amber
                          : AppColors.line2,
                      width: specimen.sealed ? 2 : 1,
                    ),
                    boxShadow: specimen.sealed
                        ? [
                            BoxShadow(
                                color:
                                    AppColors.amber.withValues(alpha: 0.3),
                                blurRadius: 10)
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // レア度別エフェクト背景（透過スプライトの背後）。
                        RarityBackdrop(rarity: specimen.imageRarity),
                        SpecimenImage(
                            localPath: specimen.localPath, weather: weather),
                      ],
                    ),
                  ),
                ),
                if (tag != null)
                  Positioned(
                    top: -7,
                    right: -7,
                    child: Text(tag, style: const TextStyle(fontSize: 15)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // 標本名（あれば）。1行省略。
          if (specimen.name != null && specimen.name!.isNotEmpty)
            Text(
              specimen.name!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          Text('$month/$day',
              style: const TextStyle(
                  color: AppColors.inkSoft, fontSize: 10, letterSpacing: 0.4)),
        ],
      ),
    );
  }
}
