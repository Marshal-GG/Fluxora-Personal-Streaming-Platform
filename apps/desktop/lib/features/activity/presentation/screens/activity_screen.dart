import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/activity_event.dart';
import 'package:fluxora_desktop/features/recent_activity/domain/repositories/recent_activity_repository.dart';
import 'package:fluxora_desktop/features/recent_activity/presentation/cubit/recent_activity_cubit.dart';
import 'package:fluxora_desktop/features/recent_activity/presentation/cubit/recent_activity_state.dart';
import 'package:fluxora_desktop/shared/widgets/flux_button.dart';
import 'package:fluxora_desktop/shared/widgets/flux_card.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';
import 'package:fluxora_desktop/shared/widgets/stat_tile.dart';

// ── Entry point ────────────────────────────────────────────────────────────────

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RecentActivityCubit>(
      create: (_) => RecentActivityCubit(
        repository: GetIt.I<RecentActivityRepository>(),
      )..loadAll(),
      child: const _ActivityView(),
    );
  }
}

// ── Main stateful view ─────────────────────────────────────────────────────────

class _ActivityView extends StatefulWidget {
  const _ActivityView();

  @override
  State<_ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<_ActivityView> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // Category filters — null means "show all". Active categories are included.
  final Set<String> _activeCategories = {
    'stream',
    'client',
    'transcode',
    'library',
    'system',
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgRoot,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: AppSpacing.s28,
          right: AppSpacing.s28,
          bottom: AppSpacing.s28,
        ),
        child: BlocBuilder<RecentActivityCubit, RecentActivityState>(
          builder: (context, state) {
            final events = state is RecentActivityLoaded ? state.events : <ActivityEvent>[];
            final filtered = _applyFilters(events);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────────────────
                PageHeader(
                  title: 'Activity',
                  subtitle:
                      'Real-time event log of streams, clients, and server operations',
                  actions: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Search input
                      SizedBox(
                        width: 220,
                        height: 34,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) =>
                              setState(() => _searchQuery = v),
                          style: AppTypography.body.copyWith(
                            color: AppColors.textBody,
                            fontSize: 12,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search events…',
                            hintStyle: AppTypography.body.copyWith(
                              color: AppColors.textDim,
                              fontSize: 12,
                            ),
                            prefixIcon: const Icon(Icons.search_rounded,
                                size: 15, color: AppColors.textDim),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 10),
                            filled: true,
                            fillColor: const Color(0x0AFFFFFF),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadii.sm),
                              borderSide: const BorderSide(
                                  color: Color(0x0FFFFFFF)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadii.sm),
                              borderSide: const BorderSide(
                                  color: Color(0x0FFFFFFF)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadii.sm),
                              borderSide: const BorderSide(
                                  color: AppColors.violet),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      // Export — disabled (no backend endpoint).
                      const FluxButton(
                        variant: FluxButtonVariant.secondary,
                        icon: Icons.download_outlined,
                        onPressed: null,
                        child: Text('Export'),
                      ),
                    ],
                  ),
                ),

                // ── Stat tiles ─────────────────────────────────────────
                _StatTilesRow(events: events),
                const SizedBox(height: AppSpacing.s18),

                // ── 2-col grid ─────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Live Activity card
                    Expanded(
                      child: _LiveActivityCard(
                        state: state,
                        events: filtered,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s14),

                    // Right sidebar
                    SizedBox(
                      width: 280,
                      child: _FilterSidebar(
                        events: events,
                        activeCategories: _activeCategories,
                        onToggle: (cat) => setState(() {
                          if (_activeCategories.contains(cat)) {
                            _activeCategories.remove(cat);
                          } else {
                            _activeCategories.add(cat);
                          }
                        }),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<ActivityEvent> _applyFilters(List<ActivityEvent> events) {
    return events.where((e) {
      // Category filter
      final cat = e.type.split('.').first;
      if (!_activeCategories.contains(cat) &&
          !_activeCategories.contains('stream') &&
          cat == 'stream') {
        return false;
      }
      // Map event prefix to filter category
      final mappedCat = switch (cat) {
        'stream' => 'stream',
        'client' => 'client',
        'transcode' || 'transcod' => 'transcode',
        'library' || 'file' => 'library',
        _ => 'system',
      };
      if (!_activeCategories.contains(mappedCat)) return false;

      // Search filter
      if (_searchQuery.isNotEmpty) {
        return e.summary
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());
      }
      return true;
    }).toList();
  }
}

// ── Stat tiles ─────────────────────────────────────────────────────────────────

class _StatTilesRow extends StatelessWidget {
  const _StatTilesRow({required this.events});

  final List<ActivityEvent> events;

  @override
  Widget build(BuildContext context) {
    // Derive counts from loaded events — no fabricated deltas.
    final today = DateTime.now().toUtc();
    final todayEvents = events.where((e) {
      try {
        final dt = DateTime.parse(e.createdAt).toUtc();
        return dt.year == today.year &&
            dt.month == today.month &&
            dt.day == today.day;
      } catch (_) {
        return false;
      }
    }).toList();

    final streamsStarted = events
        .where((e) => e.type.startsWith('stream.start'))
        .length;
    final clientEvents = events
        .where((e) => e.type.startsWith('client.'))
        .length;
    final warnings = events
        .where((e) =>
            e.type.contains('warn') || e.type.contains('error'))
        .length;

    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: 'Events Today ${todayEvents.length}',
            child: StatTile(
              icon: Icons.bar_chart_rounded,
              label: 'Events Today',
              value: '${todayEvents.length}',
              color: AppColors.violet,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s14),
        Expanded(
          child: Semantics(
            label: 'Streams Started $streamsStarted',
            child: StatTile(
              icon: Icons.play_circle_outline_rounded,
              label: 'Streams Started',
              value: '$streamsStarted',
              color: AppColors.blue,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s14),
        Expanded(
          child: Semantics(
            label: 'Client Events $clientEvents',
            child: StatTile(
              icon: Icons.devices_outlined,
              label: 'Client Events',
              value: '$clientEvents',
              color: AppColors.emerald,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s14),
        Expanded(
          child: Semantics(
            label: 'Warnings $warnings',
            child: StatTile(
              icon: Icons.warning_amber_rounded,
              label: 'Warnings',
              value: '$warnings',
              color: AppColors.amber,
              accent: AppColors.amber,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Live Activity card ─────────────────────────────────────────────────────────

class _LiveActivityCard extends StatelessWidget {
  const _LiveActivityCard({
    required this.state,
    required this.events,
  });

  final RecentActivityState state;
  final List<ActivityEvent> events;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RecentActivityCubit>();
    final isPaused = cubit.isPaused;

    return FluxCard(
      padding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s18,
              vertical: AppSpacing.s14,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Live Activity', style: AppTypography.h2),
                    const SizedBox(width: AppSpacing.s8),
                    if (!isPaused)
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.emerald,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x8010B981),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Live',
                            style: AppTypography.captionV2.copyWith(
                              color: AppColors.emerald,
                            ),
                          ),
                        ],
                      ),
                    if (isPaused)
                      Text(
                        'Paused',
                        style: AppTypography.captionV2.copyWith(
                          color: AppColors.amber,
                        ),
                      ),
                  ],
                ),
                FluxButton(
                  variant: FluxButtonVariant.secondary,
                  size: FluxButtonSize.sm,
                  icon: isPaused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  onPressed: () {
                    if (isPaused) {
                      cubit.resume();
                    } else {
                      cubit.pause();
                    }
                  },
                  child: Text(isPaused ? 'Resume' : 'Pause'),
                ),
              ],
            ),
          ),

          // Event list
          switch (state) {
            RecentActivityInitial() ||
            RecentActivityLoading() =>
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.s28),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.violet,
                    ),
                  ),
                ),
              ),
            RecentActivityFailure(:final message) => Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.s20),
                child: Center(
                  child: Text(
                    message,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textDim),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            RecentActivityLoaded() => events.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.s28),
                    child: Center(
                      child: Text(
                        'No events match the current filters.',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textDim),
                      ),
                    ),
                  )
                : Column(
                    children: events
                        .take(100)
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) => _ActivityEventRow(
                              event: entry.value,
                              isLast: entry.key ==
                                  (events.length > 100
                                          ? 100
                                          : events.length) -
                                      1,
                            ))
                        .toList(),
                  ),
          },
        ],
      ),
    );
  }
}

