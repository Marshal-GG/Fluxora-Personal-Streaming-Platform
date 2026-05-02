/// Profile screen — M7 full implementation.
///
/// Matches `docs/11_design/desktop_prototype/app/pages/profile.jsx`.
/// Left column: avatar + tab nav. Right column: tab content.
/// Tabs: Profile · Security · Preferences · Sessions · Danger Zone.
/// Only Profile tab is wired to the real `ProfileCubit`; remaining tabs
/// are informational shells (no backend today).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/profile.dart';

import 'package:fluxora_desktop/core/di/injector.dart';
import 'package:fluxora_desktop/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:fluxora_desktop/features/profile/presentation/cubit/profile_state.dart';
import 'package:fluxora_desktop/shared/widgets/flux_button.dart';
import 'package:fluxora_desktop/shared/widgets/flux_card.dart';
import 'package:fluxora_desktop/shared/widgets/flux_text_field.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';
import 'package:fluxora_desktop/shared/widgets/pill.dart';
import 'package:fluxora_desktop/shared/widgets/status_dot.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileCubit>(
      create: (_) => getIt<ProfileCubit>()..load(),
      child: const _ProfileView(),
    );
  }
}

// ── Main stateful view ────────────────────────────────────────────────────────

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  String _tab = 'profile';
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  static const _tabs = [
    (id: 'profile', label: 'Profile', icon: Icons.person_outline),
    (id: 'security', label: 'Security', icon: Icons.shield_outlined),
    (id: 'prefs', label: 'Preferences', icon: Icons.settings_outlined),
    (id: 'sessions', label: 'Active Sessions', icon: Icons.devices_outlined),
    (id: 'danger', label: 'Danger Zone', icon: Icons.info_outline),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final profile = state is ProfileLoaded ? state.profile : null;
        final dirty = state is ProfileLoaded && state.dirty;
        final saving = state is ProfileSaving;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Account',
                subtitle: 'Manage your profile, security and preferences',
                actions: dirty || saving
                    ? FluxButton(
                        variant: FluxButtonVariant.primary,
                        icon: Icons.save_outlined,
                        onPressed: saving
                            ? null
                            : () => _save(context),
                        child: Text(saving ? 'Saving…' : 'Save Changes'),
                      )
                    : null,
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column — avatar + nav
                    SizedBox(
                      width: 240,
                      child: FluxCard(
                        padding: 0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _AvatarBlock(profile: profile),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                children: [
                                  for (final t in _tabs)
                                    _TabNavItem(
                                      id: t.id,
                                      label: t.label,
                                      icon: t.icon,
                                      active: _tab == t.id,
                                      onTap: () =>
                                          setState(() => _tab = t.id),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    // Right column — tab content
                    Expanded(
                      child: SingleChildScrollView(
                        child: switch (_tab) {
                          'security' => const _SecurityTab(),
                          'prefs' => const _PrefsTab(),
                          'sessions' => const _SessionsTab(),
                          'danger' => const _DangerTab(),
                          _ => _ProfileTab(
                              profile: profile,
                              nameCtrl: _nameCtrl,
                              emailCtrl: _emailCtrl,
                            ),
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s28),
            ],
          ),
        );
      },
    );
  }

  void _save(BuildContext context) {
    context.read<ProfileCubit>().save(
          displayName: _nameCtrl.text.trim().isEmpty
              ? null
              : _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty
              ? null
              : _emailCtrl.text.trim(),
        );
  }
}

// ── Avatar block ──────────────────────────────────────────────────────────────

class _AvatarBlock extends StatelessWidget {
  const _AvatarBlock({required this.profile});
  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final letter = profile?.avatarLetter ?? 'A';
    final name = profile?.displayName ?? 'Admin';
    final email = profile?.email ?? 'admin@fluxora.local';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF))),
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFA855F7),
                  Color(0xFF6366F1),
                  Color(0xFF06B6D4),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0x4DA855F7),
                width: 3,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40A855F7),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                letter.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: AppTypography.body.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            email,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textDim,
            ),
          ),
          const SizedBox(height: 10),
          const Pill('Owner', color: PillColor.purple),
        ],
      ),
    );
  }
}

