/// Profile tab — avatar block + stats + sectioned settings + sign out.
///
/// Phase A backfill: header (display name + email + tier pill), the
/// "Account" sub-row email and the "Subscription" tier pill all consume
/// `GET /api/v1/auth/clients/me` via [ProfileCubit].  The stats row
/// (Hours / Movies / Shows) keeps a placeholder dash until Phase B's
/// `/clients/me/stats` lands — three em-dashes sit in for the legacy
/// hardcoded `284 / 62 / 18` so the UI is honest about what it knows.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:fluxora_mobile/core/router/app_router.dart';
import 'package:fluxora_mobile/features/player/presentation/cubit/player_cubit.dart';
import 'package:fluxora_mobile/features/profile/presentation/cubit/profile_cubit.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileCubit _profile;

  @override
  void initState() {
    super.initState();
    _profile = GetIt.I<ProfileCubit>();
    if (_profile.state is ProfileInitial) {
      _profile.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileCubit>.value(
      value: _profile,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () => _profile.refresh(),
            color: AppColors.violet,
            backgroundColor: AppColors.surfaceGlass,
            child: BlocBuilder<ProfileCubit, ProfileState>(
              builder: (context, state) {
                final profile = switch (state) {
                  ProfileLoaded(:final profile) => profile,
                  _ => null,
                };
                final failureMessage = switch (state) {
                  ProfileFailure(:final message) => message,
                  _ => null,
                };

                return ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const _Header(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: _AvatarBlock(profile: profile),
                    ),
                    if (failureMessage != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _ProfileFailure(message: failureMessage),
                      ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _StatRow(),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: _SettingsList(profile: profile),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                      child: _SignOutButton(
                        onTap: () => _confirmSignOut(context),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
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
  const _AvatarBlock({required this.profile});

  final ClientProfile? profile;

  String get _displayName => profile?.displayName ?? '—';
  String get _email => profile?.email ?? 'Pairing-only — no email on file';
  String get _initials {
    final name = profile?.displayName;
    if (name == null || name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    return parts.take(2).map((s) => s[0]).join().toUpperCase();
  }

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
                  _displayName,
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
                _TierPill(tier: profile?.tier),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TierPill extends StatelessWidget {
  const _TierPill({required this.tier});

  final SubscriptionTier? tier;

  @override
  Widget build(BuildContext context) {
    final label = switch (tier) {
      SubscriptionTier.free => 'FREE',
      SubscriptionTier.plus => 'PLUS MEMBER',
      SubscriptionTier.pro => 'PRO MEMBER',
      SubscriptionTier.ultimate => 'ULTIMATE MEMBER',
      null => '— LOADING',
    };
    return Container(
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
            label,
            style: AppTypography.eyebrow.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: const Color(0xFFE9D5FF),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileFailure extends StatelessWidget {
  const _ProfileFailure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x14EF4444),
        border: Border.all(color: const Color(0x40EF4444)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              size: 18, color: Color(0xFFF87171)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.captionV2
                  .copyWith(color: const Color(0xFFF87171)),
            ),
          ),
          TextButton(
            onPressed: () => context.read<ProfileCubit>().refresh(),
            child: Text(
              'Retry',
              style: AppTypography.captionV2.copyWith(
                color: AppColors.violetTint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats row (Hours · Movies · Shows) — placeholder until Phase B ──────────

class _StatRow extends StatelessWidget {
  const _StatRow();

  static const _stats = <(String, String)>[
    ('—', 'Hours'),
    ('—', 'Movies'),
    ('—', 'Shows'),
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
  const _SettingsList({required this.profile});

  final ClientProfile? profile;

  @override
  Widget build(BuildContext context) {
    final accountSub = profile?.email ?? '—';
    final subscriptionSub = profile == null
        ? 'Loading…'
        : _tierSubLabel(profile!.tier);
    final planPillLabel = profile == null ? null : _tierPillLabel(profile!.tier);

    final rows = <Widget>[
      _SettingsRow(
        icon: Icons.person_outline,
        label: 'Account',
        sub: accountSub,
      ),
      _SettingsRow(
        icon: Icons.credit_card_outlined,
        label: 'Subscription',
        sub: subscriptionSub,
        trailing: planPillLabel == null
            ? null
            : _PlanPill(label: planPillLabel),
      ),
      const _SettingsRow(
        icon: Icons.download_outlined,
        label: 'Downloads',
        sub: 'Quality · auto-delete',
      ),
      const _SettingsRow(
        icon: Icons.wifi_outlined,
        label: 'Playback',
        sub: 'Wi-Fi only · streaming quality',
      ),
      const _SettingsRow(
        icon: Icons.public_outlined,
        label: 'Language & region',
      ),
      const _SettingsRow(
        icon: Icons.notifications_outlined,
        label: 'Notifications',
      ),
      const _SettingsRow(
        icon: Icons.shield_outlined,
        label: 'Privacy & security',
      ),
      const _SettingsRow(
        icon: Icons.help_outline,
        label: 'Help & support',
      ),
      _SettingsRow(
        icon: Icons.refresh_rounded,
        label: 'Reconnect to server',
        sub: 'Use if your token was revoked',
        onTap: () => context.go(Routes.reconnect),
      ),
      const _SettingsRow(
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

  String _tierSubLabel(SubscriptionTier tier) => switch (tier) {
        SubscriptionTier.free => 'Free tier',
        SubscriptionTier.plus => 'Plus',
        SubscriptionTier.pro => 'Pro',
        SubscriptionTier.ultimate => 'Ultimate',
      };

  String _tierPillLabel(SubscriptionTier tier) => switch (tier) {
        SubscriptionTier.free => 'Free',
        SubscriptionTier.plus => 'Plus',
        SubscriptionTier.pro => 'Pro',
        SubscriptionTier.ultimate => 'Ultimate',
      };
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.sub,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? sub;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FluxRow(
      icon: icon,
      label: label,
      sub: sub,
      onTap: onTap ?? () {},
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
