import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_desktop/core/di/injector.dart';
import 'package:fluxora_desktop/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:fluxora_desktop/features/settings/presentation/cubit/settings_state.dart';

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
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsCubit, SettingsState>(
      listener: (context, state) {
        if (state is SettingsLoaded || state is SettingsSaved) {
          final url = state is SettingsLoaded
              ? state.serverUrl
              : (state as SettingsSaved).serverUrl;
          if (_urlController.text != url) {
            _urlController.text = url;
          }
        }
        if (state is SettingsSaved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Settings saved — reconnecting to server.'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is SettingsLoading;
        const isSaving = false; // saving is instant via cubit

        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Settings', style: AppTypography.headingLg),
              const SizedBox(height: 4),
              Text(
                'Configure your Fluxora server connection.',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 32),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionCard(
                        title: 'Server Connection',
                        children: [
                          _SettingRow(
                            label: 'Server URL',
                            hint:
                                'The base URL of your Fluxora server, e.g.\nhttp://localhost:8080 or http://192.168.1.10:8080',
                            child: isLoading
                                ? const SizedBox(
                                    height: 40,
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  )
                                : TextFormField(
                                    controller: _urlController,
                                    style: AppTypography.bodyMd.copyWith(
                                      color: AppColors.textPrimary,
                                      fontFamily: 'monospace',
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'http://localhost:8080',
                                      hintStyle: AppTypography.bodyMd.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                      filled: true,
                                      fillColor: AppColors.surface,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                          color: AppColors.surfaceRaised,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                          color: AppColors.surfaceRaised,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                          color: AppColors.primary,
                                          width: 2,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton(
                              onPressed: isLoading || isSaving
                                  ? null
                                  : () {
                                      context
                                          .read<SettingsCubit>()
                                          .saveServerUrl(_urlController.text);
                                    },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Save Settings'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const _SectionCard(
                        title: 'About',
                        children: [
                          _InfoRow(
                            label: 'App Version',
                            value: '0.1.0+1',
                          ),
                          SizedBox(height: 8),
                          _InfoRow(
                            label: 'Platform',
                            value: 'Desktop Control Panel',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Section card ─────────────────────────────────────────────────────────────

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
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
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
            style: AppTypography.bodySm.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
        Text(
          value,
          style: AppTypography.bodySm.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
