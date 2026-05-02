/// FluxSidebar — redesigned desktop control-panel navigation rail.
///
/// Translates `docs/11_design/desktop_prototype/app/components/sidebar.jsx`
/// lines 1–148 into Flutter verbatim. Layout regions correspond to the JSX
/// structure as follows:
///
/// - Logo header  → JSX lines 24–30
/// - Nav list     → JSX lines 32–37 / NavItem lines 123–146
/// - System status block → JSX lines 39–70
/// - Upgrade card → JSX lines 72–97
/// - User footer  → JSX lines 99–118
///
/// Compose this widget inside a [ShellRoute] builder; do **not** subclass or
/// import the legacy [AppShell] / [_Sidebar] from `sidebar.dart`.
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_gradients.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/system_stats.dart';
import 'package:fluxora_core/widgets/fluxora_logo.dart';

import 'package:fluxora_desktop/features/system_stats/presentation/cubit/system_stats_cubit.dart';
import 'package:fluxora_desktop/shared/widgets/status_dot.dart';

// ─── Nav entry definition ────────────────────────────────────────────────────

/// Immutable descriptor for a single sidebar navigation item.
///
/// Matches the `items` array in the prototype (lines 3–13).
class _NavEntry {
  const _NavEntry({
    required this.id,
    required this.label,
    required this.icon,
    required this.path,
  });

  final String id;
  final String label;
  final IconData icon;
  final String path;
}

/// The nine navigation items — order and paths are locked to the prototype.
const List<_NavEntry> _navItems = [
  _NavEntry(
    id: 'dashboard',
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    path: '/',
  ),
  _NavEntry(
    id: 'library',
    label: 'Library',
    icon: Icons.video_library_outlined,
    path: '/library',
  ),
  _NavEntry(
    id: 'clients',
    label: 'Clients',
    icon: Icons.devices_outlined,
    path: '/clients',
  ),
  _NavEntry(
    id: 'groups',
    label: 'Groups',
    icon: Icons.groups_outlined,
    path: '/groups',
  ),
  _NavEntry(
    id: 'activity',
    label: 'Activity',
    icon: Icons.bolt_outlined,
    path: '/activity',
  ),
  _NavEntry(
    id: 'transcoding',
    label: 'Transcoding',
    icon: Icons.tune_outlined,
    path: '/transcoding',
  ),
  _NavEntry(
    id: 'logs',
    label: 'Logs',
    icon: Icons.terminal,
    path: '/logs',
  ),
  _NavEntry(
    id: 'settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
    path: '/settings',
  ),
  _NavEntry(
    id: 'subscription',
    label: 'Subscription',
    icon: Icons.workspace_premium_outlined,
    path: '/subscription',
  ),
];

// ─── Uptime formatter ────────────────────────────────────────────────────────

/// Converts [seconds] to `"<hh>h <mm>m <ss>s"` — mirrors the prototype's
/// sidebar uptime display (line 48).
String _formatUptime(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  return '${h}h ${m}m ${s}s';
}

// ─── Public widget ───────────────────────────────────────────────────────────

/// Redesigned sidebar for the Fluxora desktop control panel.
///
/// Width is fixed at 232 px to match the prototype exactly. The sidebar is
/// self-contained: it reads the active route from [GoRouterState] and the
/// live system stats from [SystemStatsCubit] — no external state is passed in
/// except [currentTier], which gates the upgrade-callout card.
///
/// **Do not pass** the active path as a constructor argument; the widget
/// reads it internally to avoid stale-state bugs on deep-links.
class FluxSidebar extends StatelessWidget {
  const FluxSidebar({
    super.key,
    this.currentTier = 'free',
  });

  /// The user's current subscription tier.
  ///
  /// The upgrade callout is hidden when this equals `'ultimate'`.
  final String currentTier;

