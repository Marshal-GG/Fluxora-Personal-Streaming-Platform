import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/client_list_item.dart';
import 'package:fluxora_core/entities/enums.dart';
import 'package:fluxora_desktop/features/clients/domain/repositories/clients_repository.dart';
import 'package:fluxora_desktop/features/clients/presentation/cubit/clients_cubit.dart';
import 'package:fluxora_desktop/features/clients/presentation/cubit/clients_state.dart';
import 'package:fluxora_desktop/shared/widgets/status_badge.dart';

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ClientsCubit>(
      create: (_) => ClientsCubit(
        repository: GetIt.I<ClientsRepository>(),
      )..load(),
      child: const _ClientsView(),
    );
  }
}

class _ClientsView extends StatelessWidget {
  const _ClientsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => context.read<ClientsCubit>().load(),
          ),
        ],
      ),
      body: BlocBuilder<ClientsCubit, ClientsState>(
        builder: (context, state) => switch (state) {
          ClientsInitial() || ClientsLoading() =>
            const Center(child: CircularProgressIndicator()),
          ClientsLoaded() => _LoadedBody(state: state),
          ClientsFailure(:final message) => _ErrorBody(
              message: message,
              onRetry: () => context.read<ClientsCubit>().load(),
            ),
        },
      ),
    );
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.state});

  final ClientsLoaded state;

  @override
  Widget build(BuildContext context) {
    final clients = state.filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterRow(currentFilter: state.filter),
        const Divider(),
        Expanded(
          child: clients.isEmpty
              ? _EmptyState(filter: state.filter)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: clients.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _ClientTile(
                    client: clients[i],
                    isProcessing:
                        state.processingIds.contains(clients[i].id),
                  ),
                ),
        ),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.currentFilter});

  final ClientStatus? currentFilter;

  static const _filters = <(String, ClientStatus?)>[
    ('All', null),
    ('Pending', ClientStatus.pending),
    ('Approved', ClientStatus.approved),
    ('Rejected', ClientStatus.rejected),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Wrap(
        spacing: 8,
        children: _filters
            .map(
              (f) => FilterChip(
                label: Text(f.$1),
                selected: currentFilter == f.$2,
                onSelected: (_) =>
                    context.read<ClientsCubit>().setFilter(f.$2),
                selectedColor: AppColors.primary.withAlpha(40),
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: currentFilter == f.$2
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontSize: 13,
                ),
                backgroundColor: AppColors.surface,
                side: BorderSide(
                  color: currentFilter == f.$2
                      ? AppColors.primary.withAlpha(80)
                      : AppColors.surfaceRaised,
                ),
                shape: const StadiumBorder(),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ClientTile extends StatelessWidget {
  const _ClientTile({required this.client, required this.isProcessing});

  final ClientListItem client;
  final bool isProcessing;

  static const _platformIcons = {
    ClientPlatform.android: Icons.android,
    ClientPlatform.ios: Icons.phone_iphone,
    ClientPlatform.windows: Icons.desktop_windows,
    ClientPlatform.macos: Icons.laptop_mac,
    ClientPlatform.linux: Icons.computer,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              _platformIcons[client.platform] ?? Icons.devices,
              color: AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.name,
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${client.platform.name} · last seen ${_formatDate(client.lastSeen)}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            StatusBadge(status: client.status),
            const SizedBox(width: 16),
            if (isProcessing)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              _ActionButtons(client: client),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now().toUtc();
    final diff = now.difference(dt.toUtc());
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.client});

  final ClientListItem client;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ClientsCubit>();

    return switch (client.status) {
      ClientStatus.pending => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => cubit.approve(client.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
              child: const Text('Approve'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => cubit.reject(client.id),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
              child: const Text('Reject'),
            ),
          ],
        ),
      ClientStatus.approved => OutlinedButton(
          onPressed: () => cubit.reject(client.id),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            textStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600),
          ),
          child: const Text('Revoke'),
        ),
      ClientStatus.rejected => OutlinedButton(
          onPressed: () => cubit.approve(client.id),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.success,
            side: const BorderSide(color: AppColors.success),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            textStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600),
          ),
          child: const Text('Re-approve'),
        ),
    };
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final ClientStatus? filter;

  @override
  Widget build(BuildContext context) {
    final label = filter == null ? 'clients' : '${filter!.name} clients';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.devices_outlined,
              color: AppColors.textMuted, size: 48),
          const SizedBox(height: 12),
          Text(
            'No $label',
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
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
          const Icon(Icons.cloud_off_outlined,
              color: AppColors.textMuted, size: 56),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTypography.bodyMd
                .copyWith(color: AppColors.textSecondary),
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
