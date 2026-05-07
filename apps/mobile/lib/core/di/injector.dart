import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:fluxora_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:fluxora_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:fluxora_mobile/features/connect/data/repositories/server_discovery_repository_impl.dart';
import 'package:fluxora_mobile/features/connect/domain/repositories/server_discovery_repository.dart';
import 'package:fluxora_mobile/features/groups/data/repositories/groups_repository_impl.dart';
import 'package:fluxora_mobile/features/groups/domain/repositories/groups_repository.dart';
import 'package:fluxora_mobile/features/groups/presentation/cubit/groups_cubit.dart';
import 'package:fluxora_mobile/features/home/presentation/cubit/continue_watching_cubit.dart';
import 'package:fluxora_mobile/features/home/presentation/cubit/recent_cubit.dart';
import 'package:fluxora_mobile/features/library/data/repositories/library_repository_impl.dart';
import 'package:fluxora_mobile/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_mobile/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:fluxora_mobile/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:fluxora_mobile/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:fluxora_mobile/features/player/data/repositories/player_repository_impl.dart';
import 'package:fluxora_mobile/features/player/data/services/fluxora_audio_handler.dart';
import 'package:fluxora_mobile/features/player/domain/repositories/player_repository.dart';
import 'package:fluxora_mobile/features/player/presentation/cubit/player_cubit.dart';
import 'package:fluxora_mobile/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:fluxora_mobile/features/profile/presentation/cubit/profile_stats_cubit.dart';

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

  // Start with no base URL — configured after server discovery or on restart
  getIt.registerSingleton<ApiClient>(ApiClient());

  // Restore saved URLs and auth token across app restarts
  final storage = getIt<SecureStorage>();
  final serverUrl = await storage.getServerUrl();
  final remoteUrl = await storage.getRemoteUrl();
  final authToken = await storage.getAuthToken();
  if (serverUrl != null || remoteUrl != null) {
    getIt<ApiClient>().configure(
      localBaseUrl: serverUrl,
      remoteBaseUrl: remoteUrl,
      bearerToken: authToken,
    );
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

  getIt.registerLazySingleton<PlayerRepository>(
    () => PlayerRepositoryImpl(apiClient: getIt<ApiClient>()),
  );

  // M7: PlayerCubit doubles as the `PlaybackProvider` per plan §9.2 —
  // singleton scope so playback survives the fullscreen player popping
  // and the mini-player can subscribe to the same state.
  //
  // Player polish round (2026-05-04): the optional `audioHandler` is
  // looked up at construction time so it's null in unit tests (where
  // audio_service hasn't been initialised) and present in production
  // (registered in `main.dart` after `AudioService.init`).
  getIt.registerLazySingleton<PlayerCubit>(
    () => PlayerCubit(
      repository: getIt<PlayerRepository>(),
      secureStorage: getIt<SecureStorage>(),
      audioHandler: getIt.isRegistered<FluxoraAudioHandler>()
          ? getIt<FluxoraAudioHandler>()
          : null,
    ),
  );

  getIt.registerLazySingleton<NotificationsRepository>(
    () => NotificationsRepositoryImpl(apiClient: getIt<ApiClient>()),
  );

  // Singleton so the notifications screen's poll loop keeps running across
  // back-pops (the screen pushes off the stack but the live tail must stay
  // open for unread-count surfacing on the home tab bell).
  getIt.registerLazySingleton<NotificationsCubit>(
    () => NotificationsCubit(repository: getIt<NotificationsRepository>()),
  );

  // Phase A backfill — Home rail uses a singleton so re-entering the Home
  // tab does not drop the loaded list.  Pull-to-refresh on the Home tab
  // calls `RecentCubit.refresh()` to repaint the rail.
  getIt.registerLazySingleton<RecentCubit>(
    () => RecentCubit(repository: getIt<LibraryRepository>()),
  );

  // Phase B backfill — Continue-watching rail.  Same singleton-pattern
  // rationale as RecentCubit; both refresh on Home pull-to-refresh.
  getIt.registerLazySingleton<ContinueWatchingCubit>(
    () => ContinueWatchingCubit(repository: getIt<LibraryRepository>()),
  );

  // Profile cubit — singleton so the profile header survives bottom-tab
  // hops (most expensive piece is the network round-trip; once loaded
  // the cached `ClientProfile` is fine for the session unless the user
  // pulls to refresh).
  getIt.registerLazySingleton<ProfileCubit>(
    () => ProfileCubit(repository: getIt<AuthRepository>()),
  );

  // Profile-stats cubit — separate from ProfileCubit so a stats failure
  // can't blank the avatar header (and vice versa).  Singleton.
  getIt.registerLazySingleton<ProfileStatsCubit>(
    () => ProfileStatsCubit(repository: getIt<AuthRepository>()),
  );

  // Mobile groups (M4 + M8 + M6 of `13_groups_v2_content_spaces.md`).
  // Singleton scope so the Profile screen's group cards survive
  // bottom-tab hops; a successful /enter or /enroll on the first
  // visit doesn't have to repeat on the second.
  getIt.registerLazySingleton<GroupsRepository>(
    () => GroupsRepositoryImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<MobileGroupsCubit>(
    () => MobileGroupsCubit(repository: getIt<GroupsRepository>()),
  );
}
