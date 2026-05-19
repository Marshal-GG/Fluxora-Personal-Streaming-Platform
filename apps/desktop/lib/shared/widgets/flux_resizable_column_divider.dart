/// Shared 9-px resizable column divider for desktop data tables.
///
/// Established by the folder browser ([library_files_screen.dart]) +
/// adopted by the Clients screen ([clients_screen.dart]).  Both
/// callers needed the same visual + drag behaviour against their own
/// column enum + width storage — this widget is the column-agnostic
/// extraction.
///
/// **Visual:**
/// - 9-px outer slot ([kFluxColumnDividerWidth]) sized identically
///   between header + body so header dividers + body cells line up
///   pixel-for-pixel.
/// - 1-px hairline ([AppColors.borderSubtle]) centered vertically
///   in a 16-px tall band at rest.
/// - Thickens to a 2-px violet ([AppColors.violet]) line on hover or
///   while the operator is dragging.
/// - Cursor flips to [SystemMouseCursors.resizeLeftRight] on hover.
///
/// **Behaviour:**
/// - Horizontal drag widens the column on the LEFT (Windows Explorer
///   convention).
/// - Width math: `newWidth = dragStartWidth + details.localPosition.dx`,
///   clamped by the caller's `writeWidth` implementation.
/// - State is owned by the caller — this widget reads via
///   [readWidth] and writes via [writeWidth].  The caller is
///   responsible for the backing store (module-level Map, SecureStorage
///   blob, a ChangeNotifier, etc) and for triggering rebuilds when
///   widths change (typically a `ValueNotifier<int>` ticked from inside
///   [writeWidth]).
///
/// **Generic T** is the caller's column-identifier type — usually an
/// enum (`BrowseColumn`, `ClientColumn`) but any value-equal type
/// works.
library;

import 'package:flutter/material.dart';

import 'package:fluxora_core/constants/app_colors.dart';

/// Outer width of every header / body column divider — fixed so
/// header dividers + body cells line up pixel-for-pixel across all
/// callers.  9 px is the Windows Explorer convention for a divider
/// drag handle.
const double kFluxColumnDividerWidth = 9;

class FluxResizableColumnDivider<T> extends StatefulWidget {
  const FluxResizableColumnDivider({
    super.key,
    required this.leftColumn,
    required this.readWidth,
    required this.writeWidth,
  });

  /// Caller's identifier for the column whose RIGHT edge this divider
  /// draws.  A horizontal drag widens THIS column.
  final T leftColumn;

  /// Read the current width of [column] from the caller's storage.
  /// Called once on drag start to anchor the gesture.
  final double Function(T column) readWidth;

  /// Write a new width for [column].  Caller is responsible for any
  /// clamping ([readWidth] should return clamped values too so the
  /// next drag re-anchors correctly), persistence, and notifying
  /// listeners so dependent widgets rebuild.
  final void Function(T column, double width) writeWidth;

  @override
  State<FluxResizableColumnDivider<T>> createState() =>
      _FluxResizableColumnDividerState<T>();
}

class _FluxResizableColumnDividerState<T>
    extends State<FluxResizableColumnDivider<T>> {
  double? _dragStartWidth;
  bool _hover = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final highlight = _hover || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      // Guard: only setState when the hover state flips.  Sibling
      // rebuilds (e.g. background poll cascading through a stat tile)
      // can otherwise fire redundant onEnter / onExit and churn the
      // build phase for nothing.
      onEnter: (_) {
        if (!_hover) setState(() => _hover = true);
      },
      onExit: (_) {
        if (_hover) setState(() => _hover = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {
          _dragStartWidth = widget.readWidth(widget.leftColumn);
          setState(() => _dragging = true);
        },
        onHorizontalDragUpdate: (details) {
          final start = _dragStartWidth;
          if (start == null) return;
          widget.writeWidth(
            widget.leftColumn,
            start + details.localPosition.dx,
          );
        },
        onHorizontalDragEnd: (_) {
          _dragStartWidth = null;
          setState(() => _dragging = false);
        },
        child: SizedBox(
          width: kFluxColumnDividerWidth,
          height: 16,
          child: Center(
            child: Container(
              width: highlight ? 2 : 1,
              height: 16,
              color: highlight ? AppColors.violet : AppColors.borderSubtle,
            ),
          ),
        ),
      ),
    );
  }
}

/// Invisible 9-px body-row counterpart to [FluxResizableColumnDivider].
///
/// Reserves the same horizontal slot the header divider occupies so
/// body cells line up pixel-for-pixel with the header's resize
/// handles.  Paints nothing — body rows in the flat-list pattern
/// don't want visible inter-column rules (see DESIGN.md "Flat data
/// list rows").
class FluxColumnSpacer extends StatelessWidget {
  const FluxColumnSpacer({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: kFluxColumnDividerWidth, height: 16);
  }
}
