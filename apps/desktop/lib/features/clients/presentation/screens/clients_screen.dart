import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/client_list_item.dart';
import 'package:fluxora_core/entities/enums.dart';
import 'package:fluxora_core/entities/group.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_desktop/features/clients/domain/repositories/clients_repository.dart';
import 'package:fluxora_desktop/features/clients/presentation/cubit/clients_cubit.dart';
import 'package:fluxora_desktop/features/clients/presentation/cubit/clients_state.dart';
import 'package:fluxora_desktop/features/clients/presentation/widgets/pair_device_dialog.dart';
import 'package:fluxora_desktop/features/groups/domain/repositories/groups_repository.dart';
import 'package:fluxora_desktop/features/system_stats/presentation/cubit/system_stats_cubit.dart';
import 'package:fluxora_core/widgets/flux_button.dart';
import 'package:fluxora_core/widgets/flux_chip.dart';
import 'package:fluxora_desktop/shared/widgets/flux_card.dart';
import 'package:fluxora_desktop/shared/widgets/flux_glass_dialog.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';
import 'package:fluxora_desktop/shared/widgets/stat_tile.dart';
import 'package:fluxora_desktop/shared/widgets/status_dot.dart';

// ── Entry point ────────────────────────────────────────────────────────────────

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

// ── Main stateful view ─────────────────────────────────────────────────────────

class _ClientsView extends StatefulWidget {
  const _ClientsView();

  @override
  State<_ClientsView> createState() => _ClientsViewState();
}

class _ClientsViewState extends State<_ClientsView> {
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _deviceFilter = 'All';
  String _sortBy = 'Last Active';
  String? _selectedClientId;

  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Filtering + sorting ────────────────────────────────────────────────────

