import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_desktop/features/logs/domain/log_record.dart';
import 'package:fluxora_desktop/features/logs/domain/repositories/logs_repository.dart';
import 'package:fluxora_desktop/features/logs/presentation/cubit/logs_cubit.dart';
import 'package:fluxora_desktop/features/logs/presentation/cubit/logs_state.dart';
import 'package:fluxora_desktop/shared/widgets/flux_button.dart';
import 'package:fluxora_desktop/shared/widgets/flux_card.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';
import 'package:fluxora_desktop/shared/widgets/flux_tab_bar.dart';
import 'package:fluxora_desktop/shared/widgets/status_dot.dart';

// ── Colour maps (from prototype) ──────────────────────────────────────────────

const _levelFg = {
  'INFO': Color(0xFF3B82F6),
  'WARN': Color(0xFFF59E0B),
  'ERROR': Color(0xFFEF4444),
  'DEBUG': Color(0xFF94A3B8),
};

const _levelBg = {
  'INFO': Color(0x263B82F6),
  'WARN': Color(0x26F59E0B),
  'ERROR': Color(0x26EF4444),
  'DEBUG': Color(0x2694A3B8),
};

// ── Entry point ────────────────────────────────────────────────────────────────

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LogsCubit>(
      create: (_) => LogsCubit(
        repository: GetIt.I<LogsRepository>(),
      )..load(),
      child: const _LogsView(),
    );
  }
}

// ── Main stateful view ─────────────────────────────────────────────────────────

class _LogsView extends StatefulWidget {
  const _LogsView();

