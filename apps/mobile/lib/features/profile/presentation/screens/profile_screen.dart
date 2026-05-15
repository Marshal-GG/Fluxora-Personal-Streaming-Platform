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
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:fluxora_mobile/core/router/app_router.dart';
import 'package:fluxora_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:fluxora_mobile/features/groups/presentation/cubit/groups_cubit.dart';
import 'package:fluxora_mobile/features/groups/presentation/cubit/groups_state.dart';
import 'package:fluxora_mobile/features/groups/presentation/widgets/groups_section.dart';
import 'package:fluxora_mobile/features/player/presentation/cubit/player_cubit.dart';
import 'package:fluxora_mobile/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:fluxora_mobile/features/profile/presentation/cubit/profile_stats_cubit.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileCubit _profile;
  late final ProfileStatsCubit _stats;
  late final MobileGroupsCubit _groups;

  @override
  void initState() {
    super.initState();
    _profile = GetIt.I<ProfileCubit>();
    _stats = GetIt.I<ProfileStatsCubit>();
    _groups = GetIt.I<MobileGroupsCubit>();
    if (_profile.state is ProfileInitial) {
      _profile.load();
    }
    if (_stats.state is ProfileStatsInitial) {
      _stats.load();
    }
    if (_groups.state is MobileGroupsInitial) {
      _groups.load();
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      _profile.refresh(),
      _stats.refresh(),
      _groups.refreshSilent(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ProfileCubit>.value(value: _profile),
        BlocProvider<ProfileStatsCubit>.value(value: _stats),
        BlocProvider<MobileGroupsCubit>.value(value: _groups),
      ],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _refresh,
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
                    // M6 group surfaces — Locked / Unlocked / Visible
                    // Libraries cards.  Self-hides when there's nothing
                    // to surface (no gated groups + no provenance) so a
                    // fresh single-client install doesn't see empty
                    // sections.
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: GroupsSection(),
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
    // Self-revoke server-side BEFORE clearing the local bearer cache
    // (mobile redesign audit §17.3 #3).  Failure is non-fatal: a dead
    // network or a server that's already forgotten the client should
    // not block the user from signing out locally.  Without this call
    // the bearer token stays valid server-side until natural expiry —
    // a stolen-and-not-yet-cleared token could still authenticate.
    try {
      await getIt<AuthRepository>().revokeMe();
    } catch (_) {
      // Server unreachable, token already revoked, etc. — proceed
      // with local teardown so the user isn't trapped on the screen.
    }
    getIt<ApiClient>().clearBearerToken();
    await getIt<SecureStorage>().deleteAll();
    if (!context.mounted) return;
    context.go(Routes.splash);
  }
}

// ── Header (title only) ────────────────────────────────────────────────────
//
// The prototype ships a 38-px gear icon next to the title.  Removed at M1
// of the settings remediation plan (`docs/10_planning/archive/15_*.md`) — the
// Profile tab IS the settings surface, so a gear that opens another
// nesting was misleading visual debt.

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        'Profile',
        style: AppTypography.displayV2.copyWith(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          color: AppColors.textBright,
        ),
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

// ── Stats row (Hours · Movies · Shows) — Phase B real data ──────────────────

