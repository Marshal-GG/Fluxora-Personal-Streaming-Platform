import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/transcoding_status.dart';
import 'package:fluxora_desktop/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:fluxora_desktop/features/settings/presentation/cubit/settings_state.dart';
import 'package:fluxora_desktop/features/transcoding/domain/repositories/transcoding_repository.dart';
import 'package:fluxora_desktop/features/transcoding/presentation/cubit/transcoding_cubit.dart';
import 'package:fluxora_desktop/features/transcoding/presentation/cubit/transcoding_state.dart';
import 'package:fluxora_desktop/shared/widgets/flux_button.dart';
import 'package:fluxora_desktop/shared/widgets/flux_card.dart';
import 'package:fluxora_desktop/shared/widgets/flux_progress.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';
import 'package:fluxora_desktop/shared/widgets/pill.dart';

// ── Entry point ────────────────────────────────────────────────────────────────

class EncoderSettingsScreen extends StatelessWidget {
  const EncoderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SettingsCubit>(
          create: (_) => GetIt.I<SettingsCubit>()..loadSettings(),
        ),
        BlocProvider<TranscodingCubit>(
          create: (_) => TranscodingCubit(
            repository: GetIt.I<TranscodingRepository>(),
          )..start(),
        ),
      ],
      child: const _EncoderSettingsView(),
    );
  }
}

// ── Main view ──────────────────────────────────────────────────────────────────

class _EncoderSettingsView extends StatefulWidget {
  const _EncoderSettingsView();

  @override
  State<_EncoderSettingsView> createState() => _EncoderSettingsViewState();
}

class _EncoderSettingsViewState extends State<_EncoderSettingsView> {
  String? _encoder;
  String? _preset;
  int? _crf;

