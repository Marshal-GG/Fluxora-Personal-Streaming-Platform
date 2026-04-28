import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:fluxora_mobile/features/auth/presentation/screens/pairing_screen.dart';
import 'package:fluxora_mobile/features/connect/domain/entities/discovered_server.dart';
import 'package:fluxora_mobile/features/connect/presentation/screens/connect_screen.dart';
import 'package:fluxora_mobile/features/library/presentation/screens/files_screen.dart';
import 'package:fluxora_mobile/features/library/presentation/screens/library_screen.dart';

abstract class Routes {
  static const String connect = '/';
  static const String pairing = '/pairing';
  static const String library = '/library';
  static String libraryFiles(String id) => '/library/$id/files';
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
      path: Routes.library,
      builder: (context, state) => const LibraryScreen(),
    ),
    GoRoute(
      path: '/library/:id/files',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final name = state.extra as String? ?? '';
        return FilesScreen(libraryId: id, libraryName: name);
      },
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

  if (isAuthenticated && onPublicRoute) return Routes.library;
  if (!isAuthenticated && !onPublicRoute) return Routes.connect;
  return null;
}
