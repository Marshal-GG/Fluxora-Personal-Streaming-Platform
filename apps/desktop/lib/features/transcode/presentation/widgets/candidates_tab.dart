import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/widgets/flux_button.dart';
import 'package:fluxora_core/widgets/flux_chip.dart';

import 'package:fluxora_desktop/features/transcode/domain/entities/transcode_candidate.dart';
import 'package:fluxora_desktop/features/transcode/presentation/cubit/transcode_cubit.dart';
import 'package:fluxora_desktop/features/transcode/presentation/cubit/transcode_state.dart';
import 'package:fluxora_desktop/shared/widgets/flux_card.dart';

/// Sortable columns in the candidates table.
enum _SortColumn { name, size, output }

/// Candidates tab — flat sortable table of files needing pre-transcode.
///
/// Replaces the earlier folder-grouped tree view.  Surface mirrors the
/// 2026-05-15 concept-design mockup:
///   - Sortable column headers (Name / Size / Estimated Save).
///   - Per-row Convert button for one-at-a-time conversions.
///   - Bulk-select via header checkbox + per-row checkboxes, with the
///     existing `_EstimateFooter` showing totals when the selection is
///     non-empty.
class CandidatesTab extends StatelessWidget {
  const CandidatesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscodeCubit, TranscodeState>(
      builder: (context, state) {
        if (state is TranscodeFailure) {
          return _FailureBox(message: state.message);
        }
        if (state is! TranscodeLoaded) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.s28),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (state.candidates.isEmpty) {
          return const _EmptyBox(
            title: 'No candidates',
            body:
                'Every AV1 / VP9 file in the library already has a transcoded sidecar, '
                "or you haven't scanned a library that contains those codecs yet.",
          );
        }
        return _CandidatesView(state: state);
      },
    );
  }
}

class _CandidatesView extends StatefulWidget {
  const _CandidatesView({required this.state});

  final TranscodeLoaded state;

  @override
  State<_CandidatesView> createState() => _CandidatesViewState();
}

/// Row-count options for the per-page selector in the candidates footer.
const List<int> _rowsPerPageOptions = [10, 25, 50, 100];

class _CandidatesViewState extends State<_CandidatesView> {
  _SortColumn _sortColumn = _SortColumn.name;
  bool _ascending = true;

  int _currentPage = 0; // 0-indexed
  int _rowsPerPage = 10;

  void _onSort(_SortColumn col) {
    setState(() {
      if (_sortColumn == col) {
        _ascending = !_ascending;
      } else {
        _sortColumn = col;
        _ascending = true;
      }
      // Page numbering refers to the sorted order; reset to the first
      // page on a sort change so the operator doesn't end up looking at
      // an arbitrary middle slice of the new ordering.
      _currentPage = 0;
    });
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
  }

  void _onRowsPerPageChanged(int rows) {
    setState(() {
      _rowsPerPage = rows;
      _currentPage = 0;
    });
  }

  List<TranscodeCandidate> _sorted(List<TranscodeCandidate> candidates) {
    final list = List<TranscodeCandidate>.from(candidates);
    int cmp(TranscodeCandidate a, TranscodeCandidate b) {
      switch (_sortColumn) {
        case _SortColumn.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _SortColumn.size:
          return a.sizeBytes.compareTo(b.sizeBytes);
        case _SortColumn.output:
          return a.estOutputSizeBytes.compareTo(b.estOutputSizeBytes);
      }
    }

    list.sort((a, b) => _ascending ? cmp(a, b) : cmp(b, a));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TranscodeCubit>();
    final candidates = _sorted(widget.state.candidates);
    final selectedCount = widget.state.selectedFileIds.length;
    final allSelected =
        selectedCount == candidates.length && selectedCount > 0;
    final someSelected = selectedCount > 0 && !allSelected;

    // Slice the sorted list to just the current page.  Note: `selectAll`
    // / `clearSelection` still operate on the full candidates list, so
    // the header checkbox's tristate correctly reflects whole-list state
    // even when only a single page is visible.
    final pageCount = candidates.isEmpty
        ? 1
        : (candidates.length / _rowsPerPage).ceil();
    final safePage = _currentPage.clamp(0, pageCount - 1);
    final start = safePage * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, candidates.length);
    final pageCandidates =
        candidates.isEmpty ? <TranscodeCandidate>[] : candidates.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Table ──────────────────────────────────────────────────────
        FluxCard(
          padding: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TableHeader(
                sortColumn: _sortColumn,
                ascending: _ascending,
                onSort: _onSort,
                allSelected: allSelected,
                tristate: someSelected,
                onToggleSelectAll: () {
                  if (allSelected) {
                    cubit.clearSelection();
                  } else {
                    cubit.selectAll();
                  }
                },
              ),
              for (final candidate in pageCandidates)
                _CandidateRow(
                  candidate: candidate,
                  selected:
                      widget.state.selectedFileIds.contains(candidate.fileId),
                  busy: widget.state.busyAction,
                  onToggle: () => cubit.toggleSelection(candidate.fileId),
                  onConvert: () =>
                      cubit.startSingleTranscode(candidate.fileId),
                ),
            ],
          ),
        ),

        // ── Pagination footer ──────────────────────────────────────────
        const SizedBox(height: AppSpacing.s14),
        _PaginationFooter(
          totalItems: candidates.length,
          selectedCount: selectedCount,
          currentPage: safePage,
          pageCount: pageCount,
          rowsPerPage: _rowsPerPage,
          onPageChanged: _onPageChanged,
          onRowsPerPageChanged: _onRowsPerPageChanged,
        ),
        // Bulk-convert summary + Start-transcode action live in the
        // right-side `_TranscodeRightPanel`.
      ],
    );
  }
}

