import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_gradients.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/encoder_benchmark.dart';
import 'package:fluxora_core/entities/transcoding_status.dart';
import 'package:fluxora_desktop/core/router/app_router.dart';
import 'package:fluxora_desktop/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:fluxora_desktop/features/settings/presentation/cubit/settings_state.dart';
import 'package:fluxora_desktop/features/transcoding/domain/repositories/transcoding_repository.dart';
import 'package:fluxora_desktop/features/transcoding/presentation/cubit/transcoding_cubit.dart';
import 'package:fluxora_desktop/features/transcoding/presentation/cubit/transcoding_state.dart';
import 'package:fluxora_core/widgets/flux_button.dart';
import 'package:fluxora_core/widgets/flux_chip.dart';
import 'package:fluxora_desktop/shared/widgets/flux_card.dart';
import 'package:fluxora_desktop/shared/widgets/flux_progress.dart';
import 'package:fluxora_desktop/shared/widgets/flux_tab_bar.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';

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
          create: (_) =>
              TranscodingCubit(repository: GetIt.I<TranscodingRepository>())
                ..start(),
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
  // Global streaming mode toggle.  `'client-decode'` (the Recommended
  // default, plan 19 §M7) stream-copies modern codecs unconditionally.
  // `'auto'` (plan 20) starts with stream-copy and transparently falls
  // back to transcode when the client reports a decode error within 6 s
  // — opt-in for mixed device pools.  `'server-transcode'` is the legacy
  // plan-18 behaviour (always transcode AV1/VP9).
  String? _streamingMode;

  // Tab state — Configuration is the default landing tab (operator's most
  // common reason to be here is changing the active encoder); Benchmark is
  // a separate space because the per-encoder results table needs the full
  // page width and shouldn't compete with the live-stats sidebar for room.
  String _tab = _kConfigTab;
  static const _kConfigTab = 'config';
  static const _kBenchmarkTab = 'benchmark';
  static const _tabs = [
    FluxTab(id: _kConfigTab, label: 'Configuration', icon: Icons.tune_rounded),
    FluxTab(id: _kBenchmarkTab, label: 'Benchmark', icon: Icons.speed_rounded),
  ];

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
            _streamingMode = state.streamingMode;
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
        final isConfigTab = _tab == _kConfigTab;
        return Container(
          color: AppColors.bgRoot,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.s28,
                  right: AppSpacing.s28,
                ),
                child: PageHeader(
                  title: 'Encoder Settings',
                  subtitle: isConfigTab
                      ? 'Configure transcoding encoder, preset, and quality'
                      : 'Measure each encoder\'s throughput and capacity',
                  // Back arrow to the parent Transcoding screen — replaces
                  // the previous "Cancel" button which read like an undo
                  // affordance for unsaved settings (it wasn't, just a
                  // navigation pop).  Guard with ``canPop`` so a deep-link
                  // / restored-state entry that lands here without a
                  // navigation stack falls back to ``/transcoding``
                  // instead of crashing on an empty pop.
                  onBack: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(Routes.transcoding);
                    }
                  },
                  // Save still only renders on Configuration; Benchmark
                  // tab has no persisted state of its own.
                  actions: isConfigTab
                      ? FluxButton(
                          icon: Icons.save_outlined,
                          onPressed: settingsState is SettingsLoaded
                              ? () => _save(context, settingsState)
                              : null,
                          child: const Text('Save'),
                        )
                      : null,
                ),
              ),

              // ── Tabs ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s28,
                  0,
                  AppSpacing.s28,
                  0,
                ),
                child: FluxTabBar(
                  tabs: _tabs,
                  activeId: _tab,
                  onChange: (id) => setState(() => _tab = id),
                ),
              ),

              // ── Tab body ──────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.s28,
                    right: AppSpacing.s28,
                    top: AppSpacing.s14,
                    bottom: AppSpacing.s28,
                  ),
                  child: isConfigTab
                      ? _buildConfigTab()
                      : const _BenchmarkTab(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Configuration tab body — the original 2-column layout (settings cards
  /// on the left + live-stats sidebar on the right).  Pulled into its own
  /// method so the build above stays readable; uses the parent state's
  /// `_encoder` / `_preset` / `_crf` directly.
  Widget _buildConfigTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              // Streaming mode card (plan 19 §M7, expanded plan 20)
              _StreamingModeCard(
                value: _streamingMode ?? 'client-decode',
                onChanged: (mode) => setState(() => _streamingMode = mode),
              ),
              const SizedBox(height: AppSpacing.s14),

              // Hardware acceleration card
              _HardwareAccelCard(
                currentEncoder: _encoder,
                onEncoderChanged: (enc) => setState(() => _encoder = enc),
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
                      onChanged: (v) => setState(() => _encoder = v),
                    ),
                  ),
                  _SettingRow(
                    label: 'Encoding Preset',
                    sub: 'Speed vs quality tradeoff',
                    control: _PresetSelector(
                      value: _preset,
                      presets: _presets,
                      onChanged: (v) => setState(() => _preset = v),
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
                    sub: 'Lower = higher quality (0–51, default 23)',
                    control: _CrfSlider(
                      value: _crf ?? 23,
                      onChanged: (v) => setState(() => _crf = v),
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
    );
  }

  void _save(BuildContext context, SettingsLoaded state) {
    // Encoder Settings only edits transcoder fields — never re-send
    // licenseKey here.  Re-sending the loaded value would 422 the entire
    // PATCH whenever the stored key is malformed (Pydantic validator
    // rejects anything that isn't FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<SIG>).
    // The Settings → General tab is the only place the license can be
    // edited or cleared.
    context.read<SettingsCubit>().saveSettings(
      serverUrl: state.serverUrl,
      serverName: state.serverName,
      tier: state.tier,
      licenseKey: null,
      transcodingEncoder: _encoder,
      transcodingPreset: _preset,
      transcodingCrf: _crf,
      streamingMode: _streamingMode,
    );
  }
}

// ── Streaming mode card (plan 19 §M7) ─────────────────────────────────────────

class _StreamingModeCard extends StatelessWidget {
  const _StreamingModeCard({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsBlock(
      title: 'Streaming Mode',
      children: [
        _StreamingModeOption(
          mode: 'client-decode',
          title: 'Client decodes',
          subtitle: 'Recommended',
          body:
              'Stream original codec (AV1, VP9, HEVC, H.264) directly to '
              'your devices. Modern phones / tablets / desktops hardware-'
              'decode at near-zero power cost. Server CPU stays near 0 %.',
          warning: 'Devices older than ~2021 may fail to play AV1 sources.',
          selected: value == 'client-decode',
          onTap: () => onChanged('client-decode'),
        ),
        _StreamingModeOption(
          mode: 'auto',
          title: 'Auto',
          subtitle: 'Mixed device pools',
          body:
              'Tries client decoding first for near-zero server load. If a '
              'device cannot play the original video or audio codec, the '
              'server transparently falls back to transcoding just the '
              'affected stream for that session.',
          warning: null,
          selected: value == 'auto',
          onTap: () => onChanged('auto'),
        ),
        _StreamingModeOption(
          mode: 'server-transcode',
          title: 'Server transcodes',
          subtitle: 'Legacy / every device',
          body:
              'Server live-transcodes AV1 / VP9 sources to H.264 before '
              'streaming. Works on every device, but uses significant '
              'CPU/GPU per active stream.',
          warning: null,
          selected: value == 'server-transcode',
          onTap: () => onChanged('server-transcode'),
        ),
      ],
    );
  }
}

class _StreamingModeOption extends StatelessWidget {
  const _StreamingModeOption({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.warning,
    required this.selected,
    required this.onTap,
  });

  final String mode;
  final String title;
  final String subtitle;
  final String body;
  final String? warning;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Visual radio dot — explicit container instead of Material
            // Radio so we don't trigger the v3.32 deprecation churn around
            // RadioGroup; the InkWell-wrapped row is the actual selector.
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.violet : AppColors.textFaint,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.violet,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textBright,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Text(
                        subtitle,
                        style: AppTypography.captionV2.copyWith(
                          color: AppColors.textMutedV2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    body,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textMutedV2,
                    ),
                  ),
                  if (warning != null) ...[
                    const SizedBox(height: AppSpacing.s6),
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: AppColors.amber,
                        ),
                        const SizedBox(width: AppSpacing.s6),
                        Expanded(
                          child: Text(
                            warning!,
                            style: AppTypography.captionV2.copyWith(
                              color: AppColors.amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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
    (id: 'h264_nvenc', name: 'NVIDIA NVENC', color: AppColors.emerald),
    (id: 'h264_qsv', name: 'Intel QuickSync', color: AppColors.blue),
    (id: 'libx264', name: 'Software (libx264)', color: AppColors.textMutedV2),
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
                    const Text(
                      'Hardware Acceleration',
                      style: AppTypography.h2,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Use dedicated GPU/silicon for transcoding',
                      style: AppTypography.captionV2.copyWith(
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
                const FluxChip('Available', color: FluxChipColor.success),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s18,
              0,
              AppSpacing.s18,
              AppSpacing.s18,
            ),
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
                                  color: enc.color.withValues(alpha: 0.27),
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadii.sm,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.memory_outlined,
                                  size: 14,
                                  color: enc.color,
                                ),
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
                                    const FluxChip(
                                      'Primary',
                                      color: FluxChipColor.purple,
                                    ),
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
  const _SettingRow({required this.label, this.sub, required this.control});

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
                    style: AppTypography.captionV2.copyWith(
                      color: AppColors.textDim,
                    ),
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
    // Software
    ('libx264', 'Software (x264)'),
    ('libx265', 'Software (x265)'),
    // NVIDIA NVENC
    ('h264_nvenc', 'NVIDIA NVENC H.264'),
    ('hevc_nvenc', 'NVIDIA NVENC HEVC'),
    // Intel Quick Sync
    ('h264_qsv', 'Intel QuickSync H.264'),
    ('hevc_qsv', 'Intel QuickSync HEVC'),
    // AMD / Linux VA-API
    ('h264_vaapi', 'VAAPI H.264'),
    ('hevc_vaapi', 'VAAPI HEVC'),
    // Apple VideoToolbox (macOS only)
    ('h264_videotoolbox', 'VideoToolbox H.264'),
    ('hevc_videotoolbox', 'VideoToolbox HEVC'),
  ];

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: value,
      dropdownColor: AppColors.bgRoot,
      style: AppTypography.body.copyWith(color: AppColors.textBody),
      underline: const SizedBox.shrink(),
      items: _encoders
          .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
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

/// Inline chip-row selector for benchmark source resolution.
///
/// Visually mirrors `_FpsSelector` so the two controls feel consistent.
/// Selection is by ``(width, height)`` tuple rather than a label string so
/// the value flows directly into the API request without an extra lookup.
///
/// **Multi-select**: operators can pick any subset of [_resolutionOptions]
/// and the benchmark runs each tier sequentially through every encoder
/// (matrix mode).  At least one tier must stay selected — the parent
/// disables the Run button when [selected] is empty.
class _ResolutionSelector extends StatelessWidget {
  const _ResolutionSelector({
    required this.options,
    required this.selected,
    required this.enabled,
    required this.onToggle,
  });

  final List<({int width, int height, String label})> options;
  final Set<({int width, int height})> selected;
  final bool enabled;
  final ValueChanged<({int width, int height})> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s22,
        AppSpacing.s4,
        AppSpacing.s22,
        AppSpacing.s14,
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
                  'Source resolutions',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textBright,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Pick one or more — each runs sequentially through every '
                  'encoder',
                  style: AppTypography.captionV2.copyWith(
                    color: AppColors.textDim,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s16),
          Wrap(
            spacing: 4,
            children: options.map((opt) {
              final isSelected = selected.contains((
                width: opt.width,
                height: opt.height,
              ));
              return Semantics(
                button: true,
                selected: isSelected,
                label:
                    '${opt.label}'
                    '${isSelected ? ', selected' : ''}',
                child: GestureDetector(
                  onTap: enabled
                      ? () => onToggle((width: opt.width, height: opt.height))
                      : null,
                  child: MouseRegion(
                    cursor: enabled
                        ? SystemMouseCursors.click
                        : SystemMouseCursors.forbidden,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0x2EA855F7)
                            : const Color(0x08FFFFFF),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0x80A855F7)
                              : const Color(0x0FFFFFFF),
                        ),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: Text(
                        opt.label,
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: !enabled
                              ? AppColors.textDim
                              : isSelected
                              ? AppColors.violetSoft
                              : AppColors.textMutedV2,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Benchmark tab ──────────────────────────────────────────────────────────────

/// Top-level Benchmark tab body.
///
/// Two-column layout: the run pane on the left (controls + results) and a
/// 280-px history sidebar on the right.  Sharing state at this level lets
/// the sidebar re-render after a fresh run completes and lets a sidebar
/// click swap the visible result without round-tripping through the run
/// pane's own state.
class _BenchmarkTab extends StatefulWidget {
  const _BenchmarkTab();

  @override
  State<_BenchmarkTab> createState() => _BenchmarkTabState();
}

class _BenchmarkTabState extends State<_BenchmarkTab> {
  EncoderBenchmarkRun? _currentRun;
  // Bumped after every fresh run so the sidebar refetches its history list
  // — without this the sidebar would be stale until the operator clicked
  // its refresh button.  Sidebar-driven selections (loading an old run)
  // don't bump the version since the underlying history is unchanged.
  int _historyVersion = 0;

  void _setRunFromBenchmark(EncoderBenchmarkRun run) {
    setState(() {
      _currentRun = run;
      _historyVersion++;
    });
  }

  void _setRunFromHistory(EncoderBenchmarkRun run) {
    setState(() => _currentRun = run);
  }

  void _onRunDeleted(int deletedId) {
    // If the deleted run is the one currently visible, drop it from the
    // pane so the operator isn't left looking at orphaned data.
    setState(() {
      _historyVersion++;
      if (_currentRun?.id == deletedId) {
        _currentRun = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _BenchmarkBlock(
            run: _currentRun,
            onRunComplete: _setRunFromBenchmark,
          ),
        ),
        const SizedBox(width: AppSpacing.s14),
        SizedBox(
          width: 280,
          child: _BenchmarkHistorySidebar(
            currentRunId: _currentRun?.id,
            historyVersion: _historyVersion,
            onSelect: _setRunFromHistory,
            onDelete: _onRunDeleted,
          ),
        ),
      ],
    );
  }
}

// ── Benchmark block ────────────────────────────────────────────────────────────

/// Benchmark trigger + result-pane card.
///
/// State split: this widget owns the *transient* knobs (running flag, error
/// surface, fps + resolution selectors); the `run` it displays comes from
/// the parent `_BenchmarkTab` so the history sidebar can swap the visible
/// result by selecting an old entry.  Pulls [TranscodingRepository] from
/// GetIt directly so it doesn't have to be threaded through the parent.
class _BenchmarkBlock extends StatefulWidget {
  const _BenchmarkBlock({required this.run, required this.onRunComplete});

  /// The benchmark run currently rendered in the results pane.  Null on
  /// first mount before any run has happened OR after the operator deletes
  /// the visible run from history.
  final EncoderBenchmarkRun? run;

  /// Called with the freshly-completed run so the parent can update its
  /// state (highlighted history entry + sidebar refresh).
  final ValueChanged<EncoderBenchmarkRun> onRunComplete;

  @override
  State<_BenchmarkBlock> createState() => _BenchmarkBlockState();
}

class _BenchmarkBlockState extends State<_BenchmarkBlock> {
  static final _log = Logger();

  // Frame-rate options the operator can pick.  24 covers cinema-standard
  // movies; 30 is the typical default + most TV broadcast; 60 covers sports,
  // gaming captures, and smartphone footage.  Higher than 60 has no value
  // for this product (player doesn't render high-refresh material specially)
  // — the server-side validator caps at 60 so anything else would 422.
  static const _fpsOptions = <int>[24, 30, 60];

  // Resolution tiers shown in the UI.  Mirrors the server-side
  // ``benchmark_service._RESOLUTION_TIERS`` snap so any value the
  // operator picks lands on a known workload — and the benchmark history
  // stays comparable across runs.  Labels say "720p" rather than
  // "1280×720" because that's the language operators actually use when
  // discussing their library.
  static const _resolutionOptions = <({int width, int height, String label})>[
    (width: 1280, height: 720, label: '720p'),
    (width: 1920, height: 1080, label: '1080p'),
    (width: 3840, height: 2160, label: '4K'),
  ];

  bool _running = false;
  String? _error;
  int _selectedFps = 30;
  // Live progress snapshot from the server, polled every 500 ms while
  // ``_running`` is true.  Null between runs.
  BenchmarkProgress? _progress;
  Timer? _progressTimer;
  // Resolution selection — multi-pick.  Defaults to 1080p alone (matches
  // the prior single-resolution baseline so the first-time experience is
  // unchanged for operators who don't care about matrix mode).  Adding a
  // tier extends the run; the encode + cap probe both honor each tier so
  // the per-(encoder, resolution) row reflects that exact workload.
  // Operators can pick any subset; an empty set disables Run.
  Set<({int width, int height})> _selectedResolutions = {
    (width: 1920, height: 1080),
  };

  Future<void> _runBenchmark() async {
    setState(() {
      _running = true;
      _error = null;
      _progress = null;
    });
    _startProgressPolling();
    try {
      final repo = GetIt.I<TranscodingRepository>();
      // Walk in canonical-tier order (720p → 1080p → 4K) so the matrix
      // executes smallest-first.  Smallest-first means the operator sees
      // results land for the lighter workload before the heavier ones —
      // a 4K-first run would have the desktop spinning silently for
      // 30+ s before any rows appear.
      final ordered = _resolutionOptions
          .where(
            (opt) => _selectedResolutions.contains((
              width: opt.width,
              height: opt.height,
            )),
          )
          .map((opt) => Resolution(width: opt.width, height: opt.height))
          .toList();
      final run = await repo.benchmark(
        fps: _selectedFps,
        resolutions: ordered,
        // Cap verification is no longer opt-in — the chip would lie about
        // capacity if the operator never enabled it (registry default of
        // 3 is just a vendor doc; the real number on patched / RTX-40 /
        // driver-530+ setups is higher).  Always probe so the chip is
        // honest by default.
      );
      if (!mounted) return;
      _stopProgressPolling();
      setState(() {
        _running = false;
        _progress = null;
      });
      // Bubble the run up so the parent _BenchmarkTab can rerender both
      // the result pane (via widget.run) and the history sidebar (via
      // historyVersion bump).
      widget.onRunComplete(run);
    } catch (e, st) {
      _log.w('Encoder benchmark failed', error: e, stackTrace: st);
      if (!mounted) return;
      _stopProgressPolling();
      setState(() {
        _error = e.toString();
        _running = false;
        _progress = null;
      });
    }
  }

  /// Poll ``GET /benchmark/progress`` every 500 ms while a benchmark run
  /// is in flight.  500 ms is fast enough for "current encoder" updates
  /// to feel live (most encoders take 5–15 s) without flooding the
  /// localhost loopback.  The first poll fires immediately so the
  /// progress card appears within one frame of clicking Run.
  void _startProgressPolling() {
    _progressTimer?.cancel();
    _pollProgress();
    _progressTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _pollProgress(),
    );
  }

  void _stopProgressPolling() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  Future<void> _pollProgress() async {
    try {
      final repo = GetIt.I<TranscodingRepository>();
      final snap = await repo.benchmarkProgress();
      if (!mounted || !_running) return;
      setState(() => _progress = snap.running ? snap : null);
    } catch (e) {
      // Progress poll failures are silent — the main POST is still
      // running and will surface its own error if anything is broken.
      // Logging the poll failure would spam the log on every tick.
    }
  }

  @override
  void dispose() {
    _stopProgressPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsBlock(
      title: 'Benchmark',
      children: [
        _SettingRow(
          label: 'Test Encode',
          sub: 'Runs an 8 s synthetic encode through every available encoder',
          control: FluxButton(
            variant: FluxButtonVariant.secondary,
            size: FluxButtonSize.sm,
            icon: _running ? null : Icons.play_arrow_rounded,
            // Disabled while running OR when no resolutions are selected
            // — running with an empty set would just hand the server the
            // 720p default, which surprises an operator who deliberately
            // unticked every tier.  Explicit disabled state is honest.
            onPressed: (_running || _selectedResolutions.isEmpty)
                ? null
                : _runBenchmark,
            child: Text(_running ? 'Running…' : 'Run Benchmark'),
          ),
        ),
        // Resolution selector — multi-pick (720p library content / 1080p
        // live capture / 2160p HDR).  Bigger frames need more GPU bandwidth
        // + VRAM per session, so the per-encoder concurrent-capacity chip
        // can drop sharply when going 720p → 4K; matrix mode lets the
        // operator see all three tiers in one click.
        _ResolutionSelector(
          options: _resolutionOptions,
          selected: _selectedResolutions,
          enabled: !_running,
          onToggle: (v) => setState(() {
            // Toggle membership.  Allows the operator to drop down to
            // zero tiers transiently — Run is gated on non-empty above so
            // they can't accidentally trigger an empty-set request.
            if (_selectedResolutions.contains(v)) {
              _selectedResolutions = {..._selectedResolutions}..remove(v);
            } else {
              _selectedResolutions = {..._selectedResolutions, v};
            }
          }),
        ),
        // Frame-rate selector — 60 fps roughly halves each encoder's
        // realtime multiplier (twice the frames per source-second), so
        // operators planning for sports/gaming/phone footage benchmarks
        // need to pick it explicitly rather than infer 60-fps capability
        // from a 30-fps run.
        _FpsSelector(
          options: _fpsOptions,
          selected: _selectedFps,
          enabled: !_running,
          onChanged: (v) => setState(() => _selectedFps = v),
        ),
        // Live progress card — only rendered while a benchmark is in
        // flight.  Shows "Encoder N of M · current step" + a determinate
        // progress bar so the operator isn't staring at a dead spinner
        // for 60+ seconds.
        if (_running)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s22,
              AppSpacing.s10,
              AppSpacing.s22,
              AppSpacing.s14,
            ),
            child: _BenchmarkProgressCard(progress: _progress),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s22,
              0,
              AppSpacing.s22,
              AppSpacing.s14,
            ),
            child: Text(
              'Benchmark failed: $_error',
              style: AppTypography.captionV2.copyWith(color: AppColors.red),
            ),
          ),
        if (widget.run != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s22,
              0,
              AppSpacing.s22,
              AppSpacing.s18,
            ),
            child: _BenchmarkResultsTable(run: widget.run!),
          ),
      ],
    );
  }
}

// ── Benchmark history sidebar ──────────────────────────────────────────────────

/// Right-side panel listing recent benchmark runs.  Refetches when
/// [historyVersion] bumps (parent signals a fresh run completed).  Clicking
/// a row pulls the full body and hands it back via [onSelect]; the trash
/// icon deletes the entry and triggers [onDelete].
class _BenchmarkHistorySidebar extends StatefulWidget {
  const _BenchmarkHistorySidebar({
    required this.currentRunId,
    required this.historyVersion,
    required this.onSelect,
    required this.onDelete,
  });

  final int? currentRunId;
  final int historyVersion;
  final ValueChanged<EncoderBenchmarkRun> onSelect;
  final ValueChanged<int> onDelete;

  @override
  State<_BenchmarkHistorySidebar> createState() =>
      _BenchmarkHistorySidebarState();
}

class _BenchmarkHistorySidebarState extends State<_BenchmarkHistorySidebar> {
  static final _log = Logger();

  bool _loading = false;
  String? _error;
  List<BenchmarkHistoryEntry> _entries = const [];
  int? _busyId; // id of an entry currently mid-load or mid-delete

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant _BenchmarkHistorySidebar old) {
    super.didUpdateWidget(old);
    if (widget.historyVersion != old.historyVersion) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = GetIt.I<TranscodingRepository>();
      final history = await repo.benchmarkHistory();
      if (!mounted) return;
      setState(() {
        _entries = history.entries;
        _loading = false;
      });
    } catch (e, st) {
      _log.w('Benchmark history fetch failed', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _select(BenchmarkHistoryEntry entry) async {
    if (entry.id == widget.currentRunId) return; // already showing
    setState(() => _busyId = entry.id);
    try {
      final repo = GetIt.I<TranscodingRepository>();
      final run = await repo.benchmarkHistoryEntry(entry.id);
      if (!mounted) return;
      widget.onSelect(run);
    } catch (e, st) {
      _log.w('Benchmark history fetch entry failed', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Couldn\'t load that run: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(BenchmarkHistoryEntry entry) async {
    setState(() => _busyId = entry.id);
    try {
      final repo = GetIt.I<TranscodingRepository>();
      await repo.deleteBenchmarkHistoryEntry(entry.id);
      if (!mounted) return;
      widget.onDelete(entry.id);
      // Also drop it from our local list immediately for snappy feedback;
      // the parent's historyVersion bump will refetch on its own.
      setState(() {
        _entries = _entries
            .where((e) => e.id != entry.id)
            .toList(growable: false);
      });
    } catch (e, st) {
      _log.w('Benchmark history delete failed', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Couldn\'t delete that run: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FluxCard(
      padding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with refresh action
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s18,
              vertical: AppSpacing.s14,
            ),
            child: Row(
              children: [
                const Text('Recent Runs', style: AppTypography.h2),
                const Spacer(),
                Tooltip(
                  message: 'Refresh history',
                  waitDuration: const Duration(milliseconds: 350),
                  child: GestureDetector(
                    onTap: _loading ? null : _refresh,
                    child: MouseRegion(
                      cursor: _loading
                          ? SystemMouseCursors.forbidden
                          : SystemMouseCursors.click,
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 16,
                        color: _loading
                            ? AppColors.textDim
                            : AppColors.textBody,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0x0AFFFFFF), height: 1, thickness: 1),
          if (_loading && _entries.isEmpty)
            const _SidebarStateText('Loading history…')
          else if (_error != null && _entries.isEmpty)
            _SidebarStateText(_error!, isError: true)
          else if (_entries.isEmpty)
            const _SidebarStateText(
              'No runs yet — click Run Benchmark to record your first.',
            )
          else
            // Cap visible list height so a long history doesn't push the
            // page below the fold; the list itself scrolls.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _entries.length,
                itemBuilder: (context, i) {
                  final entry = _entries[i];
                  return _HistoryEntryRow(
                    entry: entry,
                    isActive: entry.id == widget.currentRunId,
                    isBusy: entry.id == _busyId,
                    onTap: () => _select(entry),
                    onDelete: () => _delete(entry),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarStateText extends StatelessWidget {
  const _SidebarStateText(this.message, {this.isError = false});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s18,
        vertical: AppSpacing.s18,
      ),
      child: Text(
        message,
        style: AppTypography.captionV2.copyWith(
          color: isError ? AppColors.red : AppColors.textDim,
        ),
      ),
    );
  }
}

class _HistoryEntryRow extends StatefulWidget {
  const _HistoryEntryRow({
    required this.entry,
    required this.isActive,
    required this.isBusy,
    required this.onTap,
    required this.onDelete,
  });

  final BenchmarkHistoryEntry entry;
  final bool isActive;
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_HistoryEntryRow> createState() => _HistoryEntryRowState();
}

class _HistoryEntryRowState extends State<_HistoryEntryRow> {
  bool _hover = false;

  /// Humanised "today HH:MM" / "yesterday HH:MM" / "MMM d HH:MM" stamp.
  /// Avoids dragging in `intl` for one helper.
  String _formatTimestamp(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDay = DateTime(local.year, local.month, local.day);
    final delta = today.difference(entryDay).inDays;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    if (delta == 0) return 'Today $hh:$mm';
    if (delta == 1) return 'Yesterday $hh:$mm';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final m = months[local.month - 1];
    return '$m ${local.day} $hh:$mm';
  }

  /// Sidebar caption resolution label.  Single-resolution runs name the
  /// tier ("1080p"); matrix runs collapse to a "N res" count so a long
  /// row doesn't blow past the 280-px sidebar width.  Operators clicking
  /// into the run see the full tier list in the source caption.
  String _resolutionLabel() {
    if (widget.entry.resolutionCount > 1) {
      return '${widget.entry.resolutionCount} res';
    }
    final w = widget.entry.width;
    final h = widget.entry.height;
    if (w == 1280 && h == 720) return '720p';
    if (w == 1920 && h == 1080) return '1080p';
    if (w == 3840 && h == 2160) return '4K';
    return '${w}x$h';
  }

  @override
  Widget build(BuildContext context) {
    final activeBg = widget.isActive
        ? const Color(0x14A855F7)
        : (_hover ? const Color(0x06FFFFFF) : Colors.transparent);
    final accent = widget.isActive ? AppColors.violet : AppColors.textDim;
    return MouseRegion(
      cursor: widget.isBusy
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.isBusy ? null : widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s14,
            vertical: AppSpacing.s10,
          ),
          decoration: BoxDecoration(
            color: activeBg,
            border: const Border(bottom: BorderSide(color: Color(0x06FFFFFF))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Active indicator dot — violet when this entry is the
              // currently-rendered run, muted otherwise.
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTimestamp(widget.entry.startedAt),
                      style: AppTypography.body.copyWith(
                        color: AppColors.textBright,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_resolutionLabel()} · '
                      '${widget.entry.fps} fps · '
                      '${widget.entry.encoderCount} encoder'
                      '${widget.entry.encoderCount == 1 ? '' : 's'}',
                      style: AppTypography.captionV2.copyWith(
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              // Delete affordance — only visible on hover so a row
              // doesn't read as "click anywhere to delete".
              if (_hover && !widget.isBusy)
                Tooltip(
                  message: 'Delete this run',
                  waitDuration: const Duration(milliseconds: 350),
                  child: GestureDetector(
                    onTap: widget.onDelete,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.only(left: AppSpacing.s8),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 15,
                        color: AppColors.red,
                      ),
                    ),
                  ),
                )
              else if (widget.isBusy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.violet,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// In-flight progress card — rendered inside `_BenchmarkBlock` while a
/// benchmark is running.  Shows three lines:
///   1. Status line — "Encoding h264_nvenc" / "Verifying NVENC session
///      cap" / "Starting benchmark…"
///   2. Determinate progress bar — `completed / total` fraction.
///   3. Caption — "Encoder 3 of 6" when known.
///
/// Falls back to indeterminate copy when the first poll hasn't returned
/// (initial 0–500 ms after clicking Run).
class _BenchmarkProgressCard extends StatelessWidget {
  const _BenchmarkProgressCard({required this.progress});

  final BenchmarkProgress? progress;

  /// Friendly tier label for matrix-mode status copy.  Falls back to
  /// "WxH" for non-canonical sizes.
  static String _tierLabel(int width, int height) {
    if (width == 1280 && height == 720) return '720p';
    if (width == 1920 && height == 1080) return '1080p';
    if (width == 3840 && height == 2160) return '4K';
    return '${width}x$height';
  }

  String _statusLine() {
    final p = progress;
    if (p == null || !p.running) return 'Preparing benchmark…';
    final step = p.currentStep ?? 'starting';
    final encoder = p.currentEncoder;
    // Matrix mode tagging — when total > 1, prefix the encoder name with
    // its current resolution so the operator always knows which tier
    // the row in flight belongs to without checking the caption.
    final inMatrix = (p.totalResolutions ?? 1) > 1;
    final resTag =
        inMatrix &&
            p.currentResolutionWidth != null &&
            p.currentResolutionHeight != null
        ? ' [${_tierLabel(p.currentResolutionWidth!, p.currentResolutionHeight!)}]'
        : '';
    switch (step) {
      case 'encoding':
        return encoder == null ? 'Encoding…' : 'Encoding $encoder$resTag';
      case 'verifying_cap':
        return encoder == null
            ? 'Verifying session cap…'
            : 'Verifying $encoder session cap$resTag';
      case 'starting':
        return 'Starting benchmark…';
      default:
        return 'Working…';
    }
  }

  String? _captionLine() {
    final p = progress;
    if (p == null ||
        !p.running ||
        p.totalEncoders == null ||
        p.currentIndex == null) {
      return null;
    }
    final base = 'Step ${p.currentIndex} of ${p.totalEncoders}';
    // Matrix-mode adds "(Resolution N of M)" so the operator can see how
    // far through the resolution sweep they are independently of the
    // step counter (which counts encoder × resolution pairs).
    final totalRes = p.totalResolutions ?? 1;
    if (totalRes > 1 && p.currentResolutionIndex != null) {
      return '$base  ·  Res ${p.currentResolutionIndex} of $totalRes';
    }
    return base;
  }

  /// Determinate fraction in [0.0, 1.0], or null while we're between
  /// completed-encoder ticks (Flutter's LinearProgressIndicator falls
  /// back to indeterminate animation when value is null).
  double? _fraction() {
    final p = progress;
    if (p == null || !p.running) return null;
    final total = p.totalEncoders;
    if (total == null || total <= 0) return null;
    final completed = p.completed ?? 0;
    final index = p.currentIndex ?? 0;
    // Halfway-credit the in-flight encoder so the bar moves between
    // discrete completion ticks instead of jumping in chunks.
    final inflight = (index > completed) ? 0.5 : 0.0;
    return ((completed + inflight) / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final fraction = _fraction();
    final caption = _captionLine();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: const Color(0x14A855F7),
        border: Border.all(color: const Color(0x40A855F7)),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: AppColors.violet,
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Text(
                  _statusLine(),
                  style: AppTypography.body.copyWith(
                    color: AppColors.textBright,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (caption != null)
                Text(
                  caption,
                  style: AppTypography.captionV2.copyWith(
                    color: AppColors.textDim,
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),
          _GradientProgressBar(value: fraction),
        ],
      ),
    );
  }
}

/// Linear progress bar with the brand violet gradient fill (and an
/// indeterminate sweeping animation when ``value`` is null).
///
/// Flutter's stock ``LinearProgressIndicator`` only takes a single
/// ``valueColor`` — no native gradient support — so this widget paints
/// the track + filled segment manually with the same
/// ``AppGradients.progress`` band the rest of the app uses.
class _GradientProgressBar extends StatefulWidget {
  const _GradientProgressBar({required this.value});

  /// Determinate fraction in [0.0, 1.0].  ``null`` triggers the
  /// indeterminate sweeping animation (initial 0–500 ms after Run is
  /// clicked, before the first progress poll returns).
  final double? value;

  @override
  State<_GradientProgressBar> createState() => _GradientProgressBarState();
}

class _GradientProgressBarState extends State<_GradientProgressBar>
    with SingleTickerProviderStateMixin {
  static const double _height = 4;
  static const double _radius = 2;
  static const Color _trackColor = Color(0x14FFFFFF);

  late final AnimationController _sweep;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.value == null) _sweep.repeat();
  }

  @override
  void didUpdateWidget(covariant _GradientProgressBar old) {
    super.didUpdateWidget(old);
    if (widget.value == null && !_sweep.isAnimating) {
      _sweep.repeat();
    } else if (widget.value != null && _sweep.isAnimating) {
      _sweep.stop();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: SizedBox(
        height: _height,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final v = widget.value;
            // Track + fill both painted as Positioned children of a Stack —
            // Positioned gives them their own width independent of the
            // tight parent constraints (a plain ``AnimatedContainer(width:
            // fillWidth)`` inside a tight box would be forced to fill the
            // parent and would always read as 100%).
            return Stack(
              fit: StackFit.expand,
              children: [
                // Track behind the fill.
                const ColoredBox(color: _trackColor),
                if (v != null)
                  // Determinate — gradient fills [0, v * width], animated
                  // via AnimatedPositioned so width transitions are
                  // smooth between encoder ticks instead of chunky jumps.
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOut,
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: (v.clamp(0.0, 1.0)) * w,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppGradients.progress,
                      ),
                    ),
                  )
                else
                  // Indeterminate — 35 %-wide gradient strip sweeps
                  // left-to-right; off-screen-left → off-screen-right per
                  // animation cycle.
                  AnimatedBuilder(
                    animation: _sweep,
                    builder: (context, _) {
                      const stripFrac = 0.35;
                      final stripW = w * stripFrac;
                      final start = -stripW + (w + stripW) * _sweep.value;
                      return Stack(
                        children: [
                          Positioned(
                            left: start,
                            top: 0,
                            bottom: 0,
                            width: stripW,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: AppGradients.progress,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Inline chip-row selector for benchmark source frame rate.
///
/// Visual style mirrors the existing `_PresetSelector` for `Encoding Preset`
/// so the two controls feel consistent.  Disabled (greyed) while a benchmark
/// is running — changing the value mid-run would mismatch the displayed
/// results against the actual measurement.
class _FpsSelector extends StatelessWidget {
  const _FpsSelector({
    required this.options,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final List<int> options;
  final int selected;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s22,
        AppSpacing.s4,
        AppSpacing.s22,
        AppSpacing.s14,
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
                  'Source frame rate',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textBright,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '24 = cinema · 30 = TV · 60 = sports / games',
                  style: AppTypography.captionV2.copyWith(
                    color: AppColors.textDim,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s16),
          Wrap(
            spacing: 4,
            children: options.map((fps) {
              final isSelected = fps == selected;
              return Semantics(
                button: true,
                selected: isSelected,
                label: '$fps fps${isSelected ? ', selected' : ''}',
                child: GestureDetector(
                  onTap: enabled ? () => onChanged(fps) : null,
                  child: MouseRegion(
                    cursor: enabled
                        ? SystemMouseCursors.click
                        : SystemMouseCursors.forbidden,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0x2EA855F7)
                            : const Color(0x08FFFFFF),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0x80A855F7)
                              : const Color(0x0FFFFFFF),
                        ),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: Text(
                        '$fps fps',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: !enabled
                              ? AppColors.textDim
                              : isSelected
                              ? AppColors.violetSoft
                              : AppColors.textMutedV2,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _BenchmarkResultsTable extends StatelessWidget {
  const _BenchmarkResultsTable({required this.run});

  final EncoderBenchmarkRun run;

  // Vendor display order matches the encoder advisor's priority chain
  // ordering — software is the universal fallback, then GPU vendors in
  // alphabetical order so the layout is predictable across hosts.
  static const _vendorOrder = ['software', 'nvidia', 'intel', 'amd', 'apple'];
  static const _vendorLabels = {
    'software': 'Software',
    'nvidia': 'NVIDIA NVENC',
    'intel': 'Intel Quick Sync',
    'amd': 'AMD VAAPI',
    'apple': 'Apple VideoToolbox',
  };

  @override
  Widget build(BuildContext context) {
    if (run.results.isEmpty) {
      return Text(
        'No encoders detected on this server.',
        style: AppTypography.captionV2.copyWith(color: AppColors.textDim),
      );
    }

    // Distinct (width, height) tuples in this run.  Single-resolution
    // runs collapse to one entry; matrix runs preserve operator-selection
    // order.  Used both to drive the row layout (per-row resolution chip
    // when > 1) and to render the source caption.
    final resolutions = run.resolutions.isNotEmpty
        ? run.resolutions
        : <Resolution>[Resolution(width: run.width, height: run.height)];
    final isMatrix = resolutions.length > 1;

    // Group results by vendor.  Each section gets a small caps label;
    // unknown vendors (shouldn't happen but defensive) get rendered last
    // under their raw name.  Within a vendor, sort by (encoder name,
    // resolution pixel count) so a matrix run reads as
    // ``h264_nvenc[720p, 1080p, 4K]`` then ``hevc_nvenc[...]`` — operator
    // mental model is "I want to compare the same encoder across tiers".
    final byVendor = <String, List<EncoderBenchmarkResult>>{};
    for (final r in run.results) {
      byVendor.putIfAbsent(r.vendor, () => []).add(r);
    }
    for (final list in byVendor.values) {
      list.sort((a, b) {
        final byEncoder = a.encoder.compareTo(b.encoder);
        if (byEncoder != 0) return byEncoder;
        return (a.width * a.height).compareTo(b.width * b.height);
      });
    }

    final sections = <Widget>[
      // Source-workload caption — pre-empts the "wait, did it test at
      // 89 fps?" confusion by making it clear the encoder result line's
      // ``out fps`` is the *encoder's* output rate, not the source rate.
      _SourceWorkloadCaption(
        resolutions: resolutions,
        fps: run.fps,
        durationSec: run.durationSec,
      ),
      const SizedBox(height: AppSpacing.s10),
    ];
    for (final v in _vendorOrder) {
      final list = byVendor.remove(v);
      if (list == null || list.isEmpty) continue;
      sections.add(_VendorSectionHeader(label: _vendorLabels[v] ?? v));
      for (final r in list) {
        sections.add(
          _BenchmarkResultRow(
            result: r,
            sourceFps: run.fps,
            showResolutionChip: isMatrix,
          ),
        );
      }
      sections.add(const SizedBox(height: AppSpacing.s10));
    }
    // Anything not in the known order — render at the end so we don't
    // silently drop rows on a future encoder vendor we haven't catalogued.
    for (final entry in byVendor.entries) {
      sections.add(_VendorSectionHeader(label: entry.key.toUpperCase()));
      for (final r in entry.value) {
        sections.add(
          _BenchmarkResultRow(
            result: r,
            sourceFps: run.fps,
            showResolutionChip: isMatrix,
          ),
        );
      }
      sections.add(const SizedBox(height: AppSpacing.s10));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: sections,
    );
  }
}

/// Plain-text "Source: 1280×720 · 60 fps · 8 s" line above the per-encoder
/// table.  Anchors what every metric in the rows below means by stating the
/// workload that produced them — without this, "89 fps" in a row reads as
/// "this is the test fps" when it actually means "this encoder produced 89
/// frames per wall-clock second".
class _SourceWorkloadCaption extends StatelessWidget {
  const _SourceWorkloadCaption({
    required this.resolutions,
    required this.fps,
    required this.durationSec,
  });

  /// One entry for single-resolution runs; multiple entries for matrix
  /// runs (rendered as a comma-joined tier list).  Order preserved.
  final List<Resolution> resolutions;
  final int fps;
  final int durationSec;

  /// Friendly label for a single tier — falls back to "1280x720" for
  /// non-canonical sizes (which the server clamps away anyway, but we
  /// stay defensive against unexpected history payloads).
  static String _tierLabel(int width, int height) {
    if (width == 1280 && height == 720) return '720p';
    if (width == 1920 && height == 1080) return '1080p';
    if (width == 3840 && height == 2160) return '4K';
    return '${width}x$height';
  }

  @override
  Widget build(BuildContext context) {
    final size = resolutions.length == 1
        ? '${resolutions.first.width}x${resolutions.first.height}'
        : resolutions.map((r) => _tierLabel(r.width, r.height)).join(', ');
    return Row(
      children: [
        const Icon(Icons.movie_outlined, size: 13, color: AppColors.textDim),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            'Source: $size  -  $fps fps  -  $durationSec s synthetic clip',
            style: AppTypography.captionV2.copyWith(color: AppColors.textDim),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _VendorSectionHeader extends StatelessWidget {
  const _VendorSectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s6, bottom: AppSpacing.s4),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.captionV2.copyWith(
              color: AppColors.textDim,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppSpacing.s10),
          const Expanded(
            child: Divider(color: Color(0x0FFFFFFF), height: 1, thickness: 1),
          ),
        ],
      ),
    );
  }
}

class _BenchmarkResultRow extends StatelessWidget {
  const _BenchmarkResultRow({
    required this.result,
    required this.sourceFps,
    this.showResolutionChip = false,
  });

  final EncoderBenchmarkResult result;
  final int sourceFps;

  /// Set by [_BenchmarkResultsTable] when the run carries multiple
  /// resolutions.  Renders a "720p" / "1080p" / "4K" pill next to the
  /// codec chip so the operator can tell at a glance which tier each
  /// row belongs to.  Off in single-resolution mode (the source caption
  /// at the top already names the tier; per-row chips would just be
  /// noise).
  final bool showResolutionChip;

  /// Friendly tier label for [result.width] x [result.height].  Falls
  /// back to "WxH" for non-canonical sizes.
  String get _resolutionLabel {
    final w = result.width;
    final h = result.height;
    if (w == 1280 && h == 720) return '720p';
    if (w == 1920 && h == 1080) return '1080p';
    if (w == 3840 && h == 2160) return '4K';
    return '${w}x$h';
  }

  // Header colour: emerald = ≥1× realtime, amber = sub-realtime, red = failed.
  Color get _passColor {
    if (!result.passed) return AppColors.red;
    final rt = result.realtimeMultiplier;
    if (rt != null && rt < 1) return AppColors.amber;
    return AppColors.emerald;
  }

  // Concurrent chip variant maps the same passing/sub-realtime/failed grades
  // to FluxChip colours — emerald for healthy multi-stream, amber when
  // cap-bound by a vendor-documented session limit, error for failed.
  FluxChipColor get _concurrentChipColor {
    if (!result.passed || result.recommendedConcurrent == null) {
      return FluxChipColor.neutral;
    }
    if (_isCapBound) {
      return FluxChipColor.warning;
    }
    return FluxChipColor.success;
  }

  /// Effective cap = verified value when present, else registry default.
  /// Used to colour the concurrent chip + drive the tooltip wording.
  int? get _effectiveCap =>
      result.verifiedConcurrent ?? result.concurrentSessionCap;

  bool get _isCapBound =>
      _effectiveCap != null &&
      result.recommendedConcurrent != null &&
      result.recommendedConcurrent! >= _effectiveCap!;

  String _concurrentLabel() {
    final n = result.recommendedConcurrent;
    if (n == null) return '—';
    final word = n == 1 ? 'stream' : 'streams';
    return '$n $word';
  }

  /// Hover explainer for the concurrent chip.  Differentiates between the
  /// vendor-documented cap (`recommendedConcurrent` capped by
  /// `concurrentSessionCap` from the registry — a default that may not
  /// apply to patched drivers / RTX 40-series / driver 530+) and the
  /// empirically-verified cap (`verifiedConcurrent` populated by the
  /// cap-probe when "Verify session caps" was enabled).
  String? _concurrentTooltip() {
    if (result.recommendedConcurrent == null) {
      return result.passed ? null : 'No measurement — encoder did not finish.';
    }
    final base =
        'Sustained capacity at realtime: ${result.recommendedConcurrent} '
        '${result.recommendedConcurrent == 1 ? "stream" : "streams"} '
        '(min of measured throughput and session cap).';

    final verified = result.verifiedConcurrent;
    if (verified != null) {
      // Cap was probed at the same workload as the main benchmark
      // (1280×720 @ chosen fps) — say so explicitly.  If the verified
      // value exceeds the registry default, call that out so the
      // operator knows their patched / newer-driver setup is being
      // honoured.
      final registry = result.concurrentSessionCap;
      const probeNote =
          'Probed at the same resolution + frame rate as '
          'this benchmark.';
      if (registry != null && verified > registry) {
        return '$base\n\nMeasured cap: $verified concurrent sessions '
            '(NVIDIA\'s documented default is $registry; your driver / '
            'card supports more). $probeNote';
      }
      if (registry != null && verified < registry) {
        return '$base\n\nMeasured cap: $verified concurrent sessions '
            '(below the documented $registry — driver may be throttling '
            'or other GPU activity may have interfered). $probeNote';
      }
      return '$base\n\nMeasured cap: $verified concurrent sessions '
          '— matches the vendor default. $probeNote';
    }

    if (!_isCapBound) return base;

    // Cap wasn't probed; chip reflects the registry default.  Be
    // explicit that this is documentation, not measurement.
    if (result.vendor == 'nvidia') {
      return '$base\n\nThis is NVIDIA\'s documented '
          '${result.concurrentSessionCap}-session default for consumer '
          'GeForce cards. Driver 530+ removed it on RTX 40-series; '
          'community patches lift it on older cards. Enable '
          '"Verify session caps" before re-running to measure your '
          'actual ceiling.';
    }
    return '$base\n\nThis is the vendor\'s documented '
        '${result.concurrentSessionCap}-session default. Enable '
        '"Verify session caps" before re-running to measure the actual '
        'ceiling on your hardware.';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row: status icon + encoder name + codec pill + concurrent chip
          Row(
            children: [
              Icon(
                result.passed
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                size: 14,
                color: _passColor,
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                result.encoder,
                style: AppTypography.body.copyWith(
                  color: AppColors.textBright,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              FluxChip(
                result.codec.toUpperCase(),
                color: FluxChipColor.neutral,
              ),
              if (showResolutionChip) ...[
                const SizedBox(width: AppSpacing.s6),
                FluxChip(
                  _resolutionLabel,
                  // Violet neutral pill — same family as the codec chip
                  // but tinted so the operator's eye groups encoder rows
                  // by tier visually (every "1080p" pill in the table
                  // shares the same colour).
                  color: FluxChipColor.purple,
                ),
              ],
              const Spacer(),
              if (result.recommendedConcurrent != null)
                Tooltip(
                  message: _concurrentTooltip() ?? '',
                  waitDuration: const Duration(milliseconds: 350),
                  preferBelow: false,
                  child: FluxChip(
                    _concurrentLabel(),
                    color: _concurrentChipColor,
                    // verified_outlined when the cap was empirically
                    // measured; layers_outlined when the chip reflects
                    // only the registry default.  Subtle visual cue —
                    // hover reveals the full distinction.
                    icon: result.verifiedConcurrent != null
                        ? Icons.verified_outlined
                        : Icons.layers_outlined,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // ── Metrics row OR error line
          if (result.passed)
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: _MetricsLine(
                result: result,
                sourceFps: sourceFps,
                speedColor: _passColor,
              ),
            )
          else if (result.error != null)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 2),
              child: Text(
                result.error!,
                style: AppTypography.captionV2.copyWith(color: AppColors.red),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

/// One-line dot-separated metric strip rendered below each passed encoder
/// row.  Nullable metrics (GPU%/VRAM on software encoders, startup when the
/// first frame wasn't seen) are omitted entirely so the line stays terse.
///
/// Every tile is wrapped in a tooltip explaining what the metric measures
/// and the unit — these labels are otherwise too terse for someone reading
/// the screen for the first time ("fps" reads as "test rate" when it's
/// actually the encoder's *output* rate; "realtime" needs the equation
/// to be intuitive).
class _MetricsLine extends StatelessWidget {
  const _MetricsLine({
    required this.result,
    required this.sourceFps,
    required this.speedColor,
  });

  final EncoderBenchmarkResult result;
  final int sourceFps;
  final Color speedColor;

  String _fmtFps(double? v) =>
      v == null ? '—' : (v < 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(0));

  String _fmtSpeed(double? v) => v == null ? '—' : '${v.toStringAsFixed(2)}×';

  String _fmtBitrate(double? kbps) {
    if (kbps == null) return '—';
    if (kbps >= 1000) return '${(kbps / 1000).toStringAsFixed(1)} Mb/s';
    return '${kbps.toStringAsFixed(0)} kb/s';
  }

  @override
  Widget build(BuildContext context) {
    const mono = TextStyle(
      fontFamily: 'JetBrains Mono',
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
    );
    final dim = AppTypography.captionV2.copyWith(color: AppColors.textDim);

    final tiles = <_MetricTile>[
      if (result.initMs != null)
        _MetricTile(
          label: 'startup',
          value: '${result.initMs}ms',
          valueStyle: mono.copyWith(color: AppColors.textBright),
          tooltip:
              'Wall-clock from FFmpeg launch to the first encoded '
              'frame.  Includes hwaccel device init + encoder session '
              'creation — NVENC typically takes ~500 ms here, software '
              'encoders ~50 ms.',
        ),
      _MetricTile(
        label: 'out fps',
        value: _fmtFps(result.fps),
        valueStyle: mono.copyWith(color: AppColors.textBright),
        tooltip:
            'Encoder *output* rate — frames per wall-clock second '
            'this encoder produced.  The source clip ran at $sourceFps '
            'fps; values above $sourceFps mean the encoder ran faster '
            'than realtime.',
      ),
      _MetricTile(
        label: 'realtime',
        value: _fmtSpeed(result.speedX),
        valueStyle: mono.copyWith(color: speedColor),
        tooltip:
            'How many seconds of source content the encoder '
            'processed per second of wall-clock.  ≥ 1.0× sustains a live '
            'stream at the source rate; below 1.0× the encoder lags '
            'behind realtime and a live stream would underrun.',
      ),
      _MetricTile(
        label: 'bitrate',
        value: _fmtBitrate(result.bitrateKbps),
        valueStyle: mono.copyWith(color: AppColors.textBright),
        tooltip:
            'Average encoded output bitrate measured by the muxer '
            'over the run.  Drives bandwidth + storage planning — a 4 Mb/s '
            'stream needs 4 Mb/s of upstream per concurrent viewer.',
      ),
      if (result.gpuUtilizationPercent != null)
        _MetricTile(
          label: 'gpu',
          value: '${result.gpuUtilizationPercent!.toStringAsFixed(0)}%',
          valueStyle: mono.copyWith(color: AppColors.textBright),
          tooltip:
              'GPU encoder-engine utilisation sampled once at the '
              'midpoint of the run via the vendor probe (nvidia-smi / '
              'intel_gpu_top / radeontop).  High values mean adding more '
              'concurrent streams will saturate the silicon.',
        ),
      if (result.vramUsedMb != null)
        _MetricTile(
          label: 'vram',
          value: '${result.vramUsedMb} MB',
          valueStyle: mono.copyWith(color: AppColors.textBright),
          tooltip:
              'Video memory in use during the run.  Each additional '
              'concurrent encode roughly multiplies this number — useful '
              'for predicting OOM on cards with limited VRAM.',
        ),
    ];

    final children = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10),
            child: Text('·', style: dim),
          ),
        );
      }
      children.add(tiles[i]);
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.valueStyle,
    required this.tooltip,
  });

  final String label;
  final String value;
  final TextStyle valueStyle;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 350),
      preferBelow: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(value, style: valueStyle),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.captionV2.copyWith(color: AppColors.textDim),
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
    final loadValue = (gpuUtil != null ? gpuUtil / 100.0 : 0.0).clamp(0.0, 1.0);

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
                    ? const Border(bottom: BorderSide(color: Color(0x0AFFFFFF)))
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    k,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textDim,
                    ),
                  ),
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
            Text(
              'Load',
              style: AppTypography.captionV2.copyWith(color: AppColors.textDim),
            ),
            const SizedBox(height: AppSpacing.s6),
            FluxProgress(value: loadValue, color: AppColors.amber),
          ],
        ],
      ),
    );
  }
}
