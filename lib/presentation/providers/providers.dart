// アプリ全体の Provider 定義。
//
// 依存グラフ:
//   appDatabaseProvider
//     ├── specimenRepositoryProvider
//     │     └── specimenListProvider (AsyncNotifierProvider)
//     └── settingsRepositoryProvider
//           ├── birthDateProvider (FutureProvider)
//           └── sealEntitlementProvider (FutureProvider)
//   saltRepositoryProvider
//     └── userSaltProvider (FutureProvider)
//
// 注意:
// - DB / リポジトリは presentation から直接触らない（必ずこのファイルの Provider 経由）。
// - salt は非同期取得（shared_preferences）。利用側は AsyncValue でローディングを考慮すること。
// - 標本画像はサーバー配信＋ローカル保存（ADR-0011）。旧ベクター生成は廃止済み。

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:specimen_box/data/db/app_database.dart' as db_lib
    show AppDatabase;
import 'package:specimen_box/data/db/app_database.dart'
    show Specimen; // Drift生成モデル（db_lib.AppDatabase が依存）
import 'package:specimen_box/data/db/connection/connection.dart';
import 'package:specimen_box/data/questions/question_loader.dart';
import 'package:specimen_box/data/repositories/salt_repository.dart';
import 'package:specimen_box/data/repositories/settings_repository.dart';
import 'package:specimen_box/data/repositories/specimen_repository.dart';
import 'package:specimen_box/data/services/specimen_image_service.dart';
import 'package:specimen_box/domain/purchase/seal_entitlement.dart';
import 'package:specimen_box/domain/questions/daily_question.dart';
import 'package:specimen_box/domain/questions/next_question_resolver.dart';
import 'package:specimen_box/domain/specimen/specimen.dart'
    as domain show Specimen;
import 'package:specimen_box/platform/api/api_config.dart';
import 'package:specimen_box/platform/api/http_specimen_api.dart';
import 'package:specimen_box/platform/api/specimen_api.dart';
import 'package:specimen_box/platform/image_store/file_image_store.dart';
import 'package:specimen_box/platform/image_store/image_downloader.dart';
import 'package:specimen_box/platform/image_store/image_store.dart';
import 'package:specimen_box/platform/notifications/ios_notification_service.dart';
import 'package:specimen_box/platform/notifications/notification_service.dart';
import 'package:specimen_box/platform/purchase/ios_purchase_service.dart';
import 'package:specimen_box/platform/purchase/purchase_service.dart';

// ---------------------------------------------------------------------------
// DB / リポジトリ層 Provider
// ---------------------------------------------------------------------------

/// AppDatabase の Provider。
///
/// アプリ起動時に1インスタンス生成し、dispose 時に close する。
final appDatabaseProvider = Provider<db_lib.AppDatabase>((ref) {
  final database = db_lib.AppDatabase(openConnection('specimen_box.db'));
  ref.onDispose(database.close);
  return database;
});

/// SpecimenRepository の Provider。
final specimenRepositoryProvider = Provider<SpecimenRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return SpecimenRepository(database.specimensDao);
});

/// SettingsRepository の Provider。
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return SettingsRepository(database.settingsDao);
});

/// 保存済み生年月日の Provider。
///
/// - 未設定の場合は null を返す。
/// - 利用側は AsyncValue でローディング/エラーを考慮すること。
final birthDateProvider = FutureProvider<DateTime?>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.getBirthDate();
});

/// 封印エンタイトルメントの Provider。
///
/// - 未設定の場合は `SealEntitlement(unlocked: false, credits: 0)` を返す。
/// - 利用側は AsyncValue でローディング/エラーを考慮すること。
final sealEntitlementProvider = FutureProvider<SealEntitlement>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.getSealEntitlement();
});

// ---------------------------------------------------------------------------
// Salt Provider
// ---------------------------------------------------------------------------

/// SharedPreferences の Provider（非同期初期化）。
final _sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

