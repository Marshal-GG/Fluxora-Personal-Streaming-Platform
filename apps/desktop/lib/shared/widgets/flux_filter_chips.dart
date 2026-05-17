/// FluxFilterChips — shared rounded-pill chip row.
///
/// Pixel-matches the design used on the Library page's type-filter
/// strip.  Lifted out of `library_screen.dart` so the folder browser
/// (and any future surface that needs a horizontal kind-filter row)
/// can re-use the same visual without forking the widget.
///
/// Two consumption modes:
///   - Single-select (default) — every chip is mutually exclusive.
///     Pass `activeId` + `onChange`.  Matches a kind picker like
///     `All / Folders / Videos / …`.
///   - Independent toggles — pass `activeIds` (a set) + `onToggle`
///     instead.  Each chip flips in/out without affecting the others.
///     Convenient for the "Indexed only" affordance.
///
/// Authors can render a thin vertical divider between sub-groups by
/// dropping a `FluxFilterChipsDivider` widget into the `extra`
/// trailing slot (see [LibraryBrowseFilterChips]).
library;

import 'package:flutter/material.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_spacing.dart';

import 'package:fluxora_desktop/shared/widgets/flux_tab_bar.dart' show FluxTab;

/// Horizontal `Wrap` of rounded-pill filter chips.
class FluxFilterChips extends StatelessWidget {
  /// Single-select constructor — exactly one chip can be active at a
  /// time.  `activeId` matches one of the `tabs[].id`s; `onChange`
  /// fires on every tap (including taps on the already-active chip).
  const FluxFilterChips({
    super.key,
    required this.tabs,
    required this.activeId,
    required ValueChanged<String> this.onChange,
    this.trailing,
  })  : activeIds = null,
        onToggle = null;

  /// Multi-select constructor — each chip flips independently in/out
  /// of `activeIds`.  Useful for combining filters (e.g. "Videos"
  /// kind + "Indexed only" stacked toggle).
  const FluxFilterChips.multi({
    super.key,
    required this.tabs,
    required Set<String> this.activeIds,
    required ValueChanged<String> this.onToggle,
    this.trailing,
  })  : activeId = null,
        onChange = null;

  final List<FluxTab> tabs;
  final String? activeId;
  final ValueChanged<String>? onChange;

  final Set<String>? activeIds;
  final ValueChanged<String>? onToggle;

  /// Optional trailing widgets — appended after the chip row inside
  /// the same `Wrap`.  Typical use: a `FluxFilterChipsDivider` + an
  /// independent toggle chip group.
  final List<Widget>? trailing;

  bool _isActive(FluxTab tab) {
    if (activeIds != null) return activeIds!.contains(tab.id);
    return tab.id == activeId;
  }

  void _onTap(FluxTab tab) {
    if (onToggle != null) {
      onToggle!(tab.id);
    } else if (onChange != null) {
      onChange!(tab.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
      child: Wrap(
        spacing: AppSpacing.s6,
        runSpacing: AppSpacing.s6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final tab in tabs)
            FluxFilterChip(
              tab: tab,
              isActive: _isActive(tab),
              onTap: () => _onTap(tab),
            ),
          ...?trailing,
        ],
      ),
    );
  }
}

/// Single rounded-pill chip — public so callers can compose custom
/// chip groups (e.g. a single independent toggle next to a single-
/// select group, with a divider in between).
class FluxFilterChip extends StatefulWidget {
  const FluxFilterChip({
    super.key,
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  final FluxTab tab;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<FluxFilterChip> createState() => _FluxFilterChipState();
}

class _FluxFilterChipState extends State<FluxFilterChip> {
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s10,
            vertical: AppSpacing.s6,
          ),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.tab.icon != null) ...[
                Icon(widget.tab.icon, size: 12, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                widget.tab.label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight:
                      widget.isActive ? FontWeight.w600 : FontWeight.w500,
                  color: fg,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin 1×16 vertical separator for sub-grouping chip rows (e.g. the
/// kind-filter group vs. the independent "Indexed only" toggle).
class FluxFilterChipsDivider extends StatelessWidget {
  const FluxFilterChipsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
      color: const Color(0x14FFFFFF),
    );
  }
}