// ── Pagination footer ────────────────────────────────────────────────────────

class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({
    required this.totalItems,
    required this.selectedCount,
    required this.currentPage,
    required this.pageCount,
    required this.rowsPerPage,
    required this.onPageChanged,
    required this.onRowsPerPageChanged,
  });

  final int totalItems;
  final int selectedCount;
  final int currentPage;
  final int pageCount;
  final int rowsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onRowsPerPageChanged;

  @override
  Widget build(BuildContext context) {
    final countText = '$totalItems candidate'
        '${totalItems == 1 ? '' : 's'}'
        '${selectedCount > 0 ? ' · $selectedCount selected' : ''}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      child: Row(
        children: [
          Text(
            countText,
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textMutedV2),
          ),
          const Spacer(),
          _PageNav(
            currentPage: currentPage,
            pageCount: pageCount,
            onPageChanged: onPageChanged,
          ),
          const Spacer(),
          _RowsPerPageDropdown(
            value: rowsPerPage,
            onChanged: onRowsPerPageChanged,
          ),
        ],
      ),
    );
  }
}

class _PageNav extends StatelessWidget {
  const _PageNav({
    required this.currentPage,
    required this.pageCount,
    required this.onPageChanged,
  });

  final int currentPage;
  final int pageCount;
  final ValueChanged<int> onPageChanged;

  /// Build the displayed page list with ellipsis-collapse for large
  /// counts.  Layout matches the common "1 … 4 5 6 … 10" pattern.
  List<_PageEntry> _visiblePages() {
    if (pageCount <= 7) {
      return [for (int i = 0; i < pageCount; i++) _PageEntry.page(i)];
    }
    final out = <_PageEntry>[];
    out.add(const _PageEntry.page(0));
    final start = (currentPage - 1).clamp(1, pageCount - 4);
    final end = (start + 2).clamp(start, pageCount - 2);
    if (start > 1) out.add(_PageEntry.ellipsis);
    for (int i = start; i <= end; i++) {
      out.add(_PageEntry.page(i));
    }
    if (end < pageCount - 2) out.add(_PageEntry.ellipsis);
    out.add(_PageEntry.page(pageCount - 1));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PageArrow(
          icon: Icons.chevron_left_rounded,
          enabled: currentPage > 0,
          onTap: () => onPageChanged(currentPage - 1),
        ),
        const SizedBox(width: AppSpacing.s4),
        for (final entry in _visiblePages()) ...[
          if (entry.isEllipsis)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '…',
                style: TextStyle(color: AppColors.textDim),
              ),
            )
          else
            _PageNumberButton(
              page: entry.page,
              isActive: entry.page == currentPage,
              onTap: () => onPageChanged(entry.page),
            ),
          const SizedBox(width: 2),
        ],
        const SizedBox(width: AppSpacing.s2),
        _PageArrow(
          icon: Icons.chevron_right_rounded,
          enabled: currentPage < pageCount - 1,
          onTap: () => onPageChanged(currentPage + 1),
        ),
      ],
    );
  }
}

