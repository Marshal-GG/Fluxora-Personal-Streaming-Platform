import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/group.dart';
import 'package:fluxora_desktop/features/groups/domain/repositories/groups_repository.dart';
import 'package:fluxora_desktop/features/groups/presentation/cubit/groups_cubit.dart';
import 'package:fluxora_desktop/features/groups/presentation/cubit/groups_state.dart';
import 'package:fluxora_desktop/shared/widgets/flux_button.dart';
import 'package:fluxora_desktop/shared/widgets/flux_card.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';
import 'package:fluxora_desktop/shared/widgets/pill.dart';
import 'package:fluxora_desktop/shared/widgets/stat_tile.dart';
import 'package:fluxora_desktop/shared/widgets/status_dot.dart';

// ── Entry point ────────────────────────────────────────────────────────────────

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<GroupsCubit>(
      create: (_) =>
          GroupsCubit(repository: GetIt.I<GroupsRepository>())..load(),
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

class _GroupsLoaded extends StatelessWidget {
  const _GroupsLoaded({required this.state});

  final GroupsLoaded state;

  @override
  Widget build(BuildContext context) {
    final groups = state.groups;
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
                      child: StatTile(
                        icon: Icons.group_work_outlined,
                        label: 'Total Groups',
                        value: '${groups.length}',
                        color: AppColors.violet,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s14),
                    Expanded(
                      child: StatTile(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Active Groups',
                        value: '$activeGroups',
                        color: AppColors.emerald,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s14),
                    Expanded(
                      child: StatTile(
                        icon: Icons.person_outline_rounded,
                        label: 'Total Members',
                        value: '$totalMembers',
                        color: AppColors.blue,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s14),
                    Expanded(
                      child: StatTile(
                        icon: Icons.people_outline_rounded,
                        label: 'Avg Members',
                        value: '$avgMembers',
                        color: AppColors.amber,
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
                      // Header row
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.s18,
                          vertical: AppSpacing.s14,
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text('All Groups',
                                style: AppTypography.h2),
                            FluxButton(
                              variant: FluxButtonVariant.secondary,
                              size: FluxButtonSize.sm,
                              icon: Icons.filter_list_rounded,
                              onPressed: null,
                              child: Text('Filter'),
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
                            SizedBox(width: 32),
                          ],
                        ),
                      ),
                      // Rows
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
                      else
                        ...groups.map(
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
          ),
      ],
    );
  }

  void _showCreateDialog(BuildContext context) {
    // TODO: Replace Material showDialog with FluxDialog at M6 cutover.
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _CreateGroupDialog(
        onConfirm: (name, description) {
          context.read<GroupsCubit>().createGroup(
                name: name,
                description: description,
              );
        },
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
                width: 32,
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
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceGlass,
        title: Text(
          'Delete "${g.name}"?',
          style: AppTypography.h2
              .copyWith(color: AppColors.textBright),
        ),
        content: Text(
          'This will remove the group and all its member associations. This cannot be undone.',
          style: AppTypography.bodySmall
              .copyWith(color: AppColors.textMutedV2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<GroupsCubit>().deleteGroup(g.id);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.red),
            ),
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
  });

  final Group group;
  final List<Map<String, dynamic>> members;
  final bool membersLoading;

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
                FluxButton(
                  variant: FluxButtonVariant.ghost,
                  size: FluxButtonSize.sm,
                  icon: Icons.edit_outlined,
                  onPressed: () =>
                      _showEditDialog(context, group),
                  child: const SizedBox.shrink(),
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
                          Pill(
                            isActive ? 'Active' : 'Inactive',
                            color: isActive
                                ? PillColor.success
                                : PillColor.neutral,
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
                  value:
                      '${r.timeWindow!.startH}:00–${r.timeWindow!.endH}:00',
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
                        children: r.allowedLibraries!
                            .map((l) => Pill(l,
                                color: PillColor.info))
                            .toList(),
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
    // TODO: Replace with FluxDialog at M6 cutover.
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => _EditGroupDialog(
        group: g,
        onConfirm: (name, description) {
          context.read<GroupsCubit>().updateGroup(
                g.id,
                name: name,
                description: description,
              );
        },
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context, String groupId) {
    // TODO: Replace with FluxDialog at M6 cutover.
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceGlass,
        title: Text('Add Member',
            style:
                AppTypography.h2.copyWith(color: AppColors.textBright)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Client ID',
            border: OutlineInputBorder(),
          ),
          style: AppTypography.body.copyWith(color: AppColors.textBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final clientId = controller.text.trim();
              if (clientId.isNotEmpty) {
                context
                    .read<GroupsCubit>()
                    .addMember(groupId, clientId);
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Group g) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceGlass,
        title: Text(
          'Delete "${g.name}"?',
          style:
              AppTypography.h2.copyWith(color: AppColors.textBright),
        ),
        content: Text(
          'This will remove the group and all its member associations.',
          style: AppTypography.bodySmall
              .copyWith(color: AppColors.textMutedV2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<GroupsCubit>().deleteGroup(g.id);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.red)),
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
          FluxButton(
            variant: FluxButtonVariant.ghost,
            size: FluxButtonSize.sm,
            onPressed: () => context
                .read<GroupsCubit>()
                .removeMember(groupId, clientId),
            child: const Icon(Icons.remove_circle_outline_rounded,
                size: 13, color: AppColors.textDim),
          ),
        ],
      ),
    );
  }
}

// ── Dialogs ────────────────────────────────────────────────────────────────────

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog({required this.onConfirm});

  final void Function(String name, String? description) onConfirm;

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceGlass,
      title: Text('Create Group',
          style: AppTypography.h2.copyWith(color: AppColors.textBright)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Group Name *',
              border: OutlineInputBorder(),
            ),
            style:
                AppTypography.body.copyWith(color: AppColors.textBody),
          ),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
            ),
            style:
                AppTypography.body.copyWith(color: AppColors.textBody),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            widget.onConfirm(
                name, _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim());
            Navigator.pop(context);
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _EditGroupDialog extends StatefulWidget {
  const _EditGroupDialog({required this.group, required this.onConfirm});

  final Group group;
  final void Function(String name, String? description) onConfirm;

  @override
  State<_EditGroupDialog> createState() => _EditGroupDialogState();
}

class _EditGroupDialogState extends State<_EditGroupDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.group.name);
    _descCtrl =
        TextEditingController(text: widget.group.description ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceGlass,
      title: Text('Edit Group',
          style: AppTypography.h2.copyWith(color: AppColors.textBright)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Group Name',
              border: OutlineInputBorder(),
            ),
            style:
                AppTypography.body.copyWith(color: AppColors.textBody),
          ),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
            style:
                AppTypography.body.copyWith(color: AppColors.textBody),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            widget.onConfirm(
                name, _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim());
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
