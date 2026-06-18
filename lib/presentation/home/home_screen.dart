import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:specimen_box/domain/rarity/rarity.dart';
import 'package:specimen_box/domain/specimen/specimen.dart';
import 'package:specimen_box/domain/weathering/weathering.dart';
import 'package:specimen_box/presentation/answer/answer_screen.dart';
import 'package:specimen_box/presentation/collection/collection_screen.dart';
import 'package:specimen_box/presentation/detail/detail_screen.dart';
import 'package:specimen_box/presentation/providers/providers.dart';
import 'package:specimen_box/presentation/theme/app_tokens.dart';
import 'package:specimen_box/presentation/widgets/rarity_backdrop.dart';
import 'package:specimen_box/presentation/widgets/seal_balance.dart';
import 'package:specimen_box/domain/questions/daily_dig_limit.dart';
import 'package:specimen_box/presentation/widgets/specimen_image.dart';

const List<String> _kWeekdayJp = ['月', '火', '水', '木', '金', '土', '日'];

/// 1日あたりの表示スロット＝取得上限（[[0018-three-daily-notifications]]）。
/// 取得上限 [kDailyDigLimit] と同一にして表示と制限をズレさせない。
const int _kSlotsPerDay = kDailyDigLimit;

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// 標本箱ホーム: 直近1週間を日付ごとに表示し、他の日はカレンダーから辿る（[[画面仕様]] §3.3）。
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final specimenList = ref.watch(specimenListProvider);
    final entitlement = ref.watch(sealEntitlementProvider).value;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('化石箱', style: Theme.of(context).textTheme.displaySmall),
        centerTitle: false,
        actions: [
          if (entitlement != null)
            Center(child: SealBalanceChip(entitlement: entitlement)),
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined,
                color: AppColors.inkSoft, size: 20),
            tooltip: 'カレンダー',
            onPressed: () => _openCalendar(context, specimenList.value ?? const []),
          ),
          IconButton(
            icon: const Icon(Icons.grid_view_rounded,
                color: AppColors.inkSoft, size: 20),
            tooltip: '化石一覧',
            onPressed: () => _openCollection(context),
          ),
        ],
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
          if (specimens.isEmpty) {
            return _EmptyState(onNavigate: () => _openAnswer(context));
          }
          return _WeekView(specimens: specimens);
        },
      ),
    );
  }

  void _openAnswer(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AnswerScreen()),
    );
  }

  void _openCollection(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CollectionScreen()),
    );
  }

  /// カレンダーを開き、発掘済みの日を選ぶとその日の標本シートを表示する。
  Future<void> _openCalendar(
      BuildContext context, List<Specimen> specimens) async {
    final datesWithSpecimens = <String, int>{};
    for (final s in specimens) {
      datesWithSpecimens.update(s.date, (v) => v + 1, ifAbsent: () => 1);
    }
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _CalendarSheet(counts: datesWithSpecimens),
    );
    if (picked == null || !context.mounted) return;
    _openDaySheet(context, picked, specimens);
  }

  void _openDaySheet(
      BuildContext context, DateTime date, List<Specimen> specimens) {
    final key = _ymd(date);
    final ofDay = specimens.where((s) => s.date == key).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _DaySheet(date: date, specimens: ofDay),
    );
  }
}

