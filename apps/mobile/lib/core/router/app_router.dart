import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:fluxora_mobile/features/auth/presentation/screens/pairing_screen.dart';
import 'package:fluxora_mobile/features/auth/presentation/screens/reconnect_screen.dart';
import 'package:fluxora_mobile/features/connect/domain/entities/discovered_server.dart';
import 'package:fluxora_mobile/features/connect/presentation/screens/connect_screen.dart';
import 'package:fluxora_mobile/features/connect/presentation/screens/scan_qr_screen.dart';
import 'package:fluxora_mobile/features/detail/presentation/screens/detail_screen.dart';
// Downloads screen is hidden in v1 (decision §5 row 4); the file stays
// in tree so re-enabling for v1.1 / Phase E is a one-line restoration.
// import 'package:fluxora_mobile/features/downloads/presentation/screens/downloads_screen.dart';
import 'package:fluxora_mobile/features/episodes/presentation/screens/episodes_screen.dart';
import 'package:fluxora_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:fluxora_mobile/features/library/presentation/screens/files_screen.dart';
import 'package:fluxora_mobile/features/library/presentation/screens/library_screen.dart';
import 'package:fluxora_mobile/features/group_watch/presentation/screens/group_watch_screen.dart';
import 'package:fluxora_mobile/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:fluxora_mobile/features/offline/presentation/screens/offline_screen.dart';
import 'package:fluxora_mobile/features/player/presentation/screens/player_screen.dart';
import 'package:fluxora_mobile/features/xray/presentation/screens/xray_screen.dart';
import 'package:fluxora_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:fluxora_mobile/features/search/presentation/screens/search_screen.dart';
import 'package:fluxora_mobile/shared/widgets/mobile_shell.dart';

/// Named route paths.
///
/// The 4 tab paths (`home` / `library` / `search` / `profile`) are
/// nested inside the [StatefulShellRoute] and share the bottom-tab
/// chrome. The Downloads tab is hidden in v1 (decision §5 row 4 of
/// the real-data backfill plan) — `downloads_screen.dart` stays in the
/// tree so Phase E / v1.1 can restore it without rebuilding the screen.
/// Auth-gate paths (`connect`, `pairing`, `reconnect`) and full-screen
/// deep-link paths (`player`, `libraryFiles`) bypass the shell.
abstract class Routes {
  static const String connect = '/connect';
  static const String pairing = '/pairing';

  /// Lost-token recovery (Phase A backfill plan §9.2). Reached when the
  /// bearer token is dead but `client_id` + `server_url` are still in
  /// secure storage. The screen re-fires `POST /auth/request-pair`
  /// against the saved server; the operator approves it again and a
  /// fresh token replaces the dead one.
  static const String reconnect = '/reconnect';

  /// QR-code pairing scanner — fallback path when mDNS discovery can't
  /// reach the server.  Camera reads the canonical
  /// `fluxora://pair?host=&port=&name=` payload rendered by the desktop
  /// control panel (see `PairingUri`).
  static const String scanQr = '/scan-qr';

  static const String home = '/home';
  static const String library = '/library';
  static const String search = '/search';
  static const String profile = '/profile';

  /// Library tab pre-filtered by content-type.  Consumed by the Home
  /// browse strip and the Search empty-state chip group (mobile redesign
  /// plan §17.2 trending replacement).  Valid filter values match the
  /// library screen's `_LibraryFilter` enum: `movies`, `shows`, `music`,
  /// `files`.  Anything else falls back to the unfiltered tab.
  static String libraryWithFilter(String filter) => '/library?filter=$filter';

  static String libraryFiles(String id) => '/library-files/$id';
  static const String player = '/player';

  /// Re-enters the fullscreen player screen without restarting the
  /// stream — used by the mini-player tap. The singleton `PlayerCubit`
  /// is already in `PlayerReady` state.
  static const String playerResume = '/player/resume';
  static const String notifications = '/notifications';

  /// Offline empty state — "You're offline / Retry connection"
  /// (mobile redesign plan §M10).  v1: route registered, screen
  /// rendered, but no live connectivity detector wired yet (no
  /// `connectivity_plus` in pubspec).  v1.1 plug-in target.
  static const String offline = '/offline';

