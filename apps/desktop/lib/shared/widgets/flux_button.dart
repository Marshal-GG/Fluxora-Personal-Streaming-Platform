/// FluxButton — primary interactive control primitive.
///
/// Pixel-matches `Button` in
/// `docs/11_design/desktop_prototype/app/components/primitives.jsx` lines 42–64.
///
/// Supports six visual variants ([FluxButtonVariant]) and three sizes
/// ([FluxButtonSize]). Hover state is animated over 150 ms; the cursor
/// switches to a pointer when enabled. No Material ripple is used.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_gradients.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_shadows.dart';

/// Visual style of a [FluxButton].
enum FluxButtonVariant {
  /// Purple gradient CTA — [AppGradients.brand] fill with glow shadow.
  primary,

  /// Translucent white surface — subtle background, white-tinted border.
  secondary,

  /// Fully transparent — no visible background or border at rest.
  ghost,

  /// Transparent with a violet border — used for secondary CTAs.
  outline,

  /// Red-tinted destructive action.
  danger,

  /// Green-tinted confirmation action.
  success,
}

/// Vertical and horizontal footprint of a [FluxButton].
enum FluxButtonSize {
  /// `padding: 6/12`, font 12 px, icons 13 px.
  sm,

  /// `padding: 9/16`, font 13 px, icons 15 px. Default.
  md,

  /// `padding: 12/22`, font 14 px, icons 15 px.
  lg,
}

/// A custom button widget that pixel-matches the prototype `Button` primitive.
///
/// Deliberately avoids [ElevatedButton], [OutlinedButton], and Material ripple.
/// Hover is implemented via [MouseRegion] + [setState]; tap via [GestureDetector].
class FluxButton extends StatefulWidget {
  const FluxButton({
    super.key,
    required this.child,
    this.onPressed,
    this.variant = FluxButtonVariant.primary,
    this.size = FluxButtonSize.md,
    this.icon,
    this.iconRight,
    this.fullWidth = false,
  });

  /// The label (usually a [Text]) rendered inside the button.
  final Widget child;

  /// Callback fired on tap. When `null` the button is disabled (opacity 0.5).
  final VoidCallback? onPressed;

  /// Visual style. Defaults to [FluxButtonVariant.primary].
  final FluxButtonVariant variant;

  /// Size preset. Defaults to [FluxButtonSize.md].
  final FluxButtonSize size;

  /// Optional leading icon.
  final IconData? icon;

  /// Optional trailing icon.
  final IconData? iconRight;

  /// When `true` the button stretches to fill its parent's width.
  final bool fullWidth;

  @override
  State<FluxButton> createState() => _FluxButtonState();
}

class _FluxButtonState extends State<FluxButton> {
  bool _hovered = false;

  // ── Size tokens ───────────────────────────────────────────────────────────

  EdgeInsets get _padding => switch (widget.size) {
        FluxButtonSize.sm => const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        FluxButtonSize.md => const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        FluxButtonSize.lg => const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      };

  double get _fontSize => switch (widget.size) {
        FluxButtonSize.sm => 12,
        FluxButtonSize.md => 13,
        FluxButtonSize.lg => 14,
      };

  double get _iconSize => widget.size == FluxButtonSize.sm ? 13 : 15;

  // ── Variant tokens ────────────────────────────────────────────────────────

  /// Base background colour for non-gradient variants.
  Color? get _bgColor => switch (widget.variant) {
        FluxButtonVariant.primary => null, // uses gradient
        FluxButtonVariant.secondary => const Color(0x0AFFFFFF), // rgba(255,255,255,0.04)
        FluxButtonVariant.ghost => Colors.transparent,
        FluxButtonVariant.outline => Colors.transparent,
        FluxButtonVariant.danger => const Color(0x1AEF4444),
        FluxButtonVariant.success => const Color(0x1F10B981),
      };

  /// Hover overlay colour layered on top of the base.
  Color get _hoverOverlay => switch (widget.variant) {
        FluxButtonVariant.primary => const Color(0x14FFFFFF),
        FluxButtonVariant.secondary => const Color(0x14FFFFFF),
        FluxButtonVariant.ghost => const Color(0x0AFFFFFF),
        FluxButtonVariant.outline => const Color(0x0AA855F7),
        FluxButtonVariant.danger => const Color(0x14EF4444),
        FluxButtonVariant.success => const Color(0x1410B981),
      };

  /// Border colour (null = no border).
  Color? get _borderColor => switch (widget.variant) {
        FluxButtonVariant.primary => null,
        FluxButtonVariant.secondary => const Color(0x14FFFFFF), // rgba(255,255,255,0.08)
        FluxButtonVariant.ghost => Colors.transparent,
        FluxButtonVariant.outline => AppColors.borderHover, // rgba(168,85,247,0.4)
        FluxButtonVariant.danger => const Color(0x4DEF4444), // rgba(239,68,68,0.3)
        FluxButtonVariant.success => const Color(0x4D10B981), // rgba(16,185,129,0.3)
      };

  /// Foreground (icon + text) colour.
  Color get _fgColor => switch (widget.variant) {
        FluxButtonVariant.primary => Colors.white,
        FluxButtonVariant.secondary => AppColors.textBody,
        FluxButtonVariant.ghost => AppColors.textMutedV2,
        FluxButtonVariant.outline => AppColors.violetTint,
        FluxButtonVariant.danger => const Color(0xFFF87171),
        FluxButtonVariant.success => const Color(0xFF34D399),
      };

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    final bool isPrimary = widget.variant == FluxButtonVariant.primary;

    // Resolve effective background: gradient variants handled via decoration,
    // solid variants compose base + optional hover overlay.
    final Color? effectiveBg = !isPrimary && _hovered && enabled
        ? Color.alphaBlend(_hoverOverlay, _bgColor ?? Colors.transparent)
        : _bgColor;

    final BoxDecoration decoration = isPrimary
        ? BoxDecoration(
            gradient: enabled ? AppGradients.brand : null,
            color: enabled ? null : const Color(0xFF6B5B95),
            boxShadow: (enabled && !_hovered) ? AppShadows.buttonGlow : null,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          )
        : BoxDecoration(
            color: effectiveBg,
            border: _borderColor != null
                ? Border.all(color: _borderColor!, width: 1)
                : null,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          );

    // Stack a hover tint over primary gradient (gradient itself can't animate).
    Widget inner = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: _padding,
      decoration: decoration,
      child: Row(
        mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: _iconSize, color: _fgColor),
            const SizedBox(width: 8),
          ],
          DefaultTextStyle.merge(
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: _fontSize,
              fontWeight: FontWeight.w600,
              color: _fgColor,
              height: 1,
            ),
            child: widget.child,
          ),
          if (widget.iconRight != null) ...[
            const SizedBox(width: 8),
            Icon(widget.iconRight, size: _iconSize, color: _fgColor),
          ],
        ],
      ),
    );

    // For the primary variant, overlay the hover tint on top of the gradient
    // via a Stack + ClipRRect (gradient itself cannot be animated cheaply).
    if (isPrimary && enabled) {
      inner = ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Stack(
          children: [
            inner,
            if (_hovered)
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  color: _hoverOverlay,
                ),
              ),
          ],
        ),
      );
    }

    Widget result = Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
        onExit: enabled ? (_) => setState(() => _hovered = false) : null,
        child: GestureDetector(
          onTap: widget.onPressed,
          behavior: HitTestBehavior.opaque,
          child: inner,
        ),
      ),
    );

    if (widget.fullWidth) {
      result = SizedBox(width: double.infinity, child: result);
    }

    return result;
  }
}