// ── Activity event row ─────────────────────────────────────────────────────────

class _ActivityEventRow extends StatelessWidget {
  const _ActivityEventRow({required this.event, required this.isLast});

  final ActivityEvent event;
  final bool isLast;

  static (Color, IconData) _iconFor(String type) {
    final category = type.split('.').first;
    return switch (category) {
      'stream' => (AppColors.blue, Icons.play_circle_outline_rounded),
      'client' => (AppColors.violet, Icons.devices_outlined),
      'library' => (AppColors.cyan, Icons.folder_outlined),
      'file' => (AppColors.cyan, Icons.insert_drive_file_outlined),
      'settings' => (AppColors.amber, Icons.settings_outlined),
      'transcode' || 'transcod' => (AppColors.pink, Icons.memory_outlined),
      'system' => (AppColors.textMutedV2, Icons.dns_outlined),
      _ => (AppColors.textMutedV2, Icons.circle_outlined),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (color, iconData) = _iconFor(event.type);

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0x08FFFFFF))),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s20,
        vertical: AppSpacing.s14,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: Icon(iconData, size: 15, color: color),
            ),
          ),
          const SizedBox(width: AppSpacing.s14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.summary,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textBody,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  event.type,
                  style: AppTypography.captionV2
                      .copyWith(color: AppColors.textDim),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Text(
            _relativeTime(event.createdAt),
            style: AppTypography.monoCaption
                .copyWith(color: AppColors.textDim),
          ),
        ],
      ),
    );
  }

  static String _relativeTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toUtc();
      final diff = DateTime.now().toUtc().difference(dt);
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '—';
    }
  }
}