  @override
  State<_LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends State<_LogsView> {
  // ── Tab / filter state ────────────────────────────────────────────────────
  String _activeTab = 'all';
  String _levelFilter = 'ALL';
  String _timeRange = 'Last 24 Hours';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  // ── Pause / polling ───────────────────────────────────────────────────────
  bool _paused = false;
  Timer? _pollTimer;
  List<LogRecord> _snapshot = [];

  // ── Scroll ────────────────────────────────────────────────────────────────
  final _scrollCtrl = ScrollController();

  // ── Expansion ─────────────────────────────────────────────────────────────
  int? _expandedIndex;

  static const _tabs = [
    FluxTab(id: 'all', label: 'Live Logs', icon: Icons.show_chart),
    FluxTab(id: 'files', label: 'Log Files', icon: Icons.insert_drive_file_outlined),
    FluxTab(id: 'export', label: 'Export Logs', icon: Icons.download_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _startPolling();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_paused && mounted) {
        context.read<LogsCubit>().load();
      }
    });
  }

  void _togglePause() => setState(() => _paused = !_paused);

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  // ── Filter logic ──────────────────────────────────────────────────────────

  List<LogRecord> _filtered(List<LogRecord> records) {
    // Tab filter maps to level.
    final String? tabLevel = switch (_activeTab) {
      'errors' => 'ERROR',
      'warnings' => 'WARN',
      'info' => 'INFO',
      _ => null, // 'all'
    };

    return records.where((r) {
      if (tabLevel != null && r.level != tabLevel) return false;
      if (_levelFilter != 'ALL' && r.level != _levelFilter) return false;
      if (_searchQuery.isNotEmpty &&
          !r.message.toLowerCase().contains(_searchQuery) &&
          !r.source.toLowerCase().contains(_searchQuery)) {
        return false;
      }
      return true;
    }).toList();
  }

  // ── Level summary counts ──────────────────────────────────────────────────

  Map<String, int> _counts(List<LogRecord> records) {
    final m = <String, int>{'INFO': 0, 'WARN': 0, 'ERROR': 0, 'DEBUG': 0};
    for (final r in records) {
      if (m.containsKey(r.level)) m[r.level] = m[r.level]! + 1;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LogsCubit, LogsState>(
      listener: (context, state) {
        if (state is LogsLoaded && !_paused) {
          _snapshot = state.records;
          _scrollToBottom();
        } else if (state is LogsLoaded && _snapshot.isEmpty) {
          _snapshot = state.records;
        }
      },
      builder: (context, state) {
        final records =
            state is LogsLoaded ? state.records : _snapshot;
        final counts = _counts(records);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Main content ───────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.s24,
                  right: AppSpacing.s24,
                  bottom: AppSpacing.s24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    PageHeader(
                      title: 'Logs',
                      subtitle: 'View and monitor server logs in real time',
                      actions: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FluxButton(
                            variant: FluxButtonVariant.secondary,
                            size: FluxButtonSize.sm,
                            icon: _paused ? Icons.play_arrow : Icons.pause,
                            onPressed: _togglePause,
                            child: Text(_paused ? 'Resume' : 'Pause'),
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          FluxButton(
                            variant: FluxButtonVariant.danger,
                            size: FluxButtonSize.sm,
                            icon: Icons.delete_outline,
                            onPressed: () =>
                                context.read<LogsCubit>().load(),
                            child: const Text('Clear Logs'),
                          ),
                        ],
                      ),
                    ),

                    // Tab bar
                    FluxTabBar(
                      tabs: _tabs,
                      activeId: _activeTab,
                      onChange: (id) =>
                          setState(() => _activeTab = id),
                    ),

                    const SizedBox(height: AppSpacing.s14),

                    if (_activeTab == 'files') ...[
                      const _PlaceholderTab(label: 'Log Files', subtitle: 'Log file listing not yet available.'),
                    ] else if (_activeTab == 'export') ...[
                      const _PlaceholderTab(label: 'Export Logs', subtitle: 'Log export requires a backend endpoint (planned).'),
                    ] else ...[
                      // Live logs table
                      Expanded(child: _LiveLogsTable(
                        records: _filtered(records),
                        scrollCtrl: _scrollCtrl,
                        expandedIndex: _expandedIndex,
                        onExpand: (i) => setState(() =>
                            _expandedIndex = _expandedIndex == i ? null : i),
                      )),

                      // Footer: live indicator + count
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.s8),
                        child: Row(
                          children: [
                            StatusDot(
                              status: _paused
                                  ? DotStatus.inactive
                                  : DotStatus.online,
                              size: 6,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _paused ? 'Paused' : 'Live',
                              style: AppTypography.captionV2.copyWith(
                                color: _paused
                                    ? AppColors.textDim
                                    : AppColors.emerald,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_filtered(records).length} entries',
                              style: AppTypography.captionV2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Right-rail filter panel ────────────────────────────────────
            _FilterRail(
              levelFilter: _levelFilter,
              timeRange: _timeRange,
              searchCtrl: _searchCtrl,
              counts: counts,
              totalCount: records.length,
              onLevelChanged: (v) => setState(() => _levelFilter = v),
              onTimeRangeChanged: (v) => setState(() => _timeRange = v),
              onReset: () {
                setState(() {
                  _levelFilter = 'ALL';
                  _timeRange = 'Last 24 Hours';
                  _searchCtrl.clear();
                  _searchQuery = '';
                });
              },
              onApply: () => context.read<LogsCubit>().load(),
            ),
          ],
        );
      },
    );
  }
}

// ── Live logs table ───────────────────────────────────────────────────────────

class _LiveLogsTable extends StatelessWidget {
  const _LiveLogsTable({
    required this.records,
    required this.scrollCtrl,
    required this.expandedIndex,
    required this.onExpand,
  });

  final List<LogRecord> records;
  final ScrollController scrollCtrl;
  final int? expandedIndex;
  final ValueChanged<int> onExpand;

