/// PageHeader — every screen's title row.
///
/// Pixel-matches the inline `PageHeader` invoked at the top of every
/// `docs/11_design/desktop_prototype/app/screens/*.jsx` — a left-aligned
/// title (with an optional muted subtitle) and an optional right-aligned
/// `actions` widget (typically a row of [FluxButton]s).
///
/// Vertical padding of 24 px top and bottom; **no horizontal padding** —
/// each screen owns its own horizontal padding via the screen wrapper, so
/// the header tracks alignment with the content below.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.onBack,
  });

  /// Big title string. Rendered with [AppTypography.h1].
  final String title;

  /// Optional muted subtitle below the title. [AppTypography.bodySmall].
  final String? subtitle;

  /// Optional widget aligned to the right edge — usually a `Row` of
  /// `FluxButton`s. When null, the right side is empty.
  final Widget? actions;

  /// Optional back-navigation callback.  When non-null a circular back
  /// arrow is rendered to the left of the title — the standard "this is
  /// a sub-page; tap to return" affordance used across the app.  Pages
  /// that are top-level destinations (Dashboard, Library, etc.) leave
  /// this null.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onBack != null) ...[
            _BackButton(onTap: onBack!),
            const SizedBox(width: AppSpacing.s14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.h1.copyWith(
                    color: AppColors.textBright,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    subtitle!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textMutedV2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (actions != null) ...[
            const SizedBox(width: AppSpacing.s16),
            actions!,
          ],
        ],
      ),
    );
  }
}

/// Circular back-arrow button used by [PageHeader.onBack].  36×36 px hit
/// target with a violet hover tint matching the app's secondary-action
/// palette.  Wrapped in a Tooltip so screen-reader users + new operators
/// learn what it does.
class _BackButton extends StatefulWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _hover = false;

  // ``MouseRegion.onExit`` can fire mid-route-transition after this state's
  // widget has been disposed (the back button is the trigger for that
  // transition).  Guard every setState so a late onExit doesn't throw a
  // "setState called after dispose" — same pattern used across the
  // codebase's hover-state widgets.
  void _setHover(bool value) {
    if (!mounted) return;
    setState(() => _hover = value);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: Tooltip(
        message: 'Back',
        waitDuration: const Duration(milliseconds: 350),
        child: Semantics(
          button: true,
          label: 'Back',
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _hover
                    ? const Color(0x1AA855F7) // violet 10 %
                    : const Color(0x08FFFFFF),
                border: Border.all(
                  color: _hover
                      ? const Color(0x66A855F7)
                      : const Color(0x14FFFFFF),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 18,
                color: AppColors.textBright,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
