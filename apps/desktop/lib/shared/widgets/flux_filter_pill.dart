/// Shared single-select filter pill — `FluxToolbarPillButton` trigger
/// + sticky glass popup ([FluxGlassPopupSurface]) hosting one
/// [FluxPopupRow.singleSelect] row per option.
///
/// Established by the Clients screen ([clients_screen.dart]) — three
/// identical assemblies (Status / Devices / Sort) all wired this way.
/// Extracted here so future data-toolbar screens (Sessions, Logs,
/// Transcoding) get the same chrome + behaviour without duplicating
/// the wrapper.
///
/// **Versus the folder browser's Filter button:** that one is a
/// bespoke multi-axis composition (single-select kind rows + a
/// boolean "Indexed only" toggle row + a SHOW eyebrow heading) and
/// owns its own assembly inside the screen.  This widget is the
/// single-axis case where the popup is just a flat radio-group of
/// options.
///
/// **Generic T** is the option-value type — usually a `String` (as in
/// the Clients status filter `'All' / 'Online' / 'Pending' /
/// 'Revoked'`) but any value-equal type works, including enums.
library;

import 'package:flutter/material.dart';

import 'package:fluxora_core/constants/app_radii.dart';

import 'package:fluxora_desktop/shared/widgets/flux_glass_popup_surface.dart';
import 'package:fluxora_desktop/shared/widgets/flux_popup_row.dart';
import 'package:fluxora_desktop/shared/widgets/flux_toolbar_pill_button.dart';

class FluxFilterPill<T> extends StatelessWidget {
  const FluxFilterPill({
    super.key,
    required this.leadingIcon,
    required this.summary,
    required this.options,
    required this.selected,
    required this.optionIcon,
    required this.optionLabel,
    required this.isActive,
    required this.onSelected,
    this.height = 32,
    this.borderRadius,
    this.popupWidth = 200,
    this.popupAnchor = FluxFilterPillPopupAnchor.left,
  });

  /// Glyph rendered on the LEFT of the pill label (e.g.
  /// `Icons.adjust_rounded` for a status filter).
  final IconData leadingIcon;

  /// Summary string rendered as the pill label — typically `'All
  /// Status'` at rest, `'Pending'` when a non-default option is
  /// selected.  Caller owns the summary string formatting.
  final String summary;

  /// Option values to render in the popup, in display order.
  final List<T> options;

  /// Currently-selected option — gets the active check + violet tint
  /// inside the popup.
  final T selected;

  /// Glyph for each option's leading slot in the popup.
  final IconData Function(T option) optionIcon;

  /// Human-readable label for each option in the popup.
  final String Function(T option) optionLabel;

  /// `true` when [selected] is the non-default option for this filter
  /// — flips the pill itself into the violet-tint active treatment so
  /// the operator sees a filter is applied without opening the popup.
  final bool isActive;

  /// Fires when the operator taps an option row.  Popup stays mounted
  /// so the operator can rapid-fire toggle and watch the listing
  /// update in place.
  final ValueChanged<T> onSelected;

  /// Pill height — defaults to 32 px (matches search-box-style data
  /// toolbars).  See [FluxToolbarPillButton.height].
  final double height;

  /// Pill corner radius — defaults to `BorderRadius.circular(7)`
  /// (rounded-rectangle input chrome).  Pass `null` for the fully-
  /// rounded default of [FluxToolbarPillButton].
  final BorderRadius? borderRadius;

  /// Popup body width.  Defaults to 200 px — enough for one-line
  /// labels in 12.5 / 500 Inter without ellipsis truncation.
  final double popupWidth;

  /// Which side of the trigger the popup anchors to.  Use [left] when
  /// the pill sits on the LEFT side of the toolbar (popup extends
  /// DOWN+RIGHT) — the Clients screen's Status / Devices / Sort pills.
  /// Use [right] when the pill sits on the RIGHT side (popup extends
  /// DOWN+LEFT) — the folder browser's Filter pill.
  final FluxFilterPillPopupAnchor popupAnchor;

  @override
  Widget build(BuildContext context) {
    return FluxToolbarPillButton(
      label: summary,
      leadingIcon: leadingIcon,
      isActive: isActive,
      height: height,
      borderRadius: borderRadius ?? BorderRadius.circular(7),
      popupBuilder: (_, link, dismiss) {
        final isRight = popupAnchor == FluxFilterPillPopupAnchor.right;
        return Positioned(
          left: 0,
          top: 0,
          width: popupWidth,
          child: CompositedTransformFollower(
            link: link,
            targetAnchor:
                isRight ? Alignment.bottomRight : Alignment.bottomLeft,
            followerAnchor: isRight ? Alignment.topRight : Alignment.topLeft,
            offset: const Offset(0, 6),
            showWhenUnlinked: false,
            child: Material(
              color: Colors.transparent,
              child: TapRegion(
                onTapOutside: (_) => dismiss(),
                child: FluxGlassPopupSurface(
                  width: popupWidth,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final option in options)
                        FluxPopupRow.singleSelect(
                          icon: optionIcon(option),
                          label: optionLabel(option),
                          isActive: option == selected,
                          onTap: () => onSelected(option),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Which side of the trigger the [FluxFilterPill]'s popup anchors to.
enum FluxFilterPillPopupAnchor {
  /// Popup's top-LEFT corner anchors to the trigger's bottom-LEFT
  /// corner → popup extends DOWN+RIGHT.  Use when the pill sits on
  /// the LEFT side of a toolbar.
  left,

  /// Popup's top-RIGHT corner anchors to the trigger's bottom-RIGHT
  /// corner → popup extends DOWN+LEFT.  Use when the pill sits on
  /// the RIGHT side of a toolbar.
  right,
}