/// SaltRepository の Provider。
final saltRepositoryProvider = FutureProvider<SaltRepository>((ref) async {
  final prefs = await ref.watch(_sharedPreferencesProvider.future);
  return SaltRepository(prefs);
});

/// userSalt の Provider。
///
/// 初回起動時に生成・永続化、以降は同値を返す（不変）。
/// 利用側は AsyncValue でローディング/エラーを考慮すること。
final userSaltProvider = FutureProvider<String>((ref) async {
  final repo = await ref.watch(saltRepositoryProvider.future);
  return repo.getSalt();
});

// ---------------------------------------------------------------------------
// Drift Specimen → domain Specimen 変換
// ---------------------------------------------------------------------------

/// Drift 生成の [Specimen] を domain の [domain.Specimen] に変換する。
domain.Specimen _toDomain(Specimen row) {
  return domain.Specimen(
    id: row.id,
    answer: row.answerText,
    questionId: row.questionId,
    questionText: row.questionText,
    date: row.date,
    status: row.status,
    createdAt: row.createdAt,
    imageId: row.imageId,
    localPath: row.localPath,
    imageRarity: row.imageRarity,
    name: row.name,
  );
}

// ---------------------------------------------------------------------------
// 標本リスト Provider（AsyncNotifier）
// ---------------------------------------------------------------------------

/// 標本リストの AsyncNotifier。
///
/// - [build]: DB から全件を新しい順で取得し domain.Specimen に変換して返す。
/// - [add]: 新しい domain.Specimen を保存してリストを再読込する。
/// - [seal]: 指定 id を sealed に一方向更新して保存→リストを再読込する（ADR-0010 決定3）。
class SpecimenListNotifier
    extends AsyncNotifier<List<domain.Specimen>> {
  @override
  Future<List<domain.Specimen>> build() async {
    final repo = ref.watch(specimenRepositoryProvider);
    final rows = await repo.getAll();
    return rows.map(_toDomain).toList();
  }

  /// 新しい Specimen を DB に保存してリストを再読込する。
  Future<void> add(domain.Specimen specimen) async {
    final repo = ref.read(specimenRepositoryProvider);
    await repo.save(
      id: specimen.id,
      date: specimen.date,
      questionId: specimen.questionId,
      questionText: specimen.questionText,
      answerText: specimen.answer,
      status: specimen.status,
      createdAt: specimen.createdAt,
      imageId: specimen.imageId,
      localPath: specimen.localPath,
      imageRarity: specimen.imageRarity,
      name: specimen.name,
    );
    // リスト再読込
    ref.invalidateSelf();
    await future;
  }

  /// [id] の標本を sealed に**一方向**で更新して保存→リストを再読込する。
  ///
  /// ADR-0010 決定3: 封印は永久・解除導線は持たない。
  Future<void> seal(String id) async {
    final repo = ref.read(specimenRepositoryProvider);
    await repo.seal(id);
    ref.invalidateSelf();
    await future;
  }

  /// 1回の起動で再取得を試みる deferred 標本の最大件数。
  ///
  /// 長期オフライン後に deferred が大量に溜まっても、起動直後に直列 API 呼び出しで
  /// 帯域・バッテリを圧迫しないよう上限を設ける。超過分は次回起動に持ち越す。
  static const int _kRetryLimit = 5;

  /// 画像未取得（deferred）の標本をオンライン復帰時に再取得する（ADR-0011 決定6）。
  ///
  /// - best-effort: 失敗した標本はそのまま deferred を維持（次回再試行）。
  /// - 1回の起動で最大 [_kRetryLimit] 件まで。残りは次回に持ち越す。
  /// - 1件でも確定したらリストを再読込する。例外は投げない（呼び出しは fire-and-forget 可）。
  Future<void> retryDeferredImages() async {
    final repo = ref.read(specimenRepositoryProvider);
    final settings = ref.read(settingsRepositoryProvider);
    final SpecimenImageService service;
    try {
      service = await ref.read(specimenImageServiceProvider.future);
    } catch (_) {
      return; // 取得経路が使えない（オフライン等）。
    }

    final deferred = await repo.findDeferred();
    if (deferred.isEmpty) return;
    final targets = deferred.take(_kRetryLimit);

    var updated = false;
    for (final row in targets) {
      try {
        final owned = await settings.getOwnedImageIds();
        final acquired = await service.acquire(owned: owned);
        if (acquired.isFetched) {
          await repo.setImage(row.id, acquired.imageId!, acquired.localPath!,
              rarity: acquired.rarity, name: acquired.name);
          await settings.addOwnedImageId(acquired.imageId!);
          updated = true;
        } else if (acquired.exhausted) {
          // プール枯渇: これ以上引いても無駄なので中断（次回再試行）。
          break;
        }
        // deferred（ネット失敗）のときはこの標本をスキップし次へ。
      } catch (_) {
        // 個別失敗は無視して次の標本へ。
      }
    }

    if (updated) {
      ref.invalidateSelf();
      await future;
    }
  }
}

