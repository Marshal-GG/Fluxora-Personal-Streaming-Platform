/// Profile-screen group surfaces — three cards (Locked / Unlocked /
/// Visible Libraries) wired to [MobileGroupsCubit].
///
/// Plan: `docs/10_planning/13_groups_v2_content_spaces.md` §M6.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/fluxora_core.dart';

import 'package:fluxora_mobile/features/groups/domain/repositories/groups_repository.dart';
import 'package:fluxora_mobile/features/groups/presentation/cubit/groups_cubit.dart';
import 'package:fluxora_mobile/features/groups/presentation/cubit/groups_state.dart';
import 'package:fluxora_mobile/features/groups/presentation/widgets/pin_modals.dart';

/// All-in-one section that renders the three M6 cards.  Designed to be
/// dropped into the Profile screen between the stat row and the
/// settings list.  Hides itself entirely when the cubit has no
/// content to surface (no gated groups + no provenance worth showing).
class GroupsSection extends StatelessWidget {
  const GroupsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MobileGroupsCubit, MobileGroupsState>(
      builder: (context, state) {
        if (state is MobileGroupsLoading || state is MobileGroupsInitial) {
          return const _LoadingShell();
        }
        if (state is MobileGroupsFailure) {
          return _FailureShell(message: state.message);
        }
        final loaded = state as MobileGroupsLoaded;
        final locked = loaded.lockedGroups;
        final unlocked = loaded.unlockedGroups;
        final visible = loaded.libraryIds;
        // Hide the entire section if nothing meaningful — fresh install
        // with one operator client + no PIN-gated groups would otherwise
        // show three empty cards.
        if (locked.isEmpty && unlocked.isEmpty && visible.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (locked.isNotEmpty) ...[
              _LockedGroupsCard(groups: locked, parentState: loaded),
              const SizedBox(height: 12),
            ],
            if (unlocked.isNotEmpty) ...[
              _UnlockedGroupsCard(groups: unlocked, parentState: loaded),
              const SizedBox(height: 12),
            ],
            if (visible.isNotEmpty)
              _VisibleLibrariesCard(
                libraryIds: visible,
                provenance: loaded.groupsContributing,
                groupsById: {for (final g in loaded.groups) g.id: g},
              ),
          ],
        );
      },
    );
  }
}

// ── Locked Groups ──────────────────────────────────────────────────────────

class _LockedGroupsCard extends StatelessWidget {
  const _LockedGroupsCard({
    required this.groups,
    required this.parentState,
  });

  final List<MobileGroupRow> groups;
  final MobileGroupsLoaded parentState;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Locked groups',
      caption: 'Tap to unlock content from groups you\'re a member of.',
      icon: Icons.lock_outline_rounded,
      iconColor: AppColors.amber,
      child: Column(
        children: [
          for (var i = 0; i < groups.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                color: Color(0x10FFFFFF),
              ),
            _LockedGroupRow(
              group: groups[i],
              isBusy: parentState.actionInFlight == groups[i].id,
            ),
          ],
        ],
      ),
    );
  }
}

class _LockedGroupRow extends StatelessWidget {
  const _LockedGroupRow({required this.group, required this.isBusy});

