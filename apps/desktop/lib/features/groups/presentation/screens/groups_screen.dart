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
import 'package:fluxora_core/entities/library.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_desktop/features/clients/domain/repositories/clients_repository.dart';
import 'package:fluxora_desktop/features/groups/domain/repositories/groups_repository.dart';
import 'package:fluxora_desktop/features/groups/presentation/cubit/groups_cubit.dart';
import 'package:fluxora_desktop/features/groups/presentation/cubit/groups_state.dart';
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_core/widgets/flux_button.dart';
import 'package:fluxora_core/widgets/flux_chip.dart';
import 'package:fluxora_desktop/shared/widgets/flux_card.dart';
import 'package:fluxora_desktop/shared/widgets/flux_glass_dialog.dart';
import 'package:fluxora_desktop/shared/widgets/flux_switch.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';
import 'package:fluxora_desktop/shared/widgets/stat_tile.dart';
import 'package:fluxora_desktop/shared/widgets/status_dot.dart';

// ── Entry point ────────────────────────────────────────────────────────────────

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<GroupsCubit>(
      create: (_) => GroupsCubit(
        repository: GetIt.I<GroupsRepository>(),
        libraryRepository: GetIt.I<LibraryRepository>(),
      )..load(),
      child: const _GroupsView(),
    );
  }
}

// ── Main view ──────────────────────────────────────────────────────────────────

class _GroupsView extends StatelessWidget {
  const _GroupsView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GroupsCubit, GroupsState>(
      builder: (context, state) {
        return Container(
          color: AppColors.bgRoot,
          child: switch (state) {
            GroupsInitial() || GroupsLoading() => const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.violet,
                  ),
                ),
              ),
            GroupsFailure(:final message) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      style: AppTypography.body
                          .copyWith(color: AppColors.textMutedV2),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    FluxButton(
                      variant: FluxButtonVariant.secondary,
                      icon: Icons.refresh_rounded,
                      onPressed: () =>
                          context.read<GroupsCubit>().load(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            GroupsLoaded() => _GroupsLoaded(state: state),
          },
        );
      },
    );
  }
}

// ── Loaded layout ──────────────────────────────────────────────────────────────

class _GroupsLoaded extends StatefulWidget {
  const _GroupsLoaded({required this.state});

  final GroupsLoaded state;

  @override
  State<_GroupsLoaded> createState() => _GroupsLoadedState();
}

class _GroupsLoadedState extends State<_GroupsLoaded> {
  // Filter state — client-side because the soft cap of 50 rows on
  // `benchmark_history` doesn't apply here but groups stay small in
  // practice (handful of devices per household).  Mirrors the Clients
  // screen filter pattern: search box + status popup.
  String _searchQuery = '';
  String _statusFilter = 'All';

  /// Apply search + status filter to the group list.  Stat tiles still
  /// read the unfiltered list via `widget.state.groups` so "Total Groups"
  /// doesn't lie when a filter is active.
  List<Group> get _filteredGroups {
    return widget.state.groups.where((g) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final hit = g.name.toLowerCase().contains(q) ||
            (g.description?.toLowerCase().contains(q) ?? false);
        if (!hit) return false;
      }
      if (_statusFilter != 'All') {
        if (_statusFilter == 'Active' && g.status != GroupStatus.active) {
          return false;
        }
        if (_statusFilter == 'Inactive' &&
            g.status != GroupStatus.inactive) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final groups = state.groups;
    final filteredGroups = _filteredGroups;
    final totalMembers =
        groups.fold<int>(0, (sum, g) => sum + g.memberCount);
    final activeGroups =
        groups.where((g) => g.status == GroupStatus.active).length;
    final avgMembers =
        groups.isEmpty ? 0 : (totalMembers / groups.length).round();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Main content ─────────────────────────────────────────────────
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
                PageHeader(
                  title: 'Groups',
                  subtitle:
                      'Organize clients into groups with shared restrictions',
                  actions: FluxButton(
                    icon: Icons.add_rounded,
                    onPressed: () =>
                        _showCreateDialog(context),
                    child: const Text('Create Group'),
                  ),
                ),

                // ── Stat tiles ─────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: 'Total Groups ${groups.length}',
                        child: StatTile(
                          icon: Icons.group_work_outlined,
                          label: 'Total Groups',
                          value: '${groups.length}',
                          color: AppColors.violet,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s14),
                    Expanded(
                      child: Semantics(
                        label: 'Active Groups $activeGroups',
                        child: StatTile(
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Active Groups',
                          value: '$activeGroups',
                          color: AppColors.emerald,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s14),
                    Expanded(
                      child: Semantics(
                        label: 'Total Members $totalMembers',
                        child: StatTile(
                          icon: Icons.person_outline_rounded,
                          label: 'Total Members',
                          value: '$totalMembers',
                          color: AppColors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s14),
                    Expanded(
                      child: Semantics(
                        label: 'Avg Members $avgMembers',
                        child: StatTile(
                          icon: Icons.people_outline_rounded,
                          label: 'Avg Members',
                          value: '$avgMembers',
                          color: AppColors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s18),

                // ── Groups table ───────────────────────────────────────
                FluxCard(
                  padding: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row — title + search + status filter.
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s18,
                          vertical: AppSpacing.s14,
                        ),
                        child: Row(
                          children: [
                            const Text('All Groups',
                                style: AppTypography.h2),
                            const SizedBox(width: AppSpacing.s14),
                            // Inline search field — same compact pattern
                            // the Clients screen uses.  Filters by name +
                            // description so an operator who labelled a
                            // group via its description still finds it.
                            Expanded(
                              child: _GroupsSearchField(
                                onChanged: (v) =>
                                    setState(() => _searchQuery = v),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s10),
                            _GroupsStatusFilter(
                              selected: _statusFilter,
                              onSelected: (v) =>
                                  setState(() => _statusFilter = v),
                            ),
                          ],
                        ),
                      ),
                      // Column headers
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0x0DFFFFFF)),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s18,
                          vertical: AppSpacing.s10,
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'GROUP NAME',
                                style: AppTypography.eyebrow,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'MEMBERS',
                                style: AppTypography.eyebrow,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'STATUS',
                                style: AppTypography.eyebrow,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'CREATED',
                                style: AppTypography.eyebrow,
                              ),
                            ),
                            SizedBox(width: 44),
                          ],
                        ),
                      ),
                      // Rows.  Three empty states: (a) no groups at all
                      // → onboarding copy, (b) filter active and empty
                      // → "no matches" copy with clear-filters action,
                      // (c) populated → render filtered list.
                      if (groups.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.s28,
                          ),
                          child: Center(
                            child: Text(
                              'No groups yet. Create one to get started.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textDim,
                              ),
                            ),
                          ),
                        )
                      else if (filteredGroups.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.s28,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'No groups match your filters.',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textDim,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.s8),
                                FluxButton(
                                  variant: FluxButtonVariant.ghost,
                                  size: FluxButtonSize.sm,
                                  onPressed: () => setState(() {
                                    _searchQuery = '';
                                    _statusFilter = 'All';
                                  }),
                                  child: const Text('Clear filters'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...filteredGroups.map(
                          (g) => _GroupRow(
                            group: g,
                            isSelected:
                                state.selectedGroup?.id == g.id,
                            onTap: () => context
                                .read<GroupsCubit>()
                                .selectGroup(g),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Detail panel ─────────────────────────────────────────────────
        if (state.selectedGroup != null)
          _GroupDetailPanel(
            group: state.selectedGroup!,
            members: state.members,
            membersLoading: state.membersLoading,
            libraries: state.libraries,
          ),
      ],
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _CreateGroupDialog(
        libraries: widget.state.libraries,
        onConfirm: (name, description, restrictions) {
          context.read<GroupsCubit>().createGroup(
                name: name,
                description: description,
                restrictions: restrictions,
              );
        },
      ),
    );
  }
}

