/// Account detail screen — the M2 surface of the mobile-settings
/// remediation plan (`docs/10_planning/archive/15_*.md`).
///
/// Reads the per-client profile from the singleton [ProfileCubit] (Phase
/// A backfill cache) and renders eight diagnostic-style fields the user
/// might need to share with their server operator.  The single editable
/// field is the **display name**, mutated via the `PATCH /auth/clients/me`
/// endpoint added at M2.5; on save the cubit refreshes so the Profile
/// tab's header reflects the new name without a manual reload.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:fluxora_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:fluxora_mobile/features/profile/presentation/cubit/profile_cubit.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileCubit>.value(
      value: GetIt.I<ProfileCubit>(),
      child: const _AccountView(),
    );
  }
}

class _AccountView extends StatelessWidget {
  const _AccountView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: FluxAppBar(
        title: 'Account',
        transparent: true,
        onBack: () => context.pop(),
      ),
      body: SafeArea(
        top: false,
        child: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) => switch (state) {
            ProfileInitial() ||
            ProfileLoading() =>
              const Center(child: BrandLoader(size: 56)),
            ProfileFailure(:final message) => _FailureBody(message: message),
            ProfileLoaded(:final profile) => _LoadedBody(profile: profile),
          },
        ),
      ),
    );
  }
}

