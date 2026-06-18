import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:specimen_box/domain/notification/notification_scheduler.dart';
import 'package:specimen_box/domain/notification/notify_time.dart';
import 'package:specimen_box/presentation/answer/answer_screen.dart';
import 'package:specimen_box/presentation/home/home_screen.dart';
import 'package:specimen_box/presentation/onboarding/onboarding_screen.dart';
import 'package:specimen_box/presentation/providers/providers.dart';
import 'package:specimen_box/presentation/theme/app_tokens.dart';

/// アプリ全体で共有するナビゲーターキー。
///
/// 通知タップハンドラ（foreground/background/cold start）が
/// Widget ツリーの外から画面遷移を行うために使用する。
/// GlobalKey の同一性を保証するため、providers には置かずトップレベルで定義する。
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// **実機テスト用フラグ**: 通知を高頻度で発火させて配信/タップ導線を検証する。
///
/// 通常起動（本番）は false。検証時は次のように起動する:
/// `flutter run --dart-define=NOTIFY_TEST_MODE=true`
/// 間隔・件数も上書き可:
/// `--dart-define=NOTIFY_TEST_INTERVAL=20 --dart-define=NOTIFY_TEST_COUNT=8`
const bool kNotifyTestMode = bool.fromEnvironment('NOTIFY_TEST_MODE');

/// テスト通知の間隔（秒）。既定 30 秒。
const int kNotifyTestIntervalSeconds =
    int.fromEnvironment('NOTIFY_TEST_INTERVAL', defaultValue: 30);

/// テスト通知の件数。既定 5 件。
const int kNotifyTestCount =
    int.fromEnvironment('NOTIFY_TEST_COUNT', defaultValue: 5);

/// yyyymmdd 文字列（または null）を解析して [AnswerScreen] に遷移するヘルパ。
///
/// - [payload] が有効な yyyymmdd 文字列なら、その日付の [AnswerScreen] に遷移する。
/// - null または不正な文字列なら、[AnswerScreen(targetDate: null)]（当日）に遷移する。
/// - [navigatorKey.currentState] が未準備の場合は何もしない。
void navigateToDailyQuestion(String? payload) {
  final date = yyyymmddStringToDate(payload);
  navigatorKey.currentState?.push(
    MaterialPageRoute<void>(
      builder: (_) => AnswerScreen(targetDate: date),
    ),
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      child: _AppWithNotification(),
    ),
  );
}

/// 起動時に通知の初期化・先行スケジュールを行うラッパー Widget。
///
/// `ProviderScope` 配下の `ConsumerWidget` として Riverpod provider を利用する。
/// 通知の初期化はバックグラウンドで行い、失敗しても起動を止めない。
class _AppWithNotification extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AppWithNotification> createState() =>
      _AppWithNotificationState();
}

class _AppWithNotificationState extends ConsumerState<_AppWithNotification> {
  @override
  void initState() {
    super.initState();
    // 起動後に通知の初期化と先行スケジュールを非同期で行う。
    // await せず fire-and-forget にして UI 表示を遅延させない。
    _scheduleNotificationsOnLaunch();
    // ADR-0011 決定6: 画像未取得（deferred）の標本をオンライン復帰時に再取得する。
    // fire-and-forget（失敗しても UI を妨げない・例外は notifier 側で握る）。
    ref.read(specimenListProvider.notifier).retryDeferredImages();
  }

  Future<void> _scheduleNotificationsOnLaunch() async {
    try {
      // 通知サービスと userSalt を取得（非同期）。
      final svc = await ref.read(notificationServiceProvider.future);
      final salt = await ref.read(userSaltProvider.future);

      // T5(a): foreground/background タップハンドラの登録。
      // payload（yyyymmdd 文字列）を受け取り、当日の問い画面に遷移する。
      svc.onTap(navigateToDailyQuestion);

      // 権限要求（初回のみダイアログが出る。以降は即時 true/false が返る）。
      await svc.requestPermission();

      if (kNotifyTestMode) {
        // 実機テスト用: 既存をクリアし、直近に高頻度で通知を積む。
        // タップで当日の問い（AnswerScreen）が開くことを素早く検証する。
        await svc.cancelAll();
        final payload = dateToYyyymmdd(DateTime.now()).toString();
        final planned = computeTestSchedule(
          now: DateTime.now(),
          payload: payload,
          count: kNotifyTestCount,
          intervalSeconds: kNotifyTestIntervalSeconds,
        );
        for (final item in planned) {
          await svc.scheduleAt(
            id: item.id,
            when: item.when,
            payload: item.payload,
          );
        }
      } else {
        // 本番: 数日先まで先行スケジュール（既存 pending との重複は自動回避）。
        await reconcile(
          svc,
          now: DateTime.now(),
          userSalt: salt,
        );
      }

      // T5(b): cold start（終了状態からの通知タップ）の処理。
      // 通知タップで起動した場合の payload を取得し、非 null なら遷移する。
      // navigatorKey.currentState はフレーム描画後に準備されるため
      // addPostFrameCallback で遷移を遅延させる。
      final launchPayload = await svc.initialPayload();
      if (launchPayload != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigateToDailyQuestion(launchPayload);
        });
      }
      // null なら通常起動（通知経由でない）→ 何もしない。
    } catch (e, st) {
      // 通知の失敗はアプリ起動を止めない（サイレント処理）。
      debugPrint('通知スケジュール失敗（無視）: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SpecimenBoxApp();
  }
}