// ── Header search + filter widgets ─────────────────────────────────────────────

/// Compact search field rendered inline with the table header.  Matches the
/// Clients screen's `_SearchField` look (low-chrome dark pill with a search
/// icon prefix) so the two screens feel consistent.
class _GroupsSearchField extends StatefulWidget {
  const _GroupsSearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_GroupsSearchField> createState() => _GroupsSearchFieldState();
}

class _GroupsSearchFieldState extends State<_GroupsSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: const Color(0x06FFFFFF),
        border: Border.all(color: const Color(0x14FFFFFF)),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(Icons.search_rounded,
              size: 13, color: Color(0xFF64748B)),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: widget.onChanged,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.textBody,
                height: 1,
              ),
              decoration: const InputDecoration(
                hintText: 'Search groups…',
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

/// Status filter dropdown — All / Active / Inactive.  Mirrors the
/// `_FilterDropdown` pattern used on the Clients screen so the two
/// screens look identical at the chrome level.
class _GroupsStatusFilter extends StatelessWidget {
  const _GroupsStatusFilter({
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  static const _options = ['All', 'Active', 'Inactive'];

  @override
  Widget build(BuildContext context) {
    final label = selected == 'All' ? 'All Status' : selected;
    return PopupMenuButton<String>(
      tooltip: '',
      color: AppColors.bgRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        side: const BorderSide(color: Color(0x14FFFFFF)),
      ),
      onSelected: onSelected,
      itemBuilder: (_) => _options
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
                    fontWeight:
                        o == selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ))
          .toList(),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0x06FFFFFF),
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
                color: AppColors.textBody,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 14, color: AppColors.textDim),
          ],
        ),
      ),
    );
  }
}

// ── Group table row ────────────────────────────────────────────────────────────

class _GroupRow extends StatefulWidget {
  const _GroupRow({
    required this.group,
    required this.isSelected,
    required this.onTap,
  });

  final Group group;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_GroupRow> createState() => _GroupRowState();
}