// ── Filter sidebar ─────────────────────────────────────────────────────────────

class _FilterSidebar extends StatelessWidget {
  const _FilterSidebar({
    required this.events,
    required this.activeCategories,
    required this.onToggle,
  });

  final List<ActivityEvent> events;
  final Set<String> activeCategories;
  final ValueChanged<String> onToggle;

  static const _categories = [
    ('stream', 'Streams', AppColors.violet),
    ('client', 'Clients', AppColors.blue),
    ('transcode', 'Transcoding', AppColors.pink),
    ('library', 'Library', AppColors.emerald),
    ('system', 'System', AppColors.textMutedV2),
  ];

  int _countForCategory(String cat) {
    return events.where((e) {
      final prefix = e.type.split('.').first;
      return switch (cat) {
        'transcode' => prefix == 'transcode' || prefix == 'transcod',
        'library' => prefix == 'library' || prefix == 'file',
        _ => prefix == cat,
      };
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return FluxCard(
      padding: AppSpacing.s18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter by Type', style: AppTypography.h2),
          const SizedBox(height: AppSpacing.s12),
          ..._categories.map((cat) {
            final (id, label, color) = cat;
            final count = _countForCategory(id);
            final isActive = activeCategories.contains(id);

            return GestureDetector(
              onTap: () => onToggle(id),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: isActive
                              ? color.withValues(alpha: 0.2)
                              : Colors.transparent,
                          border: Border.all(
                            color: isActive ? color : AppColors.textDim,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: isActive
                            ? Icon(Icons.check_rounded,
                                size: 9, color: color)
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.s10),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          label,
                          style: AppTypography.body.copyWith(
                            color: isActive
                                ? AppColors.textBody
                                : AppColors.textDim,
                          ),
                        ),
                      ),
                      Text(
                        '$count',
                        style: AppTypography.monoCaption.copyWith(
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
