/// FluxShell — root layout for every redesigned screen.
///
/// Replaces the old `AppShell` (Material `Scaffold` + sidebar `Row`). Wraps
/// every routed screen in:
///
/// ```
///   Row(
///     [ FluxSidebar 232px ],
///     [ Expanded:
///         Column(
///           [ Expanded: <screen> ],
///           [ FluxStatusBar 28px ],
///         )
///     ],
///   )
/// ```
///
/// Provides a single `SystemStatsCubit` to the entire subtree so the
/// sidebar's System Status block, the status bar, and the Dashboard
/// sparklines all read the same polling stream — no double polls.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_desktop/core/di/injector.dart';
import 'package:fluxora_desktop/features/system_stats/presentation/cubit/system_stats_cubit.dart';
import 'package:fluxora_desktop/shared/widgets/flux_sidebar.dart';
import 'package:fluxora_desktop/shared/widgets/flux_status_bar.dart';

class FluxShell extends StatelessWidget {
  const FluxShell({super.key, required this.child});

  /// The routed screen content rendered to the right of the sidebar and
  /// above the status bar.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SystemStatsCubit>(
      create: (_) => getIt<SystemStatsCubit>()..start(),
      child: Scaffold(
        backgroundColor: AppColors.bgRoot,
        body: SafeArea(
          child: Row(
            children: [
              const FluxSidebar(),
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: child),
                    const FluxStatusBar(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