// ── Tab nav item ──────────────────────────────────────────────────────────────

class _TabNavItem extends StatelessWidget {
  const _TabNavItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String id;
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? const Color(0x24A855F7)
                : Colors.transparent,
            border: Border.all(
              color: active
                  ? const Color(0x4DA855F7)
                  : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: active
                    ? AppColors.violetTint
                    : AppColors.textMutedV2,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.w500,
                  color: active
                      ? const Color(0xFFE9D5FF)
                      : AppColors.textMutedV2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Profile
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({
    required this.profile,
    required this.nameCtrl,
    required this.emailCtrl,
  });
  final Profile? profile;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  @override
  void didUpdateWidget(_ProfileTab old) {
    super.didUpdateWidget(old);
    // Sync controllers when profile first loads (controllers start empty).
    if (old.profile == null && widget.profile != null) {
      widget.nameCtrl.text = widget.profile?.displayName ?? '';
      widget.emailCtrl.text = widget.profile?.email ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final lastLogin = profile?.lastLoginAt;
    final createdAt = profile?.createdAt;

    return FluxCard(
      padding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Profile Information',
            subtitle: 'Update your personal details and contact information',
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _FormField(
                        label: 'Display Name',
                        child: FluxTextField(
                          controller: widget.nameCtrl,
                          hint: 'Your display name',
                          width: double.infinity,
                          onChanged: (_) =>
                              context.read<ProfileCubit>().markDirty(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _FormField(
                        label: 'Email',
                        child: FluxTextField(
                          controller: widget.emailCtrl,
                          hint: 'your@email.com',
                          keyboardType: TextInputType.emailAddress,
                          width: double.infinity,
                          onChanged: (_) =>
                              context.read<ProfileCubit>().markDirty(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (createdAt != null)
                      Expanded(
                        child: _ReadOnlyField(
                          label: 'Member Since',
                          value: _shortDate(createdAt),
                        ),
                      ),
                    if (createdAt != null) const SizedBox(width: 14),
                    if (lastLogin != null)
                      Expanded(
                        child: _ReadOnlyField(
                          label: 'Last Sign-in',
                          value: _shortDate(lastLogin),
                        ),
                      ),
                    if (lastLogin == null && createdAt == null)
                      const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _shortDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso.length > 10 ? iso.substring(0, 10) : iso;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Security (informational shell)
// ─────────────────────────────────────────────────────────────────────────────

class _SecurityTab extends StatelessWidget {
  const _SecurityTab();

  @override
  Widget build(BuildContext context) {
    return FluxCard(
      padding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Security',
            subtitle: 'Password and two-factor authentication',
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ReadOnlyField(
                  label: 'Password',
                  value: '••••••••••••',
                ),
                const SizedBox(height: 14),
                Text(
                  'Password changes and 2FA are managed via the server\'s admin interface.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textDim,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                // Recent login activity
                Text(
                  'Recent Login Activity',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                for (final row in const [
                  ('This device', 'LAN', 'Now', DotStatus.online),
                ])
                  _LoginRow(
                    device: row.$1,
                    ip: row.$2,
                    when: row.$3,
                    status: row.$4,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginRow extends StatelessWidget {
  const _LoginRow({
    required this.device,
    required this.ip,
    required this.when,
    required this.status,
  });

  final String device;
  final String ip;
  final String when;
  final DotStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x08FFFFFF))),
      ),
      child: Row(
        children: [
          StatusDot(status: status),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              device,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            ip,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textMutedV2,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            when,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textMutedV2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Preferences (informational shell)
// ─────────────────────────────────────────────────────────────────────────────

class _PrefsTab extends StatelessWidget {
  const _PrefsTab();

  @override
  Widget build(BuildContext context) {
    return FluxCard(
      padding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Preferences', subtitle: ''),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                for (final pref in const [
                  (
                    label: 'Email notifications',
                    sub: 'Receive product news and updates',
                    on: true,
                  ),
                  (
                    label: 'Weekly activity digest',
                    sub: 'Sent every Monday at 9am',
                    on: true,
                  ),
                  (
                    label: 'Auto-play next episode',
                    sub: 'When watching TV shows',
                    on: false,
                  ),
                  (
                    label: 'Beta features',
                    sub: 'Try experimental features early',
                    on: false,
                  ),
                ])
                  _SwitchRow(
                    label: pref.label,
                    sub: pref.sub,
                    initial: pref.on,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatefulWidget {
  const _SwitchRow({
    required this.label,
    required this.sub,
    required this.initial,
  });

  final String label;
  final String sub;
  final bool initial;

  @override
  State<_SwitchRow> createState() => _SwitchRowState();
}

class _SwitchRowState extends State<_SwitchRow> {
  late bool _on;

  @override
  void initState() {
    super.initState();
    _on = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x08FFFFFF))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.sub,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textDim,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _on = !_on),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38,
                height: 22,
                decoration: BoxDecoration(
                  gradient: _on
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF8B5CF6),
                            Color(0xFFA855F7),
                          ],
                        )
                      : null,
                  color: _on ? null : const Color(0x14FFFFFF),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      top: 3,
                      left: _on ? 19 : 3,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Active Sessions (informational shell)
// ─────────────────────────────────────────────────────────────────────────────

class _SessionsTab extends StatelessWidget {
  const _SessionsTab();

  @override
  Widget build(BuildContext context) {
    return FluxCard(
      padding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Sessions',
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Devices currently signed in to your account',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const _SessionRow(
            device: 'This device',
            meta: 'Desktop Control Panel',
            ip: 'localhost',
            when: 'Now',
            isCurrent: true,
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.device,
    required this.meta,
    required this.ip,
    required this.when,
    required this.isCurrent,
  });

  final String device;
  final String meta;
  final String ip;
  final String when;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x08FFFFFF))),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.desktop_windows_outlined,
            size: 16,
            color: AppColors.violet,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      device,
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Text(
                        '● Current',
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 10.5,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  meta,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textMutedV2,
                  ),
                ),
              ],
            ),
          ),
          Text(
            ip,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textMutedV2,
              fontFamily: 'JetBrainsMono',
            ),
          ),
          const SizedBox(width: 14),
          Text(
            when,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textMutedV2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Danger Zone
// ─────────────────────────────────────────────────────────────────────────────

class _DangerTab extends StatelessWidget {
  const _DangerTab();

  @override
  Widget build(BuildContext context) {
    return FluxCard(
      padding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
            decoration: const BoxDecoration(
              color: Color(0x0DEF4444),
              border: Border(
                bottom: BorderSide(color: Color(0x33EF4444)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Danger Zone',
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: const Color(0xFFF87171),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Irreversible and destructive actions',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textMutedV2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final action in const [
            (
              title: 'Export Account Data',
              sub: 'Download all your data as a ZIP archive',
              btn: 'Export',
              danger: false,
            ),
            (
              title: 'Reset All Preferences',
              sub: 'Restore default settings without deleting data',
              btn: 'Reset',
              danger: false,
            ),
            (
              title: 'Delete Profile',
              sub: 'Permanently delete your operator profile',
              btn: 'Delete Profile',
              danger: true,
            ),
          ])
            _DangerRow(
              title: action.title,
              sub: action.sub,
              btn: action.btn,
              isDanger: action.danger,
            ),
        ],
      ),
    );
  }
}

class _DangerRow extends StatelessWidget {
  const _DangerRow({
    required this.title,
    required this.sub,
    required this.btn,
    required this.isDanger,
  });

  final String title;
  final String sub;
  final String btn;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x0AFFFFFF))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textDim,
                  ),
                ),
              ],
            ),
          ),
          FluxButton(
            // TODO: no backend for these actions; disabled
            variant:
                isDanger ? FluxButtonVariant.danger : FluxButtonVariant.outline,
            size: FluxButtonSize.sm,
            onPressed: null,
            child: Text(btn),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textDim,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textMutedV2,
            fontWeight: FontWeight.w500,
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textMutedV2,
            fontWeight: FontWeight.w500,
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0x08FFFFFF),
            border: Border.all(color: const Color(0x14FFFFFF)),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textMutedV2,
            ),
          ),
        ),
      ],
    );
  }
}
