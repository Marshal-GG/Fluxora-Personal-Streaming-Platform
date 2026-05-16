import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:fluxora_desktop/features/clients/data/repositories/clients_repository_impl.dart';
import 'package:fluxora_desktop/features/clients/domain/repositories/clients_repository.dart';
import 'package:fluxora_desktop/features/groups/data/repositories/groups_repository_impl.dart';
import 'package:fluxora_desktop/features/groups/domain/repositories/groups_repository.dart';
import 'package:fluxora_desktop/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:fluxora_desktop/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:fluxora_desktop/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:fluxora_desktop/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:fluxora_desktop/features/profile/domain/repositories/profile_repository.dart';
import 'package:fluxora_desktop/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:fluxora_desktop/features/transcode/data/repositories/transcode_repository_impl.dart';
import 'package:fluxora_desktop/features/transcode/domain/repositories/transcode_repository.dart';
import 'package:fluxora_desktop/features/transcode/presentation/cubit/transcode_cubit.dart';
import 'package:fluxora_desktop/features/transcoding/data/repositories/transcoding_repository_impl.dart';
import 'package:fluxora_desktop/features/transcoding/domain/repositories/transcoding_repository.dart';
import 'package:fluxora_desktop/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:fluxora_desktop/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:fluxora_desktop/features/library/data/repositories/library_repository_impl.dart';
import 'package:fluxora_desktop/features/library/data/services/library_events_service.dart';
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_cubit.dart';
import 'package:fluxora_desktop/features/logs/data/repositories/logs_repository_impl.dart';
import 'package:fluxora_desktop/features/logs/domain/repositories/logs_repository.dart';
import 'package:fluxora_desktop/features/orders/data/repositories/orders_repository_impl.dart';
import 'package:fluxora_desktop/features/orders/domain/repositories/orders_repository.dart';
import 'package:fluxora_desktop/features/orders/presentation/cubit/orders_cubit.dart';
import 'package:fluxora_desktop/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:fluxora_desktop/features/activity/domain/repositories/activity_repository.dart';
import 'package:fluxora_desktop/features/activity/data/repositories/activity_repository_impl.dart';
import 'package:fluxora_desktop/features/system_stats/data/repositories/system_stats_repository_impl.dart';
import 'package:fluxora_desktop/features/system_stats/domain/repositories/system_stats_repository.dart';
import 'package:fluxora_desktop/features/system_stats/presentation/cubit/system_stats_cubit.dart';
import 'package:fluxora_desktop/features/storage/data/repositories/storage_repository_impl.dart';
import 'package:fluxora_desktop/features/storage/domain/repositories/storage_repository.dart';
import 'package:fluxora_desktop/features/storage/presentation/cubit/storage_cubit.dart';
import 'package:fluxora_desktop/features/recent_activity/data/repositories/recent_activity_repository_impl.dart';
import 'package:fluxora_desktop/features/recent_activity/domain/repositories/recent_activity_repository.dart';

final getIt = GetIt.instance;

/// Default server URL used when nothing is stored in secure storage yet.
///
/// Port `8000` matches the server's `fluxora_port` default in
/// `apps/server/config.py`.  Earlier desktop builds defaulted to `:8080`
/// which silently broke fresh installs — the polling loop logged
/// `WSAECONNREFUSED` every 1.1 s with no UI hint that the URL just didn't
/// match the server.  Operators who already have a saved `server_url` in
/// secure storage are unaffected (`getServerUrl()` overrides this).
const _defaultServerUrl = 'http://localhost:8000';