class _StatRow extends StatelessWidget {
  const _StatRow();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileStatsCubit, ProfileStatsState>(
      builder: (context, state) {
        final tuples = switch (state) {
          ProfileStatsLoaded(:final stats) => <(String, String)>[
              ('${stats.hours}', 'Hours'),
              ('${stats.movies}', 'Movies'),
              ('${stats.shows}', 'Shows'),
            ],
          // Loading / failure / initial — render em-dashes so the row still
          // takes up its layout slot but doesn't lie about the numbers.
          _ => const <(String, String)>[
              ('—', 'Hours'),
              ('—', 'Movies'),
              ('—', 'Shows'),
            ],
        };

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0x08FFFFFF),
            border: Border.all(color: AppColors.borderSubtle),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              for (var i = 0; i < tuples.length; i++) ...[
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        tuples[i].$1,
                        style: AppTypography.displayV2.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppColors.textBright,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tuples[i].$2.toUpperCase(),
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
                if (i < tuples.length - 1)
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
      },
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
        onTap: () => context.push(Routes.account),
      ),
      _SettingsRow(
        icon: Icons.credit_card_outlined,
        label: 'Subscription',
        sub: subscriptionSub,
        trailing: planPillLabel == null
            ? null
            : _PlanPill(label: planPillLabel),
        onTap: () => context.push(Routes.upgrade),
      ),
      _SettingsRow(
        icon: Icons.podcasts_rounded,
        label: 'Playback',
        sub: 'Bg playback · Wi-Fi only · quality · autoplay · subtitles',
        onTap: () => context.push(Routes.playbackPrefs),
      ),
      const _StubRow(
        icon: Icons.notifications_outlined,
        label: 'Notifications',
        sub: 'Push opt-in + per-category preferences',
      ),
      const _StubRow(
        icon: Icons.public_outlined,
        label: 'Language & region',
        sub: 'Localization not enabled in v1',
      ),
      _SettingsRow(
        icon: Icons.shield_outlined,
        label: 'Privacy & security',
        onTap: () => context.push(Routes.privacy),
      ),
      _SettingsRow(
        icon: Icons.help_outline,
        label: 'Help & support',
        onTap: () => _showHelpSheet(context),
      ),
      _SettingsRow(
        icon: Icons.refresh_rounded,
        label: 'Reconnect to server',
        sub: 'Use if your token was revoked',
        onTap: () => context.go(Routes.reconnect),
      ),
      _SettingsRow(
        icon: Icons.info_outline,
        label: 'About Fluxora',
        onTap: () => _showAboutSheet(context),
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

/// Stubbed-disabled row — renders at 50 % opacity with a violet "v1.1"
/// pill in place of the chevron, no `onTap`.  Used for surfaces the
/// prototype reserves a slot for but v1 doesn't ship (Notifications
/// preferences pending push opt-in; Language & region pending i18n).
/// Mobile-settings remediation plan §M5.
class _StubRow extends StatelessWidget {
  const _StubRow({required this.icon, required this.label, this.sub});

  final IconData icon;
  final String label;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.55,
      child: FluxRow(
        icon: icon,
        label: label,
        sub: sub,
        onTap: () {},
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.violet.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.violet.withValues(alpha: 0.32),
            ),
          ),
          child: Text(
            'v1.1',
            style: AppTypography.captionV2.copyWith(
              color: AppColors.violetTint,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
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
    return Semantics(
      button: true,
      label: 'Sign out and unpair this device',
      child: GestureDetector(
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
      ),
    );
  }
}

// ── About + Help & support sheets (M1 settings remediation) ────────────────

/// Read app version + build from `package_info_plus`.  Returned as a single
/// preformatted "vX.Y.Z · build N" string so the sheets don't each
/// duplicate the formatting logic.
Future<String> _readAppVersion() async {
  final info = await PackageInfo.fromPlatform();
  return 'v${info.version} · build ${info.buildNumber}';
}

/// About Fluxora — version + tagline + credit.  Static otherwise.
Future<void> _showAboutSheet(BuildContext context) async {
  await showFluxBottomSheet<void>(
    context: context,
    builder: (sheetCtx) => FluxBottomSheet(
      title: 'About Fluxora',
      trailing: IconButton(
        icon: const Icon(Icons.close_rounded, color: AppColors.textMutedV2),
        onPressed: () => Navigator.of(sheetCtx).maybePop(),
        splashRadius: 18,
        tooltip: 'Close',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          const Center(child: FluxoraMark(size: 56, glow: true)),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'Fluxora Mobile',
              style: AppTypography.h1
                  .copyWith(color: AppColors.textBright, fontSize: 17),
            ),
          ),
          const SizedBox(height: 4),
          FutureBuilder<String>(
            future: _readAppVersion(),
            builder: (_, snap) => Center(
              child: Text(
                snap.data ?? '—',
                style: AppTypography.captionV2
                    .copyWith(color: AppColors.textMutedV2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Stream. Sync. Anywhere.',
              style: AppTypography.body.copyWith(
                color: AppColors.textBody,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 14),
          Text(
            'Self-hosted media streaming for movies, TV, music and '
            'documents — your library, on any device, with zero cloud '
            'lock-in.',
            style: AppTypography.body.copyWith(color: AppColors.textBody),
          ),
          const SizedBox(height: 12),
          Text(
            'Made by Marshal · 2026',
            style: AppTypography.captionV2
                .copyWith(color: AppColors.textDim),
          ),
        ],
      ),
    ),
  );
}

/// Help & support — exposes diagnostic info the user can hand to whoever
/// runs their Fluxora server (operator).  Self-hosted means no central
/// support channel; the operator IS the support channel.
Future<void> _showHelpSheet(BuildContext context) async {
  final secureStorage = GetIt.I<SecureStorage>();
  final serverUrl = await secureStorage.getServerUrl() ?? 'Unknown';
  final clientId = await secureStorage.getClientId() ?? 'Unknown';
  final appVersion = await _readAppVersion();
  if (!context.mounted) return;
  await showFluxBottomSheet<void>(
    context: context,
    builder: (sheetCtx) => FluxBottomSheet(
      title: 'Help & support',
      trailing: IconButton(
        icon: const Icon(Icons.close_rounded, color: AppColors.textMutedV2),
        onPressed: () => Navigator.of(sheetCtx).maybePop(),
        splashRadius: 18,
        tooltip: 'Close',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Fluxora is self-hosted. For account questions, server '
            'outages, or feature requests, contact the operator who '
            'paired this device.',
            style: AppTypography.body.copyWith(color: AppColors.textBody),
          ),
          const SizedBox(height: 16),
          Text(
            'Diagnostic info',
            style: AppTypography.eyebrow
                .copyWith(color: AppColors.textMutedV2, letterSpacing: 0.4),
          ),
          const SizedBox(height: 8),
          _DiagnosticRow(label: 'App version', value: appVersion),
          const SizedBox(height: 6),
          _DiagnosticRow(
            label: 'Server URL',
            value: serverUrl,
            copyable: true,
          ),
          const SizedBox(height: 6),
          _DiagnosticRow(
            label: 'Device ID',
            value: clientId,
            copyable: true,
          ),
          const SizedBox(height: 18),
          FluxButton(
            fullWidth: true,
            variant: FluxButtonVariant.secondary,
            icon: Icons.refresh_rounded,
            onPressed: () {
              Navigator.of(sheetCtx).pop();
              context.go(Routes.reconnect);
            },
            child: const Text('Reconnect to server'),
          ),
        ],
      ),
    ),
  );
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0x08FFFFFF),
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: AppTypography.captionV2
                  .copyWith(color: AppColors.textMutedV2),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.body.copyWith(
                color: AppColors.textBright,
                fontFamily: 'monospace',
                fontSize: 12.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (copyable)
            IconButton(
              icon: const Icon(
                Icons.copy_rounded,
                size: 16,
                color: AppColors.textMutedV2,
              ),
              splashRadius: 18,
              tooltip: 'Copy $label',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: value));
                messenger.showSnackBar(
                  SnackBar(content: Text('Copied $label')),
                );
              },
            ),
        ],
      ),
    );
  }
}
