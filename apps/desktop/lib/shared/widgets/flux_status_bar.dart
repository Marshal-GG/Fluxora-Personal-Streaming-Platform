/// FluxStatusBar — the 28-px bottom strip rendered at the foot of the
/// desktop shell.
///
/// Translates the `StatusBar` component from
/// `docs/11_design/desktop_prototype/app/components/topbar.jsx` into Flutter.
/// The prototype renders a monospace strip with CPU · RAM · network · uptime
/// on the right, a connection state indicator on the left, and a centred
/// LAN-mode label. This widget is a faithful pixel-matched translation.
///
/// Consumption: wrap the app shell in a `BlocProvider<SystemStatsCubit>` and
/// place `FluxStatusBar()` at the bottom of the root column. The widget reads
/// `SystemStatsCubit` via `BlocSelector` — no `BlocProvider` is needed here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/system_stats.dart';
import 'package:fluxora_desktop/features/system_stats/presentation/cubit/system_stats_cubit.dart';
import 'package:fluxora_desktop/shared/widgets/status_dot.dart';

/// Bottom status strip — 28 px tall, glass background, 1 px top border.
///
/// Three regions:
/// - **Left**: connection state indicator + label.
/// - **Centre**: LAN mode / IP label (floats between [Spacer]s).
/// - **Right**: CPU · RAM · Network · Uptime metrics separated by thin
///   vertical dividers. Network and Uptime are hidden below 1100 px to
///   prevent overflow on narrow windows.
class FluxStatusBar extends StatelessWidget {
  const FluxStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SystemStatsCubit, SystemStatsState, SystemStats?>(
      selector: (state) => state.latest,
      builder: (context, latest) {
        final bool wide =
            MediaQuery.of(context).size.width >= 1100;

        return Container(
          height: AppSpacing.s28,
          decoration: const BoxDecoration(
            color: AppColors.titlebarGlass,
            border: Border(
              top: BorderSide(color: AppColors.borderSubtle, width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // ── Left: connection indicator ──────────────────────────
              _LeadingRegion(latest: latest),

              const Spacer(),

              // ── Centre: LAN mode label ──────────────────────────────
              if (latest != null) _CentreLabel(latest: latest),

              const Spacer(),

              // ── Right: metrics ──────────────────────────────────────
              _TrailingRegion(latest: latest, showExtended: wide),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Leading region
// ─────────────────────────────────────────────────────────────────────────────

class _LeadingRegion extends StatelessWidget {
  const _LeadingRegion({required this.latest});

  final SystemStats? latest;

  @override
  Widget build(BuildContext context) {
    final DotStatus dotStatus;
    final String label;

    if (latest == null) {
      dotStatus = DotStatus.idle;
      label = 'Connecting…';
    } else if (latest!.internetConnected) {
      dotStatus = DotStatus.online;
      label = 'Secure connection active';
    } else {
      dotStatus = DotStatus.offline;
      label = 'Offline';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        StatusDot(status: dotStatus, size: 6),
        const SizedBox(width: AppSpacing.s8),
        Text(
          label,
          style: AppTypography.captionV2.copyWith(
            color: AppColors.textMutedV2,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Centre region
// ─────────────────────────────────────────────────────────────────────────────

class _CentreLabel extends StatelessWidget {
  const _CentreLabel({required this.latest});

  final SystemStats latest;

  @override
  Widget build(BuildContext context) {
    final String label = (latest.lanIp != null && latest.lanIp!.isNotEmpty)
        ? 'LAN · ${latest.lanIp}'
        : 'LAN';

    return Text(
      label,
      style: AppTypography.monoMicro.copyWith(
        color: AppColors.violetTint,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trailing region
// ─────────────────────────────────────────────────────────────────────────────

class _TrailingRegion extends StatelessWidget {
  const _TrailingRegion({
    required this.latest,
    required this.showExtended,
  });

  final SystemStats? latest;
  final bool showExtended;

  @override
  Widget build(BuildContext context) {
    final String cpuValue =
        latest != null ? '${latest!.cpuPercent.toStringAsFixed(0)}%' : '—';
    final Color cpuColor = latest != null
        ? _pctColor(latest!.cpuPercent)
        : AppColors.textBody;

    final String ramValue = latest != null
        ? '${_fmtBytes(latest!.ramUsedBytes)} / ${_fmtBytes(latest!.ramTotalBytes)}'
        : '—';
    final Color ramColor = latest != null
        ? _pctColor(latest!.ramPercent)
        : AppColors.textBody;

    final String netValue = latest != null
        ? '↓${latest!.networkInMbps.toStringAsFixed(1)}  ↑${latest!.networkOutMbps.toStringAsFixed(1)} Mbps'
        : '—';

    final String uptimeValue =
        latest != null ? _formatUptime(latest!.uptimeSeconds) : '—';

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // CPU
        _MetricChip(
          icon: Icons.memory,
          label: 'CPU',
          value: cpuValue,
          valueColor: cpuColor,
        ),
        const _Divider(),

        // RAM
        _MetricChip(
          icon: Icons.developer_board,
          label: 'RAM',
          value: ramValue,
          valueColor: ramColor,
        ),

        // Network and Uptime are hidden on narrow windows.
        if (showExtended) ...[
          const _Divider(),
          _MetricChip(
            icon: Icons.swap_vert,
            label: 'NET',
            value: netValue,
            valueColor: AppColors.textBody,
          ),
          const _Divider(),
          _MetricChip(
            icon: Icons.schedule,
            label: 'UP',
            value: uptimeValue,
            valueColor: AppColors.textBody,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single metric chip: icon + label + value
// ─────────────────────────────────────────────────────────────────────────────

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label $value',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 12, color: AppColors.textMutedV2),
          const SizedBox(width: AppSpacing.s6),
          Text(
            label,
            style: AppTypography.eyebrow.copyWith(
              fontSize: 9,
              color: AppColors.textDim,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: AppSpacing.s4),
          Text(
            value,
            style: AppTypography.monoMicro.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vertical divider between metrics
// ─────────────────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
      color: AppColors.borderSubtle,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a colour that escalates from neutral → amber → red as [p] rises.
///
/// - p >= 85 → [AppColors.statusError] (red)
/// - p >= 60 → [AppColors.statusIdle] (amber)
/// - otherwise → [AppColors.textBody]
Color _pctColor(double p) {
  if (p >= 85) return AppColors.statusError;
  if (p >= 60) return AppColors.statusIdle;
  return AppColors.textBody;
}

/// Formats a raw byte count to `"X.X GB"` (one decimal place).
///
/// Values under 1 GB are shown as `"X.X MB"` to avoid `"0.0 GB"`.
String _fmtBytes(int bytes) {
  if (bytes >= 1073741824) {
    // 1 GB = 1024^3
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }
  return '${(bytes / 1048576).toStringAsFixed(1)} MB';
}

/// Formats [seconds] as `"HHh MMm"` — no seconds shown at status-bar size.
///
/// Examples: `3723` → `"1h 02m"`, `45` → `"0h 00m"`.
String _formatUptime(int seconds) {
  final int h = seconds ~/ 3600;
  final int m = (seconds % 3600) ~/ 60;
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}
