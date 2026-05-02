/// StatusDot — small coloured circle with an optional glow halo.
///
/// Matches `StatusDot` in
/// `docs/11_design/desktop_prototype/app/components/primitives.jsx` lines 22–26.
///
/// Usage:
/// ```dart
/// StatusDot(status: DotStatus.online)
/// StatusDot(status: DotStatus.streaming, size: 10)
/// ```
library;

import 'package:flutter/widgets.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_shadows.dart';

/// Semantic status values that [StatusDot] understands.
///
/// Maps directly to the prototype's `colors` object:
/// ```js
/// { online, active, streaming, idle, pending, offline, inactive, error }
/// ```
enum DotStatus {
  online,
  active,
  streaming,
  idle,
  pending,
  offline,
  inactive,
  error,
}

/// Circular status indicator dot.
///
/// For [DotStatus.online], [DotStatus.active], and [DotStatus.streaming] a
/// soft glow halo is applied via [AppShadows.dotGlow]. All other states render
/// as a plain filled circle.
class StatusDot extends StatelessWidget {
  const StatusDot({
    super.key,
    required this.status,
    this.size = 8,
  });

  /// The status to visualise.
  final DotStatus status;

  /// Diameter of the dot in logical pixels. Defaults to 8.
  final double size;

  Color _colorFor(DotStatus s) {
    switch (s) {
      case DotStatus.online:
        return AppColors.statusOnline;
      case DotStatus.active:
        return AppColors.statusActive;
      case DotStatus.streaming:
        return AppColors.statusStreaming;
      case DotStatus.idle:
        return AppColors.statusIdle;
      case DotStatus.pending:
        return AppColors.statusPending;
      case DotStatus.offline:
        return AppColors.statusOffline;
      case DotStatus.inactive:
        return AppColors.statusInactive;
      case DotStatus.error:
        return AppColors.statusError;
    }
  }

  bool _hasGlow(DotStatus s) {
    return s == DotStatus.online ||
        s == DotStatus.active ||
        s == DotStatus.streaming;
  }

  @override
  Widget build(BuildContext context) {
    final Color color = _colorFor(status);
    final List<BoxShadow> shadows =
        _hasGlow(status) ? AppShadows.dotGlow(color) : const [];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: shadows,
      ),
    );
  }
}
