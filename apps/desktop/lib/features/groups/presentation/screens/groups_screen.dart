import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/enums.dart';
import 'package:fluxora_core/entities/group.dart';
import 'package:fluxora_core/entities/library.dart';
import 'package:fluxora_desktop/core/router/app_router.dart';
import 'package:fluxora_desktop/features/groups/domain/repositories/groups_repository.dart';
import 'package:fluxora_desktop/features/groups/presentation/cubit/groups_cubit.dart';
import 'package:fluxora_desktop/features/groups/presentation/cubit/groups_state.dart';
import 'package:fluxora_desktop/features/groups/presentation/screens/group_edit_screen.dart' show groupColor, groupIconData;
import 'package:fluxora_desktop/features/groups/presentation/widgets/group_form_widgets.dart';
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_core/widgets/flux_button.dart';
import 'package:fluxora_core/widgets/flux_chip.dart';
import 'package:fluxora_desktop/shared/widgets/flux_card.dart';
import 'package:fluxora_desktop/shared/widgets/flux_glass_dialog.dart';
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
                    onPressed: () => context.push(Routes.groupNew),
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
                        color: groupColor(g.color).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: Center(
                        child: Icon(
                          groupIconData(g.icon),
                          size: 14,
                          color: groupColor(g.color),
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
                        context.push(Routes.groupEdit(group.id)),
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
                    color: groupColor(group.color).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Center(
                    child: Icon(
                      groupIconData(group.icon),
                      size: 20,
                      color: groupColor(group.color),
                    ),
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
                  value: formatTimeWindow(r.timeWindow) ?? '—',
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
      builder: (dialogCtx) => AddMemberDialog(
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
