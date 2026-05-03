/// FluxAppBar — mobile app bar with optional blur + transparent variant.
///
/// 52 px tall. Default `bg = rgba(8,6,20,0.85)` with a 20-px backdrop blur
/// that matches the prototype's translucent app-bar tint. Pass
/// `transparent: true` to skip the bg + blur (used by the player and the
/// photo viewer where the app bar floats over media).
///
/// Implements [PreferredSizeWidget] so it can drop into [Scaffold.appBar].
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_typography.dart';

class FluxAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FluxAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.trailing,
    this.onBack,
    this.transparent = false,
    this.centerTitle = false,
  });

  /// Title text. Ignored when [titleWidget] is provided.
  final String? title;

  /// Custom title widget — wins over [title] when set. Useful for
  /// avatar-then-wordmark headers, search fields, etc.
  final Widget? titleWidget;

  /// Optional leading widget. When `null` and [onBack] is set, a default
  /// chevron-back button is rendered.
  final Widget? leading;

  /// Optional list of trailing widgets (icon buttons, chips, etc.).
  final List<Widget>? trailing;

  /// When set, a back button is rendered as the default leading. Pass
  /// `() => Navigator.of(context).maybePop()` for the standard pop behaviour.
  final VoidCallback? onBack;

  /// When `true`, no background fill or blur is applied.
  final bool transparent;

  /// When `true`, the title is centered instead of left-aligned.
  final bool centerTitle;

  static const double _height = 52;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    final Widget? resolvedLeading = leading ??
        (onBack != null
            ? IconButton(
                icon: const Icon(Icons.chevron_left, size: 24),
                color: AppColors.textBright,
                onPressed: onBack,
                splashRadius: 22,
              )
            : null);

    final Widget? resolvedTitle = titleWidget ??
        (title != null
            ? Text(
                title!,
                style: AppTypography.h1.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textBright,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null);

    Widget bar = SizedBox(
      height: _height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: NavigationToolbar(
          leading: resolvedLeading,
          middle: resolvedTitle,
          trailing: trailing != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final w in trailing!) ...[
                      w,
                      const SizedBox(width: 4),
                    ],
                  ],
                )
              : null,
          centerMiddle: centerTitle,
        ),
      ),
    );

    if (!transparent) {
      bar = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: ColoredBox(
            color: const Color(0xD908061A), // rgba(8,6,20,0.85)
            child: bar,
          ),
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: bar,
    );
  }
}
