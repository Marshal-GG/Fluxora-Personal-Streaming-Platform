import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:fluxora_mobile/features/auth/presentation/screens/pairing_screen.dart';
import 'package:fluxora_mobile/features/connect/domain/entities/discovered_server.dart';
import 'package:fluxora_mobile/features/connect/presentation/screens/connect_screen.dart';
import 'package:fluxora_mobile/features/detail/presentation/screens/detail_screen.dart';
import 'package:fluxora_mobile/features/downloads/presentation/screens/downloads_screen.dart';
import 'package:fluxora_mobile/features/episodes/presentation/screens/episodes_screen.dart';
import 'package:fluxora_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:fluxora_mobile/features/library/presentation/screens/files_screen.dart';
import 'package:fluxora_mobile/features/library/presentation/screens/library_screen.dart';
import 'package:fluxora_mobile/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:fluxora_mobile/features/player/presentation/screens/player_screen.dart';
import 'package:fluxora_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:fluxora_mobile/features/search/presentation/screens/search_screen.dart';
import 'package:fluxora_mobile/shared/widgets/mobile_shell.dart';

/// Named route paths.
///
/// The 5 tab paths (`home` / `library` / `search` / `downloads` / `profile`)
/// are nested inside the [StatefulShellRoute] and share the bottom-tab
/// chrome. Auth-gate paths (`connect`, `pairing`) and full-screen deep-link
/// paths (`player`, `libraryFiles`) bypass the shell.
abstract class Routes {
  static const String connect = '/connect';
  static const String pairing = '/pairing';

  static const String home = '/home';
  static const String library = '/library';
  static const String search = '/search';
  static const String downloads = '/downloads';
  static const String profile = '/profile';

  static String libraryFiles(String id) => '/library-files/$id';
  static const String player = '/player';

  /// Re-enters the fullscreen player screen without restarting the
  /// stream — used by the mini-player tap. The singleton `PlayerCubit`
  /// is already in `PlayerReady` state.
  static const String playerResume = '/player/resume';
  static const String notifications = '/notifications';

  static String detail(String id) => '/detail/$id';
  static String episodes(String id) => '/episodes/$id';
}

final GoRouter appRouter = GoRouter(
  initialLocation: Routes.connect,
  redirect: _guardRedirect,
  routes: [
    GoRoute(
      path: Routes.connect,
      builder: (context, state) => const ConnectScreen(),
    ),
    GoRoute(
      path: Routes.pairing,
      builder: (context, state) {
        final server = state.extra as DiscoveredServer;
        return PairingScreen(server: server);
      },
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MobileShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.library,
              builder: (context, state) => const LibraryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.search,
              builder: (context, state) => const SearchScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.downloads,
              builder: (context, state) => const DownloadsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.profile,
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/library-files/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final name = state.extra as String? ?? '';
        return FilesScreen(libraryId: id, libraryName: name);
      },
    ),
    GoRoute(
      path: Routes.player,
      builder: (context, state) {
        final file = state.extra as MediaFile;
        return PlayerScreen(file: file);
      },
    ),
    GoRoute(
      path: Routes.playerResume,
      builder: (context, state) => const PlayerScreen.resume(),
    ),
    GoRoute(
      path: Routes.notifications,
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/detail/:id',
      builder: (context, state) => DetailScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/episodes/:id',
      builder: (context, state) => EpisodesScreen(id: state.pathParameters['id']!),
    ),
  ],
);

Future<String?> _guardRedirect(
  BuildContext context,
  GoRouterState state,
) async {
  final storage = GetIt.I<SecureStorage>();
  final token = await storage.getAuthToken();
  final serverUrl = await storage.getServerUrl();

  final onPublicRoute = state.matchedLocation == Routes.connect ||
      state.matchedLocation == Routes.pairing;
  final isAuthenticated = token != null && serverUrl != null;

  if (isAuthenticated && onPublicRoute) return Routes.home;
  if (!isAuthenticated && !onPublicRoute) return Routes.connect;
  return null;
}
