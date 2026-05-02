import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/activity_event.dart';
import 'package:fluxora_core/entities/library_storage_breakdown.dart';
import 'package:fluxora_desktop/core/router/app_router.dart';
import 'package:fluxora_desktop/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:fluxora_desktop/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:fluxora_desktop/features/dashboard/presentation/cubit/dashboard_state.dart';
import 'package:fluxora_desktop/features/recent_activity/domain/repositories/recent_activity_repository.dart';
import 'package:fluxora_desktop/features/recent_activity/presentation/cubit/recent_activity_cubit.dart';
import 'package:fluxora_desktop/features/recent_activity/presentation/cubit/recent_activity_state.dart';
import 'package:fluxora_desktop/features/storage/domain/repositories/storage_repository.dart';
import 'package:fluxora_desktop/features/storage/presentation/cubit/storage_cubit.dart';
import 'package:fluxora_desktop/features/storage/presentation/cubit/storage_state.dart';
import 'package:fluxora_desktop/features/system_stats/presentation/cubit/system_stats_cubit.dart';
import 'package:fluxora_desktop/shared/widgets/flux_button.dart';
import 'package:fluxora_desktop/shared/widgets/flux_card.dart';
import 'package:fluxora_desktop/shared/widgets/flux_progress.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';
import 'package:fluxora_desktop/shared/widgets/pill.dart';
import 'package:fluxora_desktop/shared/widgets/sparkline.dart';
import 'package:fluxora_desktop/shared/widgets/stat_tile.dart';
import 'package:fluxora_desktop/shared/widgets/status_dot.dart';
import 'package:fluxora_desktop/shared/widgets/storage_donut.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<DashboardCubit>(
          create: (_) =>
              DashboardCubit(repository: GetIt.I<DashboardRepository>())
                ..load(),
        ),
        BlocProvider<StorageCubit>(
          create: (_) =>
              StorageCubit(repository: GetIt.I<StorageRepository>())..load(),
        ),
        BlocProvider<RecentActivityCubit>(
          create: (_) => RecentActivityCubit(
            repository: GetIt.I<RecentActivityRepository>(),
          )..load(),
        ),
      ],
      child: const _DashboardView(),
    );
  }
}

// ── Top-level view ─────────────────────────────────────────────────────────────

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgRoot,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: AppSpacing.s28,
          right: AppSpacing.s28,
          bottom: AppSpacing.s28,
        ),
        child: BlocBuilder<DashboardCubit, DashboardState>(
          builder: (context, state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Page header ──────────────────────────────────────────
                PageHeader(
                  title: 'Dashboard',
                  subtitle: 'Overview of your media server',
                  actions: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FluxButton(
                        variant: FluxButtonVariant.secondary,
                        icon: Icons.refresh_rounded,
                        onPressed: () => _onRestartServer(context),
                        child: const Text('Restart Server'),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      FluxButton(
                        variant: FluxButtonVariant.danger,
                        icon: Icons.stop_rounded,
                        onPressed: () => _onStopServer(context),
                        child: const Text('Stop Server'),
                      ),
                    ],
                  ),
                ),

                // ── 4 Stat tiles ─────────────────────────────────────────
                _StatTilesRow(state: state),
                const SizedBox(height: AppSpacing.s18),

                // ── Server Info + Quick Access ────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _ServerInfoCard(state: state)),
                    const SizedBox(width: AppSpacing.s14),
                    const Expanded(child: _QuickAccessCard()),
                  ],
                ),
                const SizedBox(height: AppSpacing.s14),

                // ── Recent Activity + Storage Overview ────────────────────
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _RecentActivityCard()),
                    SizedBox(width: AppSpacing.s14),
                    Expanded(child: _StorageCard()),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _onRestartServer(BuildContext context) async {
    final repo = GetIt.I<DashboardRepository>();
    try {
      await repo.restartServer();
    } catch (_) {
      // Server may briefly drop the response while it restarts — expected.
    }
  }

  Future<void> _onStopServer(BuildContext context) async {
    final repo = GetIt.I<DashboardRepository>();
    try {
      await repo.stopServer();
    } catch (_) {
      // Server may not respond after stop — that is expected.
    }
  }
}

// ── 4 Stat tiles ──────────────────────────────────────────────────────────────

