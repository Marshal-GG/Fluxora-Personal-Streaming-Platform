/// FluxTabBar — horizontal tab strip primitive.
///
/// Matches the tab row in `docs/11_design/desktop_prototype/app/screens/library.jsx`
/// lines 17–39. Used by Library (and reusable for Logs / Settings).
///
/// Layout:
/// - Container: bottom border 1 px `rgba(255,255,255,0.06)`, padding `0 4px 16px`.
/// - Gap between tabs: 18 px.
/// - Each tab: optional icon (14 px) + label, weight 500 inactive / 600 active.
/// - Active colour: `#C4A8F5`; inactive: `#94A3B8`.
/// - Active underline: 2 px `#A855F7` with `marginBottom: -1` to overlap the border.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';

/// A single tab descriptor.
class FluxTab {
  const FluxTab({
    required this.id,
    required this.label,
    this.icon,
  });

  final String id;
  final String label;
  final IconData? icon;
}

/// Horizontal tab strip that pixel-matches the prototype library tab row.
class FluxTabBar extends StatelessWidget {
  const FluxTabBar({
    super.key,
    required this.tabs,
    required this.activeId,
    required this.onChange,
  });

  final List<FluxTab> tabs;
  final String activeId;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0x0FFFFFFF), // rgba(255,255,255,0.06)
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 18),
            _FluxTabItem(
              tab: tabs[i],
              isActive: tabs[i].id == activeId,
              onTap: () => onChange(tabs[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

class _FluxTabItem extends StatefulWidget {
  const _FluxTabItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  final FluxTab tab;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_FluxTabItem> createState() => _FluxTabItemState();
}

class _FluxTabItemState extends State<_FluxTabItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color labelColor = widget.isActive
        ? AppColors.violetTint // #C4A8F5
        : AppColors.textMutedV2; // #94A3B8
    final FontWeight weight =
        widget.isActive ? FontWeight.w600 : FontWeight.w500;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          // The active 2 px underline overlaps the bottom border via -1 px offset.
          // We achieve this by painting a bottom border on the item itself and
          // letting it extend to the same bottom edge as the container border.
          padding: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.isActive
                    ? AppColors.violet // #A855F7
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.tab.icon != null) ...[
                Icon(
                  widget.tab.icon,
                  size: 14,
                  color: _hovered && !widget.isActive
                      ? AppColors.textBody
                      : labelColor,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                widget.tab.label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: weight,
                  color: _hovered && !widget.isActive
                      ? AppColors.textBody
                      : labelColor,
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
