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
///
/// Also owns the `NotificationsCubit` + `NotificationsPanelNotifier` so the
/// bell-toggle in the sidebar and the slide-over panel share one source of
/// truth.
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_desktop/core/di/injector.dart';
import 'package:fluxora_desktop/features/command_palette/presentation/notifier/command_palette_notifier.dart';
import 'package:fluxora_desktop/features/command_palette/presentation/widgets/command_palette_overlay.dart';
import 'package:fluxora_desktop/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:fluxora_desktop/features/notifications/presentation/widgets/notifications_panel.dart';
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
    return MultiBlocProvider(
      providers: [
        BlocProvider<SystemStatsCubit>(
          create: (_) => getIt<SystemStatsCubit>()..start(),
        ),
        BlocProvider<NotificationsCubit>(
          create: (_) => getIt<NotificationsCubit>()..start(),
        ),
      ],
      child: _ShellBody(child: child),
    );
  }
}

class _ShellBody extends StatefulWidget {
  const _ShellBody({required this.child});
  final Widget child;

  @override
  State<_ShellBody> createState() => _ShellBodyState();
}

class _ShellBodyState extends State<_ShellBody> {
  final _panelNotifier = NotificationsPanelNotifier();
  final _paletteNotifier = CommandPaletteNotifier();

  @override
  void dispose() {
    _panelNotifier.dispose();
    _paletteNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cmd+K on macOS, Ctrl+K elsewhere.
    final paletteShortcut = Platform.isMacOS
        ? LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyK)
        : LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK);

    return NotificationsPanelScope(
      notifier: _panelNotifier,
      child: CommandPaletteScope(
        notifier: _paletteNotifier,
        child: Shortcuts(
          shortcuts: <ShortcutActivator, Intent>{
            paletteShortcut: const _OpenCommandPaletteIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _OpenCommandPaletteIntent:
                  CallbackAction<_OpenCommandPaletteIntent>(
                onInvoke: (_) {
                  _paletteNotifier.toggle();
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: true,
              child: Scaffold(
                backgroundColor: AppColors.bgRoot,
                body: SafeArea(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _panelNotifier,
                    builder: (context, panelOpen, _) {
                      return AnimatedBuilder(
                        animation: _paletteNotifier,
                        builder: (context, _) {
                          return Stack(
                            children: [
                              Row(
                                children: [
                                  const FluxSidebar(),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        // The redesign was authored against
                                        // a 1100 px content minimum (4 stat
                                        // tiles + detail panel + table fit
                                        // cleanly above that). Below that,
                                        // horizontal-scroll the screen so
                                        // layouts don't collapse into
                                        // overflow stripes.
                                        Expanded(
                                          child: LayoutBuilder(
                                            builder: (ctx, constraints) {
                                              const minContentWidth = 1100.0;
                                              if (constraints.maxWidth >=
                                                  minContentWidth) {
                                                return widget.child;
                                              }
                                              return SingleChildScrollView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: SizedBox(
                                                  width: minContentWidth,
                                                  height:
                                                      constraints.maxHeight,
                                                  child: widget.child,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const FluxStatusBar(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (panelOpen)
                                Positioned.fill(
                                  child: NotificationsPanel(
                                    onClose: _panelNotifier.close,
                                  ),
                                ),
                              if (_paletteNotifier.isOpen)
                                Positioned.fill(
                                  child: CommandPaletteOverlay(
                                    notifier: _paletteNotifier,
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OpenCommandPaletteIntent extends Intent {
  const _OpenCommandPaletteIntent();
}

/// Inherited widget so any descendant can toggle the Cmd+K palette
/// (e.g. a sidebar button or a "Quick search" affordance).
class CommandPaletteScope extends InheritedWidget {
  const CommandPaletteScope({
    super.key,
    required this.notifier,
    required super.child,
  });

  final CommandPaletteNotifier notifier;

  static CommandPaletteNotifier of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<CommandPaletteScope>();
    assert(scope != null, 'CommandPaletteScope missing from widget tree');
    return scope!.notifier;
  }

  @override
  bool updateShouldNotify(CommandPaletteScope oldWidget) =>
      notifier != oldWidget.notifier;
}

/// Inherited widget that gives any descendant access to the
/// [NotificationsPanelNotifier] without needing GetIt.
class NotificationsPanelScope extends InheritedWidget {
  const NotificationsPanelScope({
    super.key,
    required this.notifier,
    required super.child,
  });

  final NotificationsPanelNotifier notifier;

  static NotificationsPanelNotifier of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<NotificationsPanelScope>();
    assert(scope != null, 'NotificationsPanelScope not found in tree');
    return scope!.notifier;
  }

  @override
  bool updateShouldNotify(NotificationsPanelScope oldWidget) =>
      notifier != oldWidget.notifier;
}
