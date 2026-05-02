import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/client_list_item.dart';
import 'package:fluxora_core/entities/enums.dart';
import 'package:fluxora_desktop/features/clients/domain/repositories/clients_repository.dart';
import 'package:fluxora_desktop/features/clients/presentation/cubit/clients_cubit.dart';
import 'package:fluxora_desktop/features/clients/presentation/cubit/clients_state.dart';
import 'package:fluxora_desktop/shared/widgets/flux_button.dart';
import 'package:fluxora_desktop/shared/widgets/flux_card.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';
import 'package:fluxora_desktop/shared/widgets/pill.dart';
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

    // Status filter
    if (_statusFilter != 'All') {
      result = result.where((c) {
        return switch (_statusFilter) {
          'Online' => c.status == ClientStatus.approved && c.isTrusted,
          'Offline' => c.status == ClientStatus.rejected,
          'Pending' => c.status == ClientStatus.pending,
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
                      const PageHeader(
                        title: 'Clients',
                        subtitle:
                            'Manage connected devices and client access',
                      ),

                      // ── Stat tiles ───────────────────────────────────────
                      _buildStatTiles(state),
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

  Widget _buildStatTiles(ClientsState state) {
    final clients =
        state is ClientsLoaded ? state.clients : <ClientListItem>[];
    final total = clients.length;
    final online = clients
        .where((c) => c.status == ClientStatus.approved && c.isTrusted)
        .length;

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
            label: 'Active Streams not available',
            child: const StatTile(
              icon: Icons.play_circle_outline_rounded,
              label: 'Active Streams',
              // TODO: read from SystemStatsCubit.state.latest?.activeStreams
              // once SystemStatsCubit is accessible from this widget tree.
              value: '—',
              color: Color(0xFF3B82F6),
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

        // Status popup
        _FilterDropdown(
          label: _statusFilter == 'All' ? 'All Status' : _statusFilter,
          options: const ['All', 'Online', 'Offline', 'Pending'],
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
                    color: AppColors.textMuted, size: 48),
                const SizedBox(height: AppSpacing.s12),
                Text(message,
                    style: AppTypography.bodyMd
                        .copyWith(color: AppColors.textSecondary),
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
                          onRevoke: () =>
                              context.read<ClientsCubit>().reject(c.id),
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
      onRevoke: selected != null
          ? () {
              if (state is ClientsLoaded) {
                context.read<ClientsCubit>().reject(selected!.id);
              }
            }
          : null,
    );
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
      color: const Color(0xFF1A1830),
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
    required this.onRevoke,
  });

  final ClientListItem client;
  final bool isSelected;
  final bool isProcessing;
  final VoidCallback onTap;
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
              // IP Address — no ipAddress field on ClientListItem in v1
              const Expanded(
                flex: 11,
                child: Text(
                  '—',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    color: AppColors.textMutedV2,
                  ),
                ),
              ),
              // Status
              Expanded(
                flex: 9,
                child: _StatusPill(client: c),
              ),
              // Last Active
              Expanded(
                flex: 10,
                child: _LastActiveCell(lastSeen: c.lastSeen),
              ),
              // Current Stream
              const Expanded(
                flex: 16,
                child: Text(
                  // TODO: join per-client active session once a
                  // per-client session list endpoint is available.
                  '—',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.textFaint,
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.client});

  final ClientListItem client;

  @override
  Widget build(BuildContext context) {
    if (client.status == ClientStatus.approved && client.isTrusted) {
      return const Pill('Online', color: PillColor.success);
    } else if (client.status == ClientStatus.approved && !client.isTrusted) {
      return const Pill('Idle', color: PillColor.warning);
    } else if (client.status == ClientStatus.rejected) {
      return const Pill('Offline', color: PillColor.neutral);
    }
    return const Pill('Pending', color: PillColor.info);
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
    required this.onRevoke,
  });

  final ClientListItem client;
  final bool isProcessing;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // View (eye) — opens detail panel (handled by row tap); visual only here
        const Tooltip(
          message: 'View client details',
          child: _SmallIconButton(
            icon: Icons.remove_red_eye_outlined,
            onTap: null, // row tap handles selection
          ),
        ),
        const SizedBox(width: 4),
        // Stop stream — disabled (no per-client stream-stop endpoint)
        const Tooltip(
          message: 'Stop stream',
          child: _SmallIconButton(
            icon: Icons.stop_circle_outlined,
            onTap: null,
          ),
        ),
        const SizedBox(width: 4),
        // More options — popup with Revoke
        isProcessing
            ? const SizedBox(
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
              )
            : PopupMenuButton<String>(
                tooltip: '',
                icon: const Icon(Icons.more_vert_rounded,
                    size: 12, color: AppColors.textMutedV2),
                iconSize: 12,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(maxWidth: 130),
                color: const Color(0xFF1A1830),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  side: const BorderSide(color: Color(0x14FFFFFF)),
                ),
                onSelected: (val) {
                  if (val == 'revoke') onRevoke();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem<String>(
                    value: 'revoke',
                    height: 32,
                    child: Row(
                      children: [
                        Icon(Icons.block_rounded,
                            size: 12, color: Color(0xFFF87171)),
                        SizedBox(width: 8),
                        Text(
                          'Revoke',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Color(0xFFF87171),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ],
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
                AppTypography.bodyMd.copyWith(color: AppColors.textMutedV2),
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
    required this.onRevoke,
  });

  final ClientListItem? client;
  final VoidCallback onClose;
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
    required this.onRevoke,
  });

  final ClientListItem client;
  final VoidCallback onClose;
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
          // TODO: render active session block once a per-client session join
          // is available from the backend. Currently no session data.

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

          const _DetailActionTile(
            icon: Icons.message_outlined,
            label: 'Send Message',
            color: AppColors.textMutedV2,
            onTap: null, // TODO: no backend endpoint for sending messages
          ),
          const SizedBox(height: 4),
          _DetailActionTile(
            icon: Icons.close_rounded,
            label: 'Disconnect Client',
            color: const Color(0xFFF87171),
            onTap: onRevoke,
          ),
          const SizedBox(height: 4),
          const _DetailActionTile(
            icon: Icons.block_rounded,
            label: 'Block Client',
            color: Color(0xFFF87171),
            onTap: null, // TODO: no backend block endpoint
          ),
          const SizedBox(height: 4),
          const _DetailActionTile(
            icon: Icons.history_rounded,
            label: 'View Playback History',
            color: AppColors.textMutedV2,
            onTap: null, // TODO: no backend playback history endpoint
          ),
        ],
      ),
    );
  }

  List<Widget> _buildInfoRows() {
    final rows = [
      ('Device Type', _deviceTypeLabel(client.platform), false),
      ('OS', client.platform.name, false),
      ('IP Address', '—', false), // no ipAddress field on ClientListItem
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
