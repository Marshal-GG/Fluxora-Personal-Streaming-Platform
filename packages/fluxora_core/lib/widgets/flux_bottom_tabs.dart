/// FluxBottomTabs — 5-item bottom tab bar from the mobile prototype.
///
/// Active tab: violet text + 700 weight + scale 1.05. Inactive: textDim +
/// 500 weight. Background `rgba(8,6,20,0.92)` with a 20-px backdrop blur.
/// 150 ms crossfade on switch + light haptic.
///
/// Pass [items] in display order (the prototype ships Home / Library /
/// Search / Downloads / Profile). [currentIndex] selects the active tab;
/// [onTap] receives the new index.
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluxora_core/constants/app_colors.dart';

/// Single entry in [FluxBottomTabs].
class FluxBottomTabItem {
  const FluxBottomTabItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

class FluxBottomTabs extends StatelessWidget {
  const FluxBottomTabs({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<FluxBottomTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const double _height = 64;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: const Color(0xEB08061A), // rgba(8,6,20,0.92)
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom,
          ),
          child: SizedBox(
            height: _height,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _Tab(
                      item: items[i],
                      selected: i == currentIndex,
                      onTap: () {
                        if (i == currentIndex) return;
                        HapticFeedback.lightImpact();
                        onTap(i);
                      },
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

class _Tab extends StatelessWidget {
  const _Tab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final FluxBottomTabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? AppColors.violet : AppColors.textDim;
    final FontWeight weight =
        selected ? FontWeight.w700 : FontWeight.w500;

    return InkWell(
      onTap: onTap,
      splashColor: AppColors.pillBgPurple,
      highlightColor: const Color(0x0AFFFFFF),
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        child: AnimatedScale(
          // M14 polish: 220 ms scale 1.0→1.05 on activate, easeOut curve
          // (mobile redesign plan §7 M14 — "tab scale 1.0→1.05").
          scale: selected ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 22, color: color),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: weight,
                  color: color,
                  letterSpacing: 0.1,
                  height: 1,
                ),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