  final MobileGroupRow group;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final state = group.enrollmentState;
    final isEnrollment =
        state == GroupEnrollmentState.enrollmentRequired;
    return InkWell(
      onTap: isBusy ? null : () => _onTap(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            _GroupAvatar(group: group),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textBright,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isEnrollment
                        ? 'Set up a PIN for this device'
                        : 'Enter PIN to unlock',
                    style: AppTypography.captionV2.copyWith(
                      color: AppColors.textMutedV2,
                    ),
                  ),
                ],
              ),
            ),
            if (isBusy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.violet,
                ),
              )
            else
              Icon(
                isEnrollment
                    ? Icons.add_circle_outline_rounded
                    : Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.violet,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context) async {
    final cubit = context.read<MobileGroupsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    if (group.enrollmentState ==
        GroupEnrollmentState.enrollmentRequired) {
      final pin = await showFluxBottomSheet<String>(
        context: context,
        builder: (_) => PinEnrollmentSheet(
          groupName: group.name,
          pinMode: group.pinMode,
        ),
      );
      if (pin == null) return;
      final ok = await cubit.enroll(group.id, pin);
      if (ok) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('${group.name} unlocked'),
            backgroundColor: AppColors.violet,
          ),
        );
      } else {
        final err = (cubit.state is MobileGroupsLoaded)
            ? (cubit.state as MobileGroupsLoaded).lastError
            : null;
        messenger.showSnackBar(
          SnackBar(content: Text(err ?? 'Enrollment failed')),
        );
      }
    } else {
      // Shared mode + per-client-already-enrolled both land on the
      // entry sheet.  Sheet copy adapts to pin_model.
      final pin = await showFluxBottomSheet<String>(
        context: context,
        builder: (_) => PinEntrySheet(
          groupName: group.name,
          pinMode: group.pinMode,
          pinModel: group.pinModel,
        ),
      );
      if (pin == null) return;
      final ok = await cubit.enter(group.id, pin);
      if (ok) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('${group.name} unlocked'),
            backgroundColor: AppColors.violet,
          ),
        );
      } else {
        final err = (cubit.state is MobileGroupsLoaded)
            ? (cubit.state as MobileGroupsLoaded).lastError
            : null;
        messenger.showSnackBar(
          SnackBar(content: Text(err ?? 'Wrong PIN')),
        );
      }
    }
  }
}

// ── Unlocked Groups ────────────────────────────────────────────────────────

class _UnlockedGroupsCard extends StatelessWidget {
  const _UnlockedGroupsCard({
    required this.groups,
    required this.parentState,
  });

