/// Toolbar pill button — rounded chip with an optional sticky popup
/// anchored beneath via `OverlayPortal` + `CompositedTransformFollower`.
///
/// Established for the folder browser's Filter dropdown
/// ([library_files_screen.dart]); generalised here so other desktop
/// toolbars (Sessions, Logs, Transcoding, future Sort menus) get the
/// same chrome + behaviour without duplicating the shell.
///
/// **Shell:** 26 px height, fully-rounded radius, 12 px horizontal
/// padding, leading icon + label + trailing caret.  Three visual states:
///
/// - **Rest:** `borderSubtle` border, transparent fill,
///   `textMutedV2` foreground.
/// - **Hover:** 3 % white fill, `textBody` foreground.
/// - **Active:** violet-tint fill (`0x24A855F7`) + violet border
///   (`0x4DA855F7`) + `violetSoft` foreground + bold label weight.
///   Active = caller-provided flag (e.g. "filter has a non-default
///   selection").
///
/// **Popup:** caller-provided builder, mounted via `OverlayPortal`
/// in the root overlay so it escapes the toolbar's clip + Stack
/// z-order.  Anchoring direction is configurable — folder-browser
/// Filter sits on the RIGHT side of the toolbar so the popup
/// right-aligns to the trigger (`targetAnchor: bottomRight,
/// followerAnchor: topRight`) so it extends DOWN+LEFT and stays
/// on-screen.  Tap-outside dismissal is the popup builder's
/// responsibility — usually wraps the popup body in a `TapRegion`.
library;

import 'package:flutter/material.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_spacing.dart';

/// Builder for the popup body.  Receives the `LayerLink` to follow +
/// a `dismiss` callback the popup should fire from `TapRegion` /
/// programmatic close paths.
typedef FluxToolbarPillPopupBuilder = Widget Function(
  BuildContext context,
  LayerLink link,
  VoidCallback dismiss,
);

class FluxToolbarPillButton extends StatefulWidget {
  const FluxToolbarPillButton({
    super.key,
    required this.label,
    required this.leadingIcon,
    this.trailingIcon = Icons.arrow_drop_down_rounded,
    required this.isActive,
    this.onTap,
    this.popupBuilder,
    this.height = 26,
    this.borderRadius,
  });

  /// Visible label.  Caller is responsible for the summary string
  /// (e.g. `'Filter'` at rest, `'Filter: Videos · Indexed'` when active).
  final String label;

  /// Leading icon (12 px).  E.g. `Icons.filter_list_rounded`.
  final IconData leadingIcon;

  /// Trailing icon (14 px) — defaults to a caret.  Pass `null` via
  /// `Icons.expand_more_rounded`-equivalent if a different glyph fits.
  final IconData trailingIcon;

  /// `true` when the caller's underlying state has a non-default value
  /// — flips the pill into the violet-tint active treatment.
  final bool isActive;

  /// Plain-tap handler.  When `popupBuilder` is also provided, `onTap`
  /// fires AFTER the popup toggles — most callers leave this null and
  /// let the popup own the interaction.
  final VoidCallback? onTap;

  /// Builds the floating popup body.  When provided, tapping the
  /// trigger toggles the popup via `OverlayPortal`.  Callers should
  /// anchor the returned widget via `CompositedTransformFollower(link:
  /// link, ...)` and wrap dismissal in `TapRegion(onTapOutside: dismiss)`.
  final FluxToolbarPillPopupBuilder? popupBuilder;

  /// Button height.  Defaults to 26 px (tuned to read as a peer of the
  /// 28 px toolbar icon buttons in the folder browser).  Pass a larger
  /// value to match a search-box-style data toolbar.
  final double height;

  /// Corner radius.  Defaults to a fully-rounded pill (`height / 2`)
  /// matching the original folder-browser Filter chip.  Pass a small
  /// fixed radius (e.g. `BorderRadius.circular(7)`) to switch to a
  /// rounded-rectangle "input chip" treatment that matches a search-box
  /// shape on data-toolbar screens (Clients, Sessions, Logs).
  final BorderRadius? borderRadius;

  @override
  State<FluxToolbarPillButton> createState() => _FluxToolbarPillButtonState();
}

class _FluxToolbarPillButtonState extends State<FluxToolbarPillButton> {
  final LayerLink _link = LayerLink();
  final OverlayPortalController _popup = OverlayPortalController();
  bool _hover = false;

  void _toggle() {
    if (widget.popupBuilder != null) {
      if (_popup.isShowing) {
        _popup.hide();
      } else {
        _popup.show();
      }
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.isActive
        ? AppColors.violetSoft
        : (_hover ? AppColors.textBody : AppColors.textMutedV2);
    final bg = widget.isActive
        ? const Color(0x24A855F7)
        : (_hover ? const Color(0x08FFFFFF) : Colors.transparent);
    final border = widget.isActive
        ? const Color(0x4DA855F7)
        : AppColors.borderSubtle;
    final shape = widget.borderRadius ??
        BorderRadius.circular(widget.height / 2);

    final trigger = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (!_hover) setState(() => _hover = true);
      },
      onExit: (_) {
        if (_hover) setState(() => _hover = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: shape,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.leadingIcon, size: 12, color: fg),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  fontWeight:
                      widget.isActive ? FontWeight.w600 : FontWeight.w500,
                  color: fg,
                ),
              ),
              const SizedBox(width: 4),
              Icon(widget.trailingIcon, size: 14, color: fg),
            ],
          ),
        ),
      ),
    );

    if (widget.popupBuilder == null) return trigger;

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _popup,
        overlayChildBuilder: (_) =>
            widget.popupBuilder!(context, _link, _popup.hide),
        child: trigger,
      ),
    );
  }
}