class _PageEntry {
  const _PageEntry.page(this.page) : isEllipsis = false;
  const _PageEntry._ellipsis()
      : page = -1,
        isEllipsis = true;

  static const _PageEntry ellipsis = _PageEntry._ellipsis();

  final int page;
  final bool isEllipsis;
}

class _PageNumberButton extends StatefulWidget {
  const _PageNumberButton({
    required this.page,
    required this.isActive,
    required this.onTap,
  });

  final int page;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_PageNumberButton> createState() => _PageNumberButtonState();
}

class _PageNumberButtonState extends State<_PageNumberButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color bg = widget.isActive
        ? const Color(0x24A855F7)
        : (_hover ? const Color(0x08FFFFFF) : Colors.transparent);
    final Color border = widget.isActive
        ? const Color(0x4DA855F7)
        : AppColors.borderSubtle;
    final Color fg = widget.isActive
        ? AppColors.violetSoft
        : (_hover ? AppColors.textBody : AppColors.textMutedV2);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(AppRadii.xs),
          ),
          child: Text(
            '${widget.page + 1}',
            style: AppTypography.bodySmall.copyWith(
              color: fg,
              fontWeight:
                  widget.isActive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _PageArrow extends StatefulWidget {
  const _PageArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_PageArrow> createState() => _PageArrowState();
}

class _PageArrowState extends State<_PageArrow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color fg = !widget.enabled
        ? AppColors.textDim
        : (_hover ? AppColors.textBright : AppColors.textBody);
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter:
          widget.enabled ? (_) => setState(() => _hover = true) : null,
      onExit:
          widget.enabled ? (_) => setState(() => _hover = false) : null,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(widget.icon, size: 16, color: fg),
        ),
      ),
    );
  }
}

class _RowsPerPageDropdown extends StatelessWidget {
  const _RowsPerPageDropdown({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Rows per page:',
          style: AppTypography.bodySmall
              .copyWith(color: AppColors.textMutedV2),
        ),
        const SizedBox(width: AppSpacing.s8),
        PopupMenuButton<int>(
          tooltip: 'Rows per page',
          initialValue: value,
          onSelected: onChanged,
          color: AppColors.bgRaised,
          itemBuilder: (ctx) => [
            for (final opt in _rowsPerPageOptions)
              PopupMenuItem<int>(
                value: opt,
                child: Text(
                  '$opt',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textBody),
                ),
              ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderSubtle),
              borderRadius: BorderRadius.circular(AppRadii.xs),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$value',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textBody),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: AppColors.textMutedV2,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Table header ─────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.sortColumn,
    required this.ascending,
    required this.onSort,
    required this.allSelected,
    required this.tristate,
    required this.onToggleSelectAll,
  });