/// 標本リストの Provider。
final specimenListProvider =
    AsyncNotifierProvider<SpecimenListNotifier, List<domain.Specimen>>(
  SpecimenListNotifier.new,
);

// ---------------------------------------------------------------------------
// 通知サービス Provider
// ---------------------------------------------------------------------------

/// [NotificationService] の Provider。
///
/// iOS 実装（[IosNotificationService]）を返す。
/// テストでは `ProviderScope` の `overrides` で `NoopNotificationService` や
/// `FakeNotificationService` に差し替えることで通知副作用を排除できる。
///
/// 非 iOS プラットフォーム（web / 未サポート OS）では [noopNotificationService] に
/// フォールバックし、既存の widget / unit テストを壊さない。
final notificationServiceProvider = FutureProvider<NotificationService>((ref) async {
  // テスト環境や非 iOS では no-op にフォールバック。
  // Platform.isIOS は dart:io が使えない環境（web）では例外になるため try-catch で保護。
  try {
    if (!Platform.isIOS) return noopNotificationService;
  } catch (_) {
    // web 等 dart:io 非対応環境。
    return noopNotificationService;
  }
  return IosNotificationService.init();
});

// ---------------------------------------------------------------------------
// 購入サービス Provider
// ---------------------------------------------------------------------------

/// [PurchaseService] の Provider。
///
/// iOS では [IosPurchaseService]（`in_app_purchase`/StoreKit）を返す。
/// 非 iOS（web / テスト / 未サポート OS）では [noopPurchaseService] にフォールバックする。
/// テストでは `ProviderScope` の `overrides` で [FakePurchaseService] に差し替える。
///
/// 実 StoreKit の購入/復元 e2e は Sandbox 実機で確認する（ADR-0010 決定6）。
final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  // Platform.isIOS は dart:io 非対応環境（web）では例外になるため try-catch で保護。
  try {
    if (!Platform.isIOS) return noopPurchaseService;
  } catch (_) {
    return noopPurchaseService;
  }
  final service = IosPurchaseService.create();
  ref.onDispose(service.dispose);
  return service;
});

// ---------------------------------------------------------------------------
// サーバー API Provider（specimen-box-server 疎通 / ADR-0011・server ADR-0004）
// ---------------------------------------------------------------------------

/// http クライアントの Provider（dispose で close）。
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// API 接続設定（base URL・App キー）。`--dart-define` から構築。
final apiConfigProvider = Provider<ApiConfig>((ref) {
  return ApiConfig.fromEnvironment();
});

/// 匿名端末トークン（get-or-create・永続）。server ADR-0005 のレート鍵。
final deviceTokenProvider = FutureProvider<String>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.getOrCreateDeviceToken();
});

/// [SpecimenApi] の Provider（http 実装）。
///
/// 端末トークン取得が非同期のため `FutureProvider<SpecimenApi>`。テストでは
/// `specimenApiProvider.overrideWith((ref) async => FakeSpecimenApi())` で差し替える。
final specimenApiProvider = FutureProvider<SpecimenApi>((ref) async {
  final config = ref.watch(apiConfigProvider);
  final client = ref.watch(httpClientProvider);
  final token = await ref.watch(deviceTokenProvider.future);
  return HttpSpecimenApi(config: config, client: client, deviceToken: token);
});

