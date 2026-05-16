/// FluxPillTabs — pill-style tab row primitive.
///
/// Visually distinct from [FluxTabBar] (the underline-style tab row).  Use
/// this when an outer page surface needs prominent button-like nav and the
/// inner content may carry its own [FluxTabBar] for sub-filters — avoids the
/// "tabs under tabs" look where both levels share the same chrome.
///
/// Each tab renders as a rounded pill matching the sidebar nav-item style:
/// violet-tinted background on active, muted text otherwise, hover tint
/// matching `rgba(255,255,255,0.03)`.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_desktop/shared/widgets/flux_tab_bar.dart';

class FluxPillTabs extends StatelessWidget {
  const FluxPillTabs({
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < tabs.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.s8),
          _PillButton(
            tab: tabs[i],
            isActive: tabs[i].id == activeId,
            onTap: () => onChange(tabs[i].id),
          ),
        ],
      ],
    );
  }
}

class _PillButton extends StatefulWidget {
  const _PillButton({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  final FluxTab tab;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = widget.isActive
        ? const Color(0x24A855F7) // rgba(168,85,247,0.14)
        : (_hovered
            ? const Color(0x08FFFFFF) // rgba(255,255,255,0.03)
            : Colors.transparent);
    final Color borderColor = widget.isActive
        ? const Color(0x4DA855F7) // rgba(168,85,247,0.3)
        : AppColors.borderSubtle;
    final Color fgColor = widget.isActive
        ? AppColors.violetSoft
        : (_hovered ? AppColors.textBody : AppColors.textMutedV2);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        button: true,
        selected: widget.isActive,
        label: '${widget.tab.label} tab',
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s14,
              vertical: AppSpacing.s10,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.tab.icon != null) ...[
                  Icon(widget.tab.icon, size: 14, color: fgColor),
                  const SizedBox(width: AppSpacing.s8),
                ],
                Text(
                  widget.tab.label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight:
                        widget.isActive ? FontWeight.w600 : FontWeight.w500,
                    color: fgColor,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