  final _SortColumn sortColumn;
  final bool ascending;
  final ValueChanged<_SortColumn> onSort;
  final bool allSelected;
  final bool tristate;
  final VoidCallback onToggleSelectAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s18,
        vertical: AppSpacing.s12,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggleSelectAll,
            behavior: HitTestBehavior.opaque,
            child: _Checkbox(
              checked: allSelected,
              tristate: tristate,
            ),
          ),
          const SizedBox(width: AppSpacing.s14),
          Expanded(
            child: _SortLabel(
              label: 'Name',
              active: sortColumn == _SortColumn.name,
              ascending: ascending,
              onTap: () => onSort(_SortColumn.name),
            ),
          ),
          SizedBox(
            width: 80,
            child: Align(
              alignment: Alignment.centerRight,
              child: _SortLabel(
                label: 'Size',
                active: sortColumn == _SortColumn.size,
                ascending: ascending,
                onTap: () => onSort(_SortColumn.size),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s14),
          const SizedBox(
            width: 60,
            child: _HeaderLabel(label: 'Codec'),
          ),
          SizedBox(
            width: 90,
            child: Align(
              alignment: Alignment.centerRight,
              child: _SortLabel(
                label: 'Output size',
                active: sortColumn == _SortColumn.output,
                ascending: ascending,
                onTap: () => onSort(_SortColumn.output),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s14),
          const SizedBox(width: 110),
        ],
      ),
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  const _HeaderLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.captionV2.copyWith(
        color: AppColors.textMutedV2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SortLabel extends StatefulWidget {
  const _SortLabel({
    required this.label,
    required this.active,
    required this.ascending,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool ascending;
  final VoidCallback onTap;

  @override
  State<_SortLabel> createState() => _SortLabelState();
}

class _SortLabelState extends State<_SortLabel> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color color = widget.active
        ? AppColors.violetTint
        : (_hover ? AppColors.textBody : AppColors.textMutedV2);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: AppTypography.captionV2.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.active) ...[
              const SizedBox(width: 4),
              Icon(
                widget.ascending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 12,
                color: color,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Single row ───────────────────────────────────────────────────────────────

class _CandidateRow extends StatefulWidget {
  const _CandidateRow({
    required this.candidate,
    required this.selected,
    required this.busy,
    required this.onToggle,
    required this.onConvert,
  });

  final TranscodeCandidate candidate;
  final bool selected;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onConvert;

  @override
  State<_CandidateRow> createState() => _CandidateRowState();
}

class _CandidateRowState extends State<_CandidateRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.candidate;

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        decoration: BoxDecoration(
          color: _hover ? const Color(0x08FFFFFF) : Colors.transparent,
          border: const Border(
            top: BorderSide(color: AppColors.borderSubtle),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s18,
          vertical: AppSpacing.s10,
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: widget.onToggle,
              behavior: HitTestBehavior.opaque,
              child: _Checkbox(checked: widget.selected),
            ),
            const SizedBox(width: AppSpacing.s14),
            Expanded(
              child: Tooltip(
                message: c.path.isEmpty ? c.name : c.path,
                child: Text(
                  c.name,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textBright,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            SizedBox(
              width: 80,
              child: Text(
                _formatBytes(c.sizeBytes),
                textAlign: TextAlign.right,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textBody,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s14),
            SizedBox(
              width: 60,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FluxChip(
                  c.videoCodec.toUpperCase(),
                  color: c.videoCodec == 'av1'
                      ? FluxChipColor.warning
                      : FluxChipColor.info,
                ),
              ),
            ),
            SizedBox(
              width: 90,
              child: Text(
                _formatBytes(c.estOutputSizeBytes),
                textAlign: TextAlign.right,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textBody,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s14),
            SizedBox(
              width: 110,
              child: Align(
                alignment: Alignment.centerRight,
                child: FluxButton(
                  variant: FluxButtonVariant.primary,
                  size: FluxButtonSize.sm,
                  icon: Icons.flash_on_rounded,
                  onPressed: widget.busy ? null : widget.onConvert,
                  child: const Text('Convert'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Self-painted checkbox — the prototype's checkbox primitive isn't
/// shared, so we draw it inline.  Supports tri-state via the `tristate`
/// flag (renders a horizontal bar instead of a check mark when some-but-
/// not-all rows are selected).
class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.checked, this.tristate = false});

  final bool checked;
  final bool tristate;

  @override
  Widget build(BuildContext context) {
    final bool filled = checked || tristate;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: filled ? AppColors.violet : const Color(0x08FFFFFF),
        border: Border.all(
          color: filled ? AppColors.violet : AppColors.borderHover,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: tristate
          ? const Center(
              child: SizedBox(
                width: 8,
                height: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.white),
                ),
              ),
            )
          : (checked
              ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
              : null),
    );
  }
}

// ── Empty / failure boxes ────────────────────────────────────────────────────

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return FluxCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s14,
          vertical: AppSpacing.s28,
        ),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.emerald,
              size: 32,
            ),
            const SizedBox(height: AppSpacing.s10),
            Text(
              title,
              style: AppTypography.body.copyWith(
                color: AppColors.textBright,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMutedV2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailureBox extends StatelessWidget {
  const _FailureBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return FluxCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s14,
          vertical: AppSpacing.s24,
        ),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.red,
              size: 28,
            ),
            const SizedBox(height: AppSpacing.s10),
            Text(
              'Failed to load candidates',
              style: AppTypography.body.copyWith(
                color: AppColors.textBright,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMutedV2,
              ),
            ),
            const SizedBox(height: AppSpacing.s14),
            FluxButton(
              variant: FluxButtonVariant.outline,
              size: FluxButtonSize.sm,
              icon: Icons.refresh_rounded,
              onPressed: () =>
                  context.read<TranscodeCubit>().loadCandidates(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Format bytes with three significant figures, switching between units.
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  double v = bytes / 1024;
  int i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
}