  @override
  Widget build(BuildContext context) {
    return FluxCard(
      padding: 0,
      child: Column(
        children: [
          // Column headers
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color(0x0DFFFFFF), // rgba(255,255,255,0.05)
                ),
              ),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text('Time',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDim)),
                ),
                SizedBox(width: 12),
                SizedBox(
                  width: 60,
                  child: Text('Level',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDim)),
                ),
                SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: Text('Source',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDim)),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Message',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDim)),
                ),
              ],
            ),
          ),

          // Log rows
          Expanded(
            child: records.isEmpty
                ? const Center(
                    child: Text(
                      'No log entries match the current filter.',
                      style: AppTypography.bodySmall,
                    ),
                  )
                : ListView.builder(
                    controller: scrollCtrl,
                    itemCount: records.length,
                    itemBuilder: (context, i) {
                      return _LogRow(
                        record: records[i],
                        isExpanded: expandedIndex == i,
                        isFirst: i == 0,
                        onTap: () => onExpand(i),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Individual log row ────────────────────────────────────────────────────────

class _LogRow extends StatefulWidget {
  const _LogRow({
    required this.record,
    required this.isExpanded,
    required this.isFirst,
    required this.onTap,
  });

  final LogRecord record;
  final bool isExpanded;
  final bool isFirst;
  final VoidCallback onTap;

  @override
  State<_LogRow> createState() => _LogRowState();
}

class _LogRowState extends State<_LogRow> {
  bool _hovered = false;

  Color _messageColor(String level) => switch (level) {
        'ERROR' => const Color(0xFFF87171),
        'WARN' => const Color(0xFFFBBF24),
        _ => AppColors.textBody,
      };

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final fg = _levelFg[r.level] ?? AppColors.textMutedV2;
    final bg = _levelBg[r.level] ?? const Color(0x2694A3B8);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: widget.isExpanded
                ? const Color(0x1AA855F7) // rgba(168,85,247,0.10)
                : _hovered
                    ? const Color(0x08FFFFFF) // rgba(255,255,255,0.02)
                    : Colors.transparent,
            border: Border(
              top: widget.isFirst
                  ? BorderSide.none
                  : const BorderSide(
                      color: Color(0x08FFFFFF), // rgba(255,255,255,0.03)
                    ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main row
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Timestamp
                    SizedBox(
                      width: 80,
                      child: Text(
                        r.shortTime,
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11.5,
                          color: AppColors.textDim,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Level pill
                    SizedBox(
                      width: 60,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(AppRadii.xs - 2), // 4
                        ),
                        child: Text(
                          r.level,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: fg,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Source
                    SizedBox(
                      width: 110,
                      child: Text(
                        r.source,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.violet,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Message
                    Expanded(
                      child: Text(
                        r.message,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11.5,
                          color: _messageColor(r.level),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Expanded detail panel
              if (widget.isExpanded)
                Container(
                  margin: const EdgeInsets.only(
                      left: 16, right: 16, bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0x0A000000),
                    borderRadius: BorderRadius.circular(AppRadii.xs),
                    border: const Border.fromBorderSide(
                      BorderSide(color: Color(0x14FFFFFF)),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SelectableText(
                          '${r.ts}  [${r.level}]  ${r.source}\n${r.message}',
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 11,
                            color: AppColors.textBody,
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CopyButton(text: r.message),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Copy button ────────────────────────────────────────────────────────────────

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.text});
  final String text;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return FluxButton(
      variant: FluxButtonVariant.ghost,
      size: FluxButtonSize.sm,
      icon: _copied ? Icons.check : Icons.copy_outlined,
      onPressed: _copy,
      child: Text(_copied ? 'Copied' : 'Copy'),
    );
  }
}

// ── Right-rail filter panel ───────────────────────────────────────────────────

class _FilterRail extends StatelessWidget {
  const _FilterRail({
    required this.levelFilter,
    required this.timeRange,
    required this.searchCtrl,
    required this.counts,
    required this.totalCount,
    required this.onLevelChanged,
    required this.onTimeRangeChanged,
    required this.onReset,
    required this.onApply,
  });

  final String levelFilter;
  final String timeRange;
  final TextEditingController searchCtrl;
  final Map<String, int> counts;
  final int totalCount;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<String> onTimeRangeChanged;
  final VoidCallback onReset;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Color(0x80141226), // rgba(13,11,28,0.5) — sidebar tint
        border: Border(
          left: BorderSide(color: Color(0x0DFFFFFF)),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.s18),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Log Filters',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textBright,
                  ),
                ),
                GestureDetector(
                  onTap: onReset,
                  child: const Text(
                    'Reset',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.violet,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.s14),

            // Level filter
            _RailDropdown<String>(
              label: 'Level',
              value: levelFilter,
              items: const [
                ('ALL', 'All Levels'),
                ('INFO', 'INFO'),
                ('WARN', 'WARN'),
                ('ERROR', 'ERROR'),
                ('DEBUG', 'DEBUG'),
              ],
              onChanged: onLevelChanged,
            ),

            const SizedBox(height: AppSpacing.s12),

            // Time range (label only — no backend hook yet)
            _RailDropdown<String>(
              label: 'Time Range',
              value: timeRange,
              items: const [
                ('Last 24 Hours', 'Last 24 Hours'),
                ('Last Hour', 'Last Hour'),
                ('Last 7 Days', 'Last 7 Days'),
              ],
              onChanged: onTimeRangeChanged,
            ),

            const SizedBox(height: AppSpacing.s12),

            // Search
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Search',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDim,
                  ),
                ),
                const SizedBox(height: 5),
                TextField(
                  controller: searchCtrl,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.textBody,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search in logs…',
                    hintStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textDim,
                    ),
                    filled: true,
                    fillColor: const Color(0x08FFFFFF),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                      borderSide:
                          const BorderSide(color: Color(0x0FFFFFFF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                      borderSide:
                          const BorderSide(color: AppColors.violet),
                    ),
                    isDense: true,
                    suffixIcon: const Icon(
                      Icons.search,
                      size: 14,
                      color: AppColors.textDim,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.s12),

            FluxButton(
              variant: FluxButtonVariant.primary,
              fullWidth: true,
              onPressed: onApply,
              child: const Text('Apply Filters'),
            ),

            const SizedBox(height: AppSpacing.s20),

            // Logs summary
            const Text(
              'Logs Summary',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textBright,
              ),
            ),
            const SizedBox(height: AppSpacing.s10),
            for (final entry in [
              ('Info', 'INFO', AppColors.blue),
              ('Warning', 'WARN', AppColors.amber),
              ('Error', 'ERROR', AppColors.red),
              ('Debug', 'DEBUG', AppColors.textMutedV2),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: entry.$3,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.$1,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.textBody,
                        ),
                      ),
                    ),
                    Text(
                      '${counts[entry.$2] ?? 0}',
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        color: AppColors.textMutedV2,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0x0DFFFFFF)),
                ),
              ),
              padding: const EdgeInsets.only(top: 8),
              margin: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Logs',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textBody,
                    ),
                  ),
                  Text(
                    '$totalCount',
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.violet,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.s20),

            // Quick actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textBright,
              ),
            ),
            const SizedBox(height: AppSpacing.s10),
            for (final action in [
              (Icons.folder_open_outlined, 'Open Log Folder',
                  'View log files in explorer'),
              (Icons.download_outlined, 'Export Current Logs',
                  'Export logs as .zip file'),
              (Icons.delete_outline, 'Clear Old Logs',
                  'Remove logs older than 7 days'),
            ])
              Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.all(AppSpacing.s10),
                decoration: BoxDecoration(
                  color: const Color(0x08FFFFFF),
                  borderRadius: BorderRadius.circular(7),
                  border: const Border.fromBorderSide(
                      BorderSide(color: Color(0x0AFFFFFF))),
                ),
                child: Row(
                  children: [
                    Icon(action.$1, size: 13, color: AppColors.textMutedV2),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            action.$2,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textBody,
                            ),
                          ),
                          Text(
                            action.$3,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.5,
                              color: AppColors.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 11, color: AppColors.textFaint),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Rail dropdown helper ───────────────────────────────────────────────────────

class _RailDropdown<T> extends StatelessWidget {
  const _RailDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textDim,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0x08FFFFFF),
            borderRadius: BorderRadius.circular(7),
            border: const Border.fromBorderSide(
                BorderSide(color: Color(0x0FFFFFFF))),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1A1730),
              iconEnabledColor: AppColors.textDim,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.textBody,
              ),
              items: items
                  .map((t) => DropdownMenuItem<T>(
                        value: t.$1,
                        child: Text(t.$2),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ── Placeholder tab content ────────────────────────────────────────────────────

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.label, required this.subtitle});
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return FluxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.h2),
          const SizedBox(height: 8),
          Text(subtitle, style: AppTypography.bodySmall),
        ],
      ),
    );
  }
}