  /// X-Ray side panel over the player (mobile redesign plan §M10).
  /// v1 ships as a UI shell with static cast + trivia fixtures —
  /// per decision §1 row 4 "X-Ray uses static cast metadata only";
  /// live ML / TMDB-credits wiring is v1.1 / Phase C of the real-data
  /// backfill plan.  Pushed with `extra: MediaFile` so the screen can
  /// render the source title in its app bar.
  static const String xray = '/xray';

  /// Group Watch (party / co-watch) over the player (mobile redesign
  /// plan §M10).  v1 ships as a UI shell — multi-client sync is
  /// Phase 5+ per decision §1 row 4 "Group Watch is a 'coming soon'
  /// placeholder that opens but cannot start a session".  Not to be
  /// confused with "Client Groups" / Groups v2.  Pushed with `extra:
  /// String` (the source title) so the hero card can render it.
  static const String groupWatch = '/group-watch';

  static String detail(String id) => '/detail/$id';
  static String episodes(String id) => '/episodes/$id';
}

/// Listens to [ApiClient.unauthorizedStream] so a dead token triggered by
/// any in-flight request mid-session bumps the user to `/reconnect`.
/// Initialised by `setupRouterUnauthorizedBridge()` after `setupInjector()`
/// completes; safe to call once at app start.
StreamSubscription<void>? _unauthorizedSub;

void setupRouterUnauthorizedBridge() {
  if (_unauthorizedSub != null) return;
  final client = GetIt.I<ApiClient>();
  _unauthorizedSub = client.unauthorizedStream.listen((_) {
    final loc = appRouter.routerDelegate.currentConfiguration.uri.path;
    // Don't yank the user out of pairing flows — the user is already
    // dealing with credential state on those screens.  /home and the
    // five tab routes (and any deep-link route) are the surfaces where
    // a dead token surprises the user mid-action; redirect those.
    const pairingFlows = {
      Routes.connect,
      Routes.pairing,
      Routes.reconnect,
    };
    if (pairingFlows.contains(loc)) return;
    appRouter.go(Routes.reconnect);
  });
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
    GoRoute(
      path: Routes.reconnect,
      builder: (context, state) => const ReconnectScreen(),
    ),
    GoRoute(
      path: Routes.scanQr,
      builder: (context, state) => const ScanQrScreen(),
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
              builder: (context, state) => LibraryScreen(
                initialFilter: state.uri.queryParameters['filter'],
              ),
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
      path: Routes.offline,
      builder: (context, state) {
        // `extra` may carry a server name string from a future
        // connectivity-watcher push; null is the safe default.
        final extra = state.extra;
        return OfflineScreen(
          serverName: extra is String ? extra : null,
        );
      },
    ),
    GoRoute(
      path: Routes.xray,
      builder: (context, state) {
        // `extra` may be a MediaFile (full detail-side push) or a
        // String (player chrome only carries fileName).  Anything
        // else falls back to the generic "X-Ray" title.
        final extra = state.extra;
        return XRayScreen(
          file: extra is MediaFile ? extra : null,
          title: extra is String ? extra : null,
        );
      },
    ),
    GoRoute(
      path: Routes.groupWatch,
      builder: (context, state) {
        // `extra` is the source title; null falls back to a generic
        // "this stream" copy in the hero card.
        final extra = state.extra;
        return GroupWatchScreen(
          title: extra is String ? extra : null,
        );
      },
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
      state.matchedLocation == Routes.pairing ||
      state.matchedLocation == Routes.reconnect ||
      state.matchedLocation == Routes.scanQr;
  final isAuthenticated = token != null && serverUrl != null;

  // Authenticated users hitting /connect or /pairing get bounced to /home.
  // /reconnect is exempt — an authenticated user opting to re-pair (after
  // an explicit "Reconnect to server" tap, say) shouldn't be reflected
  // back to /home before the screen can re-fire the request.
  if (isAuthenticated &&
      (state.matchedLocation == Routes.connect ||
          state.matchedLocation == Routes.pairing)) {
    return Routes.home;
  }
  if (!isAuthenticated && !onPublicRoute) return Routes.connect;
  return null;
}