class _StatTilesRow extends StatelessWidget {
  const _StatTilesRow({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final loaded = state is DashboardLoaded ? state as DashboardLoaded : null;
    final approvedCount = loaded?.approvedCount ?? 0;
    final libraryCount = loaded?.libraryCount ?? 0;
    final activeStreams = context
            .select<SystemStatsCubit, int?>((c) => c.state.latest?.activeStreams)
        ?? 0;
    final cpuSamples =
        context.select<SystemStatsCubit, List<double>>((c) => c.state.cpuSamples);
    final cpuPercent = context
            .select<SystemStatsCubit, double?>((c) => c.state.latest?.cpuPercent)
        ?? 0.0;

    return Row(
      children: [
        Expanded(
          child: StatTile(
            icon: Icons.folder_outlined,
            label: 'Libraries',
            value: '$libraryCount',
            color: AppColors.violet,
          ),
        ),
        const SizedBox(width: AppSpacing.s14),
        Expanded(
          child: StatTile(
            icon: Icons.devices_outlined,
            label: 'Connected Clients',
            value: '$approvedCount',
            color: AppColors.blue,
          ),
        ),
        const SizedBox(width: AppSpacing.s14),
        Expanded(
          child: StatTile(
            icon: Icons.play_circle_outline_rounded,
            label: 'Active Streams',
            value: '$activeStreams',
            color: AppColors.pink,
          ),
        ),
        const SizedBox(width: AppSpacing.s14),
        // CPU tile — custom layout to include the sparkline below value
        Expanded(
          child: FluxCard(
            padding: AppSpacing.s18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: const Center(
                        child: Icon(Icons.monitor_heart_outlined,
                            size: 20, color: AppColors.amber),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CPU Usage',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textMutedV2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${cpuPercent.toStringAsFixed(0)}%',
                            style: AppTypography.displayV2.copyWith(
                              color: AppColors.textBright,
                              height: 1.1,
                              letterSpacing: -0.24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (cpuSamples.length >= 2) ...[
                  const SizedBox(height: AppSpacing.s8),
                  Sparkline(
                    data: cpuSamples,
                    color: AppColors.amber,
                    height: 36,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Server Information card ────────────────────────────────────────────────────

class _ServerInfoCard extends StatelessWidget {
  const _ServerInfoCard({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final loaded = state is DashboardLoaded ? state as DashboardLoaded : null;
    final info = loaded?.serverInfo;
    final lanIp = context.select<SystemStatsCubit, String?>(
        (c) => c.state.latest?.lanIp);
    final internetConnected = context.select<SystemStatsCubit, bool>(
        (c) => c.state.latest?.internetConnected ?? false);
    final publicAddress = context.select<SystemStatsCubit, String?>(
        (c) => c.state.latest?.publicAddress);
    final uptimeSeconds = context.select<SystemStatsCubit, int>(
        (c) => c.state.latest?.uptimeSeconds ?? 0);

    return FluxCard(
      padding: AppSpacing.s20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Server Information', style: AppTypography.h2),
          const SizedBox(height: AppSpacing.s16),
          _InfoRow(
            label: 'Server Name',
            value: info?.serverName ?? '—',
            index: 0,
          ),
          _InfoRow(
            label: 'Local IP',
            valueWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const StatusDot(status: DotStatus.online, size: 7),
                const SizedBox(width: AppSpacing.s6),
                Text(
                  lanIp ?? '—',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textBody,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            index: 1,
          ),
          _InfoRow(
            label: 'Internet Status',
            valueWidget: internetConnected
                ? const Pill('Connected', color: PillColor.success)
                : const Pill('Offline', color: PillColor.warning),
            index: 2,
          ),
          _InfoRow(
            label: 'Public Address',
            valueWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  publicAddress ?? '—',
                  style: AppTypography.monoBody.copyWith(
                    color: AppColors.textBody,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (publicAddress != null) ...[
                  const SizedBox(width: AppSpacing.s6),
                  const Icon(Icons.open_in_new_rounded,
                      size: 11, color: AppColors.violet),
                ],
              ],
            ),
            index: 3,
          ),
          _InfoRow(
            label: 'Uptime',
            value: _formatUptime(uptimeSeconds),
            index: 4,
          ),
          _InfoRow(
            label: 'Version',
            value: info?.version ?? '—',
            index: 5,
            isLast: true,
          ),
        ],
      ),
    );
  }

  String _formatUptime(int seconds) {
    if (seconds <= 0) return '—';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h}h ${m}m ${s}s';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    this.value,
    this.valueWidget,
    required this.index,
    this.isLast = false,
  }) : assert(value != null || valueWidget != null,
            'Either value or valueWidget must be provided');

  final String label;
  final String? value;
  final Widget? valueWidget;
  final int index;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0x0AFFFFFF)),
              ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textMutedV2,
            ),
          ),
          valueWidget ??
              Text(
                value!,
                style: AppTypography.body.copyWith(
                  color: AppColors.textBody,
                  fontWeight: FontWeight.w500,
                ),
              ),
        ],
      ),
    );
  }
}

