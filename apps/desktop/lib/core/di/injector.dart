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
import 'package:fluxora_desktop/features/transcoding/data/repositories/transcoding_repository_impl.dart';
import 'package:fluxora_desktop/features/transcoding/domain/repositories/transcoding_repository.dart';
import 'package:fluxora_desktop/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:fluxora_desktop/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:fluxora_desktop/features/library/data/repositories/library_repository_impl.dart';
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';
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
import 'package:fluxora_desktop/features/recent_activity/data/repositories/recent_activity_repository_impl.dart';
import 'package:fluxora_desktop/features/recent_activity/domain/repositories/recent_activity_repository.dart';

final getIt = GetIt.instance;

/// Default server URL used when nothing is stored in secure storage yet.
const _defaultServerUrl = 'http://localhost:8080';

Future<void> setupInjector() async {
  // ── Storage ─────────────────────────────────────────────────────────────────
  const flutterSecureStorage = FlutterSecureStorage(
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );
  const secureStorage = SecureStorage(flutterSecureStorage);
  getIt.registerSingleton<SecureStorage>(secureStorage);

  // ── Network ─────────────────────────────────────────────────────────────────
  // Read the persisted server URL so the first request goes to the right host.
  final savedUrl = await secureStorage.getServerUrl() ?? _defaultServerUrl;
  getIt.registerSingleton<ApiClient>(ApiClient(localBaseUrl: savedUrl));

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
}