/// 「次の問い」を解決するサービス（ADR-0013: 通知ごとに別のランダム問い）。
///
/// 問いは**開くたびに新規取得**する（日替わり安定＝同日は同じ、は撤回）。サーバー取得＋
/// recent 窓 push（直近重複回避）、オフライン時は recent を避けたローカル選択。
///
/// [FutureProvider] で結果をキャッシュすると「同じ問いが返り続ける」ため、毎回新規取得できる
/// サービス（メソッド呼び出しごとに解決）として公開する。解決ロジックは `resolveNextQuestion`
/// （domain・Fake でユニットテスト可能）に委譲し、ここは Provider/IF/Repo の配線のみを行う。
class NextQuestionService {
  NextQuestionService(this._ref);

  final Ref _ref;

  /// 次の問いを1問解決して返す（呼ぶたびに新規取得）。
  Future<QuestionData> next() {
    final settings = _ref.read(settingsRepositoryProvider);
    return resolveNextQuestion(
      fetchRemote: () async {
        final api = await _ref.read(specimenApiProvider.future);
        final recent = await settings.getRecentQuestionIds();
        final localTime = _ref.read(nowProvider);
        final next =
            await api.fetchNextQuestion(recent: recent, localTime: localTime);
        return RemoteQuestionData(
          id: next.question.id,
          text: next.question.text,
          category: next.question.category,
          condition: next.question.condition,
        );
      },
      pushRecent: settings.pushRecentQuestionId,
      localFallback: () async {
        final salt = await _ref.read(userSaltProvider.future);
        final candidates = await QuestionLoader.loadAll();
        final recent = await settings.getRecentQuestionIds();
        return pickFreshLocalQuestion(candidates, salt, recent);
      },
    );
  }
}

/// [NextQuestionService] の Provider。テストでは specimenApiProvider を Fake に差し替える。
final nextQuestionServiceProvider =
    Provider<NextQuestionService>((ref) => NextQuestionService(ref));

/// 画像ローカル保存層（ADR-0011 決定4）。本番は [FileImageStore]。テストは Fake で override。
final imageStoreProvider = Provider<ImageStore>((ref) => const FileImageStore());

/// 画像URL→バイトのダウンローダ。`httpClientProvider` を共有。
final imageDownloaderProvider = Provider<ImageDownloader>((ref) {
  return HttpImageDownloader(client: ref.watch(httpClientProvider));
});

/// 画像取得＋ローカル保存サービス（draw→DL→save）。
final specimenImageServiceProvider =
    FutureProvider<SpecimenImageService>((ref) async {
  final api = await ref.watch(specimenApiProvider.future);
  return SpecimenImageService(
    api: api,
    store: ref.watch(imageStoreProvider),
    downloader: ref.watch(imageDownloaderProvider),
  );
});


// ---------------------------------------------------------------------------
// 現在時刻 Provider
// ---------------------------------------------------------------------------

/// 現在時刻の Provider。60秒ごとに自動更新（live-tick）。
///
/// `DateTime.now()` を画面に直書きせず、ここ経由で供給することで
/// テスト/デモ時に `ProviderScope` で `overrideWithValue(固定DateTime)` できる。
/// Timer は `onDispose` でキャンセルされるためリークしない。
// 注意: invalidateSelf + Timer.periodic は Riverpod3 の dispose→再生成挙動に依存。
// Riverpod メジャー更新時は二重タイマー / 孤立タイマーが発生しないことを再検証すること。
final nowProvider = Provider<DateTime>((ref) {
  final timer = Timer.periodic(
    const Duration(seconds: 60),
    (_) => ref.invalidateSelf(),
  );
  ref.onDispose(timer.cancel);
  return DateTime.now();
});