Future<void> setupInjector() async {
  // ── Storage ─────────────────────────────────────────────────────────────────
  const flutterSecureStorage = FlutterSecureStorage(
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );
  const secureStorage = SecureStorage(flutterSecureStorage);
  getIt.registerSingleton<SecureStorage>(secureStorage);

  // ── Network ─────────────────────────────────────────────────────────────────
  // Read the persisted server URL so the first request goes to the right host.
  // Desktop hits localhost (or a single-hop LAN address) so timeouts are
  // tuned aggressively — a dead server should fail in seconds, not freeze
  // the UI for half a minute. The mobile client keeps the longer defaults
  // because cellular round-trips on weak signal can legitimately exceed 10 s.
  final savedUrl = await secureStorage.getServerUrl() ?? _defaultServerUrl;
  getIt.registerSingleton<ApiClient>(
    ApiClient(
      localBaseUrl: savedUrl,
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  // ── WS events ───────────────────────────────────────────────────────────────
  // Real-time `library_changed` / `storage_changed` push channel.  The
  // server's `/api/v1/ws/notifications` endpoint broadcasts ephemeral
  // event frames in addition to persistent notifications; this service
  // filters for the sync-event kinds and feeds the cubits.  Started
  // eagerly so the WS is live before the operator hits the Library
  // page (one TCP connection, ~zero idle overhead).
  getIt.registerSingleton<LibraryEventsService>(
    LibraryEventsService(wsUrl: libraryEventsWsUrl(savedUrl))..start(),
  );

  // ── Repositories ─────────────────────────────────────────────────────────────
  getIt.registerLazySingleton<DashboardRepository>(
    () => DashboardRepositoryImpl(apiClient: getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<ClientsRepository>(
    () => ClientsRepositoryImpl(apiClient: getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<LibraryRepository>(
    () => LibraryRepositoryImpl(apiClient: getIt<ApiClient>()),
  );
  // Library + storage cubits are singletons so navigating away from
  // the Library page and back doesn't refetch /library + /storage —
  // the cached state stays in the cubit.  First access (on first
  // Library page visit) triggers `load()`; the operator's Refresh
  // button re-fires `load()` on demand.  Subscribe to
  // [LibraryEventsService] for real-time refresh on server-side
  // mutations (replaces the older 15 s polling timer).
  getIt.registerLazySingleton<LibraryCubit>(
    () => LibraryCubit(
      repository: getIt<LibraryRepository>(),
      events: getIt<LibraryEventsService>(),
    )..load(),
  );
  
  getIt.registerLazySingleton<LogsRepository>(
    () => LogsRepositoryImpl(apiClient: getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<ActivityRepository>(
    () => ActivityRepositoryImpl(apiClient: getIt<ApiClient>()),
  );

  // ── Settings cubit ────────────────────────────────────────────────────────────
  getIt.registerFactory<SettingsCubit>(
    () => SettingsCubit(
      secureStorage: getIt<SecureStorage>(),
      apiClient: getIt<ApiClient>(),
    ),
  );

  // ── Orders ────────────────────────────────────────────────────────────────────
  getIt.registerLazySingleton<OrdersRepository>(
    () => OrdersRepositoryImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerFactory<OrdersCubit>(
    () => OrdersCubit(repository: getIt<OrdersRepository>()),
  );

  // ── System stats ─────────────────────────────────────────────────────────────
  // Polls /api/v1/info/stats every 1.1 s; one shared cubit at the shell
  // level so sidebar / status bar / Dashboard sparklines all read the same
  // ring buffer.
  getIt.registerLazySingleton<SystemStatsRepository>(
    () => SystemStatsRepositoryImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerFactory<SystemStatsCubit>(
    () => SystemStatsCubit(repository: getIt<SystemStatsRepository>()),
  );

  // ── Storage ───────────────────────────────────────────────────────────────────
  getIt.registerLazySingleton<StorageRepository>(
    () => StorageRepositoryImpl(apiClient: getIt<ApiClient>()),
  );
  // Same pattern as LibraryCubit — single instance shared across the
  // Library page's lifetime + navigations.  Refresh button re-loads
  // explicitly.  Subscribes to `storage_changed` events for real-time
  // refresh on scan / delete.
  getIt.registerLazySingleton<StorageCubit>(
    () => StorageCubit(
      repository: getIt<StorageRepository>(),
      events: getIt<LibraryEventsService>(),
    )..load(),
  );

  // ── Recent activity ───────────────────────────────────────────────────────────
  getIt.registerLazySingleton<RecentActivityRepository>(
    () => RecentActivityRepositoryImpl(apiClient: getIt<ApiClient>()),
  );

  // ── Profile ───────────────────────────────────────────────────────────────────
  getIt.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerFactory<ProfileCubit>(
    () => ProfileCubit(repository: getIt<ProfileRepository>()),
  );

  // ── Notifications ─────────────────────────────────────────────────────────────
  getIt.registerLazySingleton<NotificationsRepository>(
    () => NotificationsRepositoryImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerFactory<NotificationsCubit>(
    () => NotificationsCubit(repository: getIt<NotificationsRepository>()),
  );

  // ── Groups ────────────────────────────────────────────────────────────────────
  getIt.registerLazySingleton<GroupsRepository>(
    () => GroupsRepositoryImpl(apiClient: getIt<ApiClient>()),
  );

  // ── Transcoding ───────────────────────────────────────────────────────────────
  getIt.registerLazySingleton<TranscodingRepository>(
    () => TranscodingRepositoryImpl(apiClient: getIt<ApiClient>()),
  );

  // ── Library transcode (M5 of 18_library_transcode_plan.md) ───────────────────
  // Distinct from `Transcoding` above (live encoder status) — this drives
  // the operator-initiated AV1 / VP9 → H.264 sidecar workflow.  Cubit is
  // a factory so each TranscodeScreen mount gets a fresh polling timer.
  getIt.registerLazySingleton<TranscodeRepository>(
    () => TranscodeRepositoryImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerFactory<TranscodeCubit>(
    () => TranscodeCubit(repository: getIt<TranscodeRepository>()),
  );
}
