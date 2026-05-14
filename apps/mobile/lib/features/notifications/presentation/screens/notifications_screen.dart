/// Notifications screen — grouped Today / This week / Earlier.
///
/// Reachable from the Home tab's bell icon. Modal-style scaffold (back
/// button + "Mark all read"). Each row maps `AppNotification.category` to
/// a colored 36×36 icon square + title + sub + relative timestamp +
/// optional unread dot. Backed by the singleton [NotificationsCubit] which
/// polls `/api/v1/notifications` every 5 s; live WS migration tracked at
/// the repository's `TODO(WS)`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:get_it/get_it.dart';

import 'package:fluxora_mobile/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:fluxora_mobile/features/notifications/presentation/cubit/notifications_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = GetIt.I<NotificationsCubit>();
    if (_cubit.state is NotificationsInitial) {
      _cubit.start();
    }
  }

  Future<void> _refresh() async {
    await _cubit.start();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificationsCubit>.value(
      value: _cubit,
      child: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          final unreadCount =
              state is NotificationsLoaded ? state.unreadCount : 0;

          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: FluxAppBar(
              title: 'Notifications',
              onBack: () => Navigator.of(context).maybePop(),
              trailing: [
                Semantics(
                  button: true,
                  label: 'Mark all notifications as read',
                  enabled: unreadCount > 0,
                  child: TextButton(
                    onPressed: unreadCount > 0
                        ? () =>
                            context.read<NotificationsCubit>().markAllRead()
                        : null,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.violetTint,
                      disabledForegroundColor: AppColors.textDim,
                    ),
                    child: Text(
                      'Mark all read',
                      style: AppTypography.captionV2.copyWith(
                        color: unreadCount > 0
                            ? AppColors.violetTint
                            : AppColors.textDim,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.violet,
              backgroundColor: AppColors.surfaceGlass,
              child: switch (state) {
                NotificationsInitial() ||
                NotificationsLoading() =>
                  const _LoadingView(),
                NotificationsFailure(:final message) => _FailureView(
                    message: message,
                    onRetry: _refresh,
                  ),
                NotificationsLoaded(:final items) => _LoadedView(
                    items: items,
                  ),
              },
            ),
          );
        },
      ),
    );
  }
}

// ── Loaded list ─────────────────────────────────────────────────────────────

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.items});

  final List<AppNotification> items;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = <AppNotification>[];
    final thisWeek = <AppNotification>[];
    final earlier = <AppNotification>[];
    for (final n in items) {
      final dt = DateTime.tryParse(n.createdAt);
      if (dt == null) {
        earlier.add(n);
        continue;
      }
      final age = now.difference(dt);
      if (age.inDays < 1) {
        today.add(n);
      } else if (age.inDays < 7) {
        thisWeek.add(n);
      } else {
        earlier.add(n);
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: _EmptyState(),
          ),
        if (today.isNotEmpty) _Group(label: 'Today', items: today),
        if (thisWeek.isNotEmpty) _Group(label: 'This week', items: thisWeek),
        if (earlier.isNotEmpty) _Group(label: 'Earlier', items: earlier),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.items});

  final String label;
  final List<AppNotification> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(label.toUpperCase(), style: AppTypography.eyebrow),
        ),
        for (final n in items) _NotificationRow(item: n),
      ],
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.item});

  final AppNotification item;

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
        NotificationCategory.license => Icons.workspace_premium_outlined,
        NotificationCategory.transcode => Icons.tune_outlined,
        NotificationCategory.storage => Icons.storage_outlined,
      };

  String _relativeTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final age = DateTime.now().difference(dt);
    if (age.inMinutes < 1) return 'Just now';
    if (age.inMinutes < 60) return '${age.inMinutes}m';
    if (age.inHours < 24) return '${age.inHours}h';
    if (age.inDays < 7) return '${age.inDays}d';
    return '${(age.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(item.category);
    final isUnread = item.readAt == null;

    return Semantics(
      button: true,
      label: isUnread
          ? '${item.title}, unread. ${item.message}'
          : '${item.title}. ${item.message}',
      child: InkWell(
      onTap: () {
        if (isUnread) {
          context.read<NotificationsCubit>().markRead(item.id);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(_categoryIcon(item.category), size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textBright,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _relativeTime(item.createdAt),
                        style: AppTypography.captionV2.copyWith(
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.message,
                    style: AppTypography.captionV2
                        .copyWith(color: AppColors.textMutedV2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isUnread) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.violet,
                  shape: BoxShape.circle,
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

// ── Loading / failure / empty ───────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 200),
        Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.violet,
            ),
          ),
        ),
      ],
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      children: [
        const SizedBox(height: 96),
        const Icon(
          Icons.cloud_off_outlined,
          size: 40,
          color: AppColors.textDim,
        ),
        const SizedBox(height: 12),
        Text(
          'Couldn\'t reach your server',
          textAlign: TextAlign.center,
          style: AppTypography.h2.copyWith(color: AppColors.textBright),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.captionV2.copyWith(color: AppColors.textMutedV2),
        ),
        const SizedBox(height: 16),
        Center(
          child: FluxButton(
            onPressed: () => onRetry(),
            child: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.notifications_off_outlined,
          size: 40,
          color: AppColors.textDim,
        ),
        const SizedBox(height: 12),
        Text(
          'You\'re all caught up',
          style: AppTypography.h2.copyWith(color: AppColors.textBright),
        ),
        const SizedBox(height: 4),
        Text(
          'New activity from your server will land here.',
          textAlign: TextAlign.center,
          style:
              AppTypography.captionV2.copyWith(color: AppColors.textMutedV2),
        ),
      ],
    );
  }
}
