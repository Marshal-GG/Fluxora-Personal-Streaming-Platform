/// FluxSwitch — custom toggle that pixel-matches the prototype `TToggle`.
///
/// Matches `TToggle` in
/// `docs/11_design/desktop_prototype/app/screens/settings.jsx` lines 158–169.
///
/// Uses [MouseRegion] + [GestureDetector] with a custom painted track/thumb.
/// No Material [Switch] chrome is used.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';

class FluxSwitch extends StatefulWidget {
  const FluxSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<FluxSwitch> createState() => _FluxSwitchState();
}

class _FluxSwitchState extends State<FluxSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _thumbPos;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: widget.value ? 1.0 : 0.0,
    );
    _thumbPos = Tween<double>(begin: 3, end: 19).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(FluxSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (widget.value) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: MouseRegion(
        cursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: enabled
              ? () => widget.onChanged!(!widget.value)
              : null,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              return Container(
                width: 38,
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9999),
                  gradient: widget.value
                      ? const LinearGradient(
                          colors: [Color(0xFF8B5CF6), AppColors.violet],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: widget.value
                      ? null
                      : const Color(0x14FFFFFF), // rgba(255,255,255,0.08)
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: _thumbPos.value,
                      top: 3,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
