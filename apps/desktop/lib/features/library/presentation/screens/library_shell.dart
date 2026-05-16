import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/widgets/flux_button.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_cubit.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_state.dart';
import 'package:fluxora_desktop/features/library/presentation/screens/library_screen.dart';
import 'package:fluxora_desktop/features/storage/presentation/cubit/storage_cubit.dart';
import 'package:fluxora_desktop/features/transcode/presentation/screens/transcode_screen.dart';
import 'package:fluxora_desktop/features/transcoding/presentation/screens/transcoding_screen.dart';
import 'package:fluxora_desktop/shared/widgets/flux_card.dart';
import 'package:fluxora_desktop/shared/widgets/flux_pill_tabs.dart';
import 'package:fluxora_desktop/shared/widgets/flux_tab_bar.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';

/// Outer tab host for the Library page (`/library`).  All three tab
/// bodies (Folders / Convert / Transcoding) are kept mounted via
/// [IndexedStack], so switching pills is a pure `setState` + index
/// change — no widget tear-down, no provider tear-down, no re-poll of
/// the server.  Previously each pill was its own go_router route which
/// rebuilt the entire shell and all its cubits on every tab switch
/// (the "pop in/out" feel).
///
/// Cubits live at the shell level:
///   - `LibraryCubit` + `StorageCubit` (Folders + actions slot)
///   - `TranscodeCubit` is owned by `TranscodeScreen` internally
///   - `TranscodingCubit` family is owned by `TranscodingScreen`
///
/// The shell-level cubits are created once and reused for the shell's
/// lifetime.  Inner-screen cubits stay alive across tab switches
/// because the IndexedStack keeps the widgets mounted.
class LibraryShell extends StatefulWidget {
  const LibraryShell({super.key, this.initialTab});

  /// Optional initial tab.  When null, the last-visited tab is restored
  /// (defaults to `folders` on first launch).
  final LibraryShellTabPath? initialTab;

  @override
  State<LibraryShell> createState() => _LibraryShellState();
}

class _LibraryShellState extends State<LibraryShell> {
  late LibraryShellTabPath _activeTab;

  /// Tabs the operator has actually opened.  Tabs not in this set
  /// render as `SizedBox.shrink()` inside the IndexedStack — their
  /// cubits don't get created until the first visit.  Once mounted,
  /// they stay alive for the rest of the shell's lifetime.
  final Set<LibraryShellTabPath> _visited = <LibraryShellTabPath>{};

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab ?? _rememberedLibraryTab;
    _visited.add(_activeTab);
    // Refresh is now driven by `LibraryEventsService` over WS — no
    // polling needed.  The shell just needs to remember its tab state.
  }

  void _switchTab(LibraryShellTabPath next) {
    if (_activeTab == next) return;
    setState(() {
      _activeTab = next;
      _visited.add(next);
    });
    _rememberedLibraryTab = next;
  }

  Widget _bodyFor(LibraryShellTabPath tab, Widget real) =>
      _visited.contains(tab) ? real : const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // `.value` (not `create:`) — the cubits are GetIt lazy
        // singletons, so they persist across page navigations and
        // keep their cached state.  First Library-page visit
        // creates them (and fires `load()`); subsequent visits
        // reuse the existing instance, no refetch.
        BlocProvider<LibraryCubit>.value(value: GetIt.I<LibraryCubit>()),
        BlocProvider<StorageCubit>.value(value: GetIt.I<StorageCubit>()),
      ],
      child: Container(
        color: AppColors.bgRoot,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    title: 'Library',
                    subtitle: _subtitleFor(_activeTab),
                    actions: _actionsFor(_activeTab),
                    verticalPadding: AppSpacing.s12,
                  ),
                  FluxPillTabs(
                    tabs: const [
                      FluxTab(
                        id: 'folders',
                        label: 'Libraries',
                        icon: Icons.video_library_outlined,
                      ),
                      FluxTab(
                        id: 'convert',
                        label: 'Convert',
                        icon: Icons.fast_forward_outlined,
                      ),
                      FluxTab(
                        id: 'transcoding',
                        label: 'Transcoding',
                        icon: Icons.tune_outlined,
                      ),
                    ],
                    activeId: _activeTab.id,
                    onChange: (id) {
                      final next = LibraryShellTabPath.fromId(id);
                      if (next != null) _switchTab(next);
                    },
                  ),
                  const SizedBox(height: AppSpacing.s10),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.s28,
                  right: AppSpacing.s28,
                  bottom: AppSpacing.s28,
                ),
                child: FluxCard(
                  padding: 0,
                  // IndexedStack keeps visited tab bodies mounted; only
                  // the visible one is painted.  Switching pills =
                  // O(1) index swap.  Unvisited tabs render as
                  // SizedBox.shrink() — their cubits don't construct
                  // until the operator clicks the pill.  Cubits stay
                  // alive after first visit.
                  child: IndexedStack(
                    index: _activeTab.index,
                    sizing: StackFit.expand,
                    children: [
                      _bodyFor(
                        LibraryShellTabPath.folders,
                        const LibraryScreen(embedded: true),
                      ),
                      _bodyFor(
                        LibraryShellTabPath.convert,
                        const TranscodeScreen(embedded: true),
                      ),
                      _bodyFor(
                        LibraryShellTabPath.transcoding,
                        const TranscodingScreen(embedded: true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _actionsFor(LibraryShellTabPath tab) {
    return switch (tab) {
      LibraryShellTabPath.folders =>
        BlocBuilder<LibraryCubit, LibraryState>(
          builder: (context, state) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FluxButton(
                variant: FluxButtonVariant.secondary,
                icon: Icons.refresh_rounded,
                onPressed: state is LibraryLoaded
                    ? () => context.read<LibraryCubit>().load()
                    : null,
                child: const Text('Refresh'),
              ),
              const SizedBox(width: AppSpacing.s8),
              FluxButton(
                variant: FluxButtonVariant.primary,
                icon: Icons.add_rounded,
                onPressed: () => showAddLibraryDialog(context),
                child: const Text('Add Library'),
              ),
            ],
          ),
        ),
      LibraryShellTabPath.convert => null,
      LibraryShellTabPath.transcoding => null,
    };
  }

  String _subtitleFor(LibraryShellTabPath tab) => switch (tab) {
        LibraryShellTabPath.folders =>
          'Manage your media libraries and files',
        LibraryShellTabPath.convert =>
          'Pre-convert AV1 / VP9 sources to H.264 sidecars so playback stream-copies',
        LibraryShellTabPath.transcoding =>
          'Real-time encoder load and per-session details',
      };
}

/// Tab identity for the Library shell.  Order matters — drives the
/// [IndexedStack] index via `.index`.
enum LibraryShellTabPath {
  folders('folders'),
  convert('convert'),
  transcoding('transcoding');

  const LibraryShellTabPath(this.id);

  final String id;

  static LibraryShellTabPath? fromId(String id) {
    for (final value in LibraryShellTabPath.values) {
      if (value.id == id) return value;
    }
    return null;
  }
}

/// Module-level cache of the last-visited Library tab.  Restored when
/// the shell mounts without an explicit `initialTab`.  Survives go_
/// router rebuilds; resets on hot restart / app launch.
LibraryShellTabPath _rememberedLibraryTab = LibraryShellTabPath.folders;

LibraryShellTabPath rememberedLibraryTab() => _rememberedLibraryTab;