  final List<MobileGroupRow> groups;
  final MobileGroupsLoaded parentState;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Unlocked groups',
      caption: 'Currently accessible.  Tap "Lock" to drop this device\'s '
          'grant — re-PIN on next access.',
      icon: Icons.lock_open_rounded,
      iconColor: AppColors.violet,
      trailing: groups.length > 1
          ? GestureDetector(
              onTap: () => _confirmLockAll(context),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  'Lock all',
                  style: AppTypography.captionV2.copyWith(
                    color: AppColors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          : null,
      child: Column(
        children: [
          for (var i = 0; i < groups.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                color: Color(0x10FFFFFF),
              ),
            _UnlockedGroupRow(
              group: groups[i],
              isBusy: parentState.actionInFlight == groups[i].id,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmLockAll(BuildContext context) async {
    final cubit = context.read<MobileGroupsCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F0C24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: Text(
          'Lock all groups?',
          style: AppTypography.h2.copyWith(color: AppColors.textBright),
        ),
        content: Text(
          'Drops every active grant on this device.  You\'ll need to '
          're-enter your PIN on next access.',
          style: AppTypography.body.copyWith(color: AppColors.textMutedV2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTypography.body
                  .copyWith(color: AppColors.textBright),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Lock all',
              style: AppTypography.body.copyWith(
                color: AppColors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await cubit.lockAll();
  }
}

class _UnlockedGroupRow extends StatelessWidget {
  const _UnlockedGroupRow({required this.group, required this.isBusy});

  final MobileGroupRow group;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          _GroupAvatar(group: group),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textBright,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (group.grantExpiresAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Expires ${_formatExpires(group.grantExpiresAt!)}',
                    style: AppTypography.captionV2.copyWith(
                      color: AppColors.textMutedV2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isBusy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.violet,
              ),
            )
          else
            TextButton(
              onPressed: () => context
                  .read<MobileGroupsCubit>()
                  .lock(group.id),
              child: Text(
                'Lock',
                style: AppTypography.captionV2.copyWith(
                  color: AppColors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Render an ISO timestamp as a friendly relative-or-clock string.
/// "in 11 h" for grants <12 h out, "at HH:MM" for grants today, full
/// date for further out.  Matches the desktop View As tab's format
/// loosely; mobile gets shorter copy.
String _formatExpires(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  final delta = dt.toLocal().difference(DateTime.now());
  if (delta.isNegative) return 'expired';
  if (delta.inMinutes < 60) return 'in ${delta.inMinutes} min';
  if (delta.inHours < 24) return 'in ${delta.inHours} h';
  // Same-day clock time as a fallback for sub-12 h cases that round
  // to 12+ — operator wants to know "11:32 PM," not "in 14 h."
  final local = dt.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return 'at $h:$m';
}

// ── Visible Libraries ──────────────────────────────────────────────────────

class _VisibleLibrariesCard extends StatelessWidget {
  const _VisibleLibrariesCard({
    required this.libraryIds,
    required this.provenance,
    required this.groupsById,
  });

  final List<String> libraryIds;
  final Map<String, List<String>> provenance;
  final Map<String, MobileGroupRow> groupsById;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Visible libraries',
      caption: 'Libraries this device can browse right now.',
      icon: Icons.video_library_outlined,
      iconColor: AppColors.violetTint,
      child: Column(
        children: [
          for (var i = 0; i < libraryIds.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                color: Color(0x10FFFFFF),
              ),
            _LibraryRow(
              libraryId: libraryIds[i],
              grantingGroups: (provenance[libraryIds[i]] ?? const [])
                  .map((id) => groupsById[id])
                  .whereType<MobileGroupRow>()
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({
    required this.libraryId,
    required this.grantingGroups,
  });

  final String libraryId;
  final List<MobileGroupRow> grantingGroups;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Icon(
            Icons.folder_open_rounded,
            size: 16,
            color: AppColors.textMutedV2,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show the raw library_id — the mobile Library tab is
                // the source of truth for display names; this card is
                // just a "what do you have access to" summary.  Future
                // polish: cross-reference to the cached library catalog.
                Text(
                  libraryId,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textBody,
                    fontFamily: 'JetBrainsMono',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (grantingGroups.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '← granted by ${grantingGroups.map((g) => g.name).join(", ")}',
                    style: AppTypography.captionV2.copyWith(
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared shells ──────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.caption,
    required this.icon,
    required this.iconColor,
    required this.child,
    this.trailing,
  });

  final String title;
  final String caption;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x06FFFFFF),
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Icon(icon, size: 15, color: iconColor)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textBright,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: AppTypography.captionV2.copyWith(
              color: AppColors.textMutedV2,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _GroupAvatar extends StatelessWidget {
  const _GroupAvatar({required this.group});
  final MobileGroupRow group;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(group.color) ?? AppColors.violet;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Icon(
          _iconFor(group.icon),
          size: 16,
          color: color,
        ),
      ),
    );
  }

  Color? _parseColor(String? hex) {
    if (hex == null) return null;
    final trimmed = hex.replaceAll('#', '');
    if (trimmed.length != 6) return null;
    final v = int.tryParse(trimmed, radix: 16);
    if (v == null) return null;
    return Color(0xFF000000 | v);
  }

  IconData _iconFor(String? key) {
    switch (key) {
      case 'home':
        return Icons.home_rounded;
      case 'kids':
        return Icons.child_care_rounded;
      case 'lock':
        return Icons.lock_rounded;
      case 'family':
        return Icons.family_restroom_rounded;
      case 'music':
        return Icons.music_note_rounded;
      case 'video':
        return Icons.videocam_rounded;
      case 'tv':
        return Icons.tv_rounded;
      case 'gamepad':
        return Icons.sports_esports_rounded;
      case 'headphones':
        return Icons.headphones_rounded;
      case 'download':
        return Icons.download_rounded;
      case 'globe':
      case 'public':
        return Icons.public_rounded;
      case 'coffee':
        return Icons.coffee_rounded;
      default:
        return Icons.group_rounded;
    }
  }
}

class _LoadingShell extends StatelessWidget {
  const _LoadingShell();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.violet,
          ),
        ),
      ),
    );
  }
}

class _FailureShell extends StatelessWidget {
  const _FailureShell({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x06FFFFFF),
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            size: 16,
            color: AppColors.amber,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Couldn\'t load group state — $message',
              style: AppTypography.captionV2
                  .copyWith(color: AppColors.textMutedV2),
            ),
          ),
        ],
      ),
    );
  }
}
