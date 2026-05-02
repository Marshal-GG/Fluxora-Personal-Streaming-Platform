/// Command — a single entry in the Cmd+K command palette.
///
/// Either [routePath] (navigate via go_router) or [action] (arbitrary
/// callback) must be non-null — but not both.
library;

import 'package:flutter/widgets.dart';

class Command {
  const Command({
    required this.id,
    required this.label,
    this.subtitle,
    this.icon,
    this.routePath,
    this.action,
  }) : assert(
          (routePath != null) ^ (action != null),
          'Exactly one of routePath or action must be provided.',
        );

  /// Unique identifier used as a key and for deduplication.
  final String id;

  /// Primary display label shown in the palette list.
  final String label;

  /// Optional secondary label shown beneath the primary label (muted).
  final String? subtitle;

  /// Optional leading icon.
  final IconData? icon;

  /// When set, activating the command navigates to this route.
  /// Must be null when [action] is set.
  final String? routePath;

  /// When set, activating the command calls this callback.
  /// Must be null when [routePath] is set.
  final VoidCallback? action;
}