/// 起動時に生年月日の設定状態を確認し、未設定ならオンボーディングに振り分けるゲート。
///
/// - loading: 既存トーンのスピナーを表示する。
/// - error: サイレント処理でホームにフォールバックする（DB 読み取り失敗で起動不能にしない）。
/// - data == null: [OnboardingScreen] を表示する。
/// - data != null: [HomeScreen] を表示する。
class _HomeGate extends ConsumerWidget {
  const _HomeGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final birthDate = ref.watch(birthDateProvider);
    return birthDate.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: AppColors.amber,
          ),
        ),
      ),
      // ignore: avoid_unused_parameters
      error: (e, s) => const HomeScreen(),
      data: (value) =>
          value == null ? const OnboardingScreen() : const HomeScreen(),
    );
  }
}

class SpecimenBoxApp extends StatelessWidget {
  /// 起動タイトル演出（[_SplashScreen]）をスキップするか。
  /// 既定 false（本番起動では演出を表示）。テストでは true を渡して即ゲートへ。
  final bool skipSplash;

  const SpecimenBoxApp({super.key, this.skipSplash = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: '化石箱',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja'), Locale('en')],
      locale: const Locale('ja'),
      theme: ThemeData(
        brightness: Brightness.light,
        // 丸ゴシック（発掘×ポップ）をアプリ全体の既定書体にする。
        fontFamily: 'ZenMaruGothic',
        colorScheme: ColorScheme.light(
          surface: AppColors.bg,
          primary: AppColors.coral,
          secondary: AppColors.amber,
          onSurface: AppColors.ink,
          outline: AppColors.line2,
        ),
        scaffoldBackgroundColor: AppColors.bg,
        textTheme: const TextTheme(
          // 画面タイトル（例: 「標本箱」）。丸ゴシックの太字感を weight で近似。
          displaySmall: TextStyle(
            color: AppColors.ink,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
          ),
          bodyMedium: TextStyle(
            color: AppColors.inkSoft,
            fontSize: 13,
            height: 1.8,
          ),
        ),
        useMaterial3: true,
      ),
      home: skipSplash ? const _HomeGate() : const _SplashGate(),
    );
  }
}

/// 起動タイトル演出 → 完了後にゲートへ切り替えるラッパー。
class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    if (_done) return const _HomeGate();
    return _SplashScreen(onDone: () {
      if (mounted) setState(() => _done = true);
    });
  }
}

/// 起動タイトル演出（[[画面仕様]] §3.1）。
///
/// 土の欠片が集まりアプリ名「標本箱」が立ち上がり、地層ライン＋メッセージ
/// 「日々の問いは、未発掘の地層」を提示する。タップで即スキップ。
class _SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  const _SplashScreen({required this.onDone});

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) _finish();
      });
    _c.forward();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg(double t, double start, double end) =>
      ((t - start) / (end - start)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _finish,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              final kicker = _seg(t, 0.05, 0.35);
              final title = Curves.easeOutBack.transform(_seg(t, 0.15, 0.6));
              final strata = _seg(t, 0.55, 0.85);
              final tag = _seg(t, 0.6, 0.95);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: kicker,
                    child: const Text(
                      'E X C A V A T E   T H E   E V E R Y D A Y',
                      style: TextStyle(
                          color: AppColors.coral,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 4),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Opacity(
                    opacity: title.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.6 + 0.4 * title.clamp(0.0, 1.0),
                      child: const Text(
                        '化石箱',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // 地層ライン
                  Opacity(
                    opacity: strata,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _strata(AppColors.amber, 60 * strata),
                        const SizedBox(width: 5),
                        _strata(AppColors.moss, 90 * strata),
                        const SizedBox(width: 5),
                        _strata(AppColors.mustard, 50 * strata),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Opacity(
                    opacity: tag,
                    child: Transform.translate(
                      offset: Offset(0, 10 * (1 - tag)),
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1),
                          children: [
                            TextSpan(text: '日々の問いは、'),
                            TextSpan(
                                text: '未発掘',
                                style: TextStyle(color: AppColors.coral)),
                            TextSpan(text: 'の地層'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _strata(Color color, double width) => Container(
        width: width.clamp(0.0, 100.0),
        height: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      );
}
