/// Profile tab — avatar block + stats + sectioned settings + sign out.
///
/// Matches the prototype JSX at
/// `docs/11_design/prototype/app/mobile/screens/profile.jsx`.
/// Profile data + stats are mocked client-side — the server's `/profile`
/// endpoint is the *operator* profile (server admin) and doesn't map
/// cleanly to a per-mobile-client profile. Replacement is its own ticket.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:fluxora_mobile/core/router/app_router.dart';
import 'package:fluxora_mobile/features/player/presentation/cubit/player_cubit.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const _Header(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: _AvatarBlock(),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _StatRow(),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _SettingsList(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: _SignOutButton(
                onTap: () => _confirmSignOut(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF0F0C24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: Text(
          'Sign out?',
          style: AppTypography.h2.copyWith(color: AppColors.textBright),
        ),
        content: Text(
          'This unpairs the device. You\'ll need to scan or pair again to '
          'reconnect to your server.',
          style: AppTypography.body.copyWith(color: AppColors.textMutedV2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.body.copyWith(color: AppColors.textBright),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              'Sign out',
              style: AppTypography.body.copyWith(
                color: AppColors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _performSignOut(context);
  }

  Future<void> _performSignOut(BuildContext context) async {
    final getIt = GetIt.I;
    try {
      await getIt<PlayerCubit>().dismiss();
    } catch (_) {
      // PlayerCubit may not have an active session — ignore.
    }
    getIt<ApiClient>().clearBearerToken();
    await getIt<SecureStorage>().deleteAll();
    if (!context.mounted) return;
    context.go(Routes.connect);
  }
}

// ── Header (title + settings icon button) ───────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Profile',
              style: AppTypography.displayV2.copyWith(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: AppColors.textBright,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {},
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0x0AFFFFFF),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.settings_outlined,
                size: 17,
                color: AppColors.textBright,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar block (gradient surface + circle avatar + plan pill) ─────────────

class _AvatarBlock extends StatelessWidget {
  const _AvatarBlock();

  static const _name = 'Alex Kowalski';
  static const _email = 'alex@fluxora.io';
  static const _initials = 'AK';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x2EA855F7), Color(0x0F22D3EE)],
        ),
        border: Border.all(color: const Color(0x1FFFFFFF)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x668B5CF6),
                  blurRadius: 22,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              _initials,
              style: AppTypography.displayV2.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _name,
                  style: AppTypography.h1.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBright,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _email,
                  style: AppTypography.captionV2.copyWith(
                    fontSize: 12,
                    color: AppColors.textMutedV2,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.pillBgPurple,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.workspace_premium_outlined,
                        size: 11,
                        color: Color(0xFFE9D5FF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'PLUS MEMBER',
                        style: AppTypography.eyebrow.copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: const Color(0xFFE9D5FF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats row (Hours · Movies · Shows) ──────────────────────────────────────

class _StatRow extends StatelessWidget {
  const _StatRow();

  static const _stats = <(String, String)>[
    ('284', 'Hours'),
    ('62', 'Movies'),
    ('18', 'Shows'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0x08FFFFFF),
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _stats.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Text(
                    _stats[i].$1,
                    style: AppTypography.displayV2.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppColors.textBright,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _stats[i].$2.toUpperCase(),
                    style: AppTypography.eyebrow.copyWith(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: AppColors.textMutedV2,
                    ),
                  ),
                ],
              ),
            ),
            if (i < _stats.length - 1)
              const SizedBox(
                height: 36,
                child: VerticalDivider(
                  width: 1,
                  color: AppColors.borderSubtle,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Settings list (FluxRow group with dividers) ─────────────────────────────

class _SettingsList extends StatelessWidget {
  const _SettingsList();

  @override
  Widget build(BuildContext context) {
    const rows = <Widget>[
      _SettingsRow(
        icon: Icons.person_outline,
        label: 'Account',
        sub: 'alex@fluxora.io',
      ),
      _SettingsRow(
        icon: Icons.credit_card_outlined,
        label: 'Subscription',
        sub: 'Plus · renews Jun 21',
        trailing: _PlanPill(label: 'Plus'),
      ),
      _SettingsRow(
        icon: Icons.download_outlined,
        label: 'Downloads',
        sub: 'Quality · auto-delete',
      ),
      _SettingsRow(
        icon: Icons.wifi_outlined,
        label: 'Playback',
        sub: 'Wi-Fi only · streaming quality',
      ),
      _SettingsRow(
        icon: Icons.public_outlined,
        label: 'Language & region',
      ),
      _SettingsRow(
        icon: Icons.notifications_outlined,
        label: 'Notifications',
      ),
      _SettingsRow(
        icon: Icons.shield_outlined,
        label: 'Privacy & security',
      ),
      _SettingsRow(
        icon: Icons.help_outline,
        label: 'Help & support',
      ),
      _SettingsRow(
        icon: Icons.info_outline,
        label: 'About Fluxora',
        sub: 'v1.0.0 · build 482',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0x08FFFFFF),
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              rows[i],
              if (i < rows.length - 1)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.borderSubtle,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.sub,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? sub;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return FluxRow(
      icon: icon,
      label: label,
      sub: sub,
      onTap: () {},
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) ...[
            trailing!,
            const SizedBox(width: 8),
          ],
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.textDim,
          ),
        ],
      ),
    );
  }
}

class _PlanPill extends StatelessWidget {
  const _PlanPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.pillBgPurple,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: AppTypography.eyebrow.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: const Color(0xFFE9D5FF),
        ),
      ),
    );
  }
}

// ── Sign out button (red-tinted, full width) ───────────────────────────────

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0x1AEF4444),
          border: Border.all(color: const Color(0x40EF4444)),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          'Sign out',
          style: AppTypography.body.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFF87171),
          ),
        ),
      ),
    );
  }
}
