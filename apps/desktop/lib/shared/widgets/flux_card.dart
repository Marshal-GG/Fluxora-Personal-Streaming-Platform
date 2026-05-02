/// FluxCard — glass-surface container primitive.
///
/// Matches `Card` in `docs/11_design/desktop_prototype/app/components/primitives.jsx`
/// lines 2–13.
///
/// Usage:
/// ```dart
/// FluxCard(
///   hoverable: true,
///   glow: true,
///   onTap: () { … },
///   child: Text('Hello'),
/// )
/// ```
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_shadows.dart';

/// Glass-morphic card that pixel-matches the prototype `Card` primitive.
///
/// - Background: [AppColors.surfaceGlass]
/// - Border: 1 px [AppColors.borderSubtle], transitions to [AppColors.borderHover] on hover
/// - Border radius: [AppRadii.lg] (12 px)
/// - Hover tint: `rgba(168,85,247,0.05)` overlay
/// - Glow: [AppShadows.cardGlow] when [glow] is `true`
/// - Transition: 150 ms ease (via [AnimatedContainer])
class FluxCard extends StatefulWidget {
  const FluxCard({
    super.key,
    this.child,
    this.padding = 20,
    this.hoverable = false,
    this.glow = false,
    this.onTap,
    this.margin,
  });

  /// Content rendered inside the card.
  final Widget? child;

  /// Uniform padding around [child]. Defaults to 20 px (prototype default).
  final double padding;

  /// When `true` the card reacts to mouse hover with a border and tint change.
  final bool hoverable;

  /// When `true` applies [AppShadows.cardGlow] — a violet ring + soft halo.
  final bool glow;

  /// Optional tap handler. When non-null the cursor becomes a pointer on hover.
  final VoidCallback? onTap;

  /// Optional outer margin applied around the card.
  final EdgeInsetsGeometry? margin;

  @override
  State<FluxCard> createState() => _FluxCardState();
}

class _FluxCardState extends State<FluxCard> {
  bool _hovered = false;

  // Hover tint: rgba(168,85,247,0.05) — the implicit `.hoverable-card` style.
  static const Color hoverTint = Color(0x0DA855F7);

  @override
  Widget build(BuildContext context) {
    final Color borderColor = (widget.hoverable && _hovered)
        ? AppColors.borderHover
        : AppColors.borderSubtle;

    final List<BoxShadow> shadows =
        widget.glow ? AppShadows.cardGlow : const [];

    Widget result = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: shadows,
      ),
      // Clip to the inner radius so the tint overlay never bleeds.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg - 1),
        child: Stack(
          children: [
            // Hover tint layer — fades in/out with the outer AnimatedContainer.
            if (widget.hoverable)
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  color: _hovered ? hoverTint : Colors.transparent,
                ),
              ),
            Padding(
              padding: EdgeInsets.all(widget.padding),
              child: widget.child,
            ),
          ],
        ),
      ),
    );

    // MouseRegion handles hover tracking and cursor shape.
    result = MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: widget.hoverable ? (_) => setState(() => _hovered = true) : null,
      onExit: widget.hoverable ? (_) => setState(() => _hovered = false) : null,
      child: result,
    );

    // GestureDetector is only added when a tap handler is provided so that
    // cards without onTap never intercept pointer events.
    if (widget.onTap != null) {
      result = GestureDetector(
        onTap: widget.onTap,
        child: result,
      );
    }

    return result;
  }
}
