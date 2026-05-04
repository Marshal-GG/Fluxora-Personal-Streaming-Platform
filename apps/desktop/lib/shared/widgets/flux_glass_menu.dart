import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';

/// One row in a [FluxGlassMenu].
class FluxGlassMenuItem<T> {
  const FluxGlassMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
    this.destructive = false,
    this.selected = false,
  });

  final T value;
  final String label;
  final IconData? icon;

  /// Override the icon tint. Default is [AppColors.textBody]; selected
  /// items use [AppColors.violetTint] automatically.
  final Color? iconColor;

  /// When true, the label renders in red — for destructive actions
  /// (e.g. Remove). Pairs with selected: false.
  final bool destructive;

  /// Renders a check icon in the leading slot and bumps the label to
  /// semi-bold violet. Used for "current sort" / "current view" hints.
  final bool selected;
}

/// Drop-in replacement for `PopupMenuButton` that renders a real glass
/// popup — translucent `surfaceGlass` with a `BackdropFilter(blur 20)`
/// behind it, matching the pattern used by `flux_app_bar.dart`,
/// `flux_sidebar.dart`, and `flux_bottom_tabs.dart`.
///
/// `PopupMenuButton`'s items are independent Material descendants, so a
/// single `BackdropFilter` cannot span the entire popup. This widget
/// uses a custom [PopupRoute] that renders the items inside one
/// `ClipRRect > BackdropFilter > Container(surfaceGlass)` so the blur
/// covers the whole menu.
///
/// Usage: provide a [child] (the trigger) and a list of [items]; tap
/// the trigger to open the menu, the future resolves with the selected
/// value (or `null` on dismissal).
class FluxGlassMenu<T> extends StatelessWidget {
  const FluxGlassMenu({
    super.key,
    required this.items,
    required this.child,
    required this.onSelected,
    this.width = 220,
    this.blurSigma = 20,
  });

  final List<FluxGlassMenuItem<T>> items;

  /// The trigger widget. Tapping opens the menu anchored beneath it.
  final Widget child;

  /// Called with the selected value. Not called on dismissal.
  final ValueChanged<T> onSelected;

  /// Menu width in logical pixels. Defaults to 220.
  final double width;

  /// Blur sigma applied to the [BackdropFilter]. Defaults to 20.
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: child,
    );
  }

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(box.size.bottomLeft(Offset.zero), ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showFluxGlassMenu<T>(
      context: context,
      position: position,
      items: items,
      width: width,
      blurSigma: blurSigma,
    );
    if (selected != null) onSelected(selected);
  }
}

/// Show a glass-style popup menu at [position]. Returns the selected
/// value or `null` on dismissal. Lower-level than [FluxGlassMenu] — use
/// when the trigger is more complex than an InkWell can express.
Future<T?> showFluxGlassMenu<T>({
  required BuildContext context,
  required RelativeRect position,
  required List<FluxGlassMenuItem<T>> items,
  double width = 220,
  double blurSigma = 20,
}) {
  return Navigator.of(context).push<T>(
    _GlassPopupRoute<T>(
      position: position,
      items: items,
      width: width,
      blurSigma: blurSigma,
      barrierLabel:
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ),
  );
}

class _GlassPopupRoute<T> extends PopupRoute<T> {
  _GlassPopupRoute({
    required this.position,
    required this.items,
    required this.width,
    required this.blurSigma,
    required String barrierLabel,
  }) : _barrierLabel = barrierLabel;

  final RelativeRect position;
  final List<FluxGlassMenuItem<T>> items;
  final double width;
  final double blurSigma;
  final String _barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => _barrierLabel;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 120);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return CustomSingleChildLayout(
      delegate: _GlassMenuLayoutDelegate(
        position: position,
        textDirection: Directionality.of(context),
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(
            parent: animation, curve: Curves.easeOutQuart),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(
              width: width,
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                border: Border.all(color: AppColors.borderSubtle),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in items)
                    _GlassMenuRow<T>(item: item, route: this),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassMenuRow<T> extends StatelessWidget {
  const _GlassMenuRow({required this.item, required this.route});

  final FluxGlassMenuItem<T> item;
  final _GlassPopupRoute<T> route;

  @override
  Widget build(BuildContext context) {
    final Color labelColor = item.destructive
        ? const Color(0xFFF87171)
        : item.selected
            ? AppColors.violetTint
            : AppColors.textBody;
    final FontWeight weight =
        item.selected ? FontWeight.w600 : FontWeight.w400;

    return InkWell(
      onTap: () => Navigator.of(context).pop<T>(item.value),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.selected)
              const Icon(Icons.check_rounded,
                  size: 14, color: AppColors.violetTint)
            else if (item.icon != null)
              Icon(item.icon,
                  size: 14, color: item.iconColor ?? labelColor)
            else
              const SizedBox(width: 14),
            const SizedBox(width: 8),
            Text(
              item.label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: labelColor,
                fontWeight: weight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassMenuLayoutDelegate extends SingleChildLayoutDelegate {
  _GlassMenuLayoutDelegate({
    required this.position,
    required this.textDirection,
  });

  final RelativeRect position;
  final TextDirection textDirection;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(constraints.biggest);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Anchor below + aligned to the trigger's left edge. Clamp to keep
    // the menu fully on-screen.
    double left = position.left;
    double top = position.top;
    if (left + childSize.width > size.width - 8) {
      left = size.width - childSize.width - 8;
    }
    if (left < 8) left = 8;
    if (top + childSize.height > size.height - 8) {
      top = position.top - childSize.height - 8;
    }
    if (top < 8) top = 8;
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_GlassMenuLayoutDelegate oldDelegate) =>
      position != oldDelegate.position;
}
