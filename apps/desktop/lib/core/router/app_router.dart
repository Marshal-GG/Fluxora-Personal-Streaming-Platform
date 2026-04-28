import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_desktop/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:fluxora_desktop/features/clients/presentation/screens/clients_screen.dart';
import 'package:fluxora_desktop/features/library/presentation/screens/library_screen.dart';
import 'package:fluxora_desktop/shared/widgets/sidebar.dart';

class Routes {
  Routes._();

  static const String dashboard = '/';
  static const String clients = '/clients';
  static const String library = '/library';
}

final appRouter = GoRouter(
  initialLocation: Routes.dashboard,
  routes: [
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) =>
          AppShell(child: child),
      routes: [
        GoRoute(
          path: Routes.dashboard,
          builder: (_, __) => const DashboardScreen(),
        ),
        GoRoute(
          path: Routes.clients,
          builder: (_, __) => const ClientsScreen(),
        ),
        GoRoute(
          path: Routes.library,
          builder: (_, __) => const LibraryScreen(),
        ),
      ],
    ),
  ],
);