  // Pre-computed to avoid repeated `.copyWith` in build.
  static final TextStyle _taglineStyle = AppTypography.micro.copyWith(
    color: AppColors.textDim,
    fontSize: 9.5,
    letterSpacing: 0.3,
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 232,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.sidebarGlass,
              border: Border(
                right: BorderSide(color: AppColors.borderSubtle),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Region 1: Logo header ──────────────────────────────────
                _LogoHeader(taglineStyle: _taglineStyle),

                // ── Region 2: Nav list ─────────────────────────────────────
                const Expanded(child: _NavList()),

                // ── Region 3: System status block ──────────────────────────
                const _SystemStatusBlock(),

                // ── Region 4: Upgrade callout (gated) ─────────────────────
                if (currentTier != 'ultimate') const _UpgradeCard(),

                // ── Region 5: User footer ──────────────────────────────────
                const _UserFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Region 1: Logo header ────────────────────────────────────────────────────

class _LogoHeader extends StatelessWidget {
  const _LogoHeader({required this.taglineStyle});

  final TextStyle taglineStyle;

  @override
  Widget build(BuildContext context) {
    // The horizontal wordmark contains the F lettermark integrated with
    // the FLUXORA text, so no separate `FluxoraMark` is rendered next to
    // it (would double the F).
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FluxoraWordmark(height: 28),
          const SizedBox(height: AppSpacing.s6),
          Text('Stream. Sync. Anywhere.', style: taglineStyle),
        ],
      ),
    );
  }
}

// ─── Region 2: Nav list ────────────────────────────────────────────────────────

class _NavList extends StatelessWidget {
  const _NavList();

  @override
  Widget build(BuildContext context) {
    // Active path read here — never passed via constructor to avoid stale state.
    final activePath = GoRouterState.of(context).matchedLocation;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in _navItems)
              _NavItem(entry: entry, activePath: activePath),
          ],
        ),
      ),
    );
  }
}

// ─── Nav item ──────────────────────────────────────────────────────────────────

/// Single navigation row — stateful to handle hover.
///
/// Matches NavItem JSX (lines 123–146).
class _NavItem extends StatefulWidget {
  const _NavItem({required this.entry, required this.activePath});

  final _NavEntry entry;
  final String activePath;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  bool get _isActive {
    final path = widget.entry.path;
    final loc = widget.activePath;
    // Dashboard is root — exact match only; others allow sub-paths.
    if (path == '/') return loc == '/';
    return loc == path || loc.startsWith('$path/');
  }

  // ── Style helpers ──────────────────────────────────────────────────────────

  Color get _bgColor {
    if (_isActive) return const Color(0x24A855F7); // rgba(168,85,247,0.14)
    if (_hovered) return const Color(0x08FFFFFF); // rgba(255,255,255,0.03)
    return Colors.transparent;
  }

  Border get _border {
    if (_isActive) {
      return Border.all(
        color: const Color(0x4DA855F7), // rgba(168,85,247,0.3)
        width: 1,
      );
    }
    return Border.all(color: Colors.transparent);
  }

  Color get _textColor {
    if (_isActive) return AppColors.violetSoft;
    if (_hovered) return AppColors.textBody;
    return AppColors.textMutedV2;
  }

  FontWeight get _fontWeight =>
      _isActive ? FontWeight.w600 : FontWeight.w500;

