import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_desktop/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:fluxora_desktop/features/clients/presentation/screens/clients_screen.dart';
import 'package:fluxora_desktop/features/library/presentation/screens/library_screen.dart';
import 'package:fluxora_desktop/features/orders/presentation/screens/licenses_screen.dart';
import 'package:fluxora_desktop/features/activity/presentation/screens/activity_screen.dart';
import 'package:fluxora_desktop/features/settings/presentation/screens/settings_screen.dart';
import 'package:fluxora_desktop/shared/widgets/sidebar.dart';

class Routes {
  Routes._();

  static const String dashboard = '/';
  static const String clients = '/clients';
  static const String library = '/library';
  static const String licenses = '/licenses';
  static const String activity = '/activity';
  static const String settings = '/settings';
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
          builder: (_, _) => const DashboardScreen(),
        ),
        GoRoute(
          path: Routes.clients,
          builder: (_, _) => const ClientsScreen(),
        ),
        GoRoute(
          path: Routes.library,
          builder: (_, _) => const LibraryScreen(),
        ),
        GoRoute(
          path: Routes.licenses,
          builder: (_, _) => const LicensesScreen(),
        ),
        GoRoute(
          path: Routes.activity,
          builder: (_, _) => const ActivityScreen(),
        ),
        GoRoute(
          path: Routes.settings,
          builder: (_, _) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
