/// FluxGlassPopupSurface — shared glass-popup chrome.
///
/// Wraps any [child] in the same `ClipRRect → BackdropFilter → Container`
/// stack that [FluxGlassMenu] uses internally for the Sort / per-card
/// 3-dot menus, but exposes it as a primitive so callers with custom
/// popup content (toggleable rows, async-hovered suggestion lists,
/// arbitrary widgets) can render against the same surface without
/// re-deriving the chrome.
///
/// Use [FluxGlassMenu] / [showFluxGlassMenu] when the popup is a flat
/// list of selectable items.  Use this surface when the content is
/// custom — e.g. the folder-browser column picker (checkbox rows that
/// stay open while toggling) or the path-bar autocomplete suggestions
/// (hover state driven from outside).
///
/// Position + dismissal are the caller's responsibility — this widget
/// just paints the chrome.
library;

import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';

class FluxGlassPopupSurface extends StatelessWidget {
  const FluxGlassPopupSurface({
    super.key,
    required this.child,
    this.width,
    this.padding = EdgeInsets.zero,
    this.borderRadius,
    this.blurSigma = 20,
  });

  /// The popup content.  Sized by the caller; the surface itself just
  /// wraps it in the glass chrome.
  final Widget child;

  /// Optional fixed width.  Omit to let the child size the surface.
  final double? width;

  /// Padding inside the glass container, before the child.  Default
  /// zero so callers can compose their own internal layout.
  final EdgeInsetsGeometry padding;

  /// Radius for the outer clip + the inner border + the inner clip.
  /// Defaults to [AppRadii.md] (matches [FluxGlassMenu]); pass
  /// [AppRadii.sm] for tighter info popups.
  final BorderRadius? borderRadius;

  /// Blur sigma applied to the [BackdropFilter].  Default 20 matches
  /// every other glass surface in the app (app bar, sidebar, bottom
  /// tabs, glass menu).
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadii.md);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass,
            border: Border.all(color: AppColors.borderSubtle),
            borderRadius: radius,
          ),
          child: child,
        ),
      ),
    );
  }
}