  Color get _iconColor =>
      _isActive ? AppColors.violetTint : _textColor;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go(widget.entry.path),
        child: Container(
          margin: const EdgeInsets.only(bottom: 1),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: _border,
          ),
          child: Row(
            children: [
              Icon(widget.entry.icon, color: _iconColor, size: 16),
              const SizedBox(width: AppSpacing.s11),
              Text(
                widget.entry.label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: _fontWeight,
                  color: _textColor,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Region 3: System status block ───────────────────────────────────────────

/// System Status block — JSX lines 39–70.
///
/// Subscribes to [SystemStatsCubit] via [BlocSelector]; shows skeleton
/// text when the first poll hasn't landed yet.
class _SystemStatusBlock extends StatelessWidget {
  const _SystemStatusBlock();

  // Pre-computed styles to avoid repeated .copyWith in build.
  static final TextStyle _eyebrowStyle = AppTypography.eyebrow.copyWith(
    fontSize: 10,
  );

  static final TextStyle _titleStyle = AppTypography.body.copyWith(
    fontWeight: FontWeight.w600,
  );

  static final TextStyle _subtitleStyle = AppTypography.micro.copyWith(
    color: AppColors.textDim,
  );

  static final TextStyle _monoStyle = AppTypography.monoMicro.copyWith(
    color: AppColors.textDim,
  );

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SystemStatsCubit, SystemStatsState, SystemStats?>(
      selector: (state) => state.latest,
      builder: (context, latest) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Eyebrow — JSX lines 41–43, forced to fontSize 10.
              Text('System Status', style: _eyebrowStyle),
              const SizedBox(height: AppSpacing.s10),
              // Three status rows, 10 px gap between them.
              _ServerRunningRow(
                latest: latest,
                titleStyle: _titleStyle,
                subtitleStyle: _subtitleStyle,
              ),
              const SizedBox(height: AppSpacing.s10),
              _LanModeRow(
                latest: latest,
                titleStyle: _titleStyle,
                monoStyle: _monoStyle,
              ),
              const SizedBox(height: AppSpacing.s10),
              _InternetAccessRow(
                latest: latest,
                titleStyle: _titleStyle,
                subtitleStyle: _subtitleStyle,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Row 1 — Server Running (JSX lines 45–51).
class _ServerRunningRow extends StatelessWidget {
  const _ServerRunningRow({
    required this.latest,
    required this.titleStyle,
    required this.subtitleStyle,
  });

  final SystemStats? latest;
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;

  @override
  Widget build(BuildContext context) {
    final uptime = latest != null
        ? 'Uptime: ${_formatUptime(latest!.uptimeSeconds)}'
        : 'Loading…';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Server Running', style: titleStyle),
              const SizedBox(height: 2),
              Text(uptime, style: subtitleStyle),
            ],
          ),
        ),
        StatusDot(
          status: latest != null ? DotStatus.active : DotStatus.idle,
        ),
      ],
    );
  }
}

/// Row 2 — LAN Mode (JSX lines 52–59).
class _LanModeRow extends StatelessWidget {
  const _LanModeRow({
    required this.latest,
    required this.titleStyle,
    required this.monoStyle,
  });

  final SystemStats? latest;
  final TextStyle titleStyle;
  final TextStyle monoStyle;

  @override
  Widget build(BuildContext context) {
    final ip = latest?.lanIp ?? '—';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row: wifi icon + "LAN Mode" (prototype line 54–55).
              Row(
                children: [
                  const Icon(
                    Icons.wifi,
                    size: 11,
                    color: AppColors.textMutedV2,
                  ),
                  const SizedBox(width: 6),
                  Text('LAN Mode', style: titleStyle),
                ],
              ),
              const SizedBox(height: 2),
              Text(ip, style: monoStyle),
            ],
          ),
        ),
        // No right-side widget on this row (prototype line 58 — no StatusDot).
      ],
    );
  }
}

/// Row 3 — Internet Access (JSX lines 60–68).
class _InternetAccessRow extends StatelessWidget {
  const _InternetAccessRow({
    required this.latest,
    required this.titleStyle,
    required this.subtitleStyle,
  });

  final SystemStats? latest;
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;

  @override
  Widget build(BuildContext context) {
    final connected = latest?.internetConnected ?? false;
    final subtitleText = latest == null
        ? ''
        : (connected ? 'Connected' : 'Offline');
    final subtitleColor = (latest != null && connected)
        ? AppColors.statusOnline
        : AppColors.textDim;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row: globe icon + "Internet Access" (prototype line 62–63).
              Row(
                children: [
                  const Icon(
                    Icons.language,
                    size: 11,
                    color: AppColors.textMutedV2,
                  ),
                  const SizedBox(width: 6),
                  Text('Internet Access', style: titleStyle),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitleText,
                style: subtitleStyle.copyWith(color: subtitleColor),
              ),
            ],
          ),
        ),
        StatusDot(
          status: (latest != null && connected)
              ? DotStatus.online
              : DotStatus.offline,
        ),
      ],
    );
  }
}