// ── Quick Access card ──────────────────────────────────────────────────────────

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard();

  @override
  Widget build(BuildContext context) {
    return FluxCard(
      padding: AppSpacing.s20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Access', style: AppTypography.h2),
          const SizedBox(height: AppSpacing.s16),
          // 2×2 grid
          Row(
            children: [
              Expanded(
                child: _QuickTile(
                  icon: Icons.create_new_folder_outlined,
                  title: 'Add Library',
                  sub: 'Add folders to library',
                  color: AppColors.violet,
                  onTap: () => context.go(Routes.library),
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: _QuickTile(
                  icon: Icons.devices_outlined,
                  title: 'Manage Clients',
                  sub: 'View connected devices',
                  color: AppColors.blue,
                  onTap: () => context.go(Routes.clients),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),
          Row(
            children: [
              Expanded(
                child: _QuickTile(
                  icon: Icons.group_work_outlined,
                  title: 'Create Group',
                  sub: 'Organize your content',
                  color: AppColors.pink,
                  onTap: () => context.go(Routes.groups),
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: _QuickTile(
                  icon: Icons.monitor_heart_outlined,
                  title: 'View Activity',
                  sub: 'Real-time activity',
                  color: AppColors.amber,
                  onTap: () => context.go(Routes.activity),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),
          // Span-2 settings tile
          _QuickTile(
            icon: Icons.settings_outlined,
            title: 'Server Settings',
            sub: 'Configure server options',
            color: AppColors.textMutedV2,
            onTap: () => context.go(Routes.settings),
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatefulWidget {
  const _QuickTile({
    required this.icon,
    required this.title,
    required this.sub,
    required this.color,
    required this.onTap,
    this.fullWidth = false,
  });

  final IconData icon;
  final String title;
  final String sub;
  final Color color;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  State<_QuickTile> createState() => _QuickTileState();
}

class _QuickTileState extends State<_QuickTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.fullWidth ? double.infinity : null,
          padding: const EdgeInsets.all(AppSpacing.s14),
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0x0DA855F7)
                : const Color(0x05FFFFFF),
            border: Border.all(
              color: _hovered
                  ? const Color(0x33A855F7)
                  : const Color(0x0DFFFFFF),
            ),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: widget.fullWidth
              ? Row(
                  children: [
                    Icon(widget.icon, size: 16, color: widget.color),
                    const SizedBox(width: AppSpacing.s10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textBright,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.sub,
                          style: AppTypography.captionV2.copyWith(
                            color: AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(widget.icon, size: 16, color: widget.color),
                        const SizedBox(width: AppSpacing.s10),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: AppTypography.body.copyWith(
                              color: AppColors.textBright,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.sub,
                      style: AppTypography.captionV2.copyWith(
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Recent Activity card ───────────────────────────────────────────────────────

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard();

  @override
  Widget build(BuildContext context) {
    return FluxCard(
      padding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s20,
              vertical: AppSpacing.s16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Activity', style: AppTypography.h2),
                GestureDetector(
                  onTap: () => context.go(Routes.activity),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text(
                      'View All',
                      style: AppTypography.captionV2.copyWith(
                        color: AppColors.violet,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Event list
          BlocBuilder<RecentActivityCubit, RecentActivityState>(
            builder: (context, state) {
              return switch (state) {
                RecentActivityInitial() || RecentActivityLoading() =>
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.s20),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.violet,
                        ),
                      ),
                    ),
                  ),
                RecentActivityLoaded(:final events) => events.isEmpty
                    ? Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.s20),
                        child: Center(
                          child: Text(
                            'No recent activity',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textDim,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: events
                            .take(4)
                            .map((e) => _ActivityRow(event: e))
                            .toList(),
                      ),
                RecentActivityFailure(:final message) => Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.s20),
                    child: Center(
                      child: Text(
                        message,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textDim,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              };
            },
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.event});

  final ActivityEvent event;

  static (Color, IconData) _iconFor(String type) {
    final category = type.split('.').first;
    return switch (category) {
      'client' => (AppColors.blue, Icons.devices_outlined),
      'license' => (AppColors.amber, Icons.shield_outlined),
      'transcode' => (AppColors.pink, Icons.memory_outlined),
      'storage' => (AppColors.cyan, Icons.storage_outlined),
      'system' => (AppColors.violet, Icons.dns_outlined),
      _ => (AppColors.textMutedV2, Icons.circle_outlined),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (color, iconData) = _iconFor(event.type);

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0x08FFFFFF)),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s20,
        vertical: AppSpacing.s10,
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.s8),
            ),
            child: Center(
              child: Icon(iconData, size: 13, color: color),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.summary,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textBody,
                    height: 1.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  event.type,
                  style: AppTypography.captionV2.copyWith(
                    color: AppColors.textDim,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Text(
            _relativeTime(event.createdAt),
            style: AppTypography.monoCaption.copyWith(
              color: AppColors.textDim,
            ),
          ),
        ],
      ),
    );
  }

  /// Returns a human-friendly relative time string: "2m ago", "1h ago", etc.
  static String _relativeTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toUtc();
      final diff = DateTime.now().toUtc().difference(dt);
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '—';
    }
  }
}

// ── Storage Overview card ──────────────────────────────────────────────────────

class _StorageCard extends StatelessWidget {
  const _StorageCard();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StorageCubit, StorageState>(
      builder: (context, state) {
        return switch (state) {
          StorageInitial() || StorageLoading() => const FluxCard(
              padding: AppSpacing.s20,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.s20),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.violet,
                    ),
                  ),
                ),
              ),
            ),
          StorageLoaded(:final breakdown) =>
            _StorageCardLoaded(breakdown: breakdown),
          StorageFailure(:final message) => FluxCard(
              padding: AppSpacing.s20,
              child: Center(
                child: Text(
                  message,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textDim),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        };
      },
    );
  }
}

class _StorageCardLoaded extends StatelessWidget {
  const _StorageCardLoaded({required this.breakdown});

  final LibraryStorageBreakdown breakdown;

  static const _segmentColors = [
    AppColors.violet,
    AppColors.amber,
    AppColors.emerald,
    AppColors.pink,
  ];

  static const _segmentLabels = ['Movies', 'TV Shows', 'Music', 'Others'];

  @override
  Widget build(BuildContext context) {
    final total = breakdown.totalBytes;
    final capacity = breakdown.capacityBytes;
    final byType = breakdown.byType;

    final categorySizes = [
      byType.movies,
      byType.tv,
      byType.music,
      byType.files,
    ];

    final segments = List.generate(4, (i) {
      final pct = total > 0 ? (categorySizes[i] / total) * 100.0 : 0.0;
      return StorageDonutSegment(percent: pct, color: _segmentColors[i]);
    });

    final totalStr = _humanBytes(total);
    final capacityStr = _humanBytes(capacity);
    final usedPct = capacity > 0 ? (total / capacity * 100).toStringAsFixed(0) : '0';
    final progressValue = capacity > 0 ? (total / capacity).clamp(0.0, 1.0) : 0.0;

    // Split totalStr into number + unit for the donut centre text
    final parts = totalStr.split(' ');
    final donutNum = parts.isNotEmpty ? parts[0] : '0';
    final donutUnit = parts.length > 1 ? parts[1] : '';

    return FluxCard(
      padding: AppSpacing.s20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Storage Overview', style: AppTypography.h2),
              RichText(
                text: TextSpan(
                  style: AppTypography.captionV2.copyWith(
                    color: AppColors.textMutedV2,
                    fontSize: 11,
                  ),
                  children: [
                    const TextSpan(text: 'Total: '),
                    TextSpan(
                      text: totalStr,
                      style: const TextStyle(
                        color: AppColors.textBody,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          // Donut + legend
          Row(
            children: [
              StorageDonut(
                segments: segments,
                centerText: donutNum,
                unitText: donutUnit,
                size: 120,
              ),
              const SizedBox(width: AppSpacing.s24),
              Expanded(
                child: Column(
                  children: List.generate(4, (i) {
                    final pct = total > 0
                        ? (categorySizes[i] / total * 100).round()
                        : 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _segmentColors[i],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s10),
                          Expanded(
                            child: Text(
                              _segmentLabels[i],
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textBody,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          Text(
                            _humanBytes(categorySizes[i]),
                            style: AppTypography.monoCaption.copyWith(
                              color: AppColors.textMutedV2,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          SizedBox(
                            width: 32,
                            child: Text(
                              '$pct%',
                              style: AppTypography.monoCaption.copyWith(
                                color: AppColors.textDim,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          // Progress bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$totalStr of $capacityStr used',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  color: AppColors.textMutedV2,
                  height: 1.4,
                ),
              ),
              Text(
                '$usedPct%',
                style: AppTypography.captionV2.copyWith(
                  color: AppColors.violet,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s6),
          FluxProgress(value: progressValue),
        ],
      ),
    );
  }

  /// Formats bytes to a human-readable string with binary units (B/KB/MB/GB/TB).
  static String _humanBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final formatted = value < 10
        ? value.toStringAsFixed(2)
        : value < 100
            ? value.toStringAsFixed(1)
            : value.toStringAsFixed(0);
    return '$formatted ${units[unitIndex]}';
  }
}
