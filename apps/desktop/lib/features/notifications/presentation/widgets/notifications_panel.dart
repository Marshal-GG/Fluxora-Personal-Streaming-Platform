/// NotificationsPanel — slide-over overlay mounted inside FluxShell.
///
/// Matches `docs/11_design/desktop_prototype/app/pages/notifications.jsx`.
/// Width: 420 px, full height, right-edge pinned. Toggled via
/// [NotificationsPanelNotifier] — not a route.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/app_notification.dart';

import 'package:fluxora_desktop/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:fluxora_desktop/features/notifications/presentation/cubit/notifications_state.dart';

// ── Panel toggle notifier ─────────────────────────────────────────────────────

/// Simple [ValueNotifier] that tracks whether the notifications slide-over is
/// open. Provided at the [FluxShell] level so sidebar and shell both share it.
class NotificationsPanelNotifier extends ValueNotifier<bool> {
  NotificationsPanelNotifier() : super(false);

  void toggle() => value = !value;
  void open() => value = true;
  void close() => value = false;
}

// ── Panel widget ─────────────────────────────────────────────────────────────

/// Right-edge slide-over notifications panel.
///
/// Wrap it in an [Overlay] or place it as the last child of a [Stack] inside
/// [FluxShell]. Pass [onClose] to dismiss.
class NotificationsPanel extends StatefulWidget {
  const NotificationsPanel({
    super.key,
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  State<NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<NotificationsPanel> {
  // Category filter — 'all' | 'unread' | 'system' | 'client' | 'license'
  String _filter = 'all';

  static const _filters = ['All', 'Unread', 'System', 'Client', 'License'];

  List<AppNotification> _filtered(List<AppNotification> items) {
    return switch (_filter) {
      'unread' => items.where((n) => n.readAt == null).toList(),
      'system' =>
        items.where((n) => n.category == NotificationCategory.system).toList(),
      'client' =>
        items.where((n) => n.category == NotificationCategory.client).toList(),
      'license' =>
        items.where((n) => n.category == NotificationCategory.license).toList(),
      _ => items,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dim backdrop
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: const ColoredBox(
              color: Color(0x80020108),
            ),
          ),
        ),
        // Panel itself
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          width: 420,
          child: _PanelBody(
            filter: _filter,
            onFilterChanged: (f) => setState(() => _filter = f),
            filters: _filters,
            filtered: _filtered,
            onClose: widget.onClose,
          ),
        ),
      ],
    );
  }
}

class _PanelBody extends StatelessWidget {
  const _PanelBody({
    required this.filter,
    required this.onFilterChanged,
    required this.filters,
    required this.filtered,
    required this.onClose,
  });

