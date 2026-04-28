import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:fluxora_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:fluxora_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:fluxora_mobile/features/connect/data/repositories/server_discovery_repository_impl.dart';
import 'package:fluxora_mobile/features/connect/domain/repositories/server_discovery_repository.dart';
import 'package:fluxora_mobile/features/library/data/repositories/library_repository_impl.dart';
import 'package:fluxora_mobile/features/library/domain/repositories/library_repository.dart';

final GetIt getIt = GetIt.instance;

Future<void> setupInjector() async {
  getIt.registerSingleton<FlutterSecureStorage>(
    const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  );

  getIt.registerSingleton<SecureStorage>(
    SecureStorage(getIt<FlutterSecureStorage>()),
  );

  // Start with empty base URL — configured after server discovery or on restart
  getIt.registerSingleton<ApiClient>(ApiClient(baseUrl: ''));

  // Restore saved server URL and auth token across app restarts
  final storage = getIt<SecureStorage>();
  final serverUrl = await storage.getServerUrl();
  final authToken = await storage.getAuthToken();
  if (serverUrl != null) {
    getIt<ApiClient>().configure(baseUrl: serverUrl, bearerToken: authToken);
  }

  getIt.registerLazySingleton<ServerDiscoveryRepository>(
    () => ServerDiscoveryRepositoryImpl(apiClient: getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      apiClient: getIt<ApiClient>(),
      secureStorage: getIt<SecureStorage>(),
    ),
  );

  getIt.registerLazySingleton<LibraryRepository>(
    () => LibraryRepositoryImpl(apiClient: getIt<ApiClient>()),
  );
}