/// 標本0件の空状態。
class _EmptyState extends StatelessWidget {
  final VoidCallback onNavigate;
  const _EmptyState({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ツルハシのイラスト（静止・タップ反応なし）。
            const _PickaxeBadge(size: 120),
            const SizedBox(height: 24),
            const Text(
              'まだ何も掘り出していない\n問いに答えると、化石が出てくる',
              style: TextStyle(
                  color: AppColors.inkSoft, fontSize: 14, height: 1.9),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: onNavigate,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.coral,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26)),
              ),
              child: const Text('最初の問いに回答する',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 直近1週間を日付ごとに表示するビュー。
class _WeekView extends ConsumerWidget {
  final List<Specimen> specimens;
  const _WeekView({required this.specimens});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final byDate = <String, List<Specimen>>{};
    for (final s in specimens) {
      (byDate[s.date] ??= []).add(s);
    }
    for (final list in byDate.values) {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    final today = DateTime(now.year, now.month, now.day);
    final todaySpecimens = byDate[_ymd(today)] ?? const <Specimen>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
      children: [
        // 発掘総数
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                specimens.length.toString().padLeft(3, '0'),
                style: const TextStyle(
                  color: AppColors.coral,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 12),
              const Text('発掘した化石',
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 12)),
            ],
          ),
        ),
        // 今日の発掘枠（ツルハシ＋今日掘った標本）。常設。
        _TodayDigCard(specimens: todaySpecimens, slots: _kSlotsPerDay),
        // 週見出し（今日は上の枠に出すため、ここは過去1週間）
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
          child: Row(
            children: [
              const Text('過去1週間の発掘',
                  style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1)),
              const SizedBox(width: 12),
              Expanded(
                child: Container(height: 2, color: AppColors.line2),
              ),
            ],
          ),
        ),
        // 過去7日（昨日→1週間前）。今日は上の「今日の発掘」枠に出すため除外。
        for (int i = 1; i <= 7; i++)
          _DayRow(
            index: i,
            date: today.subtract(Duration(days: i)),
            specimens: byDate[_ymd(today.subtract(Duration(days: i)))] ??
                const [],
          ),
      ],
    );
  }
}

/// 今日の発掘枠。ホーム週ビューの先頭に常設する。
///
/// 左にツルハシのイラスト（静止）、右に「今日の発掘 N/3」と今日掘った標本を並べる。
/// タップで問いは開かない（発掘の入口は通知から・[[ADR-0013]]/[[ADR-0018]]）。
class _TodayDigCard extends StatelessWidget {
  final List<Specimen> specimens;
  final int slots;
  const _TodayDigCard({required this.specimens, required this.slots});

  @override
  Widget build(BuildContext context) {
    final count = specimens.length;
    final done = count >= slots;
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 0, 4, 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ツルハシのイラスト（静止）。タップ反応なし。
          const _PickaxeBadge(size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('今日の発掘',
                        style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1)),
                    const SizedBox(width: 10),
                    Text('$count/$slots',
                        style: const TextStyle(
                            color: AppColors.inkFaint, fontSize: 11)),
                    if (done) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle_outline,
                          size: 13, color: AppColors.amber),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                // 今日掘った標本（最大 slots スロット。空きは未発掘の穴）。
                _DayHaul(specimens: specimens),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ツルハシのイラスト（手続き描画）。今日の発掘枠の左に置く。
class _PickaxeBadge extends StatelessWidget {
  final double size;
  const _PickaxeBadge({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          AppColors.sand.withValues(alpha: 0.22),
          AppColors.amber.withValues(alpha: 0.10),
        ]),
        border: Border.all(color: AppColors.line2),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.18),
        child: CustomPaint(painter: _PickaxePainter()),
      ),
    );
  }
}

/// ツルハシ（柄＋曲がった頭）を描く。土埃の世界観に合わせたマットな配色。
class _PickaxePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    Offset p(double x, double y) => Offset(x * s, y * s);

    // 柄（木）: 左下→右上の太いライン。
    final handle = Paint()
      ..color = const Color(0xFF8A5A33)
      ..strokeWidth = s * 0.12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(p(0.30, 0.86), p(0.66, 0.30), handle);

    // 頭（金属）: 頂部を横切る三日月状の曲線。両端が尖る。
    final head = Paint()
      ..color = const Color(0xFF6E6A66)
      ..strokeWidth = s * 0.10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final headPath = Path()
      ..moveTo(0.34 * s, 0.24 * s)
      ..quadraticBezierTo(0.66 * s, 0.06 * s, 0.92 * s, 0.40 * s);
    canvas.drawPath(headPath, head);

    // 金属のハイライト（細い明線）。
    final shine = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = s * 0.03
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final shinePath = Path()
      ..moveTo(0.40 * s, 0.20 * s)
      ..quadraticBezierTo(0.66 * s, 0.05 * s, 0.88 * s, 0.36 * s);
    canvas.drawPath(shinePath, shine);
  }

  @override
  bool shouldRepaint(covariant _PickaxePainter oldDelegate) => false;
}

