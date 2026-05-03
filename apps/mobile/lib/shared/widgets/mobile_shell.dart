import 'package:flutter/material.dart';
import 'package:fluxora_core/widgets/flux_bottom_tabs.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fluxora_mobile/shared/widgets/flux_mini_player.dart';

/// Bottom-tab shell wrapping the 5 primary tab branches of the redesigned
/// mobile app. Consumed by the [StatefulShellRoute.indexedStack] in
/// `app_router.dart`. Tab order matches prototype `TAB_ITEMS` in
/// `docs/11_design/prototype/app/mobile/components/mobile-primitives.jsx`.
///
/// Each branch preserves its own navigation history; switching tabs is a
/// crossfade via [FluxBottomTabs] with a light haptic. Tapping the active
/// tab pops to its branch root (the second arg of `goBranch`).
class MobileShell extends StatelessWidget {
  const MobileShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const List<FluxBottomTabItem> _tabs = [
    FluxBottomTabItem(icon: LucideIcons.layoutDashboard, label: 'Home'),
    FluxBottomTabItem(icon: LucideIcons.bookOpen, label: 'Library'),
    FluxBottomTabItem(icon: LucideIcons.search, label: 'Search'),
    FluxBottomTabItem(icon: LucideIcons.download, label: 'Downloads'),
    FluxBottomTabItem(icon: LucideIcons.user, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FluxMiniPlayer(),
          FluxBottomTabs(
            items: _tabs,
            currentIndex: navigationShell.currentIndex,
            onTap: (i) => navigationShell.goBranch(
              i,
              initialLocation: i == navigationShell.currentIndex,
            ),
          ),
        ],
      ),
    );
  }
}
