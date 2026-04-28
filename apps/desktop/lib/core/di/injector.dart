import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:fluxora_desktop/features/clients/data/repositories/clients_repository_impl.dart';
import 'package:fluxora_desktop/features/clients/domain/repositories/clients_repository.dart';
import 'package:fluxora_desktop/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:fluxora_desktop/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:fluxora_desktop/features/library/data/repositories/library_repository_impl.dart';
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_desktop/features/settings/presentation/cubit/settings_cubit.dart';

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
  getIt.registerSingleton<ApiClient>(ApiClient(baseUrl: savedUrl));

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

  // ── Settings cubit ────────────────────────────────────────────────────────────
  getIt.registerFactory<SettingsCubit>(
    () => SettingsCubit(
      secureStorage: getIt<SecureStorage>(),
      apiClient: getIt<ApiClient>(),
    ),
  );
}