  List<ClientListItem> _applyFilters(List<ClientListItem> clients) {
    var result = clients.toList();

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.platform.name.toLowerCase().contains(q);
      }).toList();
    }

    // Status filter.  Default 'All' hides revoked / rejected clients so
    // the operator's working list is just active devices — there's a
    // dedicated "Revoked" filter to bring them back.  Without this
    // default-hide, every revoked device piles up in the table forever
    // since the server keeps the row for audit history.
    if (_statusFilter == 'All') {
      result = result
          .where((c) => c.status != ClientStatus.rejected)
          .toList();
    } else {
      result = result.where((c) {
        return switch (_statusFilter) {
          'Online' => c.status == ClientStatus.approved && c.isTrusted,
          'Pending' => c.status == ClientStatus.pending,
          'Revoked' => c.status == ClientStatus.rejected,
          _ => true,
        };
      }).toList();
    }

    // Device type filter
    if (_deviceFilter != 'All') {
      result = result.where((c) {
        return _deviceTypeLabel(c.platform) == _deviceFilter;
      }).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'Name':
        result.sort((a, b) => a.name.compareTo(b.name));
      case 'Status':
        result.sort((a, b) => a.status.name.compareTo(b.status.name));
      case 'Last Active':
        result.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgRoot,
      child: BlocBuilder<ClientsCubit, ClientsState>(
        builder: (context, state) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Main content ─────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.s28,
                    right: AppSpacing.s28,
                    bottom: AppSpacing.s28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Page header ──────────────────────────────────────
                      PageHeader(
                        title: 'Clients',
                        subtitle:
                            'Manage connected devices and client access',
                        actions: FluxButton(
                          icon: Icons.qr_code_2_rounded,
                          onPressed: () => showPairDeviceDialog(context),
                          child: const Text('Pair device'),
                        ),
                      ),

                      // ── Stat tiles ───────────────────────────────────────
                      _buildStatTiles(context, state),
                      const SizedBox(height: AppSpacing.s18),

                      // ── Filter row ───────────────────────────────────────
                      _buildFilterRow(context),
                      const SizedBox(height: AppSpacing.s14),

                      // ── Table ────────────────────────────────────────────
                      _buildTable(context, state),
                    ],
                  ),
                ),
              ),

              // ── Right detail panel ───────────────────────────────────────
              _buildDetailPanel(state),
            ],
          );
        },
      ),
    );
  }

  // ── Stat tiles ─────────────────────────────────────────────────────────────

  Widget _buildStatTiles(BuildContext context, ClientsState state) {
    final clients =
        state is ClientsLoaded ? state.clients : <ClientListItem>[];
    final total = clients.length;
    final online = clients
        .where((c) => c.status == ClientStatus.approved && c.isTrusted)
        .length;
    final activeStreams = context
            .select<SystemStatsCubit, int?>((c) => c.state.latest?.activeStreams)
        ?? 0;

    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: 'Total Clients $total',
            child: StatTile(
              icon: Icons.people_outline_rounded,
              label: 'Total Clients',
              value: '$total',
              color: const Color(0xFFA855F7),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s14),
        Expanded(
          child: Semantics(
            label: 'Online Now $online',
            child: StatTile(
              icon: Icons.circle_outlined,
              label: 'Online Now',
              value: '$online',
              color: const Color(0xFF10B981),
              accent: AppColors.textMutedV2,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s14),
        Expanded(
          child: Semantics(
            label: 'Active Streams $activeStreams',
            child: StatTile(
              icon: Icons.play_circle_outline_rounded,
              label: 'Active Streams',
              value: '$activeStreams',
              color: const Color(0xFF3B82F6),
              accent: AppColors.textMutedV2,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s14),
        Expanded(
          child: Semantics(
            label: 'Total Connections $total',
            child: StatTile(
              icon: Icons.history_rounded,
              label: 'Total Connections',
              value: '$total',
              color: const Color(0xFFEC4899),
              accent: AppColors.textMutedV2,
            ),
          ),
        ),
      ],
    );
  }

  // ── Filter row ─────────────────────────────────────────────────────────────

  Widget _buildFilterRow(BuildContext context) {
    return Row(
      children: [
        // Search input — Expanded so it shrinks when the detail panel is
        // open and the available width tightens, instead of pushing the
        // dropdowns off the right edge.
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: _SearchInput(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s10),

        // Status popup.  'All' default-hides revoked clients (see
        // _applyFilters); 'Revoked' is the explicit way to see them.
        _FilterDropdown(
          label: _statusFilter == 'All' ? 'All Status' : _statusFilter,
          options: const ['All', 'Online', 'Pending', 'Revoked'],
          selected: _statusFilter,
          onSelected: (v) => setState(() => _statusFilter = v),
        ),
        const SizedBox(width: AppSpacing.s10),

        // Device popup
        _FilterDropdown(
          label: _deviceFilter == 'All' ? 'All Devices' : _deviceFilter,
          options: const ['All', 'Mobile', 'Tablet', 'TV', 'Desktop'],
          selected: _deviceFilter,
          onSelected: (v) => setState(() => _deviceFilter = v),
        ),
        const SizedBox(width: AppSpacing.s10),

        // Sort popup
        _FilterDropdown(
          label: 'Sort: $_sortBy',
          options: const ['Name', 'Status', 'Last Active'],
          selected: _sortBy,
          onSelected: (v) => setState(() => _sortBy = v),
        ),

        const SizedBox(width: AppSpacing.s10),

        // Refresh button
        Tooltip(
          message: 'Refresh clients',
          child: _IconActionButton(
            icon: Icons.refresh_rounded,
            onTap: () => context.read<ClientsCubit>().load(),
          ),
        ),
      ],
    );
  }

  // ── Table ──────────────────────────────────────────────────────────────────

  Widget _buildTable(BuildContext context, ClientsState state) {
    return FluxCard(
      padding: 0,
      child: switch (state) {
        ClientsInitial() || ClientsLoading() => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.violet,
                ),
              ),
            ),
          ),
        ClientsFailure(:final message) => Padding(
            padding: const EdgeInsets.all(AppSpacing.s28),
            child: Column(
              children: [
                const Icon(Icons.cloud_off_outlined,
                    color: AppColors.textDim, size: 48),
                const SizedBox(height: AppSpacing.s12),
                Text(message,
                    style: AppTypography.body
                        .copyWith(color: AppColors.textMutedV2),
                    textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.s16),
                FluxButton(
                  variant: FluxButtonVariant.secondary,
                  icon: Icons.refresh_rounded,
                  onPressed: () => context.read<ClientsCubit>().load(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ClientsLoaded(:final clients) => Column(
            children: [
              // Header row
              const _TableHeaderRow(),
              // Data rows
              ...() {
                final filtered = _applyFilters(clients);
                if (filtered.isEmpty) {
                  return [
                    _EmptyTableState(
                      hasFilters: _searchQuery.isNotEmpty ||
                          _statusFilter != 'All' ||
                          _deviceFilter != 'All',
                    ),
                  ];
                }
                return filtered
                    .map((c) => _ClientRow(
                          client: c,
                          isSelected: _selectedClientId == c.id,
                          isProcessing: state.processingIds.contains(c.id),
                          onTap: () => setState(
                              () => _selectedClientId = c.id),
                          onApprove: () =>
                              context.read<ClientsCubit>().approve(c.id),
                          onReject: () =>
                              context.read<ClientsCubit>().reject(c.id),
                          onRevoke: () =>
                              _confirmRevoke(context, c),
                        ))
                    .toList();
              }(),
              // Pagination footer (visual only)
              _TableFooter(
                count: _applyFilters(clients).length,
                total: clients.length,
              ),
            ],
          ),
      },
    );
  }

  // ── Right detail panel ─────────────────────────────────────────────────────

  Widget _buildDetailPanel(ClientsState state) {
    ClientListItem? selected;
    if (_selectedClientId != null && state is ClientsLoaded) {
      try {
        selected = state.clients
            .firstWhere((c) => c.id == _selectedClientId);
      } catch (_) {
        selected = null;
      }
    }

    return _ClientDetailPanel(
      client: selected,
      onClose: () => setState(() => _selectedClientId = null),
      onApprove: selected != null
          ? () => context.read<ClientsCubit>().approve(selected!.id)
          : null,
      onReject: selected != null
          ? () => context.read<ClientsCubit>().reject(selected!.id)
          : null,
      onRevoke: selected != null
          ? () => _confirmRevoke(context, selected!)
          : null,
    );
  }

  // ── Confirm + dispatch a destructive revoke ───────────────────────────────

  Future<void> _confirmRevoke(
    BuildContext context,
    ClientListItem client,
  ) async {
    final cubit = context.read<ClientsCubit>();
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xCC0F0C24),
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.bgRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: Text(
          'Revoke ${client.name}?',
          style: AppTypography.h2.copyWith(color: AppColors.textBright),
        ),
        content: Text(
          'The device will be signed out immediately.  Its bearer token '
          'is dead the moment this lands — any in-flight request will '
          '401 on the next round-trip.  The client_id is kept for audit '
          'history; the user can pair the same device again from scratch.',
          style: AppTypography.body.copyWith(color: AppColors.textBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.body.copyWith(color: AppColors.textBright),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              'Revoke',
              style: AppTypography.body.copyWith(
                color: const Color(0xFFF87171),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await cubit.revoke(client.id);
    }
  }
}

// ── Search input ───────────────────────────────────────────────────────────────

class _SearchInput extends StatelessWidget {
  const _SearchInput({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xB3141226),
        border: Border.all(color: const Color(0x0FFFFFFF)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(Icons.search_rounded, size: 13, color: Color(0xFF64748B)),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.textBody,
                height: 1,
              ),
              decoration: const InputDecoration(
                hintText: 'Search clients…',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── Filter dropdown ────────────────────────────────────────────────────────────

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      color: AppColors.bgRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        side: const BorderSide(color: Color(0x14FFFFFF)),
      ),
      onSelected: onSelected,
      itemBuilder: (_) => options
          .map((o) => PopupMenuItem<String>(
                value: o,
                height: 32,
                child: Text(
                  o,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: o == selected
                        ? AppColors.violetTint
                        : AppColors.textBody,
                    fontWeight: o == selected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0x0AFFFFFF),
          border: Border.all(color: const Color(0x14FFFFFF)),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textBody,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 13,
              color: AppColors.textBody,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small icon button (32×32 refresh) ─────────────────────────────────────────

class _IconActionButton extends StatefulWidget {
  const _IconActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_IconActionButton> createState() => _IconActionButtonState();
}

class _IconActionButtonState extends State<_IconActionButton> {
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
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0x14FFFFFF)
                : const Color(0x0AFFFFFF),
            border: Border.all(color: const Color(0x0FFFFFFF)),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
            child: Icon(widget.icon, size: 13, color: AppColors.textMutedV2),
          ),
        ),
      ),
    );
  }
}

// ── Table header row ───────────────────────────────────────────────────────────

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: 'Inter',
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.textMutedV2,
      letterSpacing: 0.04 * 11, // 0.04em
    );

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0x0DFFFFFF)),
        ),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s18, vertical: AppSpacing.s12),
      child: const Row(
        children: [
          Expanded(flex: 16, child: Text('CLIENT', style: style)),
          Expanded(flex: 10, child: Text('DEVICE', style: style)),
          Expanded(flex: 11, child: Text('IP ADDRESS', style: style)),
          Expanded(flex: 9, child: Text('STATUS', style: style)),
          Expanded(flex: 10, child: Text('LAST ACTIVE', style: style)),
          Expanded(flex: 16, child: Text('CURRENT STREAM', style: style)),
          Expanded(
            flex: 14,
            child: Text('ACTIONS', style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

// ── Table body row ─────────────────────────────────────────────────────────────

class _ClientRow extends StatefulWidget {
  const _ClientRow({
    required this.client,
    required this.isSelected,
    required this.isProcessing,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
    required this.onRevoke,
  });

  final ClientListItem client;
  final bool isSelected;
  final bool isProcessing;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRevoke;

  @override
  State<_ClientRow> createState() => _ClientRowState();
}

class _ClientRowState extends State<_ClientRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    final bg = widget.isSelected
        ? const Color(0x14A855F7) // rgba(168,85,247,0.08)
        : _hovered
            ? const Color(0x05FFFFFF) // rgba(255,255,255,0.02)
            : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: bg,
            border: const Border(
              top: BorderSide(color: Color(0x08FFFFFF)),
            ),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s18, vertical: AppSpacing.s12),
          child: Row(
            children: [
              // Client
              Expanded(
                flex: 16,
                child: _ClientCell(client: c),
              ),
              // Device
              Expanded(
                flex: 10,
                child: _DeviceCell(platform: c.platform),
              ),
              // IP Address — populated by `clients.last_ip` (migration 023).
              Expanded(
                flex: 11,
                child: Text(
                  c.lastIp ?? '—',
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    color: AppColors.textMutedV2,
                  ),
                ),
              ),
              // Status
              Expanded(
                flex: 9,
                child: _StatusChip(client: c),
              ),
              // Last Active
              Expanded(
                flex: 10,
                child: _LastActiveCell(lastSeen: c.lastSeen),
              ),
              // Current Stream — joined from stream_sessions in
              // auth_service.list_clients (active_session.media_title).
              Expanded(
                flex: 16,
                child: Text(
                  c.activeSession?.mediaTitle ?? '—',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: c.activeSession?.mediaTitle != null
                        ? AppColors.textBody
                        : AppColors.textFaint,
                  ),
                ),
              ),
              // Actions — flex 14 to fit 3×26 px icons + 4 px gaps without
              // overflow when the detail panel is open and the table is
              // narrower (~600 px).
              Expanded(
                flex: 14,
                child: _RowActions(
                  client: c,
                  isProcessing: widget.isProcessing,
                  onApprove: widget.onApprove,
                  onReject: widget.onReject,
                  onRevoke: widget.onRevoke,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Row sub-cells ──────────────────────────────────────────────────────────────

class _ClientCell extends StatelessWidget {
  const _ClientCell({required this.client});

  final ClientListItem client;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
            child: Icon(
              _platformIcon(client.platform),
              size: 14,
              color: AppColors.textMutedV2,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                client.name,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBody,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                client.platform.name,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  color: AppColors.textDim,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeviceCell extends StatelessWidget {
  const _DeviceCell({required this.platform});

  final ClientPlatform platform;

  @override
  Widget build(BuildContext context) {
    final label = _deviceTypeLabel(platform);
    return Row(
      children: [
        Icon(_deviceTypeIcon(platform), size: 12, color: AppColors.textDim),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: AppColors.textMutedV2,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.client});

  final ClientListItem client;

  @override
  Widget build(BuildContext context) {
    if (client.status == ClientStatus.approved && client.isTrusted) {
      return const FluxChip('Online', color: FluxChipColor.success);
    } else if (client.status == ClientStatus.approved && !client.isTrusted) {
      return const FluxChip('Idle', color: FluxChipColor.warning);
    } else if (client.status == ClientStatus.rejected) {
      return const FluxChip('Offline', color: FluxChipColor.neutral);
    }
    return const FluxChip('Pending', color: FluxChipColor.info);
  }
}

class _LastActiveCell extends StatelessWidget {
  const _LastActiveCell({required this.lastSeen});

  final DateTime lastSeen;

  @override
  Widget build(BuildContext context) {
    final label = _formatRelative(lastSeen);
    final isNow = label == 'Now';
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        color: isNow ? const Color(0xFF10B981) : AppColors.textMutedV2,
      ),
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.client,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
    required this.onRevoke,
  });

  final ClientListItem client;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    if (isProcessing) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: AppColors.violet),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: switch (client.status) {
        ClientStatus.pending => [
            // Pending: prominent green Approve check + red X Reject.  These
            // are the operator's first-touch decision on a new device — the
            // mobile is sitting on the "waiting for approval" panel until
            // one of these fires.
            Tooltip(
              message: 'Approve pair request',
              child: _ColoredIconButton(
                icon: Icons.check_rounded,
                tint: const Color(0xFF10B981),
                onTap: onApprove,
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: 'Reject pair request',
              child: _ColoredIconButton(
                icon: Icons.close_rounded,
                tint: const Color(0xFFF87171),
                onTap: onReject,
              ),
            ),
          ],
        ClientStatus.approved => [
            // Approved: Revoke is the only meaningful destructive action.
            // No more-vert popup — exposing one option behind a hidden
            // affordance was the bug the user reported.
            Tooltip(
              message: 'Revoke this device',
              child: _ColoredIconButton(
                icon: Icons.block_rounded,
                tint: const Color(0xFFF87171),
                onTap: onRevoke,
              ),
            ),
          ],
        ClientStatus.rejected => [
            // Rejected / revoked rows are hidden by default (see the 'All'
            // filter in _applyFilters); when the operator surfaces them via
            // the 'Revoked' filter there's no further action — pairing has
            // to start from the device.
            const Tooltip(
              message: 'Revoked — re-pair from the device',
              child: _SmallIconButton(
                icon: Icons.history_rounded,
                onTap: null,
              ),
            ),
          ],
      },
    );
  }
}

/// Larger 28×28 colored action chip for primary row affordances.  Reserved
/// for the destructive / decisive operator actions (approve / reject /
/// revoke) so the pending-row Approve+Reject pair reads as a clear
/// fork-in-the-road choice instead of a pair of muted dots.
class _ColoredIconButton extends StatefulWidget {
  const _ColoredIconButton({
    required this.icon,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  @override
  State<_ColoredIconButton> createState() => _ColoredIconButtonState();
}

class _ColoredIconButtonState extends State<_ColoredIconButton> {
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
          duration: const Duration(milliseconds: 120),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: widget.tint.withValues(alpha: _hovered ? 0.22 : 0.14),
            border: Border.all(
              color: widget.tint.withValues(alpha: _hovered ? 0.55 : 0.4),
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
            child: Icon(widget.icon, size: 14, color: widget.tint),
          ),
        ),
      ),
    );
  }
}

// ── Small 26×26 icon button ────────────────────────────────────────────────────

class _SmallIconButton extends StatefulWidget {
  const _SmallIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  State<_SmallIconButton> createState() => _SmallIconButtonState();
}

class _SmallIconButtonState extends State<_SmallIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
        onExit: enabled ? (_) => setState(() => _hovered = false) : null,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _hovered
                  ? const Color(0x0AFFFFFF)
                  : const Color(0x08FFFFFF),
              border: Border.all(color: const Color(0x0DFFFFFF)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Icon(widget.icon, size: 12, color: AppColors.textMutedV2),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty table state ──────────────────────────────────────────────────────────

class _EmptyTableState extends StatelessWidget {
  const _EmptyTableState({required this.hasFilters});

  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.devices_outlined,
              size: 40, color: AppColors.textFaint),
          const SizedBox(height: AppSpacing.s12),
          Text(
            hasFilters ? 'No clients match your filters' : 'No clients yet',
            style:
                AppTypography.body.copyWith(color: AppColors.textMutedV2),
          ),
        ],
      ),
    );
  }
}