/// 1日分の行: 日付ブロック＋最大 [_kSlotsPerDay] スロット。
class _DayRow extends StatelessWidget {
  final int index;
  final DateTime date;
  final List<Specimen> specimens;
  const _DayRow(
      {required this.index, required this.date, required this.specimens});

  @override
  Widget build(BuildContext context) {
    final isEmpty = specimens.isEmpty;
    // 上から順に時間差で滑り込む入場アニメ（演出強め）。
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 360 + index * 80),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateBlock(date: date, count: specimens.length, dim: isEmpty),
            const SizedBox(width: 12),
            Expanded(child: _DayHaul(specimens: specimens)),
          ],
        ),
      ),
    );
  }
}

class _DateBlock extends StatelessWidget {
  final DateTime date;
  final int count;
  final bool dim;
  const _DateBlock(
      {required this.date, required this.count, required this.dim});

  @override
  Widget build(BuildContext context) {
    final color = dim ? AppColors.inkFaint : AppColors.ink;
    return SizedBox(
      width: 40,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(date.day.toString(),
                style: TextStyle(
                    color: color, fontSize: 25, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          Text(_kWeekdayJp[date.weekday - 1],
              style: TextStyle(
                  color: dim ? AppColors.inkFaint : AppColors.inkSoft,
                  fontSize: 10)),
          const SizedBox(height: 6),
          Text('$count/$_kSlotsPerDay',
              style: const TextStyle(color: AppColors.inkFaint, fontSize: 9)),
        ],
      ),
    );
  }
}

/// その日の発掘（最大3スロット。空きは未発掘の穴）。
class _DayHaul extends StatelessWidget {
  final List<Specimen> specimens;
  const _DayHaul({required this.specimens});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < _kSlotsPerDay; i++)
          Expanded(
            child: i < specimens.length
                ? _SpecimenSlot(specimen: specimens[i])
                : const _EmptyPit(),
          ),
      ],
    );
  }
}

/// 埋まっているスロット: 標本画像＋発掘時刻＋レアタグ。タップで詳細へ。
class _SpecimenSlot extends ConsumerWidget {
  final Specimen specimen;
  const _SpecimenSlot({required this.specimen});

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

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetailScreen(specimenId: specimen.id),
        ),
      ),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.slot),
                  border: Border.all(
                    color: specimen.sealed ? AppColors.amber : AppColors.line2,
                    width: specimen.sealed ? 2 : 1,
                  ),
                  boxShadow: specimen.sealed
                      ? [
                          BoxShadow(
                            color: AppColors.amber.withValues(alpha: 0.35),
                            blurRadius: 10,
                          )
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppRadii.slot - 2),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // レア度別エフェクト背景（透過スプライトの背後）。
                      RarityBackdrop(rarity: specimen.imageRarity),
                      SpecimenImage(
                        localPath: specimen.localPath,
                        weather: weather,
                      ),
                    ],
                  ),
                ),
              ),
              if (tag != null)
                Positioned(
                  top: -7,
                  right: -7,
                  child: Text(tag, style: const TextStyle(fontSize: 14)),
                ),
            ],
          ),
          const SizedBox(height: 5),
          // 標本名（あれば）。1行省略。
          if (specimen.name != null && specimen.name!.isNotEmpty)
            Text(
              specimen.name!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 9,
                  fontWeight: FontWeight.w700),
            ),
          Text(_hhmm(specimen.createdAt),
              style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 9,
                  letterSpacing: 0.4)),
        ],
      ),
    );
  }
}

