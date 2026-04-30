import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_desktop/core/router/app_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  static final _destinations = [
    (icon: Icons.dashboard_outlined, label: 'Dashboard', route: Routes.dashboard),
    (icon: Icons.devices_outlined, label: 'Clients', route: Routes.clients),
    (icon: Icons.video_library_outlined, label: 'Library', route: Routes.library),
    (icon: Icons.analytics_outlined, label: 'Activity', route: Routes.activity),
    (icon: Icons.vpn_key_outlined, label: 'Licenses', route: Routes.licenses),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = _destinations.indexWhere(
      (d) => location == d.route || location.startsWith('${d.route}/'),
    );
    final isSettingsSelected = location == Routes.settings;

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
            onDestinationSelected: (i) =>
                context.go(_destinations[i].route),
            isSettingsSelected: isSettingsSelected,
            onSettingsTap: () => context.go(Routes.settings),
          ),
          const VerticalDivider(),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.isSettingsSelected,
    required this.onSettingsTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isSettingsSelected;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.brandGradient.createShader(bounds),
                  child: const Icon(
                    Icons.bolt,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Fluxora',
                  style: AppTypography.headingMd.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Control Panel',
              style: AppTypography.caption.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          ...List.generate(
            AppShell._destinations.length,
            (i) => _NavItem(
              icon: AppShell._destinations[i].icon,
              label: AppShell._destinations[i].label,
              isSelected: i == selectedIndex,
              onTap: () => onDestinationSelected(i),
            ),
          ),
          const Spacer(),
          const Divider(),
          _NavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            isSelected: isSettingsSelected,
            onTap: onSettingsTap,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        isSelected ? AppColors.primary : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withAlpha(25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