  static const _presets = [
    'ultrafast',
    'superfast',
    'veryfast',
    'faster',
    'fast',
    'medium',
    'slow',
    'slower',
    'veryslow',
  ];

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsCubit, SettingsState>(
      listener: (context, state) {
        if (state is SettingsLoaded && _encoder == null) {
          setState(() {
            _encoder = state.transcodingEncoder;
            _preset = state.transcodingPreset;
            _crf = state.transcodingCrf;
          });
        }
        if (state is SettingsSaved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Encoder settings saved'),
              backgroundColor: AppColors.emerald,
            ),
          );
          context.pop();
        }
        if (state is SettingsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.red,
            ),
          );
        }
      },
      builder: (context, settingsState) {
        return Container(
          color: AppColors.bgRoot,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: AppSpacing.s28,
              right: AppSpacing.s28,
              bottom: AppSpacing.s28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────────────────
                PageHeader(
                  title: 'Encoder Settings',
                  subtitle:
                      'Configure transcoding encoder, preset, and quality',
                  actions: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FluxButton(
                        variant: FluxButtonVariant.secondary,
                        onPressed: () => context.pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      FluxButton(
                        icon: Icons.save_outlined,
                        onPressed: settingsState is SettingsLoaded
                            ? () => _save(context, settingsState)
                            : null,
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ),

                // ── 2-col layout ────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column
                    Expanded(
                      child: Column(
                        children: [
                          // Hardware acceleration card
                          _HardwareAccelCard(
                            currentEncoder: _encoder,
                            onEncoderChanged: (enc) =>
                                setState(() => _encoder = enc),
                          ),
                          const SizedBox(height: AppSpacing.s14),

                          // Encoder + preset card
                          _SettingsBlock(
                            title: 'Encoder & Preset',
                            children: [
                              _SettingRow(
                                label: 'Video Encoder',
                                sub: 'Active encoder for new transcodes',
                                control: _EncoderDropdown(
                                  value: _encoder,
                                  onChanged: (v) =>
                                      setState(() => _encoder = v),
                                ),
                              ),
                              _SettingRow(
                                label: 'Encoding Preset',
                                sub: 'Speed vs quality tradeoff',
                                control: _PresetSelector(
                                  value: _preset,
                                  presets: _presets,
                                  onChanged: (v) =>
                                      setState(() => _preset = v),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s14),

                          // Quality card
                          _SettingsBlock(
                            title: 'Quality',
                            children: [
                              _SettingRow(
                                label: 'Constant Rate Factor (CRF)',
                                sub:
                                    'Lower = higher quality (0–51, default 23)',
                                control: _CrfSlider(
                                  value: _crf ?? 23,
                                  onChanged: (v) =>
                                      setState(() => _crf = v),
                                ),
                              ),
                              const _SettingRow(
                                label: 'Test Encode',
                                sub: 'Benchmark hardware acceleration',
                                // TODO: wire to backend when endpoint ships.
                                control: FluxButton(
                                  variant: FluxButtonVariant.secondary,
                                  size: FluxButtonSize.sm,
                                  icon: Icons.play_arrow_rounded,
                                  onPressed: null,
                                  child: Text('Run Benchmark'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: AppSpacing.s14),

                    // Right column — live stats
                    SizedBox(
                      width: 280,
                      child: BlocBuilder<TranscodingCubit, TranscodingState>(
                        builder: (context, txState) {
                          final status = txState is TranscodingLoaded
                              ? txState.status
                              : null;
                          return _LiveStatsCard(status: status);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _save(BuildContext context, SettingsLoaded state) {
    context.read<SettingsCubit>().saveSettings(
          serverUrl: state.serverUrl,
          serverName: state.serverName,
          tier: state.tier,
          licenseKey: state.licenseKey,
          transcodingEncoder: _encoder,
          transcodingPreset: _preset,
          transcodingCrf: _crf,
        );
  }
}

// ── Hardware acceleration card ─────────────────────────────────────────────────

class _HardwareAccelCard extends StatelessWidget {
  const _HardwareAccelCard({
    required this.currentEncoder,
    required this.onEncoderChanged,
  });

  final String? currentEncoder;
  final ValueChanged<String?> onEncoderChanged;

  static const _knownEncoders = [
    (
      id: 'h264_nvenc',
      name: 'NVIDIA NVENC',
      color: AppColors.emerald,
    ),
    (
      id: 'h264_qsv',
      name: 'Intel QuickSync',
      color: AppColors.blue,
    ),
    (
      id: 'libx264',
      name: 'Software (libx264)',
      color: AppColors.textMutedV2,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return FluxCard(
      padding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s22,
              vertical: AppSpacing.s16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hardware Acceleration',
                        style: AppTypography.h2),
                    const SizedBox(height: 2),
                    Text(
                      'Use dedicated GPU/silicon for transcoding',
                      style: AppTypography.captionV2
                          .copyWith(color: AppColors.textDim),
                    ),
                  ],
                ),
                const Pill('Available', color: PillColor.success),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.s18, 0, AppSpacing.s18, AppSpacing.s18),
            child: Column(
              children: _knownEncoders.map((enc) {
                final isPrimary = currentEncoder == enc.id;
                return Semantics(
                  button: true,
                  selected: isPrimary,
                  label: '${enc.name} encoder${isPrimary ? ', selected' : ''}',
                  child: GestureDetector(
                    onTap: () => onEncoderChanged(enc.id),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(bottom: AppSpacing.s10),
                      padding: const EdgeInsets.all(AppSpacing.s14),
                      decoration: BoxDecoration(
                        color: isPrimary
                            ? const Color(0x14A855F7)
                            : const Color(0x05FFFFFF),
                        border: Border.all(
                          color: isPrimary
                              ? const Color(0x66A855F7)
                              : const Color(0x0DFFFFFF),
                          width: isPrimary ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: enc.color.withValues(alpha: 0.13),
                              border: Border.all(
                                  color: enc.color.withValues(alpha: 0.27)),
                              borderRadius:
                                  BorderRadius.circular(AppRadii.sm),
                            ),
                            child: Center(
                              child: Icon(Icons.memory_outlined,
                                  size: 14, color: enc.color),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  enc.name,
                                  style: AppTypography.body.copyWith(
                                    color: AppColors.textBright,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (isPrimary) ...[
                                  const SizedBox(width: AppSpacing.s8),
                                  const Pill('Primary',
                                      color: PillColor.purple),
                                ],
                              ],
                            ),
                          ),
                          // Selection indicator
                          Icon(
                            isPrimary
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 18,
                            color: isPrimary
                                ? AppColors.violet
                                : AppColors.textDim,
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Settings block ─────────────────────────────────────────────────────────────

class _SettingsBlock extends StatelessWidget {
  const _SettingsBlock({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return FluxCard(
      padding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s22,
              vertical: AppSpacing.s16,
            ),
            child: Text(title, style: AppTypography.h2),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    this.sub,
    required this.control,
  });

  final String label;
  final String? sub;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s22,
        vertical: AppSpacing.s14,
      ),
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
                  label,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textBright,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub!,
                    style: AppTypography.captionV2
                        .copyWith(color: AppColors.textDim),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s16),
          control,
        ],
      ),
    );
  }
}

// ── Form controls ──────────────────────────────────────────────────────────────

class _EncoderDropdown extends StatelessWidget {
  const _EncoderDropdown({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  static const _encoders = [
    ('libx264', 'Software (x264)'),
    ('libx265', 'Software (x265)'),
    ('h264_nvenc', 'NVIDIA NVENC H.264'),
    ('hevc_nvenc', 'NVIDIA NVENC HEVC'),
    ('h264_qsv', 'Intel QuickSync H.264'),
    ('hevc_qsv', 'Intel QuickSync HEVC'),
    ('h264_vaapi', 'VAAPI H.264'),
    ('h264_amf', 'AMD AMF H.264'),
  ];

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: value,
      dropdownColor: AppColors.bgRoot,
      style: AppTypography.body.copyWith(color: AppColors.textBody),
      underline: const SizedBox.shrink(),
      items: _encoders
          .map((e) => DropdownMenuItem(
                value: e.$1,
                child: Text(e.$2),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _PresetSelector extends StatelessWidget {
  const _PresetSelector({
    required this.value,
    required this.presets,
    required this.onChanged,
  });

  final String? value;
  final List<String> presets;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: presets.map((p) {
        final selected = p == value;
        return Semantics(
          button: true,
          selected: selected,
          label: 'Preset $p${selected ? ', selected' : ''}',
          child: GestureDetector(
            onTap: () => onChanged(p),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0x2EA855F7)
                    : const Color(0x08FFFFFF),
                border: Border.all(
                  color: selected
                      ? const Color(0x80A855F7)
                      : const Color(0x0FFFFFFF),
                ),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Text(
                p,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppColors.violetSoft
                      : AppColors.textMutedV2,
                ),
              ),
            ),
          ),
          ),
        );
      }).toList(),
    );
  }
}

class _CrfSlider extends StatelessWidget {
  const _CrfSlider({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.violet,
                inactiveTrackColor: const Color(0x1AFFFFFF),
                thumbColor: AppColors.violet,
                overlayColor: const Color(0x1AA855F7),
                trackHeight: 3,
              ),
              child: Slider(
                value: value.toDouble(),
                min: 0,
                max: 51,
                divisions: 51,
                onChanged: (v) => onChanged(v.toInt()),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              style: AppTypography.monoBody.copyWith(
                color: AppColors.violet,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Live stats card ────────────────────────────────────────────────────────────

class _LiveStatsCard extends StatelessWidget {
  const _LiveStatsCard({required this.status});

  final TranscodingStatus? status;

  @override
  Widget build(BuildContext context) {
    final sessionCount = status?.activeSessions.length ?? 0;

    // Pull GPU stats from the active encoder load entry.
    double? gpuUtil;
    if (status != null) {
      final load = status!.encoderLoads
          .where((l) => l.encoder == status!.activeEncoder)
          .firstOrNull;
      gpuUtil = load?.gpuUtilizationPercent ?? load?.cpuUtilizationPercent;
    }

    final rows = <(String, String, Color)>[
      ('Active Sessions', '$sessionCount', AppColors.violet),
      ('Active Encoder', status?.activeEncoder ?? '—', AppColors.emerald),
      (
        'Encoder Load',
        gpuUtil != null ? '${gpuUtil.toStringAsFixed(0)}%' : '—',
        AppColors.amber,
      ),
    ];

    // Progress bar for GPU load
    final loadValue =
        (gpuUtil != null ? gpuUtil / 100.0 : 0.0).clamp(0.0, 1.0);

    return FluxCard(
      padding: AppSpacing.s18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Live Stats', style: AppTypography.h2),
          const SizedBox(height: AppSpacing.s14),
          ...rows.asMap().entries.map((entry) {
            final i = entry.key;
            final (k, v, c) = entry.value;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: i < rows.length - 1
                    ? const Border(
                        bottom: BorderSide(color: Color(0x0AFFFFFF)))
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(k,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textDim)),
                  Text(
                    v,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (gpuUtil != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Text('Load',
                style: AppTypography.captionV2
                    .copyWith(color: AppColors.textDim)),
            const SizedBox(height: AppSpacing.s6),
            FluxProgress(value: loadValue, color: AppColors.amber),
          ],
        ],
      ),
    );
  }
}
