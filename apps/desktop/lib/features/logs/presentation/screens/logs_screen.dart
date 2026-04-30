import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_desktop/features/logs/domain/repositories/logs_repository.dart';
import 'package:fluxora_desktop/features/logs/presentation/cubit/logs_cubit.dart';
import 'package:fluxora_desktop/features/logs/presentation/cubit/logs_state.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LogsCubit>(
      create: (_) => LogsCubit(
        repository: GetIt.I<LogsRepository>(),
      )..load(),
      child: const _LogsView(),
    );
  }
}

class _LogsView extends StatelessWidget {
  const _LogsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Server Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => context.read<LogsCubit>().load(),
          ),
        ],
      ),
      body: BlocBuilder<LogsCubit, LogsState>(
        builder: (context, state) => switch (state) {
          LogsInitial() || LogsLoading() =>
            const Center(child: CircularProgressIndicator()),
          LogsLoaded(:final logs) => _LogsContent(logs: logs),
          LogsFailure(:final message) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                  const SizedBox(height: 16),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<LogsCubit>().load(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
        },
      ),
    );
  }
}

class _LogsContent extends StatelessWidget {
  const _LogsContent({required this.logs});
  final String logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Center(
        child: Text(
          'No logs available yet.',
          style: AppTypography.bodyMd.copyWith(color: AppColors.textMuted),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SelectionArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            reverse: true, // Start at the bottom
            child: Text(
              logs,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Color(0xFFD4D4D4),
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