class _GroupRowState extends State<_GroupRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final isActive = g.status == GroupStatus.active;
    Color rowBg;
    if (widget.isSelected) {
      rowBg = const Color(0x14A855F7);
    } else if (_hovered) {
      rowBg = const Color(0x08FFFFFF);
    } else {
      rowBg = Colors.transparent;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: rowBg,
            border: const Border(
              top: BorderSide(color: Color(0x08FFFFFF)),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s18,
            vertical: AppSpacing.s12,
          ),
          child: Row(
            children: [
              // Name + icon
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.violet.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.group_work_outlined,
                          size: 14,
                          color: AppColors.violet,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.name,
                            style: AppTypography.body.copyWith(
                              color: AppColors.textBright,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (g.description != null)
                            Text(
                              g.description!,
                              style: AppTypography.captionV2.copyWith(
                                color: AppColors.textDim,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Members
              Expanded(
                flex: 2,
                child: Text(
                  '${g.memberCount}',
                  style: AppTypography.body
                      .copyWith(color: AppColors.textBody),
                ),
              ),
              // Status
              Expanded(
                child: Row(
                  children: [
                    StatusDot(
                      status: isActive
                          ? DotStatus.online
                          : DotStatus.offline,
                      size: 6,
                    ),
                    const SizedBox(width: AppSpacing.s6),
                    Text(
                      isActive ? 'Active' : 'Inactive',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textBody,
                      ),
                    ),
                  ],
                ),
              ),
              // Created
              Expanded(
                child: Text(
                  _formatDate(g.createdAt),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textMutedV2,
                  ),
                ),
              ),
              // Actions
              SizedBox(
                width: 44,
                child: Tooltip(
                  message: 'Delete group',
                  child: FluxButton(
                    variant: FluxButtonVariant.ghost,
                    size: FluxButtonSize.sm,
                    onPressed: () =>
                        _showDeleteConfirm(context, g),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 14,
                      color: AppColors.red,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '—';
    }
  }

  void _showDeleteConfirm(BuildContext context, Group g) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => FluxGlassDialog(
        title: Text('Delete "${g.name}"?'),
        content: const Text(
          'This will remove the group and all its member associations. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<GroupsCubit>().deleteGroup(g.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Detail panel ───────────────────────────────────────────────────────────────

class _GroupDetailPanel extends StatelessWidget {
  const _GroupDetailPanel({
    required this.group,
    required this.members,
    required this.membersLoading,
    required this.libraries,
  });

  final Group group;
  final List<Map<String, dynamic>> members;
  final bool membersLoading;

  /// Library catalog from `GroupsLoaded.libraries` — used to resolve
  /// `allowedLibraries` ids back to human-friendly names ("Movies, TV"
  /// instead of two opaque UUIDs).  Empty list when the libraries fetch
  /// failed; chips fall back to displaying the raw id so the operator
  /// can still see *which* libraries are gated.
  final List<Library> libraries;

  @override
  Widget build(BuildContext context) {
    final isActive = group.status == GroupStatus.active;
    final r = group.restrictions;

    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: Color(0x80100E2A),
        border: Border(
          left: BorderSide(color: Color(0x0DFFFFFF)),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Panel title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Group Details', style: AppTypography.h2),
                Tooltip(
                  message: 'Edit group',
                  child: FluxButton(
                    variant: FluxButtonVariant.ghost,
                    size: FluxButtonSize.sm,
                    icon: Icons.edit_outlined,
                    onPressed: () =>
                        _showEditDialog(context, group),
                    child: const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s14),

            // Group icon + name
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: const Center(
                    child: Icon(Icons.group_work_outlined,
                        size: 20, color: AppColors.violet),
                  ),
                ),
                const SizedBox(width: AppSpacing.s10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              group.name,
                              style: AppTypography.h2.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s6),
                          FluxChip(
                            isActive ? 'Active' : 'Inactive',
                            color: isActive
                                ? FluxChipColor.success
                                : FluxChipColor.neutral,
                          ),
                        ],
                      ),
                      if (group.description != null)
                        Text(
                          group.description!,
                          style: AppTypography.captionV2.copyWith(
                            color: AppColors.textMutedV2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s18),

            // Meta rows
            _DetailRow(
                label: 'Members',
                value: '${group.memberCount}',
                index: 0),
            _DetailRow(
                label: 'Created',
                value: _formatDate(group.createdAt),
                index: 1),
            _DetailRow(
                label: 'Updated',
                value: _formatDate(group.updatedAt),
                index: 2,
                isLast: true),

            // Restrictions
            if (r != null) ...[
              const SizedBox(height: AppSpacing.s16),
              Text('Restrictions',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textBright,
                  )),
              const SizedBox(height: AppSpacing.s8),
              if (r.bandwidthCapMbps != null)
                _RestrictRow(
                    label: 'Bandwidth cap',
                    value: '${r.bandwidthCapMbps} Mbps'),
              if (r.maxRating != null)
                _RestrictRow(label: 'Max rating', value: r.maxRating!),
              if (r.timeWindow != null)
                _RestrictRow(
                  label: 'Time window',
                  value: _formatTimeWindow(r.timeWindow) ?? '—',
                ),
              if (r.allowedLibraries != null &&
                  r.allowedLibraries!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Allowed libraries',
                        style: AppTypography.captionV2.copyWith(
                          color: AppColors.textDim,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: r.allowedLibraries!.map((id) {
                          // Resolve id → name from the cached catalog.
                          // Falls back to the raw id when the library
                          // was deleted or the fetch failed — operator
                          // still sees what's gated, just less readably.
                          final lib = libraries.firstWhere(
                            (l) => l.id == id,
                            orElse: () => Library(
                              id: id,
                              name: id,
                              type: LibraryType.movies,
                              rootPaths: const [],
                              createdAt: DateTime.now(),
                            ),
                          );
                          return FluxChip(lib.name,
                              color: FluxChipColor.info);
                        }).toList(),
                      ),
                    ],
                  ),
                ),
            ],

            // Members list
            const SizedBox(height: AppSpacing.s16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Members (${group.memberCount})',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textBright,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showAddMemberDialog(context, group.id),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text(
                      'Add',
                      style: AppTypography.captionV2.copyWith(
                        color: AppColors.violet,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            if (membersLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.s12),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.violet,
                    ),
                  ),
                ),
              )
            else if (members.isEmpty)
              Text(
                'No members yet.',
                style: AppTypography.captionV2
                    .copyWith(color: AppColors.textDim),
              )
            else
              ...members.take(6).map((m) => _MemberRow(member: m,
                  groupId: group.id)),

            // Danger zone
            const SizedBox(height: AppSpacing.s20),
            FluxButton(
              variant: FluxButtonVariant.danger,
              fullWidth: true,
              icon: Icons.delete_outline_rounded,
              onPressed: () =>
                  _confirmDelete(context, group),
              child: const Text('Delete Group'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '—';
    }
  }

  void _showEditDialog(BuildContext context, Group g) {
    final state = context.read<GroupsCubit>().state;
    final libraries = state is GroupsLoaded ? state.libraries : const <Library>[];
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => _EditGroupDialog(
        group: g,
        libraries: libraries,
        onConfirm: (name, description, status, restrictions) {
          context.read<GroupsCubit>().updateGroup(
                g.id,
                name: name,
                description: description,
                status: status,
                restrictions: restrictions,
              );
        },
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context, String groupId) {
    // Existing member ids — the dialog filters these out so the operator
    // doesn't see "add Pixel 8" when Pixel 8 is already in the group.
    // Membership shape is the loose `Map<String, dynamic>` the API
    // currently returns; both `client_id` and `id` keys are observed in
    // the wild (the existing _MemberRow handles both), so this filter
    // accepts either.
    final existingIds = <String>{
      for (final m in members)
        if (m['client_id'] is String) m['client_id'] as String
        else if (m['id'] is String) m['id'] as String,
    };
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => _AddMemberDialog(
        groupName: group.name,
        existingMemberIds: existingIds,
        onConfirm: (clientIds) {
          context.read<GroupsCubit>().addMembers(groupId, clientIds);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, Group g) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => FluxGlassDialog(
        title: Text('Delete "${g.name}"?'),
        content: const Text(
          'This will remove the group and all its member associations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<GroupsCubit>().deleteGroup(g.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Small helpers ──────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.index,
    this.isLast = false,
  });

  final String label;
  final String value;
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
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  AppTypography.captionV2.copyWith(color: AppColors.textDim)),
          Text(value,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textBody, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _RestrictRow extends StatelessWidget {
  const _RestrictRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTypography.captionV2
                  .copyWith(color: AppColors.textDim)),
          Text(value,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textBody)),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.groupId});

  final Map<String, dynamic> member;
  final String groupId;

  @override
  Widget build(BuildContext context) {
    final name = member['name'] as String? ??
        member['client_name'] as String? ??
        'Unknown';
    final platform = member['platform'] as String? ?? '';
    final clientId = member['client_id'] as String? ??
        member['id'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.violetDeep.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.person_outline_rounded,
                  size: 14, color: AppColors.violetTint),
            ),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textBody)),
                if (platform.isNotEmpty)
                  Text(platform,
                      style: AppTypography.captionV2
                          .copyWith(color: AppColors.textDim)),
              ],
            ),
          ),
          Tooltip(
            message: 'Remove member',
            child: FluxButton(
              variant: FluxButtonVariant.ghost,
              size: FluxButtonSize.sm,
              onPressed: () => context
                  .read<GroupsCubit>()
                  .removeMember(groupId, clientId),
              child: const Icon(Icons.remove_circle_outline_rounded,
                  size: 13, color: AppColors.textDim),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dialogs ────────────────────────────────────────────────────────────────────

/// Day-of-week order matches Python's `datetime.weekday()` convention used
/// server-side: 0=Mon … 6=Sun.  Server `_in_window` filters by exactly this
/// list so any reordering here would silently change which days the gate
/// matches.
const _kWeekdayLabels = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Format a [TimeWindow] for the live preview caption.  Handles midnight
/// wrap (`endH <= startH`), zero-length windows, and condenses the day list
/// to "Mon-Fri" / "Weekends" / "All week" / "Mon, Wed, Fri" depending on
/// shape.  Returns null when the window is null or zero-length.
String? _formatTimeWindow(TimeWindow? w) {
  if (w == null) return null;
  if (w.startH == w.endH) return 'Disabled (zero-length window)';

  String hour(int h) => '${h.toString().padLeft(2, '0')}:00';
  final range = '${hour(w.startH)}-${hour(w.endH)}';

  // Day list compaction.  Common patterns get friendly names; arbitrary
  // sets fall back to the comma-joined abbreviation.
  final days = [...w.days]..sort();
  if (days.length == 7) return 'All week, $range';
  if (days.length == 5 && days.every((d) => d <= 4)) return 'Mon-Fri, $range';
  if (days.length == 2 && days.contains(5) && days.contains(6)) {
    return 'Weekends, $range';
  }
  if (days.isEmpty) return 'No days selected';
  final names = days.map((d) => _kWeekdayLabels[d]).join(', ');
  return '$names, $range';
}

/// Inline restriction editor used by both Create and Edit dialogs.  Owns
/// local toggle + value state; calls [onChanged] whenever any field
/// changes so the parent dialog can hold the assembled
/// [GroupRestrictions?] for its Confirm handler.
///
/// Toggles control nullability: when "Restrict streaming time" is off the
/// emitted restrictions carry `timeWindow: null`; when on, the picker's
/// values flow through.  Same pattern for "Restrict to specific
/// libraries".  Bandwidth + max rating are advisory in v1 (server doesn't
/// enforce; see `docs/10_planning/12_groups_remediation_plan.md` §4) so
/// they're rendered disabled with explanatory tooltips — operator sees the
/// surface exists without us pretending they work.
class _GroupRestrictionsForm extends StatefulWidget {
  const _GroupRestrictionsForm({
    required this.libraries,
    required this.initial,
    required this.onChanged,
  });

  /// Library catalog used by the allowlist picker.  Empty list = the
  /// libraries fetch failed or the operator has no libraries; the picker
  /// renders a placeholder explaining why nothing is selectable.
  final List<Library> libraries;
  final GroupRestrictions? initial;
  final ValueChanged<GroupRestrictions?> onChanged;

  @override
  State<_GroupRestrictionsForm> createState() => _GroupRestrictionsFormState();
}

class _GroupRestrictionsFormState extends State<_GroupRestrictionsForm> {
  bool _restrictTime = false;
  bool _restrictLibraries = false;
  TimeWindow _windowDraft = const TimeWindow(
    startH: 18,
    endH: 22,
    days: [0, 1, 2, 3, 4, 5, 6],
  );
  Set<String> _allowedLibraries = <String>{};

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    if (r != null) {
      if (r.timeWindow != null) {
        _restrictTime = true;
        _windowDraft = r.timeWindow!;
      }
      if (r.allowedLibraries != null) {
        _restrictLibraries = true;
        _allowedLibraries = r.allowedLibraries!.toSet();
      }
    }
  }

  void _emit() {
    final hasRestriction = _restrictTime || _restrictLibraries;
    if (!hasRestriction) {
      widget.onChanged(null);
      return;
    }
    widget.onChanged(
      GroupRestrictions(
        timeWindow: _restrictTime ? _windowDraft : null,
        allowedLibraries:
            _restrictLibraries ? _allowedLibraries.toList() : null,
        // Bandwidth + maxRating left null — advisory, server doesn't act
        // on them, so persisting whatever the disabled controls show
        // would just clutter the DB.  When the server starts enforcing
        // them (v2), wire the controls and pass values through here.
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Time window ───────────────────────────────────────────────
        _SectionToggleHeader(
          icon: Icons.schedule_outlined,
          label: 'Restrict streaming time',
          value: _restrictTime,
          onChanged: (v) {
            setState(() => _restrictTime = v);
            _emit();
          },
        ),
        if (_restrictTime) ...[
          const SizedBox(height: AppSpacing.s8),
          _TimeWindowPicker(
            value: _windowDraft,
            onChanged: (w) {
              setState(() => _windowDraft = w);
              _emit();
            },
          ),
        ],
        const SizedBox(height: AppSpacing.s12),

        // ── Library allowlist ─────────────────────────────────────────
        _SectionToggleHeader(
          icon: Icons.video_library_outlined,
          label: 'Restrict to specific libraries',
          value: _restrictLibraries,
          onChanged: (v) {
            setState(() {
              _restrictLibraries = v;
              if (v && _allowedLibraries.isEmpty) {
                // Pre-select all libraries when the operator first
                // toggles this on so the gate doesn't immediately deny
                // every stream.  They can untick anything they want
                // restricted.
                _allowedLibraries =
                    widget.libraries.map((l) => l.id).toSet();
              }
            });
            _emit();
          },
        ),
        if (_restrictLibraries) ...[
          const SizedBox(height: AppSpacing.s8),
          _LibraryAllowlistPicker(
            libraries: widget.libraries,
            selected: _allowedLibraries,
            onToggle: (id) {
              setState(() {
                if (_allowedLibraries.contains(id)) {
                  _allowedLibraries = {..._allowedLibraries}..remove(id);
                } else {
                  _allowedLibraries = {..._allowedLibraries, id};
                }
              });
              _emit();
            },
          ),
        ],
        const SizedBox(height: AppSpacing.s12),

        // ── Advisory fields (recorded but not enforced — see §4 of the
        //     remediation plan).  Disabled with a tooltip so the operator
        //     understands the surface exists for forward-compat.
        const _AdvisoryFieldsSection(),
      ],
    );
  }
}

/// Icon + label + right-aligned [FluxSwitch] header used for each
/// restriction subsection.  Matches the Settings screen's section header
/// pattern but inline so the dialog stays vertically compact.
class _SectionToggleHeader extends StatelessWidget {
  const _SectionToggleHeader({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textMutedV2),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textBright,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        FluxSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}

/// Time-window editor — start hour, end hour, and day-of-week chips.
/// Server enforces both the day list AND the hour range; midnight wrap
/// (`endH <= startH`) is supported by `_in_window`.  This widget exposes a
/// live preview caption ("Mon-Fri 18:00-22:00") so the operator can verify
/// the assembled rule before saving.
class _TimeWindowPicker extends StatelessWidget {
  const _TimeWindowPicker({
    required this.value,
    required this.onChanged,
  });

  final TimeWindow value;
  final ValueChanged<TimeWindow> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: const Color(0x06FFFFFF),
        border: Border.all(color: const Color(0x14FFFFFF)),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hour pickers
          Row(
            children: [
              Expanded(
                child: _HourField(
                  label: 'Start',
                  value: value.startH,
                  onChanged: (h) =>
                      onChanged(_copyWindow(value, startH: h)),
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: _HourField(
                  label: 'End',
                  value: value.endH,
                  onChanged: (h) =>
                      onChanged(_copyWindow(value, endH: h)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),

          // Day-of-week chip row — multi-select, server-side day index.
          Text(
            'Days',
            style: AppTypography.captionV2.copyWith(color: AppColors.textDim),
          ),
          const SizedBox(height: AppSpacing.s4),
          Wrap(
            spacing: 4,
            children: List.generate(7, (i) {
              final selected = value.days.contains(i);
              return GestureDetector(
                onTap: () {
                  final next = [...value.days];
                  if (selected) {
                    next.remove(i);
                  } else {
                    next.add(i);
                  }
                  onChanged(_copyWindow(value, days: next));
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 5),
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
                      _kWeekdayLabels[i],
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
              );
            }),
          ),
          const SizedBox(height: AppSpacing.s10),

          // Live preview — what the server will see.
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 12, color: AppColors.textDim),
              const SizedBox(width: AppSpacing.s6),
              Expanded(
                child: Text(
                  _formatTimeWindow(value) ?? '(no window)',
                  style: AppTypography.captionV2
                      .copyWith(color: AppColors.textMutedV2),
                ),
              ),
            ],
          ),
          if (value.endH <= value.startH && value.endH != value.startH) ...[
            const SizedBox(height: AppSpacing.s4),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 12, color: AppColors.amber),
                const SizedBox(width: AppSpacing.s6),
                Expanded(
                  child: Text(
                    'Window wraps midnight — '
                    '${value.startH.toString().padLeft(2, '0')}:00 to '
                    '${value.endH.toString().padLeft(2, '0')}:00 next day.',
                    style: AppTypography.captionV2.copyWith(
                      color: AppColors.amber.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ],
          // Timezone note — the server uses its local time.  Self-hosted
          // single-house deployments rarely care; remote-paired clients
          // across timezones do.  Documented limitation per
          // `12_groups_remediation_plan.md` §4.3.
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Times are evaluated in the server\'s local timezone.',
            style: AppTypography.captionV2.copyWith(color: AppColors.textDim),
          ),
        ],
      ),
    );
  }

  static TimeWindow _copyWindow(
    TimeWindow base, {
    int? startH,
    int? endH,
    List<int>? days,
  }) {
    return TimeWindow(
      startH: startH ?? base.startH,
      endH: endH ?? base.endH,
      days: days ?? base.days,
    );
  }
}

/// Numeric hour selector (0-23) rendered as a label + read-only field with
/// up/down chevrons.  Avoids dragging in a heavyweight time picker for a
/// 24-value range — this is faster to operate than a clock spinner.
class _HourField extends StatelessWidget {
  const _HourField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    String fmt(int h) => '${h.toString().padLeft(2, '0')}:00';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.captionV2.copyWith(color: AppColors.textDim),
        ),
        const SizedBox(height: AppSpacing.s4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0x08FFFFFF),
            border: Border.all(color: const Color(0x14FFFFFF)),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  fmt(value),
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textBright,
                  ),
                ),
              ),
              _ChevronButton(
                icon: Icons.keyboard_arrow_up_rounded,
                onTap: () => onChanged((value + 1) % 24),
              ),
              _ChevronButton(
                icon: Icons.keyboard_arrow_down_rounded,
                onTap: () => onChanged((value - 1 + 24) % 24),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChevronButton extends StatelessWidget {
  const _ChevronButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(icon, size: 14, color: AppColors.textMutedV2),
        ),
      ),
    );
  }
}