// ── Table footer (visual only) ─────────────────────────────────────────────────

class _TableFooter extends StatelessWidget {
  const _TableFooter({required this.count, required this.total});

  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x0AFFFFFF))),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s18, vertical: AppSpacing.s12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing 1 to $count of $total clients',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.textMutedV2,
            ),
          ),
          Row(
            children: [
              const _PageButton(icon: Icons.chevron_left_rounded),
              const SizedBox(width: 6),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0x2EA855F7),
                  border: Border.all(color: const Color(0x66A855F7)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Text(
                    '1',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.violetTint,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const _PageButton(icon: Icons.chevron_right_rounded),
              const SizedBox(width: 12),
              const Text(
                '10 per page',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppColors.textMutedV2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF),
        border: Border.all(color: const Color(0x0FFFFFFF)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Icon(icon, size: 12, color: AppColors.textMutedV2),
      ),
    );
  }
}

// ── Right-side detail panel ────────────────────────────────────────────────────

class _ClientDetailPanel extends StatelessWidget {
  const _ClientDetailPanel({
    required this.client,
    required this.onClose,
    required this.onApprove,
    required this.onReject,
    required this.onRevoke,
  });

  final ClientListItem? client;
  final VoidCallback onClose;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: Color(0x800D0B1C), // rgba(13,11,28,0.5)
        border: Border(
          left: BorderSide(color: Color(0x0DFFFFFF)),
        ),
      ),
      child: client == null
          ? _EmptyDetailPanel(onClose: onClose)
          : _PopulatedDetailPanel(
              client: client!,
              onClose: onClose,
              onApprove: onApprove,
              onReject: onReject,
              onRevoke: onRevoke,
            ),
    );
  }
}

