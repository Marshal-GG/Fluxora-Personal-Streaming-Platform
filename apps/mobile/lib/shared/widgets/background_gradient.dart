import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';

/// Two-radial brand gradient painted once at the router root.
///
/// Stack order: opaque bgRoot fill, topLeft violet radial (~18% alpha),
/// bottomRight cyan radial (~10% alpha), then the routed child. Each
/// screen's `Scaffold.backgroundColor` should be `Colors.transparent`
/// so the gradient shows through.
class BackgroundGradient extends StatelessWidget {
  const BackgroundGradient({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: ColoredBox(color: AppColors.bgRoot),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.2,
                colors: [Color(0x2EA855F7), Color(0x00A855F7)],
                stops: [0.0, 0.5],
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.bottomRight,
                radius: 1.0,
                colors: [Color(0x1A22D3EE), Color(0x0022D3EE)],
                stops: [0.0, 0.5],
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
