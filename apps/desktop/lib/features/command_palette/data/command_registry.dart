/// CommandRegistry — static list of all commands available in the Cmd+K palette.
///
/// Navigation commands: one per route (matches [Routes] in app_router.dart).
/// Server actions: Restart / Stop via [DashboardRepository].
/// Panel actions: Open Notifications.
///
/// The registry is rebuilt each time [buildCommandRegistry] is called so that
/// action closures always capture the latest [BuildContext] and [GoRouter].
library;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';

import 'package:fluxora_desktop/features/command_palette/domain/command.dart';
import 'package:fluxora_desktop/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:fluxora_desktop/shared/widgets/flux_shell.dart';

/// Builds the full command list for a given [context].
///
/// Call this once per palette open so closures capture a fresh context.
List<Command> buildCommandRegistry(BuildContext context) {
  final log = Logger();

  return [
    // ── Navigation ──────────────────────────────────────────────────────────
    const Command(
      id: 'nav.dashboard',
      label: 'Go to Dashboard',
      subtitle: 'Server overview and stats',
      icon: Icons.dashboard_outlined,
      routePath: '/',
    ),
    const Command(
      id: 'nav.library',
      label: 'Go to Library',
      subtitle: 'Browse and manage media libraries',
      icon: Icons.video_library_outlined,
      routePath: '/library',
    ),
    const Command(
      id: 'nav.clients',
      label: 'Go to Clients',
      subtitle: 'Manage connected devices',
      icon: Icons.devices_outlined,
      routePath: '/clients',
    ),
    const Command(
      id: 'nav.groups',
      label: 'Go to Groups',
      subtitle: 'Client groups and access control',
      icon: Icons.groups_outlined,
      routePath: '/groups',
    ),
    const Command(
      id: 'nav.activity',
      label: 'Go to Activity',
      subtitle: 'Real-time stream activity',
      icon: Icons.bolt_outlined,
      routePath: '/activity',
    ),
    const Command(
      id: 'nav.transcoding',
      label: 'Go to Transcoding',
      subtitle: 'Transcoding jobs and status',
      icon: Icons.tune_outlined,
      routePath: '/transcoding',
    ),
    const Command(
      id: 'nav.encoder',
      label: 'Go to Encoder Settings',
      subtitle: 'Hardware encoder configuration',
      icon: Icons.memory_outlined,
      routePath: '/transcoding/encoder',
    ),
    const Command(
      id: 'nav.logs',
      label: 'Go to Logs',
      subtitle: 'Live server log viewer',
      icon: Icons.terminal,
      routePath: '/logs',
    ),
    const Command(
      id: 'nav.settings',
      label: 'Go to Settings',
      subtitle: 'Server URL, name, license key',
      icon: Icons.settings_outlined,
      routePath: '/settings',
    ),
    const Command(
      id: 'nav.subscription',
      label: 'Go to Subscription',
      subtitle: 'Tier info and license management',
      icon: Icons.workspace_premium_outlined,
      routePath: '/subscription',
    ),
    const Command(
      id: 'nav.profile',
      label: 'Go to Profile',
      subtitle: 'Operator profile and preferences',
      icon: Icons.person_outline_rounded,
      routePath: '/profile',
    ),
    const Command(
      id: 'nav.help',
      label: 'Go to Help',
      subtitle: 'Documentation and support',
      icon: Icons.help_outline,
      routePath: '/help',
    ),

    // ── Server actions ───────────────────────────────────────────────────────
    Command(
      id: 'server.restart',
      label: 'Restart Server',
      subtitle: 'Gracefully restart the Fluxora server process',
      icon: Icons.restart_alt_rounded,
      action: () async {
        try {
          await GetIt.I<DashboardRepository>().restartServer();
        } catch (e, st) {
          log.w('Restart server failed', error: e, stackTrace: st);
        }
      },
    ),
    Command(
      id: 'server.stop',
      label: 'Stop Server',
      subtitle: 'Shut down the Fluxora server process',
      icon: Icons.stop_circle_outlined,
      action: () async {
        try {
          await GetIt.I<DashboardRepository>().stopServer();
        } catch (e, st) {
          // Server may not respond after stop — expected.
          log.d('Stop server response lost (expected)', error: e, stackTrace: st);
        }
      },
    ),

    // ── Panel actions ────────────────────────────────────────────────────────
    Command(
      id: 'panel.notifications',
      label: 'Open Notifications',
      subtitle: 'Toggle the notifications slide-over panel',
      icon: Icons.notifications_outlined,
      action: () => NotificationsPanelScope.of(context).toggle(),
    ),
  ];
}
