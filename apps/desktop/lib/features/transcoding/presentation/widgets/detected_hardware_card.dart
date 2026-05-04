/// DetectedHardwareCard — Slice B widget surfacing the host's CPU + GPU
/// inventory from `/api/v1/transcoding/devices`.
///
/// Renders one tile per CPU / GPU.  GPU tiles show vendor + model + VRAM
/// + driver + a list of encoder names this vendor's GPU could drive on
/// this OS (intersected with the FFmpeg build's actual `available_encoders`
/// elsewhere — this card just shows the *capability*).  Empty state when
/// no devices were detected (best-effort probe failed).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/hardware_devices.dart';
import 'package:fluxora_core/widgets/flux_chip.dart';
import 'package:fluxora_desktop/features/transcoding/presentation/cubit/hardware_cubit.dart';

class DetectedHardwareCard extends StatelessWidget {
  const DetectedHardwareCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HardwareCubit, HardwareState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(AppSpacing.s14),
          decoration: BoxDecoration(
            color: AppColors.bgRaised,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(state: state),
              const SizedBox(height: AppSpacing.s10),
              ..._buildBody(context, state),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildBody(BuildContext context, HardwareState state) {
    if (state is HardwareInitial || state is HardwareLoading) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ];
    }
    if (state is HardwareFailure) {
      return [
        Text(
          'Hardware probe failed: ${state.message}',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textDim),
        ),
      ];
    }
    final loaded = state as HardwareLoaded;
    final devices = loaded.devices;
    if (devices.cpus.isEmpty && devices.gpus.isEmpty) {
      return [
        Text(
          'No CPU or GPU detected.  Probes are best-effort — '
          'this is normal on uncommon platforms or when the platform '
          'tools (lspci / wmic / system_profiler) are missing.',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textDim),
        ),
      ];
    }
    return [
      for (final cpu in devices.cpus) _CpuTile(cpu: cpu),
      if (devices.cpus.isNotEmpty && devices.gpus.isNotEmpty)
        const SizedBox(height: AppSpacing.s8),
      for (final gpu in devices.gpus) ...[
        _GpuTile(gpu: gpu),
        if (gpu != devices.gpus.last) const SizedBox(height: 6),
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});
  final HardwareState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.developer_board_outlined,
          size: 16,
          color: AppColors.textMutedV2,
        ),
        const SizedBox(width: 8),
        Text(
          'Detected hardware',
          style: AppTypography.captionV2.copyWith(
            color: AppColors.textMutedV2,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const Spacer(),
        if (state is HardwareLoaded || state is HardwareFailure)
          IconButton(
            tooltip: 'Re-detect',
            icon: const Icon(Icons.refresh_rounded, size: 16),
            color: AppColors.textMutedV2,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            onPressed: () => context.read<HardwareCubit>().refresh(),
          ),
      ],
    );
  }
}

class _CpuTile extends StatelessWidget {
  const _CpuTile({required this.cpu});
  final CpuInfo cpu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.memory_outlined, size: 14, color: AppColors.pillFgInfo),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${cpu.model} · ${cpu.threads} threads',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textBright,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FluxChip(cpu.vendor, color: FluxChipColor.neutral),
        ],
      ),
    );
  }
}

class _GpuTile extends StatelessWidget {
  const _GpuTile({required this.gpu});
  final GpuInfo gpu;

  @override
  Widget build(BuildContext context) {
    final pillColor = switch (gpu.vendor) {
      'nvidia' => FluxChipColor.success,
      'intel' => FluxChipColor.info,
      'amd' => FluxChipColor.error,
      'apple' => FluxChipColor.purple,
      _ => FluxChipColor.neutral,
    };
    final vendorLabel = switch (gpu.vendor) {
      'nvidia' => 'NVIDIA',
      'intel' => 'Intel',
      'amd' => 'AMD',
      'apple' => 'Apple',
      _ => 'GPU',
    };
    final detail = <String>[
      if (gpu.vramMb != null) _formatVram(gpu.vramMb!),
      if (gpu.driverVersion != null && gpu.driverVersion!.isNotEmpty)
        'driver ${gpu.driverVersion}',
      if (gpu.devPath != null) gpu.devPath!,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.developer_board_outlined,
              size: 14,
              color: pillColor == FluxChipColor.success
                  ? AppColors.pillFgSuccess
                  : AppColors.pillFgInfo,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                gpu.model,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textBright,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            FluxChip(vendorLabel, color: pillColor),
          ],
        ),
        if (detail.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 2),
            child: Text(
              detail,
              style: AppTypography.captionV2.copyWith(
                color: AppColors.textDim,
              ),
            ),
          ),
        if (gpu.encoderSupport.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 4),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final enc in gpu.encoderSupport)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgRoot.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      enc,
                      style: AppTypography.captionV2.copyWith(
                        color: AppColors.textMutedV2,
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatVram(int vramMb) {
    if (vramMb >= 1024) {
      final gb = vramMb / 1024;
      return gb == gb.roundToDouble()
          ? '${gb.toInt()} GB'
          : '${gb.toStringAsFixed(1)} GB';
    }
    return '$vramMb MB';
  }
}