/// 空きスロット（未発掘の穴）。
class _EmptyPit extends StatelessWidget {
  const _EmptyPit();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.bgAlt,
            border: Border.all(color: AppColors.pitBorder),
          ),
        ),
        const SizedBox(height: 6),
        const Text('—',
            style: TextStyle(color: AppColors.inkFaint, fontSize: 9)),
      ],
    );
  }
}

/// カレンダー（月グリッド）。発掘済みの日に色玉、当日は枠強調。
class _CalendarSheet extends StatefulWidget {
  /// 'YYYY-MM-DD' → その日の発掘数。
  final Map<String, int> counts;
  const _CalendarSheet({required this.counts});

  @override
  State<_CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends State<_CalendarSheet> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  void _shift(int delta) {
    setState(() {
      final m = DateTime(_year, _month + delta, 1);
      _year = m.year;
      _month = m.month;
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstWeekday = DateTime(_year, _month, 1).weekday; // Mon=1..Sun=7
    final leading = firstWeekday == 7 ? 0 : firstWeekday; // 日曜始まり
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final now = DateTime.now();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left,
                      color: AppColors.inkSoft),
                  onPressed: () => _shift(-1),
                ),
                Text('$_year年 $_month月',
                    style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1)),
                IconButton(
                  icon: const Icon(Icons.chevron_right,
                      color: AppColors.inkSoft),
                  onPressed: () => _shift(1),
                ),
              ],
            ),
            // 曜日見出し
            Row(
              children: [
                for (final w in const ['日', '月', '火', '水', '木', '金', '土'])
                  Expanded(
                    child: Center(
                      child: Text(w,
                          style: const TextStyle(
                              color: AppColors.inkFaint, fontSize: 10)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 7,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
              children: [
                for (int i = 0; i < leading; i++) const SizedBox.shrink(),
                for (int day = 1; day <= daysInMonth; day++)
                  _CalDay(
                    day: day,
                    count: widget.counts[
                            '${_year.toString().padLeft(4, '0')}-${_month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}'] ??
                        0,
                    isToday: now.year == _year &&
                        now.month == _month &&
                        now.day == day,
                    onTap: () =>
                        Navigator.of(context).pop(DateTime(_year, _month, day)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const _CalLegend(),
          ],
        ),
      ),
    );
  }
}

class _CalDay extends StatelessWidget {
  final int day;
  final int count;
  final bool isToday;
  final VoidCallback onTap;
  const _CalDay({
    required this.day,
    required this.count,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final has = count > 0;
    return GestureDetector(
      onTap: has ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: has ? AppColors.amber.withValues(alpha: 0.10) : null,
          border: isToday
              ? Border.all(color: AppColors.amber, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$day',
                style: TextStyle(
                    color: has ? AppColors.ink : AppColors.inkFaint,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            if (has)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int k = 0; k < (count > 3 ? 3 : count); k++)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: AppColors.amber),
                    ),
                ],
              )
            else
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.pitBorder),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CalLegend extends StatelessWidget {
  const _CalLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: AppColors.amber)),
        const SizedBox(width: 5),
        const Text('発掘済み',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 11)),
        const SizedBox(width: 14),
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.pitBorder))),
        const SizedBox(width: 5),
        const Text('未発掘',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 11)),
      ],
    );
  }
}

/// 選択した日の標本シート（最大3スロット）。
class _DaySheet extends StatelessWidget {
  final DateTime date;
  final List<Specimen> specimens;
  const _DaySheet({required this.date, required this.specimens});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${date.month}月${date.day}日（${_kWeekdayJp[date.weekday - 1]}）の発掘',
              style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1),
            ),
            const SizedBox(height: 16),
            if (specimens.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('この日は未発掘',
                    style:
                        TextStyle(color: AppColors.inkSoft, fontSize: 13)),
              )
            else
              _DayHaul(specimens: specimens),
          ],
        ),
      ),
    );
  }
}