/// Multi-select chip row of library names.  Each chip is independently
/// tickable; the parent passes a set of selected library ids and a toggle
/// callback.  Empty libraries list (fetch failed or operator has no
/// libraries) renders an explanatory placeholder instead of a blank wrap
/// — without it the operator would see the toggle on but no chips and
/// wonder if the UI was broken.
class _LibraryAllowlistPicker extends StatelessWidget {
  const _LibraryAllowlistPicker({
    required this.libraries,
    required this.selected,
    required this.onToggle,
  });

  final List<Library> libraries;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: const Color(0x06FFFFFF),
        border: Border.all(color: const Color(0x14FFFFFF)),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: libraries.isEmpty
          ? Text(
              'No libraries found.  Create one from the Library screen '
              'to use this restriction.',
              style: AppTypography.captionV2
                  .copyWith(color: AppColors.textDim),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${selected.length} of ${libraries.length} '
                  '${libraries.length == 1 ? 'library' : 'libraries'} '
                  'allowed',
                  style: AppTypography.captionV2
                      .copyWith(color: AppColors.textDim),
                ),
                const SizedBox(height: AppSpacing.s8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: libraries.map((lib) {
                    final isSel = selected.contains(lib.id);
                    return GestureDetector(
                      onTap: () => onToggle(lib.id),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSel
                                ? const Color(0x2EA855F7)
                                : const Color(0x08FFFFFF),
                            border: Border.all(
                              color: isSel
                                  ? const Color(0x80A855F7)
                                  : const Color(0x0FFFFFFF),
                            ),
                            borderRadius:
                                BorderRadius.circular(AppRadii.sm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSel
                                    ? Icons.check_rounded
                                    : Icons.add_rounded,
                                size: 12,
                                color: isSel
                                    ? AppColors.violetSoft
                                    : AppColors.textMutedV2,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                lib.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isSel
                                      ? AppColors.violetSoft
                                      : AppColors.textMutedV2,
                                ),
                              ),
                            ],
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

/// Bandwidth cap + max rating placeholders.  Both fields exist in the
/// server schema (`group_restrictions.bandwidth_cap_mbps`,
/// `group_restrictions.max_rating`) but neither is enforced — see
/// `docs/10_planning/12_groups_remediation_plan.md` §4 for why.  Rendering
/// them disabled with a tooltip is the honest UX: the operator sees the
/// surface exists without us pretending it works.
class _AdvisoryFieldsSection extends StatelessWidget {
  const _AdvisoryFieldsSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s10),
      decoration: BoxDecoration(
        color: const Color(0x05FFFFFF),
        border: Border.all(color: const Color(0x0AFFFFFF)),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 12, color: AppColors.textDim),
              const SizedBox(width: AppSpacing.s6),
              Expanded(
                child: Text(
                  'Advisory fields  •  recorded but not yet enforced',
                  style: AppTypography.captionV2.copyWith(
                    color: AppColors.textDim,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Tooltip(
            message:
                'Bandwidth cap is recorded but not enforced in v1.  See '
                'docs/10_planning/12_groups_remediation_plan.md §4.1.',
            child: TextField(
              enabled: false,
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Bandwidth cap (Mbps)',
                hintText: '—',
                border: const OutlineInputBorder(),
                disabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.textDim.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Tooltip(
            message:
                'Max rating is recorded but not enforced in v1 — '
                'media_files has no rating column yet.  See '
                'docs/10_planning/12_groups_remediation_plan.md §4.2.',
            child: TextField(
              enabled: false,
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Max content rating',
                hintText: '—',
                border: const OutlineInputBorder(),
                disabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.textDim.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add Member dialog ──────────────────────────────────────────────────────────

/// Real client picker for adding members.  Replaces the earlier raw-UUID
/// `TextField` that asked operators to paste client ids by hand — a paste
/// surface nobody could reasonably use.
///
/// On open: fetches the operator's paired clients via `ClientsRepository`,
/// filters to approved + trusted (so pending pair requests + revoked
/// clients don't pollute the picker), and excludes any client already in
/// the group.  Multi-select; Confirm fires `addMembers(groupId, ids)` on
/// the cubit which sequentially walks the list.
///
/// Same pattern as the F9 Profile Sessions tab's session list (landed
/// 2026-05-07): scrollable client list with search, hover state, mounted
/// guards across awaits.
class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog({
    required this.groupName,
    required this.existingMemberIds,
    required this.onConfirm,
  });

  final String groupName;
  final Set<String> existingMemberIds;
  final void Function(List<String> clientIds) onConfirm;

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  static final _log = Logger();

  bool _loading = true;
  String? _error;
  List<ClientListItem> _clients = const [];
  final Set<String> _selected = <String>{};
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = GetIt.I<ClientsRepository>();
      final all = await repo.getClients();
      if (!mounted) return;
      setState(() {
        _clients = all;
        _loading = false;
      });
    } catch (e, st) {
      _log.w('Add-member client list load failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load clients: $e';
        _loading = false;
      });
    }
  }

  /// Eligible candidates: approved + trusted, not already in the group,
  /// matching the optional search term.  Search hits both name and id so
  /// an operator who really does want to paste a known UUID can still do
  /// so — but they no longer have to.
  List<ClientListItem> get _filtered {
    final s = _search.trim().toLowerCase();
    return _clients.where((c) {
      if (c.status != ClientStatus.approved) return false;
      if (!c.isTrusted) return false;
      if (widget.existingMemberIds.contains(c.id)) return false;
      if (s.isEmpty) return true;
      return c.name.toLowerCase().contains(s) ||
          c.id.toLowerCase().contains(s);
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final canConfirm = !_loading && _selected.isNotEmpty;
    return FluxGlassDialog(
      title: Text('Add members to ${widget.groupName}'),
      content: SizedBox(
        width: 460,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pick one or more paired devices.  Pending pair requests + '
              'revoked clients are excluded.',
              style: AppTypography.captionV2
                  .copyWith(color: AppColors.textDim),
            ),
            const SizedBox(height: AppSpacing.s12),

            // Search box — filters by name OR raw id (the latter for
            // operators who paste UUIDs from external tooling).
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded, size: 16),
                hintText: 'Search by name or id',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: AppSpacing.s10),

            // Selection counter — operator wants to know "did the click
            // register" without scrolling the list.
            Row(
              children: [
                Text(
                  _loading
                      ? 'Loading clients…'
                      : '${_selected.length} selected  ·  '
                          '${filtered.length} available',
                  style: AppTypography.captionV2
                      .copyWith(color: AppColors.textDim),
                ),
                const Spacer(),
                if (_selected.isNotEmpty && !_loading)
                  GestureDetector(
                    onTap: () => setState(_selected.clear),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Text(
                        'Clear',
                        style: AppTypography.captionV2.copyWith(
                          color: AppColors.violet,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),

            // Body — loading / error / empty / list.
            Expanded(child: _buildBody(filtered)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.violet),
          onPressed: canConfirm
              ? () {
                  widget.onConfirm(_selected.toList());
                  Navigator.pop(context);
                }
              : null,
          child: Text(
            _selected.isEmpty
                ? 'Add'
                : 'Add ${_selected.length} '
                    '${_selected.length == 1 ? "device" : "devices"}',
          ),
        ),
      ],
    );
  }

  Widget _buildBody(List<ClientListItem> filtered) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 18, color: AppColors.red),
            const SizedBox(height: AppSpacing.s8),
            Text(
              _error!,
              style:
                  AppTypography.bodySmall.copyWith(color: AppColors.textBody),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s10),
            FluxButton(
              variant: FluxButtonVariant.secondary,
              size: FluxButtonSize.sm,
              icon: Icons.refresh_rounded,
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _load();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (filtered.isEmpty) {
      // Two distinct empty states: "no clients at all" vs "all eligible
      // clients are already in the group".  Operator gets actionable
      // copy in both cases.
      final hasAnyApproved = _clients.any(
        (c) => c.status == ClientStatus.approved && c.isTrusted,
      );
      final allInGroup = hasAnyApproved &&
          _clients
              .where((c) =>
                  c.status == ClientStatus.approved && c.isTrusted)
              .every((c) => widget.existingMemberIds.contains(c.id));
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Text(
            _search.isNotEmpty
                ? 'No clients match "${_search.trim()}".'
                : allInGroup
                    ? 'Every paired device is already in this group.'
                    : 'No paired devices.  Pair one from the Clients '
                        'screen first.',
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
          final c = filtered[i];
          return _ClientPickRow(
            client: c,
            selected: _selected.contains(c.id),
            onTap: () => _toggle(c.id),
          );
        },
      ),
    );
  }
}

/// One row in the [_AddMemberDialog]'s scrollable list.
class _ClientPickRow extends StatefulWidget {
  const _ClientPickRow({
    required this.client,
    required this.selected,
    required this.onTap,
  });

  final ClientListItem client;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ClientPickRow> createState() => _ClientPickRowState();
}

class _ClientPickRowState extends State<_ClientPickRow> {
  bool _hover = false;

  IconData get _platformIcon => switch (widget.client.platform) {
        ClientPlatform.android => Icons.phone_android,
        ClientPlatform.ios => Icons.phone_iphone,
        ClientPlatform.windows => Icons.desktop_windows_outlined,
        ClientPlatform.macos => Icons.desktop_mac_outlined,
        ClientPlatform.linux => Icons.computer_outlined,
      };

  String get _platformLabel => switch (widget.client.platform) {
        ClientPlatform.android => 'Android',
        ClientPlatform.ios => 'iOS',
        ClientPlatform.windows => 'Windows',
        ClientPlatform.macos => 'macOS',
        ClientPlatform.linux => 'Linux',
      };

  String _relativeTime(DateTime dt) {
    final delta = DateTime.now().toUtc().difference(dt.toUtc());
    if (delta.inSeconds < 30) return 'Just now';
    if (delta.inMinutes < 1) return '${delta.inSeconds}s ago';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    if (delta.inDays < 7) return '${delta.inDays}d ago';
    return '${delta.inDays ~/ 7}w ago';
  }

  void _setHover(bool value) {
    if (!mounted) return;
    setState(() => _hover = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    final bg = widget.selected
        ? const Color(0x14A855F7)
        : (_hover ? const Color(0x06FFFFFF) : Colors.transparent);
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
          color: bg,
          child: Row(
            children: [
              // Selection indicator.  Boxy 14×14 outline — explicit tick
              // beats Material's Checkbox chrome which doesn't match the
              // glass dialog aesthetic.
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: widget.selected
                      ? AppColors.violet
                      : Colors.transparent,
                  border: Border.all(
                    color: widget.selected
                        ? AppColors.violet
                        : AppColors.textDim,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: widget.selected
                    ? const Icon(Icons.check_rounded,
                        size: 10, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: AppSpacing.s10),
              Icon(_platformIcon, size: 14, color: AppColors.violet),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textBright,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$_platformLabel  ·  '
                      'last seen ${_relativeTime(c.lastSeen)}',
                      style: AppTypography.captionV2
                          .copyWith(color: AppColors.textDim),
                    ),
                  ],
                ),
              ),
              if (c.lastIp != null) ...[
                const SizedBox(width: AppSpacing.s8),
                Text(
                  c.lastIp!,
                  style: AppTypography.captionV2.copyWith(
                    color: AppColors.textMutedV2,
                    fontFamily: 'JetBrainsMono',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Create / Edit dialogs ──────────────────────────────────────────────────────

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog({
    required this.libraries,
    required this.onConfirm,
  });

  final List<Library> libraries;
  final void Function(
    String name,
    String? description,
    GroupRestrictions? restrictions,
  ) onConfirm;

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  GroupRestrictions? _restrictions;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FluxGlassDialog(
      title: const Text('Create Group'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Group Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.s18),
              Text(
                'Restrictions',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBright,
                ),
              ),
              Text(
                'All restrictions are optional.  Combined across every '
                'group a client belongs to (most-restrictive wins).',
                style: AppTypography.captionV2
                    .copyWith(color: AppColors.textDim),
              ),
              const SizedBox(height: AppSpacing.s10),
              _GroupRestrictionsForm(
                libraries: widget.libraries,
                initial: null,
                onChanged: (r) => _restrictions = r,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.violet),
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            widget.onConfirm(
              name,
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
              _restrictions,
            );
            Navigator.pop(context);
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _EditGroupDialog extends StatefulWidget {
  const _EditGroupDialog({
    required this.group,
    required this.libraries,
    required this.onConfirm,
  });

  final Group group;
  final List<Library> libraries;
  final void Function(
    String name,
    String? description,
    GroupStatus status,
    GroupRestrictions? restrictions,
  ) onConfirm;

  @override
  State<_EditGroupDialog> createState() => _EditGroupDialogState();
}

class _EditGroupDialogState extends State<_EditGroupDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late GroupStatus _status;
  late GroupRestrictions? _restrictions;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.group.name);
    _descCtrl =
        TextEditingController(text: widget.group.description ?? '');
    _status = widget.group.status;
    _restrictions = widget.group.restrictions;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FluxGlassDialog(
      title: const Text('Edit Group'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.s18),

              // Status toggle — server gate filters `WHERE g.status =
              // 'active'` so flipping inactive disables the gate
              // immediately for new streams.  Existing in-flight streams
              // continue (membership-mid-stream is documented as
              // out-of-scope per §4.4 of the remediation plan).
              _SectionToggleHeader(
                icon: Icons.check_circle_outline_rounded,
                label: _status == GroupStatus.active
                    ? 'Active  •  restrictions enforced'
                    : 'Inactive  •  restrictions not enforced',
                value: _status == GroupStatus.active,
                onChanged: (v) => setState(
                  () => _status =
                      v ? GroupStatus.active : GroupStatus.inactive,
                ),
              ),
              const SizedBox(height: AppSpacing.s18),

              Text(
                'Restrictions',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBright,
                ),
              ),
              Text(
                'Toggle a restriction off to remove it.  Combined across '
                'every group a client belongs to.',
                style: AppTypography.captionV2
                    .copyWith(color: AppColors.textDim),
              ),
              const SizedBox(height: AppSpacing.s10),
              _GroupRestrictionsForm(
                libraries: widget.libraries,
                initial: widget.group.restrictions,
                onChanged: (r) => _restrictions = r,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.violet),
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            widget.onConfirm(
              name,
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
              _status,
              _restrictions,
            );
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