// ─── Region 4: Upgrade card ────────────────────────────────────────────────────

/// Upgrade callout — JSX lines 72–97.
///
/// Only rendered when [FluxSidebar.currentTier] != `'ultimate'`.
class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard();

  // Pre-computed title style — prototype line 80: 13/700/violetTint.
  static const TextStyle _titleStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.violetTint,
    height: 1.4,
  );

  // Body text style — prototype line 81: 11/400/1.45/textMutedV2.
  static const TextStyle _bodyStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textMutedV2,
    height: 1.45,
  );

  // Button label style — prototype line 90: 12/600/textBody.
  static const TextStyle _btnStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textBody,
    height: 1.4,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s14),
        decoration: BoxDecoration(
          gradient: AppGradients.upgradeCallout,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.borderHover),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title — prototype line 80.
            Text('Upgrade to Pro', style: _titleStyle),
            SizedBox(height: AppSpacing.s4),
            // Body — prototype lines 81–83.
            Text(
              'Unlock premium features and experience Fluxora without limits',
              style: _bodyStyle,
            ),
            SizedBox(height: AppSpacing.s12),
            // "View Plans" button — prototype lines 84–95.
            _UpgradeButton(btnStyle: _btnStyle),
          ],
        ),
      ),
    );
  }
}

/// "View Plans" button inside the upgrade card.
class _UpgradeButton extends StatefulWidget {
  const _UpgradeButton({required this.btnStyle});

  final TextStyle btnStyle;

  @override
  State<_UpgradeButton> createState() => _UpgradeButtonState();
}

class _UpgradeButtonState extends State<_UpgradeButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go('/subscription'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            // prototype line 87: rgba(255,255,255,0.04)
            color: _hovered
                ? const Color(0x14FFFFFF)
                : const Color(0x0AFFFFFF),
            border: Border.all(color: AppColors.borderHover),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('View Plans', style: widget.btnStyle),
              const SizedBox(width: AppSpacing.s6),
              const Icon(
                Icons.chevron_right,
                size: 12,
                color: AppColors.textBody,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Region 5: User footer ─────────────────────────────────────────────────────

/// User-profile footer — JSX lines 99–118.
///
/// Hardcoded to "Admin" / "admin@fluxora.local" for now; a Profile cubit
/// will supply real data once the `/profile` feature lands.
class _UserFooter extends StatefulWidget {
  const _UserFooter();

  @override
  State<_UserFooter> createState() => _UserFooterState();
}

class _UserFooterState extends State<_UserFooter> {
  bool _hovered = false;

  // Avatar gradient — prototype line 109.
  static const LinearGradient _avatarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA855F7), Color(0xFF6366F1)],
  );

  // Pre-computed text styles.
  static const TextStyle _nameStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    color: AppColors.textBody,
    height: 1.4,
  );

  static const TextStyle _emailStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 10.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textDim,
    height: 1.4,
  );

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go('/profile'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s14,
            vertical: AppSpacing.s10,
          ),
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0x08FFFFFF) // subtle hover tint
                : Colors.transparent,
            border: const Border(
              top: BorderSide(color: AppColors.borderSubtle),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar circle — prototype lines 107–112.
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  gradient: _avatarGradient,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  'A',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              // Name + email column — prototype lines 113–116.
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Admin', style: _nameStyle),
                    Text('admin@fluxora.local', style: _emailStyle),
                  ],
                ),
              ),
              // Chevron — prototype line 117.
              const Icon(
                Icons.expand_more,
                size: 13,
                color: AppColors.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