  final String filter;
  final ValueChanged<String> onFilterChanged;
  final List<String> filters;
  final List<AppNotification> Function(List<AppNotification>) filtered;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFA140C28), Color(0xFA0F0820)],
        ),
        border: Border(
          left: BorderSide(color: Color(0x2EA855F7)),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 48,
            offset: Offset(-12, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _Header(onClose: onClose),
          _FilterBar(
            filter: filter,
            filters: filters,
            onChanged: onFilterChanged,
          ),
          Expanded(
            child: BlocBuilder<NotificationsCubit, NotificationsState>(
              builder: (context, state) {
                return switch (state) {
                  NotificationsInitial() ||
                  NotificationsLoading() =>
                    const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFA855F7),
                      ),
                    ),
                  NotificationsFailure(:final message) => Center(
                      child: Text(
                        message,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textDim),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  NotificationsLoaded(:final items) => () {
                      final visible = filtered(items);
                      if (visible.isEmpty) return const _EmptyState();
                      return _NotificationList(items: visible);
                    }(),
                };
              },
            ),
          ),
          const _Footer(),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s20,
        vertical: 18,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x0DFFFFFF))),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_outlined,
              size: 16, color: Color(0xFFA855F7)),
          const SizedBox(width: AppSpacing.s10),
          Text(
            'Notifications',
            style: AppTypography.h2.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.s10),
          BlocSelector<NotificationsCubit, NotificationsState, int>(
            selector: (s) =>
                s is NotificationsLoaded ? s.unreadCount : 0,
            builder: (_, count) {
              if (count == 0) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x33A855F7),
                  border: Border.all(color: const Color(0x66A855F7)),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  '$count new',
                  style: AppTypography.eyebrow.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE9D5FF),
                  ),
                ),
              );
            },
          ),
          const Spacer(),
          _IconBtn(
            icon: Icons.done_all,
            tooltip: 'Mark all as read',
            onTap: () =>
                context.read<NotificationsCubit>().markAllRead(),
          ),
          const SizedBox(width: 4),
          _IconBtn(
            icon: Icons.close,
            tooltip: 'Close',
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.filters,
    required this.onChanged,
  });

  final String filter;
  final List<String> filters;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF))),
      ),
      child: Row(
        children: [
          for (final f in filters)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _FilterChip(
                label: f,
                active: filter.toLowerCase() == f.toLowerCase(),
                onTap: () => onChanged(f.toLowerCase()),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? const Color(0x26A855F7) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: active
                  ? const Color(0xFFE9D5FF)
                  : AppColors.textMutedV2,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Notification list ─────────────────────────────────────────────────────────

class _NotificationList extends StatelessWidget {
  const _NotificationList({required this.items});
  final List<AppNotification> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) =>
          _NotificationRow(notification: items[i]),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification});
  final AppNotification notification;

  static Color _categoryColor(NotificationCategory cat) => switch (cat) {
        NotificationCategory.system => const Color(0xFF94A3B8),
        NotificationCategory.client => const Color(0xFF10B981),
        NotificationCategory.license => const Color(0xFFA855F7),
        NotificationCategory.transcode => const Color(0xFF3B82F6),
        NotificationCategory.storage => const Color(0xFFF59E0B),
      };

  static IconData _categoryIcon(NotificationCategory cat) => switch (cat) {
        NotificationCategory.system => Icons.settings_outlined,
        NotificationCategory.client => Icons.devices_outlined,
        NotificationCategory.license =>
          Icons.workspace_premium_outlined,
        NotificationCategory.transcode => Icons.tune_outlined,
        NotificationCategory.storage => Icons.storage_outlined,
      };

  static String _routeForKind(String? kind) => switch (kind) {
        'client' => '/clients',
        'license' => '/subscription',
        'transcode' => '/transcoding',
        'storage' => '/library',
        _ => '/',
      };

  String _relativeTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final color = _categoryColor(n.category);
    final isUnread = n.readAt == null;
    final cubit = context.read<NotificationsCubit>();

    return GestureDetector(
      onTap: () {
        cubit.markRead(n.id);
        final route = _routeForKind(n.relatedKind);
        context.go(route);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s20,
            vertical: 12,
          ),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0x08FFFFFF))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Unread dot
              if (isUnread)
                Padding(
                  padding: const EdgeInsets.only(top: 13, right: 6),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFA855F7),
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              else
                const SizedBox(width: 12),
              // Icon badge
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  border: Border.all(color: color.withValues(alpha: 0.24)),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(_categoryIcon(n.category), size: 13, color: color),
              ),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style: AppTypography.body.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textBright,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      n.message,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMutedV2,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _relativeTime(n.createdAt),
                      style: AppTypography.monoMicro.copyWith(
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              // Dismiss button
              _IconBtn(
                icon: Icons.close,
                tooltip: 'Dismiss',
                onTap: () => cubit.dismiss(n.id),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0x1AA855F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.notifications_none_outlined,
              size: 28,
              color: Color(0xFFA855F7),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'All caught up',
            style: AppTypography.h2.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No notifications to show.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textDim),
          ),
        ],
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s20,
        vertical: 12,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x0DFFFFFF))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.go('/settings'),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                'Notification Settings',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.violet,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () =>
                context.read<NotificationsCubit>().markAllRead(),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                'Mark all as read',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMutedV2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared icon button ────────────────────────────────────────────────────────

class _IconBtn extends StatefulWidget {
  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 30,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    Widget btn = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0x14FFFFFF)
                : const Color(0x08FFFFFF),
            border: Border.all(color: const Color(0x14FFFFFF)),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(widget.icon, size: 13, color: AppColors.textMutedV2),
        ),
      ),
    );
    if (widget.tooltip != null) {
      btn = Tooltip(message: widget.tooltip!, child: btn);
    }
    return btn;
  }
}
