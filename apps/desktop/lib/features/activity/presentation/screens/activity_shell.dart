import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_desktop/features/activity/presentation/screens/activity_screen.dart';
import 'package:fluxora_desktop/features/logs/presentation/screens/logs_screen.dart';
import 'package:fluxora_desktop/shared/widgets/flux_card.dart';
import 'package:fluxora_desktop/shared/widgets/flux_pill_tabs.dart';
import 'package:fluxora_desktop/shared/widgets/flux_tab_bar.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';

/// Outer tab host for the Activity page (`/activity`).  Both tab bodies
/// (Sessions / Logs) are kept mounted via [IndexedStack] so switching
/// pills is a pure `setState` + index change — no widget tear-down, no
/// cubit re-creation, no server re-poll on tab change.
///
/// Live HLS transcoding sessions moved to `/library/transcoding` on
/// 2026-05-16 — Activity is purely an event-feed page now.
class ActivityShell extends StatefulWidget {
  const ActivityShell({super.key, this.initialTab});

  /// Optional initial tab.  When null, the last-visited tab is restored
  /// (defaults to `sessions` on first launch).
  final ActivityShellTabPath? initialTab;

  @override
  State<ActivityShell> createState() => _ActivityShellState();
}

class _ActivityShellState extends State<ActivityShell> {
  late ActivityShellTabPath _activeTab;

  /// Tabs the operator has actually opened.  Unvisited tabs render as
  /// `SizedBox.shrink()` so their cubits don't start polling until the
  /// first visit; once mounted they stay alive.
  final Set<ActivityShellTabPath> _visited = <ActivityShellTabPath>{};

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab ?? _rememberedActivityTab;
    _visited.add(_activeTab);
  }

  void _switchTab(ActivityShellTabPath next) {
    if (_activeTab == next) return;
    setState(() {
      _activeTab = next;
      _visited.add(next);
    });
    _rememberedActivityTab = next;
  }

  Widget _bodyFor(ActivityShellTabPath tab, Widget real) =>
      _visited.contains(tab) ? real : const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgRoot,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  title: 'Activity',
                  subtitle: _subtitleFor(_activeTab),
                  verticalPadding: AppSpacing.s12,
                ),
                FluxPillTabs(
                  tabs: const [
                    FluxTab(
                      id: 'sessions',
                      label: 'Sessions',
                      icon: Icons.bolt_outlined,
                    ),
                    FluxTab(
                      id: 'logs',
                      label: 'Logs',
                      icon: Icons.terminal,
                    ),
                  ],
                  activeId: _activeTab.id,
                  onChange: (id) {
                    final next = ActivityShellTabPath.fromId(id);
                    if (next != null) _switchTab(next);
                  },
                ),
                const SizedBox(height: AppSpacing.s10),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.s28,
                right: AppSpacing.s28,
                bottom: AppSpacing.s28,
              ),
              child: FluxCard(
                padding: 0,
                // Visited tab bodies stay mounted; unvisited render as
                // SizedBox.shrink() so their cubits don't construct
                // until first click.  Once visited, cubits poll for
                // the shell's lifetime regardless of which tab is
                // visible.
                child: IndexedStack(
                  index: _activeTab.index,
                  sizing: StackFit.expand,
                  children: [
                    _bodyFor(
                      ActivityShellTabPath.sessions,
                      const ActivityScreen(embedded: true),
                    ),
                    _bodyFor(
                      ActivityShellTabPath.logs,
                      const LogsScreen(embedded: true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _subtitleFor(ActivityShellTabPath tab) => switch (tab) {
        ActivityShellTabPath.sessions =>
          'Real-time events and session history',
        ActivityShellTabPath.logs => 'Server logs',
      };
}

/// Tab identity for the Activity shell.  Order matters — drives the
/// [IndexedStack] index via `.index`.
enum ActivityShellTabPath {
  sessions('sessions'),
  logs('logs');

  const ActivityShellTabPath(this.id);

  final String id;

  static ActivityShellTabPath? fromId(String id) {
    for (final value in ActivityShellTabPath.values) {
      if (value.id == id) return value;
    }
    return null;
  }
}

/// Module-level cache of the last-visited Activity tab.  Restored when
/// the shell mounts without an explicit `initialTab`.  Survives go_
/// router rebuilds; resets on hot restart / app launch.
ActivityShellTabPath _rememberedActivityTab = ActivityShellTabPath.sessions;

ActivityShellTabPath rememberedActivityTab() => _rememberedActivityTab;