class _FailureBody extends StatelessWidget {
  const _FailureBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.textMutedV2, size: 32),
          const SizedBox(height: 12),
          Text(message,
              style: AppTypography.body.copyWith(color: AppColors.textBody),
              textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FluxButton(
            variant: FluxButtonVariant.secondary,
            icon: Icons.refresh_rounded,
            onPressed: () => context.read<ProfileCubit>().refresh(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.profile});

  final ClientProfile profile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _IdentityCard(profile: profile),
        const SizedBox(height: 14),
        const _SectionEyebrow(label: 'Profile'),
        const SizedBox(height: 6),
        _AccountRowCard(
          children: [
            _EditableNameRow(profile: profile),
            const _Divider(),
            _ReadOnlyRow(
              icon: Icons.alternate_email_rounded,
              label: 'Email',
              value: profile.email ?? '—',
            ),
            const _Divider(),
            _ReadOnlyRow(
              icon: Icons.workspace_premium_outlined,
              label: 'Subscription',
              value: _tierLabel(profile.tier),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _SectionEyebrow(label: 'Device'),
        const SizedBox(height: 6),
        _AccountRowCard(
          children: [
            _ReadOnlyRow(
              icon: Icons.phone_iphone_rounded,
              label: 'Platform',
              value: _platformLabel(profile.platform),
            ),
            const _Divider(),
            _ReadOnlyRow(
              icon: Icons.event_available_outlined,
              label: 'Paired since',
              value: _formatDate(profile.pairedAt),
            ),
            const _Divider(),
            _ReadOnlyRow(
              icon: Icons.schedule_rounded,
              label: 'Last seen',
              value: _formatDate(profile.lastSeen),
            ),
            const _Divider(),
            _AsyncReadOnlyRow(
              icon: Icons.info_outline_rounded,
              label: 'App version',
              value: _readAppVersion(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _SectionEyebrow(label: 'Diagnostic IDs'),
        const SizedBox(height: 6),
        _AccountRowCard(
          children: [
            _CopyableRow(
              icon: Icons.fingerprint_rounded,
              label: 'Device ID',
              value: profile.id,
              monospace: true,
            ),
            const _Divider(),
            _AsyncCopyableRow(
              icon: Icons.dns_outlined,
              label: 'Server URL',
              value: _readServerUrl(),
              monospace: true,
            ),
          ],
        ),
      ],
    );
  }
}

// ── Identity card (avatar + display name + email + tier pill) ──────────────

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile});

  final ClientProfile profile;

  @override
  Widget build(BuildContext context) {
    final initials = _initialsFrom(profile.displayName);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.violet.withValues(alpha: 0.18),
            AppColors.cyan.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
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
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: AppTypography.h1.copyWith(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: AppTypography.h1.copyWith(
                    color: AppColors.textBright,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (profile.email != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    profile.email!,
                    style: AppTypography.captionV2
                        .copyWith(color: AppColors.textMutedV2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Edit display name row + sheet ──────────────────────────────────────────

class _EditableNameRow extends StatelessWidget {
  const _EditableNameRow({required this.profile});

  final ClientProfile profile;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      onTap: () => _openEditSheet(context, profile.displayName),
      child: Row(
        children: [
          const Icon(Icons.badge_outlined,
              color: AppColors.violetTint, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Display name',
                  style: AppTypography.captionV2
                      .copyWith(color: AppColors.textMutedV2),
                ),
                const SizedBox(height: 2),
                Text(
                  profile.displayName,
                  style: AppTypography.body
                      .copyWith(color: AppColors.textBright),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.edit_outlined,
              size: 16, color: AppColors.textMutedV2),
        ],
      ),
    );
  }

  void _openEditSheet(BuildContext context, String current) {
    final cubit = context.read<ProfileCubit>();
    showFluxBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => FluxBottomSheet(
        title: 'Rename device',
        trailing: IconButton(
          icon:
              const Icon(Icons.close_rounded, color: AppColors.textMutedV2),
          onPressed: () => Navigator.of(sheetCtx).maybePop(),
          splashRadius: 18,
          tooltip: 'Close',
        ),
        child: _EditNameForm(currentName: current, profileCubit: cubit),
      ),
    );
  }
}

class _EditNameForm extends StatefulWidget {
  const _EditNameForm({required this.currentName, required this.profileCubit});

  final String currentName;
  final ProfileCubit profileCubit;

  @override
  State<_EditNameForm> createState() => _EditNameFormState();
}

class _EditNameFormState extends State<_EditNameForm> {
  late final TextEditingController _controller;
  String? _error;
  bool _saving = false;

  static final _log = Logger();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Name cannot be empty.');
      return;
    }
    if (raw.length > 50) {
      setState(() => _error = 'Name must be 50 characters or fewer.');
      return;
    }
    if (raw == widget.currentName) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await GetIt.I<AuthRepository>().updateMe(displayName: raw);
      await widget.profileCubit.refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Renamed device to "$raw".')),
      );
    } catch (e, st) {
      _log.e('updateMe failed', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not update name. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Shown to your server operator and other paired devices in this '
          'household.',
          style:
              AppTypography.captionV2.copyWith(color: AppColors.textMutedV2),
        ),
        const SizedBox(height: 14),
        FluxTextField(
          controller: _controller,
          hint: 'My iPhone',
          autofocus: true,
          enabled: !_saving,
          onSubmitted: (_) => _save(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: AppTypography.captionV2
                .copyWith(color: const Color(0xFFF87171)),
          ),
        ],
        const SizedBox(height: 16),
        FluxButton(
          fullWidth: true,
          size: FluxButtonSize.lg,
          icon: _saving ? null : Icons.check_rounded,
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Read-only / async / copyable rows ──────────────────────────────────────

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      child: Row(
        children: [
          Icon(icon, color: AppColors.violetTint, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.captionV2
                      .copyWith(color: AppColors.textMutedV2),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.body
                      .copyWith(color: AppColors.textBright),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AsyncReadOnlyRow extends StatelessWidget {
  const _AsyncReadOnlyRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final Future<String> value;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: value,
      builder: (_, snap) => _ReadOnlyRow(
        icon: icon,
        label: label,
        value: snap.data ?? '—',
      ),
    );
  }
}

class _CopyableRow extends StatelessWidget {
  const _CopyableRow({
    required this.icon,
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      child: Row(
        children: [
          Icon(icon, color: AppColors.violetTint, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.captionV2
                      .copyWith(color: AppColors.textMutedV2),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textBright,
                    fontFamily: monospace ? 'monospace' : null,
                    fontSize: monospace ? 12.5 : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded,
                size: 16, color: AppColors.textMutedV2),
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

class _AsyncCopyableRow extends StatelessWidget {
  const _AsyncCopyableRow({
    required this.icon,
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final IconData icon;
  final String label;
  final Future<String> value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: value,
      builder: (_, snap) => _CopyableRow(
        icon: icon,
        label: label,
        value: snap.data ?? '—',
        monospace: monospace,
      ),
    );
  }
}

// ── Layout primitives ──────────────────────────────────────────────────────

class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 0, 0),
      child: Text(
        label,
        style: AppTypography.eyebrow
            .copyWith(color: AppColors.textMutedV2, letterSpacing: 0.4),
      ),
    );
  }
}

class _AccountRowCard extends StatelessWidget {
  const _AccountRowCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x08FFFFFF),
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _RowShell extends StatelessWidget {
  const _RowShell({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final padded = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: child,
    );
    if (onTap == null) return padded;
    return InkWell(onTap: onTap, child: padded);
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: AppColors.borderSubtle);
}

// ── Helpers ────────────────────────────────────────────────────────────────

Future<String> _readAppVersion() async {
  final info = await PackageInfo.fromPlatform();
  return 'v${info.version} · build ${info.buildNumber}';
}

Future<String> _readServerUrl() async {
  final url = await GetIt.I<SecureStorage>().getServerUrl();
  return url ?? '—';
}

String _initialsFrom(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}

String _tierLabel(SubscriptionTier tier) => switch (tier) {
      SubscriptionTier.free => 'Free',
      SubscriptionTier.plus => 'Plus',
      SubscriptionTier.pro => 'Pro',
      SubscriptionTier.ultimate => 'Ultimate',
    };

String _platformLabel(ClientPlatform platform) => switch (platform) {
      ClientPlatform.android => 'Android',
      ClientPlatform.ios => 'iOS',
      ClientPlatform.windows => 'Windows',
      ClientPlatform.macos => 'macOS',
      ClientPlatform.linux => 'Linux',
    };

String _formatDate(DateTime? d) {
  if (d == null) return '—';
  final local = d.toLocal();
  // YYYY-MM-DD HH:MM — short ISO-ish, no timezone, no seconds.
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
