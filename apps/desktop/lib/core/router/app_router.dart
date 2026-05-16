import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_desktop/features/activity/presentation/screens/activity_shell.dart';
import 'package:fluxora_desktop/features/clients/presentation/screens/clients_screen.dart';
import 'package:fluxora_desktop/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:fluxora_desktop/features/groups/presentation/screens/group_edit_screen.dart';
import 'package:fluxora_desktop/features/groups/presentation/screens/groups_screen.dart';
import 'package:fluxora_desktop/features/library/presentation/screens/library_files_screen.dart';
import 'package:fluxora_desktop/features/library/presentation/screens/library_shell.dart';
import 'package:fluxora_desktop/features/help/presentation/screens/help_screen.dart';
import 'package:fluxora_desktop/features/profile/presentation/screens/profile_screen.dart';
import 'package:fluxora_desktop/features/settings/presentation/screens/settings_screen.dart';
import 'package:fluxora_desktop/features/subscription/presentation/screens/subscription_screen.dart';
import 'package:fluxora_desktop/features/transcoding/presentation/screens/encoder_settings_screen.dart';
import 'package:fluxora_desktop/shared/showcase/primitives_showcase_screen.dart';
import 'package:fluxora_desktop/shared/widgets/flux_shell.dart';

class Routes {
  Routes._();

  static const String dashboard = '/';
  static const String library = '/library';
  static String libraryFiles(String id) => '/library/$id/files';
  static const String clients = '/clients';
  static const String groups = '/groups';
  static const String groupNew = '/groups/new';
  static String groupEdit(String id) => '/groups/$id/edit';
  static const String activity = '/activity';
  // Deprecated per-tab URLs — all redirect back to the shell root.
  // The shell owns tab state internally now (IndexedStack + setState),
  // so the URL no longer encodes the active pill.  Kept as redirects
  // so old bookmarks don't 404.
  static const String libraryFolders = '/library/folders';
  static const String libraryConvert = '/library/convert';
  static const String libraryTranscoding = '/library/transcoding';
  static const String activitySessions = '/activity/sessions';
  static const String activityLogs = '/activity/logs';
  static const String transcode = '/transcode';
  static const String transcoding = '/transcoding';
  static const String logs = '/logs';
  static const String settings = '/settings';
  static const String subscription = '/subscription';
  static const String profile = '/profile';
  static const String encoderSettings = '/transcoding/encoder';
  static const String help = '/help';

  // Redesign primitives showcase — deep-link only, removed at M9 cutover.
  static const String showcase = '/showcase';
}

final appRouter = GoRouter(
  initialLocation: Routes.dashboard,
  routes: [
    // Showcase is intentionally outside the ShellRoute — it renders without
    // the sidebar/status-bar chrome so primitives sit on a clean #08061A
    // canvas for visual diff against the prototype.
    GoRoute(
      path: Routes.showcase,
      builder: (_, _) => const PrimitivesShowcaseScreen(),
    ),
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) =>
          FluxShell(child: child),
      routes: [
        GoRoute(
          path: Routes.dashboard,
          builder: (_, _) => const DashboardScreen(),
        ),
        // Library shell mounts once at /library; tab switching is
        // internal (IndexedStack + setState) so the cubits + bodies
        // stay alive across pill clicks.
        GoRoute(
          path: Routes.library,
          builder: (_, _) => const LibraryShell(),
        ),
        // Deprecated per-tab paths — redirect to the shell root.  The
        // shell restores the last-visited tab via `rememberedLibraryTab`.
        GoRoute(
          path: Routes.libraryFolders,
          redirect: (_, _) => Routes.library,
        ),
        GoRoute(
          path: Routes.libraryConvert,
          redirect: (_, _) => Routes.library,
        ),
        GoRoute(
          path: Routes.libraryTranscoding,
          redirect: (_, _) => Routes.library,
        ),
        // Literal-segment library routes match before the :id param route
        // below ('/library/folders' does NOT collide with ':id=folders').
        GoRoute(
          path: '/library/:id/files',
          builder: (_, state) =>
              LibraryFilesScreen(libraryId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: Routes.clients,
          builder: (_, _) => const ClientsScreen(),
        ),
        GoRoute(
          path: Routes.groups,
          builder: (_, _) => const GroupsScreen(),
        ),
        // Dedicated group create / edit page — plan in
        // `docs/10_planning/14_groups_management_page.md`.  `/groups/new`
        // must be registered BEFORE `/groups/:id/edit` so go_router
        // matches the literal segment instead of treating "new" as an
        // id.  The list page (`/groups`) keeps using its existing
        // create/edit modal during M1-M3 of the plan; M4 retires it.
        GoRoute(
          path: Routes.groupNew,
          builder: (_, _) => const GroupEditScreen.create(),
        ),
        GoRoute(
          path: '/groups/:id/edit',
          builder: (_, state) =>
              GroupEditScreen.edit(id: state.pathParameters['id']!),
        ),
        // Activity shell mounts once at /activity; tab switching is
        // internal so cubits + bodies stay alive across pill clicks.
        GoRoute(
          path: Routes.activity,
          builder: (_, _) => const ActivityShell(),
        ),
        GoRoute(
          path: Routes.activitySessions,
          redirect: (_, _) => Routes.activity,
        ),
        GoRoute(
          path: Routes.activityLogs,
          redirect: (_, _) => Routes.activity,
        ),
        // /transcoding (live HLS sessions) lives inside /library now;
        // /transcode (sidecar convert) does too.  /logs lives inside
        // /activity.  All three redirect to their new shell root.
        GoRoute(
          path: Routes.transcoding,
          redirect: (_, _) => Routes.library,
        ),
        GoRoute(
          path: Routes.logs,
          redirect: (_, _) => Routes.activity,
        ),
        GoRoute(
          path: Routes.transcode,
          redirect: (_, _) => Routes.library,
        ),
        GoRoute(
          path: Routes.encoderSettings,
          builder: (_, _) => const EncoderSettingsScreen(),
        ),
        GoRoute(
          path: Routes.settings,
          builder: (_, _) => const SettingsScreen(),
        ),
        GoRoute(
          path: Routes.subscription,
          builder: (_, _) => const SubscriptionScreen(),
        ),
        GoRoute(
          path: Routes.profile,
          builder: (_, _) => const ProfileScreen(),
        ),
        GoRoute(
          path: Routes.help,
          builder: (_, _) => const HelpScreen(),
        ),
      ],
    ),
  ],
);