class _EmptyDetailPanel extends StatelessWidget {
  const _EmptyDetailPanel({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Client Details',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBright,
                ),
              ),
              Tooltip(
                message: 'Close panel',
                child: GestureDetector(
                  onTap: onClose,
                  child: const Icon(Icons.close_rounded,
                      size: 14, color: AppColors.textDim),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s32),
          const Center(
            child: Column(
              children: [
                Icon(Icons.devices_outlined,
                    size: 40, color: AppColors.textFaint),
                SizedBox(height: AppSpacing.s12),
                Text(
                  'Select a client to see details',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.textMutedV2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PopulatedDetailPanel extends StatelessWidget {
  const _PopulatedDetailPanel({
    required this.client,
    required this.onClose,
    required this.onApprove,
    required this.onReject,
    required this.onRevoke,
  });

  final ClientListItem client;
  final VoidCallback onClose;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final isOnline =
        client.status == ClientStatus.approved && client.isTrusted;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Client Details',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBright,
                ),
              ),
              Tooltip(
                message: 'Close panel',
                child: GestureDetector(
                  onTap: onClose,
                  child: const Icon(Icons.close_rounded,
                      size: 14, color: AppColors.textDim),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),

          // ── Avatar block ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: const Color(0x1AA855F7),
              border: Border.all(color: const Color(0x33A855F7)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0x2EA855F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      _platformIcon(client.platform),
                      size: 26,
                      color: AppColors.violetTint,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s10),
                Text(
                  client.name,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBright,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StatusDot(
                      status: isOnline ? DotStatus.online : DotStatus.offline,
                      size: 6,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isOnline ? 'Online' : _statusLabel(client),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: isOnline
                            ? const Color(0xFF10B981)
                            : AppColors.textMutedV2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // ── Info rows ────────────────────────────────────────────────────
          ..._buildInfoRows(),

          // ── Active Session ────────────────────────────────────────────────
          if (client.activeSession != null) ...[
            const SizedBox(height: AppSpacing.s16),
            _ActiveSessionBlock(session: client.activeSession!),
          ],

          // ── Groups (M3, 2026-05-07) ──────────────────────────────────────
          // Bidirectional editing: operator can see + manage group
          // membership from the client side instead of having to navigate
          // to the Groups screen → drill into a group → Add Member.
          // Only shown for approved + trusted clients — pending pair
          // requests can't legally be in a group (server enforces via
          // group_members FK + the existing add-member 404 path).
          if (client.status == ClientStatus.approved && client.isTrusted) ...[
            const SizedBox(height: AppSpacing.s16),
            _ClientGroupsSection(client: client),
          ],

          const SizedBox(height: AppSpacing.s16),

          // ── Client Actions ───────────────────────────────────────────────
          const Text(
            'Client Actions',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textBright,
            ),
          ),
          const SizedBox(height: AppSpacing.s10),

          // Status-aware action stack — mirrors the row actions but with
          // labelled tiles instead of icon-only chips.
          ..._statusActionTiles(),
        ],
      ),
    );
  }

  List<Widget> _statusActionTiles() {
    switch (client.status) {
      case ClientStatus.pending:
        return [
          _DetailActionTile(
            icon: Icons.check_rounded,
            label: 'Approve pair request',
            color: const Color(0xFF10B981),
            onTap: onApprove,
          ),
          const SizedBox(height: 4),
          _DetailActionTile(
            icon: Icons.close_rounded,
            label: 'Reject pair request',
            color: const Color(0xFFF87171),
            onTap: onReject,
          ),
        ];
      case ClientStatus.approved:
        return [
          _DetailActionTile(
            icon: Icons.block_rounded,
            label: 'Revoke this device',
            color: const Color(0xFFF87171),
            onTap: onRevoke,
          ),
        ];
      case ClientStatus.rejected:
        return [
          const _DetailActionTile(
            icon: Icons.history_rounded,
            label: 'Revoked — re-pair from the device',
            color: AppColors.textMutedV2,
            onTap: null,
          ),
        ];
    }
  }

  List<Widget> _buildInfoRows() {
    final rows = [
      ('Device Type', _deviceTypeLabel(client.platform), false),
      ('OS', client.platform.name, false),
      ('IP Address', client.lastIp ?? '—', false),
      ('First Connected', '—', false), // no backend field
      ('Last Active', _formatRelative(client.lastSeen), false),
      ('Total Sessions', '—', false), // no backend field
      ('Total Watch Time', '—', true), // no backend field
    ];

    return rows.map(((String label, String value, bool isLast) record) {
      final (label, value, isLast) = record;
      final isIp = label == 'IP Address';
      return Container(
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: Color(0x0AFFFFFF))),
        ),
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.textMutedV2,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontFamily: isIp ? 'JetBrains Mono' : 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textBody,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

// ── Active session block ──────────────────────────────────────────────────────

class _ActiveSessionBlock extends StatelessWidget {
  const _ActiveSessionBlock({required this.session});

  final ActiveSessionInfo session;

  @override
  Widget build(BuildContext context) {
    final title = session.mediaTitle ?? 'Active session';
    final encoder = session.encoderUsed ?? 'unknown';
    final elapsed = _formatElapsed(session.startedAt);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: const Color(0x1410B981), // emerald 8 % — "live" tint
        border: Border.all(color: const Color(0x3310B981)),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              StatusDot(status: DotStatus.streaming, size: 6),
              SizedBox(width: 6),
              Text(
                'Currently Streaming',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textBright,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Encoder $encoder · $elapsed',
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 11,
              color: AppColors.textMutedV2,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatElapsed(DateTime startedAt) {
    final delta = DateTime.now().toUtc().difference(startedAt.toUtc());
    if (delta.inHours >= 1) {
      final h = delta.inHours;
      final m = delta.inMinutes.remainder(60);
      return '${h}h ${m}m';
    }
    if (delta.inMinutes >= 1) {
      return '${delta.inMinutes}m';
    }
    return '${delta.inSeconds.clamp(0, 59)}s';
  }
}

// ── Detail action tile ─────────────────────────────────────────────────────────

class _DetailActionTile extends StatefulWidget {
  const _DetailActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  State<_DetailActionTile> createState() => _DetailActionTileState();
}

class _DetailActionTileState extends State<_DetailActionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
        onExit: enabled ? (_) => setState(() => _hovered = false) : null,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s10, vertical: AppSpacing.s8),
            decoration: BoxDecoration(
              color: _hovered
                  ? const Color(0x0AFFFFFF)
                  : const Color(0x05FFFFFF),
              border: Border.all(color: const Color(0x0AFFFFFF)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                Icon(widget.icon, size: 13, color: widget.color),
                const SizedBox(width: AppSpacing.s10),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    color: widget.color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────

IconData _platformIcon(ClientPlatform platform) => switch (platform) {
      ClientPlatform.android => Icons.android_rounded,
      ClientPlatform.ios => Icons.phone_iphone_rounded,
      ClientPlatform.windows => Icons.desktop_windows_rounded,
      ClientPlatform.macos => Icons.laptop_mac_rounded,
      ClientPlatform.linux => Icons.computer_rounded,
    };

String _deviceTypeLabel(ClientPlatform platform) => switch (platform) {
      ClientPlatform.android => 'Mobile',
      ClientPlatform.ios => 'Mobile',
      ClientPlatform.windows => 'Desktop',
      ClientPlatform.macos => 'Desktop',
      ClientPlatform.linux => 'Desktop',
    };

IconData _deviceTypeIcon(ClientPlatform platform) => switch (platform) {
      ClientPlatform.android => Icons.phone_android_rounded,
      ClientPlatform.ios => Icons.phone_iphone_rounded,
      ClientPlatform.windows => Icons.desktop_windows_rounded,
      ClientPlatform.macos => Icons.laptop_mac_rounded,
      ClientPlatform.linux => Icons.computer_rounded,
    };

String _statusLabel(ClientListItem client) => switch (client.status) {
      ClientStatus.approved => 'Idle',
      ClientStatus.rejected => 'Offline',
      ClientStatus.pending => 'Pending',
    };

String _formatRelative(DateTime dt) {
  final now = DateTime.now().toUtc();
  final diff = now.difference(dt.toUtc());
  if (diff.inSeconds < 60) return 'Now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

// ── Groups section (M3, 2026-05-07) ────────────────────────────────────────────

/// "Groups" section on the client detail panel.  Renders one chip per
/// group the client belongs to (with a hover-revealed × that removes the
/// client from that group) plus a `+` button that opens [_PickGroupDialog]
/// to add the client to a group.  Group membership data comes from the
/// `auth_service.list_clients` join (M3); add/remove operations call
/// `GroupsRepository` directly + trigger `ClientsCubit.refreshSilent()`
/// so the chip set updates without flickering through `ClientsLoading`.
class _ClientGroupsSection extends StatelessWidget {
  const _ClientGroupsSection({required this.client});

  final ClientListItem client;

  Future<void> _onAddToGroup(BuildContext context) async {
    final memberOf = client.groups.map((g) => g.id).toSet();
    final picked = await showDialog<GroupSummary>(
      context: context,
      builder: (_) => _PickGroupDialog(
        clientName: client.name,
        excludeGroupIds: memberOf,
      ),
    );
    if (picked == null || !context.mounted) return;
    try {
      await GetIt.I<GroupsRepository>().addMember(picked.id, client.id);
    } catch (e, st) {
      Logger().w('Add client to group failed',
          error: e, stackTrace: st);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add to ${picked.name}: $e')),
      );
      return;
    }
    if (!context.mounted) return;
    // Silent refresh — chip set will pick up the new entry without
    // collapsing the detail panel.  Note: depending on the build of
    // ClientsCubit at the time of this M3 ship, `refreshSilent` may not
    // exist yet; fall back to `load()` if so (the user briefly sees the
    // loading spinner — acceptable trade-off).
    final cubit = context.read<ClientsCubit>();
    try {
      await cubit.refreshSilent();
    } catch (_) {
      await cubit.load();
    }
  }

  Future<void> _onRemoveFromGroup(
    BuildContext context,
    GroupSummary group,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => FluxGlassDialog(
        title: Text('Remove from ${group.name}?'),
        content: Text(
          '${client.name} will no longer be subject to this group\'s '
          'restrictions.  Existing in-flight streams continue until '
          'they end naturally.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await GetIt.I<GroupsRepository>().removeMember(group.id, client.id);
    } catch (e, st) {
      Logger().w('Remove client from group failed',
          error: e, stackTrace: st);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove from ${group.name}: $e')),
      );
      return;
    }
    if (!context.mounted) return;
    final cubit = context.read<ClientsCubit>();
    try {
      await cubit.refreshSilent();
    } catch (_) {
      await cubit.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Groups',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textBright,
              ),
            ),
            Tooltip(
              message: 'Add to group',
              child: GestureDetector(
                onTap: () => _onAddToGroup(context),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.violet.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: const Icon(Icons.add_rounded,
                        size: 14, color: AppColors.violet),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        if (client.groups.isEmpty)
          Text(
            'Not in any group.  Click + to add this device to one.',
            style: AppTypography.captionV2
                .copyWith(color: AppColors.textDim),
          )
        else
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: client.groups
                .map((g) => _ClientGroupChip(
                      group: g,
                      onRemove: () => _onRemoveFromGroup(context, g),
                    ))
                .toList(),
          ),
      ],
    );
  }
}

/// One group chip in the client detail panel — renders the group name +
/// a small status dot (emerald = active / muted = inactive) + a
/// hover-revealed × that triggers [onRemove].  Hidden-on-hover removal
/// affordance keeps the chip set scannable when the operator isn't
/// actively trying to detach a client.
class _ClientGroupChip extends StatefulWidget {
  const _ClientGroupChip({required this.group, required this.onRemove});

  final GroupSummary group;
  final VoidCallback onRemove;

  @override
  State<_ClientGroupChip> createState() => _ClientGroupChipState();
}

class _ClientGroupChipState extends State<_ClientGroupChip> {
  bool _hover = false;

  void _setHover(bool v) {
    if (!mounted) return;
    setState(() => _hover = v);
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.group.status == GroupStatus.active;
    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x14A855F7),
          border: Border.all(color: const Color(0x40A855F7)),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF10B981)
                    : AppColors.textDim,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              widget.group.name,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textBright,
              ),
            ),
            if (_hover) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: 'Remove from group',
                child: GestureDetector(
                  onTap: widget.onRemove,
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Icon(Icons.close_rounded,
                        size: 12, color: AppColors.textDim),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Modal that lists every group the operator has + lets them pick one
/// to add the [clientName] client to.  Filters out groups the client is
/// already in (passed as [excludeGroupIds]).  Mirrors the pattern of the
/// Groups screen's `_AddMemberDialog` — same fetch-on-open + scrollable
/// list shape — but inverted (pick a group instead of a client).
class _PickGroupDialog extends StatefulWidget {
  const _PickGroupDialog({
    required this.clientName,
    required this.excludeGroupIds,
  });

  final String clientName;
  final Set<String> excludeGroupIds;

  @override
  State<_PickGroupDialog> createState() => _PickGroupDialogState();
}

class _PickGroupDialogState extends State<_PickGroupDialog> {
  bool _loading = true;
  String? _error;
  List<GroupSummary> _groups = const <GroupSummary>[];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = GetIt.I<GroupsRepository>();
      final all = await repo.list();
      if (!mounted) return;
      setState(() {
        // Only show active groups — adding to an inactive group is
        // permitted server-side but the operator's intent is almost
        // certainly to pick an enforcing group.  Inactive groups
        // appear after the operator re-activates them on the Groups
        // screen.
        _groups = all
            .where((g) => g.status == GroupStatus.active)
            .map((g) => GroupSummary(
                  id: g.id,
                  name: g.name,
                  status: g.status,
                ))
            .toList();
        _loading = false;
      });
    } catch (e, st) {
      Logger().w('Pick-group fetch failed', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load groups: $e';
        _loading = false;
      });
    }
  }

  List<GroupSummary> get _filtered {
    final s = _search.trim().toLowerCase();
    return _groups.where((g) {
      if (widget.excludeGroupIds.contains(g.id)) return false;
      if (s.isEmpty) return true;
      return g.name.toLowerCase().contains(s);
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return FluxGlassDialog(
      title: Text('Add ${widget.clientName} to group'),
      content: SizedBox(
        width: 420,
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pick an active group to add this device to.  Restrictions '
              'apply to new streams immediately.',
              style: AppTypography.captionV2
                  .copyWith(color: AppColors.textDim),
            ),
            const SizedBox(height: AppSpacing.s10),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded, size: 16),
                hintText: 'Search groups',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: AppSpacing.s10),
            Expanded(child: _buildBody(filtered)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildBody(List<GroupSummary> filtered) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.violet,
          ),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: AppTypography.bodySmall.copyWith(color: AppColors.textBody),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (filtered.isEmpty) {
      // Two empty states: search-narrowed-to-zero vs nothing-to-pick-from.
      // The latter usually means the client is already in every active
      // group — the operator has nothing left to add.
      final allConsumed = _groups.isNotEmpty &&
          _groups.every((g) => widget.excludeGroupIds.contains(g.id));
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Text(
            _search.isNotEmpty
                ? 'No active groups match "${_search.trim()}".'
                : allConsumed
                    ? 'This device is already in every active group.'
                    : 'No active groups.  Create one from the '
                        'Groups screen first.',
            style:
                AppTypography.captionV2.copyWith(color: AppColors.textDim),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x06FFFFFF),
        border: Border.all(color: const Color(0x14FFFFFF)),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          thickness: 1,
          color: Color(0x06FFFFFF),
        ),
        itemBuilder: (_, i) {
          final g = filtered[i];
          return _PickGroupRow(
            group: g,
            onTap: () => Navigator.pop(context, g),
          );
        },
      ),
    );
  }
}

class _PickGroupRow extends StatefulWidget {
  const _PickGroupRow({required this.group, required this.onTap});

  final GroupSummary group;
  final VoidCallback onTap;

  @override
  State<_PickGroupRow> createState() => _PickGroupRowState();
}

class _PickGroupRowState extends State<_PickGroupRow> {
  bool _hover = false;

  void _setHover(bool v) {
    if (!mounted) return;
    setState(() => _hover = v);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s10,
          ),
          color: _hover ? const Color(0x06FFFFFF) : Colors.transparent,
          child: Row(
            children: [
              const Icon(Icons.group_work_outlined,
                  size: 14, color: AppColors.violet),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  widget.group.name,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textBright,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 14, color: AppColors.textDim),
            ],
          ),
        ),
      ),
    );
  }
}
