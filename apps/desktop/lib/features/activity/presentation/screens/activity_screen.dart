import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/stream_session.dart';
import 'package:fluxora_desktop/features/activity/domain/repositories/activity_repository.dart';
import 'package:fluxora_desktop/features/activity/presentation/cubit/activity_cubit.dart';
import 'package:fluxora_desktop/shared/widgets/stat_card.dart';
import 'package:intl/intl.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ActivityCubit>(
      create: (_) => ActivityCubit(
        GetIt.I<ActivityRepository>(),
      )..loadSessions(),
      child: const _ActivityView(),
    );
  }
}

class _ActivityView extends StatelessWidget {
  const _ActivityView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Activity Monitoring'),
        actions: [
          BlocBuilder<ActivityCubit, ActivityState>(
            builder: (context, state) => IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () => context.read<ActivityCubit>().loadSessions(),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocBuilder<ActivityCubit, ActivityState>(
        builder: (context, state) => state.when(
          initial: () => const SizedBox.shrink(),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (message) => _ErrorView(message: message),
          loaded: (sessions) => _SessionsList(sessions: sessions),
        ),
      ),
    );
  }
}

class _SessionsList extends StatelessWidget {
  const _SessionsList({required this.sessions});

  final List<StreamSession> sessions;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummary(context),
          const SizedBox(height: 32),
          Text(
            'Active Sessions',
            style: AppTypography.headingMd.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          _buildTable(context),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        SizedBox(
          width: 240,
          child: StatCard(
            label: 'Active Streams',
            value: sessions.length.toString(),
            icon: Icons.play_circle_outline,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _buildTable(BuildContext context) {
    if (sessions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.inbox_outlined, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 16),
                Text(
                  'No active sessions',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: AppColors.surfaceRaised,
            ),
            child: DataTable(
              headingTextStyle: AppTypography.headingSm.copyWith(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
              dataTextStyle: AppTypography.bodyMd.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              columnSpacing: 32,
              columns: const [
                DataColumn(label: Text('CLIENT ID')),
                DataColumn(label: Text('FILE ID')),
                DataColumn(label: Text('STARTED')),
                DataColumn(label: Text('TYPE')),
                DataColumn(label: Text('PROGRESS')),
                DataColumn(label: Text('ACTIONS')),
              ],
              rows: sessions.map((session) {
                final startTime = DateFormat('HH:mm:ss').format(session.startedAt.toLocal());
                return DataRow(
                  cells: [
                    DataCell(Text(session.clientId, style: AppTypography.mono)),
                    DataCell(Text(session.fileId, style: AppTypography.mono)),
                    DataCell(Text(startTime)),
                    DataCell(_Badge(
                      label: session.connectionType.name.toUpperCase(),
                      color: session.connectionType.name == 'webrtc' 
                        ? AppColors.accent 
                        : AppColors.primary,
                    )),
                    DataCell(Text(session.progressSec != null 
                      ? '${session.progressSec!.toStringAsFixed(1)}s' 
                      : '-')),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.stop_circle_outlined, color: AppColors.error, size: 20),
                        tooltip: 'Terminate Session',
                        onPressed: () => _confirmTerminate(context, session.id),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmTerminate(BuildContext context, String sessionId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Terminate Session'),
        content: const Text('Are you sure you want to stop this stream session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<ActivityCubit>().stopSession(sessionId);
              Navigator.pop(dialogContext);
            },
            child: const Text('Terminate', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.textMuted, size: 56),
          const SizedBox(height: 16),
          Text(message, style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.read<ActivityCubit>().loadSessions(),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
