import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_desktop/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:fluxora_desktop/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:fluxora_desktop/features/dashboard/presentation/cubit/dashboard_state.dart';
import 'package:fluxora_desktop/shared/widgets/stat_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DashboardCubit>(
      create: (_) => DashboardCubit(
        repository: GetIt.I<DashboardRepository>(),
      )..load(),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          BlocBuilder<DashboardCubit, DashboardState>(
            builder: (context, state) => IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () =>
                  context.read<DashboardCubit>().load(),
            ),
          ),
        ],
      ),
      body: BlocBuilder<DashboardCubit, DashboardState>(
        builder: (context, state) => switch (state) {
          DashboardInitial() || DashboardLoading() =>
            const Center(child: CircularProgressIndicator()),
          DashboardLoaded() => _LoadedBody(state: state),
          DashboardFailure(:final message) => _ErrorBody(
              message: message,
              onRetry: () => context.read<DashboardCubit>().load(),
            ),
        },
      ),
    );
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.state});

  final DashboardLoaded state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ServerInfoCard(state: state),
          const SizedBox(height: 24),
          Text(
            'Overview',
            style: AppTypography.headingSm.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          _StatsRow(state: state),
        ],
      ),
    );
  }
}

class _ServerInfoCard extends StatelessWidget {
  const _ServerInfoCard({required this.state});

  final DashboardLoaded state;

  @override
  Widget build(BuildContext context) {
    final info = state.serverInfo;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.serverName,
                    style: AppTypography.headingMd.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version ${info.version} · ${info.tier.name.toUpperCase()}',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const _StatusPill(
              label: 'Online',
              color: AppColors.success,
            ),
            const SizedBox(width: 8),
            _RemoteAccessPill(remoteUrl: info.remoteUrl),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
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

class _RemoteAccessPill extends StatelessWidget {
  const _RemoteAccessPill({required this.remoteUrl});

  final String? remoteUrl;

  @override
  Widget build(BuildContext context) {
    final configured = remoteUrl != null && remoteUrl!.isNotEmpty;
    final color = configured ? AppColors.accent : AppColors.textMuted;
    final label = configured ? 'Remote: on' : 'Remote: off';
    return Tooltip(
      message: configured
          ? 'Off-LAN clients can reach this server at $remoteUrl'
          : 'No FLUXORA_PUBLIC_URL configured — off-LAN clients cannot reach this server',
      child: _StatusPill(label: label, color: color),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.state});

  final DashboardLoaded state;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        SizedBox(
          width: 200,
          child: StatCard(
            label: 'Approved Clients',
            value: '${state.approvedCount}',
            icon: Icons.check_circle_outline,
            color: AppColors.success,
          ),
        ),
        SizedBox(
          width: 200,
          child: StatCard(
            label: 'Pending Approval',
            value: '${state.pendingCount}',
            icon: Icons.pending_outlined,
            color: AppColors.warning,
          ),
        ),
        SizedBox(
          width: 200,
          child: StatCard(
            label: 'Total Clients',
            value: '${state.clients.length}',
            icon: Icons.devices_outlined,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AppColors.textMuted,
            size: 56,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
