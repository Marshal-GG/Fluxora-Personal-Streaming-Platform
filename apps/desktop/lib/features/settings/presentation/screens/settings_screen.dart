import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_desktop/core/di/injector.dart';
import 'package:fluxora_desktop/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:fluxora_desktop/features/settings/presentation/cubit/settings_state.dart';
import 'package:go_router/go_router.dart';

const _kTiers = ['free', 'plus', 'pro', 'ultimate'];

const _kTierLabels = {
  'free': 'Free — 1 stream',
  'plus': 'Plus — 3 streams · \$4.99/mo',
  'pro': 'Pro — 10 streams · \$9.99/mo',
  'ultimate': 'Ultimate — Unlimited · \$19.99/mo',
};

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SettingsCubit>()..loadSettings(),
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatefulWidget {
  const _SettingsView();

  @override
  State<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<_SettingsView> {
  late final TextEditingController _urlController;
  late final TextEditingController _nameController;
  late final TextEditingController _licenseController;
  final _formKey = GlobalKey<FormState>();
  String _selectedTier = 'free';

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _nameController = TextEditingController();
    _licenseController = TextEditingController();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  void _syncFromState(SettingsState state) {
    String? url;
    String? name;
    String? license;
    String? tier;

    if (state is SettingsLoaded) {
      url = state.serverUrl;
      name = state.serverName;
      license = state.licenseKey ?? '';
      tier = state.tier;
    } else if (state is SettingsSaved) {
      url = state.serverUrl;
      name = state.serverName;
      tier = state.tier;
    }

    if (url != null && _urlController.text != url) _urlController.text = url;
    if (name != null && _nameController.text != name) _nameController.text = name;
    if (license != null && _licenseController.text != license) {
      _licenseController.text = license;
    }
    if (tier != null && _selectedTier != tier) {
      setState(() => _selectedTier = tier!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsCubit, SettingsState>(
      listener: (context, state) {
        _syncFromState(state);
        if (state is SettingsSaved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Settings saved — reconnecting to server.'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
        if (state is SettingsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is SettingsLoading;

        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Settings', style: AppTypography.headingLg),
              const SizedBox(height: 4),
              Text(
                'Configure your Fluxora server connection and subscription.',
                style: AppTypography.bodyMd
                    .copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Server connection ──────────────────────────
                          _SectionCard(
                            title: 'Server Connection',
                            children: [
                              _SettingRow(
                                label: 'Server URL',
                                hint:
                                    'The base URL of your Fluxora server, e.g.\nhttp://localhost:8080 or http://192.168.1.10:8080',
                                child: _buildTextField(
                                  isLoading: isLoading,
                                  controller: _urlController,
                                  hintText: 'http://localhost:8080',
                                  monospace: true,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _SettingRow(
                                label: 'Server Name',
                                hint: 'Displayed to clients during discovery.',
                                child: _buildTextField(
                                  isLoading: isLoading,
                                  controller: _nameController,
                                  hintText: 'Fluxora Server',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // ── Remote access ──────────────────────────────
                          if (state is SettingsLoaded)
                            _RemoteAccessSection(state: state),
                          if (state is SettingsLoaded)
                            const SizedBox(height: 24),
                          // ── Subscription ───────────────────────────────
                          _SectionCard(
                            title: 'Subscription',
                            children: [
                              _SettingRow(
                                label: 'Plan',
                                hint:
                                    'Changing the plan updates your stream concurrency limit immediately.',
                                child: isLoading
                                    ? const _LoadingField()
                                    : _TierSelector(
                                        selectedTier: _selectedTier,
                                        onChanged: (t) =>
                                            setState(() => _selectedTier = t),
                                      ),
                              ),
                              const SizedBox(height: 16),
                              _SettingRow(
                                label: 'License Key',
                                hint:
                                    'Optional. Enter your license key to activate a paid plan.',
                                child: _buildTextField(
                                  isLoading: isLoading,
                                  controller: _licenseController,
                                  hintText: 'FLUXORA-XXXX-XXXX-XXXX-XXXX',
                                  monospace: true,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => context.go('/licenses'),
                                  icon: const Icon(Icons.vpn_key_outlined, size: 16),
                                  label: const Text('View Issued Licenses'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                              if (state is SettingsLoaded) ...[
                                const SizedBox(height: 12),
                                _StreamLimitBadge(
                                    maxStreams:
                                        state.maxConcurrentStreams),
                              ],
                            ],
                          ),
                          const SizedBox(height: 24),
                          // ── Save button ────────────────────────────────
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton(
                              onPressed: isLoading
                                  ? null
                                  : () => context
                                      .read<SettingsCubit>()
                                      .saveSettings(
                                        serverUrl: _urlController.text,
                                        serverName: _nameController.text,
                                        tier: _selectedTier,
                                        licenseKey:
                                            _licenseController.text.trim().isEmpty
                                                ? null
                                                : _licenseController.text.trim(),
                                      ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                              ),
                              child: const Text('Save Settings'),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // ── About ──────────────────────────────────────
                          const _SectionCard(
                            title: 'About',
                            children: [
                              _InfoRow(
                                  label: 'App Version', value: '0.1.0+1'),
                              SizedBox(height: 8),
                              _InfoRow(
                                  label: 'Platform',
                                  value: 'Desktop Control Panel'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required bool isLoading,
    required TextEditingController controller,
    required String hintText,
    bool monospace = false,
  }) {
    if (isLoading) return const _LoadingField();
    return TextFormField(
      controller: controller,
      style: AppTypography.bodyMd.copyWith(
        color: AppColors.textPrimary,
        fontFamily: monospace ? 'monospace' : null,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle:
            AppTypography.bodyMd.copyWith(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.surfaceRaised),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.surfaceRaised),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

// ── Tier selector ─────────────────────────────────────────────────────────────

class _TierSelector extends StatelessWidget {
  const _TierSelector({
    required this.selectedTier,
    required this.onChanged,
  });

  final String selectedTier;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceRaised),
      ),
      child: DropdownButton<String>(
        value: selectedTier,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: AppColors.surface,
        style: AppTypography.bodyMd.copyWith(color: AppColors.textPrimary),
        items: _kTiers
            .map(
              (t) => DropdownMenuItem(
                value: t,
                child: Text(_kTierLabels[t] ?? t),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

// ── Remote access section ────────────────────────────────────────────────────

class _RemoteAccessSection extends StatelessWidget {
  const _RemoteAccessSection({required this.state});

  final SettingsLoaded state;

  @override
  Widget build(BuildContext context) {
    final remoteUrl = state.remoteUrl;
    final configured = remoteUrl != null && remoteUrl.isNotEmpty;
    return _SectionCard(
      title: 'Remote Access',
      children: [
        _SettingRow(
          label: 'Public URL',
          hint: configured
              ? 'Off-LAN clients reach this server through Cloudflare Tunnel.'
              : 'Set FLUXORA_PUBLIC_URL on the server to enable off-LAN access.\nSee the Cloudflare Tunnel runbook for setup.',
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.surfaceRaised),
            ),
            child: Text(
              configured ? remoteUrl : 'Not configured',
              style: AppTypography.bodyMd.copyWith(
                color: configured
                    ? AppColors.textPrimary
                    : AppColors.textMuted,
                fontFamily: configured ? 'monospace' : null,
              ),
            ),
          ),
        ),
        if (configured) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              _ReachabilityBadge(status: state.remoteAccessStatus),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed:
                    state.remoteAccessStatus == RemoteAccessStatus.checking
                        ? null
                        : () =>
                            context.read<SettingsCubit>().checkRemoteAccess(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Check now'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ReachabilityBadge extends StatelessWidget {
  const _ReachabilityBadge({required this.status});

  final RemoteAccessStatus? status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      RemoteAccessStatus.reachable =>
        ('Tunnel reachable', AppColors.success, Icons.check_circle),
      RemoteAccessStatus.unreachable =>
        ('Tunnel unreachable', AppColors.error, Icons.error_outline),
      RemoteAccessStatus.checking =>
        ('Checking…', AppColors.textMuted, Icons.hourglass_empty),
      null => ('Not checked yet', AppColors.textMuted, Icons.help_outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stream limit badge ────────────────────────────────────────────────────────

class _StreamLimitBadge extends StatelessWidget {
  const _StreamLimitBadge({required this.maxStreams});

  final int maxStreams;

  @override
  Widget build(BuildContext context) {
    final label = maxStreams >= 9999
        ? 'Unlimited concurrent streams'
        : '$maxStreams concurrent stream${maxStreams == 1 ? '' : 's'} allowed';
    return Row(
      children: [
        const Icon(Icons.info_outline,
            size: 14, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.caption
              .copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

// ── Loading placeholder ───────────────────────────────────────────────────────

class _LoadingField extends StatelessWidget {
  const _LoadingField();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 40,
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceRaised),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

// ── Setting row ───────────────────────────────────────────────────────────────

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.child,
    this.hint,
  });

  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodySm.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        child,
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(
            hint!,
            style: AppTypography.caption
                .copyWith(color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: AppTypography.bodySm
                .copyWith(color: AppColors.textMuted),
          ),
        ),
        Text(
          value,
          style: AppTypography.bodySm
              .copyWith(color: AppColors.textPrimary),
        ),
      ],
    );
  }
}
