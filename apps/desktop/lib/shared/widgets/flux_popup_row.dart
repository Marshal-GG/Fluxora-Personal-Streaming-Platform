/// Single row inside a glass popup — leading icon + label + optional
/// trailing widget, with hover + active background tints that match
/// the desktop control panel's filter / sort / picker popups.
///
/// Established for the folder browser's Filter dropdown
/// ([library_files_screen.dart]) for both single-select kind rows
/// (trailing = check mark when active, blank otherwise) and binary
/// toggle rows (trailing = checkbox glyph that flips on/off).
/// Generalised here so future popups (Sort menus, view-mode pickers,
/// column togglers) share the same row chrome.
///
/// **States:**
///
/// - **Rest:** transparent fill, `textMutedV2` foreground, regular weight.
/// - **Hover:** 3 % white fill, `textBody` foreground.
/// - **Active:** violet-tint fill (`0x1AA855F7`) + `violetSoft`
///   foreground + bold label weight.  "Active" semantics are
///   caller-defined — single-select rows are active when the row's
///   value matches the popup's current selection; toggle rows are
///   active when the binary state is on.
///
/// **Trailing slot:** caller-provided via [trailingBuilder] so the
/// trailing glyph can adapt to the row's foreground colour (which
/// itself depends on hover + active state).  Returning `null` leaves
/// the trailing slot blank.  See the named constructors below for
/// the two standard treatments.
library;

import 'package:flutter/material.dart';

import 'package:fluxora_core/constants/app_colors.dart';

/// Builder for the trailing widget.  Receives the row's effective
/// foreground colour so the glyph can match the row's hover/active
/// state without the caller re-deriving it.
typedef FluxPopupRowTrailingBuilder = Widget? Function(
  BuildContext context,
  Color foreground,
);

class FluxPopupRow extends StatefulWidget {
  const FluxPopupRow({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.trailingBuilder,
  });

  /// Single-select row treatment — trailing check mark appears only
  /// when [isActive], otherwise blank 14-px space holds the column
  /// width steady so the popup doesn't shift as the selection moves.
  /// Use for picker / radio-group popups (Filter kind, Sort key, etc.).
  FluxPopupRow.singleSelect({
    Key? key,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) : this(
          key: key,
          icon: icon,
          label: label,
          isActive: isActive,
          onTap: onTap,
          trailingBuilder: (_, _) => isActive
              ? const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: AppColors.violetSoft,
                )
              : const SizedBox(width: 14),
        );

  /// Binary-toggle row treatment — trailing checkbox glyph that flips
  /// between `check_box_rounded` and `check_box_outline_blank_rounded`
  /// on [isActive], colour-matched to the row's foreground.  Use for
  /// boolean preferences (Indexed only, Show hidden, etc.).
  FluxPopupRow.toggle({
    Key? key,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) : this(
          key: key,
          icon: icon,
          label: label,
          isActive: isActive,
          onTap: onTap,
          trailingBuilder: (_, fg) => Icon(
            isActive
                ? Icons.check_box_rounded
                : Icons.check_box_outline_blank_rounded,
            size: 14,
            color: fg,
          ),
        );

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final FluxPopupRowTrailingBuilder? trailingBuilder;

  @override
  State<FluxPopupRow> createState() => _FluxPopupRowState();
}

class _FluxPopupRowState extends State<FluxPopupRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.isActive
        ? AppColors.violetSoft
        : (_hover ? AppColors.textBody : AppColors.textMutedV2);
    final bg = widget.isActive
        ? const Color(0x1AA855F7)
        : (_hover ? const Color(0x08FFFFFF) : Colors.transparent);

    final trailing = widget.trailingBuilder?.call(context, fg);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (!_hover) setState(() => _hover = true);
      },
      onExit: (_) {
        if (_hover) setState(() => _hover = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(widget.icon, size: 14, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight:
                        widget.isActive ? FontWeight.w600 : FontWeight.w500,
                    color: fg,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
