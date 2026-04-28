import 'package:get_it/get_it.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_desktop/features/clients/data/repositories/clients_repository_impl.dart';
import 'package:fluxora_desktop/features/clients/domain/repositories/clients_repository.dart';
import 'package:fluxora_desktop/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:fluxora_desktop/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:fluxora_desktop/features/library/data/repositories/library_repository_impl.dart';
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';

final getIt = GetIt.instance;

Future<void> setupInjector() async {
  getIt.registerSingleton<ApiClient>(
    ApiClient(baseUrl: 'http://localhost:8080'),
  );

  getIt.registerLazySingleton<DashboardRepository>(
    () => DashboardRepositoryImpl(apiClient: getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<ClientsRepository>(
    () => ClientsRepositoryImpl(apiClient: getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<LibraryRepository>(
    () => LibraryRepositoryImpl(apiClient: getIt<ApiClient>()),
  );
}
