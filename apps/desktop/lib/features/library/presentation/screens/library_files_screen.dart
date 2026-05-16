/// Folder browser for a single library.
///
/// Replaces the v1 curated `media_files`-row table (which only showed
/// the small subset of files the scanner indexed).  The operator
/// asked for an Explorer-style view that surfaces every file in the
/// library's root_paths — including non-media + hidden files when
/// toggled.
///
/// Click semantics on the desktop control panel (which has no in-app
/// player):
///   * Directory → navigate into it
///   * File      → open in OS default app (`launchUrl(Uri.file(...))`)
///   * Right pane (future)  → file metadata / actions
///
/// Backed by `GET /api/v1/library/{id}/browse` — see
/// [LibraryBrowseCubit] for the data layer.

library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
        Clipboard,
        ClipboardData,
        HardwareKeyboard,
        KeyDownEvent,
        KeyEvent,
        KeyRepeatEvent,
        LogicalKeyboardKey;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/widgets/flux_button.dart';

import 'package:fluxora_desktop/core/router/app_router.dart';
import 'package:fluxora_desktop/features/library/domain/entities/browse_entry.dart';
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_browse_cubit.dart';
import 'package:fluxora_desktop/features/library/presentation/widgets/library_browse_context_menu.dart';
import 'package:fluxora_desktop/features/library/presentation/widgets/library_browse_count_footer.dart';
import 'package:fluxora_desktop/features/library/presentation/widgets/library_browse_detail_panel.dart';
import 'package:fluxora_desktop/features/library/presentation/widgets/library_browse_filter_chips.dart';
import 'package:fluxora_desktop/features/library/presentation/widgets/library_browse_search_bar.dart';
import 'package:fluxora_desktop/features/library/presentation/widgets/library_browse_view_toggle.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';

final _log = Logger();

class LibraryFilesScreen extends StatelessWidget {
  const LibraryFilesScreen({super.key, required this.libraryId});

  final String libraryId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LibraryBrowseCubit>(
      create: (_) => LibraryBrowseCubit(
        libraryId: libraryId,
        repository: GetIt.I<LibraryRepository>(),
      )..load(),
      child: const _LibraryBrowseView(),
    );
  }
}

class _LibraryBrowseView extends StatefulWidget {
  const _LibraryBrowseView();

  @override
  State<_LibraryBrowseView> createState() => _LibraryBrowseViewState();
}

class _LibraryBrowseViewState extends State<_LibraryBrowseView> {
  // Body-level focus node so the keyboard handler captures arrows /
  // Enter / Backspace / etc.  Autofocus on first build so the operator
  // doesn't have to click the body before keyboard nav works.  Plan 28
  // §5.3.
  final FocusNode _bodyFocus = FocusNode(debugLabel: 'browse-body');
  // Search-bar focus node owned at the screen level so `/` can yank
  // focus into the field from anywhere in the body.
  final FocusNode _searchFocus = FocusNode(debugLabel: 'browse-search');

  @override
  void dispose() {
    _bodyFocus.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Keyboard-event handler routing arrows / Enter / Backspace / Esc /
  /// Home / End / PageUp/Down / `/` to cubit methods or focus changes.
  /// Plan 28 §5.3.  Returns [KeyEventResult.handled] when the event
  /// was consumed so the widget tree doesn't double-fire.
  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final cubit = context.read<LibraryBrowseCubit>();
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      cubit.stepSelection(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      cubit.stepSelection(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft &&
        HardwareKeyboard.instance.isAltPressed) {
      cubit.goBack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight &&
        HardwareKeyboard.instance.isAltPressed) {
      cubit.goForward();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageDown) {
      cubit.stepSelection(10);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageUp) {
      cubit.stepSelection(-10);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      cubit.selectFirst();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      cubit.selectLast();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _openSelected();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      cubit.goUp();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      cubit.clearSelection();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.slash) {
      _searchFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyA &&
        HardwareKeyboard.instance.isControlPressed) {
      cubit.selectAllVisible();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _openSelected() {
    final cubit = context.read<LibraryBrowseCubit>();
    final resolved = cubit.resolveSelected();
    if (resolved == null) return;
    if (resolved.entry.isDir) {
      cubit.navigateTo(resolved.relativePath);
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    launchUrl(Uri.file(resolved.absolutePath)).then((ok) {
      if (!ok && mounted) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text('Could not open: ${resolved.entry.name}'),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _bodyFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Container(
      color: AppColors.bgRoot,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header — matches the Encoder Settings shape: rounded
          // back button on the left, h1 + subtitle, action row on
          // the right (one violet primary + compact icon toggles).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s28),
            child: PageHeader(
              title: 'Library Files',
              subtitle:
                  'Browse the actual folder structure under this library',
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(Routes.libraryFolders);
                }
              },
              actions: const _HeaderActions(),
              verticalPadding: AppSpacing.s16,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s28, 0, AppSpacing.s28, AppSpacing.s8,
            ),
            child: _BreadcrumbBar(searchFocusNode: _searchFocus),
          ),
          // Type-filter chip row — only shown when the body is loaded
          // (no point cluttering the loading skeleton).  Plan 28 §5.1.
          BlocBuilder<LibraryBrowseCubit, LibraryBrowseState>(
            buildWhen: (a, b) =>
                a.runtimeType != b.runtimeType,
            builder: (context, state) {
              if (state is! LibraryBrowseLoaded) {
                return const SizedBox.shrink();
              }
              return const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.s28, 0, AppSpacing.s28, AppSpacing.s10,
                ),
                child: LibraryBrowseFilterChips(),
              );
            },
          ),
          // Body is a Row: scrolling listing on the left + fixed-width
          // detail panel on the right.  Phase A of plan 28 — panel
          // shows metadata for the currently-selected entry.
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.s28,
                            right: AppSpacing.s14,
                          ),
                          child: BlocBuilder<LibraryBrowseCubit,
                              LibraryBrowseState>(
                            builder: (context, state) => switch (state) {
                              LibraryBrowseInitial() ||
                              LibraryBrowseLoading() =>
                                const _BrowseLoadingBody(),
                              LibraryBrowseLoaded(:final response) =>
                                _BrowseBody(response: response),
                              LibraryBrowseFailure(:final message) =>
                                _BrowseFailureBody(message: message),
                            },
                          ),
                        ),
                      ),
                      // Count footer pinned below the body.  Plan 28 §5.2.
                      const Padding(
                        padding: EdgeInsets.only(
                          left: AppSpacing.s28,
                          right: AppSpacing.s14,
                          bottom: AppSpacing.s6,
                        ),
                        child: LibraryBrowseCountFooter(),
                      ),
                    ],
                  ),
                ),
                const LibraryBrowseDetailPanel(),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}

// ── Header actions: back-to-library + show-hidden toggle ──────────────────

class _HeaderActions extends StatelessWidget {
  const _HeaderActions();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryBrowseCubit, LibraryBrowseState>(
      builder: (context, state) {
        final cubit = context.read<LibraryBrowseCubit>();
        final loaded = state is LibraryBrowseLoaded ? state : null;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show-hidden toggle — operator's local pref, persisted by
            // the cubit instance for this screen's lifetime.  Compact
            // icon button so the toggle state (active = violet tint)
            // is the primary affordance.
            _ToolbarIconButton(
              icon: cubit.showHidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              tooltip: cubit.showHidden
                  ? 'Hide hidden files'
                  : 'Show hidden files',
              active: cubit.showHidden,
              onTap: () => cubit.setShowHidden(!cubit.showHidden),
            ),
            const SizedBox(width: AppSpacing.s8),
            // Refresh re-fetches the current directory listing — useful
            // when files were added / removed externally and the
            // operator wants a fresh view without manual navigation.
            _ToolbarIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh',
              onTap: () => cubit.refresh(),
            ),
            const SizedBox(width: AppSpacing.s8),
            // Density cycle button — Compact / Cosy / Comfortable.
            // One-shot icon button that cycles forward; icon + tooltip
            // reflect the current mode.
            _DensityCycleButton(density: cubit.density),
            const SizedBox(width: AppSpacing.s10),
            // List ↔ Grid view toggle (Phase A — segmented control).
            const LibraryBrowseViewToggle(),
            const SizedBox(width: AppSpacing.s12),
            // Primary action — opens the current directory in the OS
            // file manager.  Matches the "Save" pattern from Encoder
            // Settings: one violet FluxButton with icon + label.
            FluxButton(
              icon: Icons.folder_open_outlined,
              onPressed: loaded == null
                  ? null
                  : () => _openCurrentInFileManager(context, loaded),
              child: const Text('Open in Explorer'),
            ),
          ],
        );
      },
    );
  }
}

Future<void> _openCurrentInFileManager(
  BuildContext context,
  LibraryBrowseLoaded loaded,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final response = loaded.response;
  final separator = response.rootPath.contains(r'\') ? r'\' : '/';
  final tail = response.relativePath.isEmpty
      ? ''
      : response.relativePath.replaceAll('/', separator);
  final absolute = tail.isEmpty
      ? response.rootPath
      : '${response.rootPath}$separator$tail';
  try {
    final ok = await launchUrl(Uri.file(absolute));
    if (!ok) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not open folder: $absolute')),
      );
    }
  } catch (e, st) {
    _log.e('open-current-in-file-manager failed: $absolute',
        error: e, stackTrace: st);
    messenger?.showSnackBar(
      SnackBar(content: Text('Could not open folder: $e')),
    );
  }
}

// ── Breadcrumb bar ─────────────────────────────────────────────────────────

class _BreadcrumbBar extends StatefulWidget {
  const _BreadcrumbBar({this.searchFocusNode});

  /// Optional focus node passed down to the embedded search bar so the
  /// screen-level `/` shortcut can yank focus into the field.
  final FocusNode? searchFocusNode;

  @override
  State<_BreadcrumbBar> createState() => _BreadcrumbBarState();
}

class _BreadcrumbBarState extends State<_BreadcrumbBar> {
  bool _editing = false;
  final TextEditingController _pathController = TextEditingController();
  final FocusNode _pathFocus = FocusNode(debugLabel: 'browse-path-edit');
  String? _validationError;

  @override
  void dispose() {
    _pathController.dispose();
    _pathFocus.dispose();
    super.dispose();
  }

  void _beginEdit(LibraryBrowseLoaded loaded) {
    final response = loaded.response;
    final separator = response.rootPath.contains(r'\') ? r'\' : '/';
    final tail = response.relativePath.isEmpty
        ? ''
        : response.relativePath.replaceAll('/', separator);
    final initial = tail.isEmpty
        ? response.rootPath
        : '${response.rootPath}$separator$tail';
    _pathController.text = initial;
    _pathController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: initial.length,
    );
    setState(() {
      _editing = true;
      _validationError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pathFocus.requestFocus();
    });
  }

  void _cancelEdit() {
    setState(() {
      _editing = false;
      _validationError = null;
    });
  }

  Future<void> _commitEdit() async {
    final input = _pathController.text.trim();
    final cubit = context.read<LibraryBrowseCubit>();
    final ok = await cubit.navigateToAbsolute(input);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _validationError = 'Path is outside this library or does not exist';
      });
      return;
    }
    setState(() {
      _editing = false;
      _validationError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryBrowseCubit, LibraryBrowseState>(
      builder: (context, state) {
        if (state is! LibraryBrowseLoaded) {
          return const SizedBox(height: 28);
        }
        final response = state.response;
        final cubit = context.read<LibraryBrowseCubit>();

        // Back / Forward history icons live left of the up button.
        // Plan 28 Phase D — Alt+← / Alt+→ also dispatch these.
        final historyButtons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolbarIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: cubit.canGoBack ? 'Back (Alt+←)' : 'No history',
              onTap: cubit.canGoBack ? () => cubit.goBack() : null,
            ),
            const SizedBox(width: 2),
            _ToolbarIconButton(
              icon: Icons.arrow_forward_ios_rounded,
              tooltip: cubit.canGoForward
                  ? 'Forward (Alt+→)'
                  : 'No forward history',
              onTap: cubit.canGoForward
                  ? () => cubit.goForward()
                  : null,
            ),
          ],
        );

        // Common left affordance + trailing search + copy.
        final upButton = _ToolbarIconButton(
          icon: Icons.arrow_upward_rounded,
          tooltip: response.parentPath == null
              ? 'At library root'
              : 'Go up one level',
          onTap: response.parentPath == null
              ? null
              : () => cubit.goUp(),
        );

        if (_editing) {
          return Row(
            children: [
              historyButtons,
              const SizedBox(width: AppSpacing.s4),
              upButton,
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Focus(
                  onKeyEvent: (_, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.escape) {
                      _cancelEdit();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: _pathController,
                    focusNode: _pathFocus,
                    onSubmitted: (_) => _commitEdit(),
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      color: AppColors.textBright,
                    ),
                    cursorColor: AppColors.violet,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      filled: true,
                      fillColor: const Color(0x0AFFFFFF),
                      hintText: r'D:\Library\Subdir',
                      hintStyle: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        color: AppColors.textFaint,
                      ),
                      errorText: _validationError,
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadii.sm - 1),
                        borderSide:
                            const BorderSide(color: Color(0x14FFFFFF)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadii.sm - 1),
                        borderSide: const BorderSide(
                          color: AppColors.violet,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              _ToolbarIconButton(
                icon: Icons.check_rounded,
                tooltip: 'Navigate (Enter)',
                onTap: _commitEdit,
              ),
              const SizedBox(width: AppSpacing.s4),
              _ToolbarIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Cancel (Esc)',
                onTap: _cancelEdit,
              ),
            ],
          );
        }

        final segments = response.relativePath.isEmpty
            ? const <String>[]
            : response.relativePath.split('/');

        // Build a series of breadcrumb chips: root then each segment.
        final chips = <Widget>[
          _BreadcrumbSegment(
            label: _displayRoot(response.rootPath),
            tooltip: response.rootPath,
            onTap: () => cubit.navigateTo(''),
            isLast: segments.isEmpty,
          ),
        ];

        // Build the running relative path so each chip knows its target.
        final accum = <String>[];
        for (var i = 0; i < segments.length; i++) {
          accum.add(segments[i]);
          final target = accum.join('/');
          chips
            ..add(const _BreadcrumbSeparator())
            ..add(_BreadcrumbSegment(
              label: segments[i],
              tooltip: target,
              onTap: () => cubit.navigateTo(target),
              isLast: i == segments.length - 1,
            ));
        }

        // Trailing icon row: history + "go up" (parent) + edit
        // affordance + search field + raw-path copy.
        return Row(
          children: [
            historyButtons,
            const SizedBox(width: AppSpacing.s4),
            upButton,
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Tooltip(
                message: 'Click to edit path',
                waitDuration: const Duration(milliseconds: 600),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _beginEdit(state),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: chips),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s6),
            _ToolbarIconButton(
              icon: Icons.edit_rounded,
              tooltip: 'Edit path',
              onTap: () => _beginEdit(state),
            ),
            const SizedBox(width: AppSpacing.s10),
            LibraryBrowseSearchBar(
              width: 240,
              focusNode: widget.searchFocusNode,
            ),
            const SizedBox(width: AppSpacing.s8),
            _ToolbarIconButton(
              icon: Icons.copy_rounded,
              tooltip: 'Copy absolute path',
              onTap: () => _copyAbsolutePath(context, response),
            ),
          ],
        );
      },
    );
  }

  /// Show just the leaf-most segment of the root path (e.g. `D:/Movies`
  /// → `Movies`) so the breadcrumb doesn't dominate the bar.  Full path
  /// stays in the tooltip.
  String _displayRoot(String absolute) {
    if (absolute.isEmpty) return 'Library';
    final normalised = absolute.replaceAll('\\', '/');
    final parts = normalised.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return absolute;
    final last = parts.last;
    return last.isEmpty ? absolute : last;
  }

  Future<void> _copyAbsolutePath(
      BuildContext context, BrowseResponse response) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final separator = response.rootPath.contains(r'\') ? r'\' : '/';
    final tail = response.relativePath.isEmpty
        ? ''
        : response.relativePath.replaceAll('/', separator);
    final full = tail.isEmpty
        ? response.rootPath
        : '${response.rootPath}$separator$tail';
    await Clipboard.setData(ClipboardData(text: full));
    messenger?.showSnackBar(
      const SnackBar(content: Text('Path copied to clipboard')),
    );
  }
}

class _BreadcrumbSegment extends StatelessWidget {
  const _BreadcrumbSegment({
    required this.label,
    required this.tooltip,
    required this.onTap,
    required this.isLast,
  });

  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color =
        isLast ? AppColors.textBright : AppColors.textBody;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLast ? null : onTap,
        borderRadius: BorderRadius.circular(4),
        hoverColor: isLast ? Colors.transparent : const Color(0x0DA855F7),
        child: Tooltip(
          message: tooltip,
          waitDuration: const Duration(milliseconds: 600),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: isLast ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BreadcrumbSeparator extends StatelessWidget {
  const _BreadcrumbSeparator();

  @override
  Widget build(BuildContext context) => const Icon(
        Icons.chevron_right_rounded,
        size: 14,
        color: AppColors.textFaint,
      );
}

// ── Body: loading / failure / list ─────────────────────────────────────────

class _BrowseLoadingBody extends StatelessWidget {
  const _BrowseLoadingBody();

  @override
  Widget build(BuildContext context) {
    // A handful of placeholder rows — same shape as the real list so
    // there's no layout shift when the data lands.
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      itemCount: 8,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (_, _) => Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0x05FFFFFF),
          border: Border.all(color: const Color(0x0AFFFFFF)),
          borderRadius: BorderRadius.circular(7),
        ),
      ),
    );
  }
}

class _BrowseFailureBody extends StatelessWidget {
  const _BrowseFailureBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline,
              size: 48, color: AppColors.textMutedV2),
          const SizedBox(height: AppSpacing.s12),
          Text(
            message,
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textMutedV2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s12),
          _ToolbarIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Retry',
            onTap: () => context.read<LibraryBrowseCubit>().load(),
          ),
        ],
      ),
    );
  }
}

/// Body switcher between list + grid views; applies the cubit's UI
/// prefs (sort / filter / search / indexed-only) before rendering.
/// Phase A of plan 28.
class _BrowseBody extends StatelessWidget {
  const _BrowseBody({required this.response});

  final BrowseResponse response;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryBrowseCubit, LibraryBrowseState>(
      builder: (context, _) {
        final cubit = context.read<LibraryBrowseCubit>();
        final filtered = applyBrowseFilters(
          response.entries,
          indexedOnly: cubit.indexedOnly,
          kindFilter: cubit.kindFilter,
          search: cubit.search,
          sortBy: cubit.sortBy,
          sortAsc: cubit.sortAsc,
        );

        if (filtered.isEmpty) {
          return _EmptyBody(
            response: response,
            hasActiveFilters: cubit.indexedOnly ||
                cubit.search.isNotEmpty ||
                cubit.kindFilter != BrowseKindFilter.all,
          );
        }

        return cubit.viewMode == BrowseViewMode.list
            ? _BrowseListView(
                response: response,
                entries: filtered,
                selectedNames: cubit.selectedNames,
                sortBy: cubit.sortBy,
                sortAsc: cubit.sortAsc,
                onSort: cubit.setSort,
                density: cubit.density,
              )
            : _BrowseGridView(
                response: response,
                entries: filtered,
                selectedNames: cubit.selectedNames,
                density: cubit.density,
              );
      },
    );
  }
}

/// Distinct empty-state copy per scenario.  At root: "empty library."
/// In subdir: "empty folder."  With filters active: "no matches."
class _EmptyBody extends StatelessWidget {
  const _EmptyBody({
    required this.response,
    required this.hasActiveFilters,
  });

  final BrowseResponse response;
  final bool hasActiveFilters;

  @override
  Widget build(BuildContext context) {
    final (icon, body) = switch ((hasActiveFilters, response.relativePath.isEmpty)) {
      (true, _) => (
        Icons.search_off_rounded,
        'No entries match the current filters.',
      ),
      (false, true) => (
        Icons.folder_off_outlined,
        'This library is empty.  Add files under one of its root paths.',
      ),
      (false, false) => (
        Icons.folder_open_outlined,
        'This folder is empty.',
      ),
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppColors.textMutedV2),
          const SizedBox(height: AppSpacing.s12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Text(
              body,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textMutedV2),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowseListView extends StatelessWidget {
  const _BrowseListView({
    required this.response,
    required this.entries,
    required this.selectedNames,
    required this.sortBy,
    required this.sortAsc,
    required this.onSort,
    required this.density,
  });

  final BrowseResponse response;
  final List<BrowseEntry> entries;
  final Set<String> selectedNames;
  final BrowseSortColumn sortBy;
  final bool sortAsc;
  final ValueChanged<BrowseSortColumn> onSort;
  final BrowseDensity density;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SortableColumnHeaderRow(
          sortBy: sortBy,
          sortAsc: sortAsc,
          onSort: onSort,
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: AppSpacing.s14),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (_, i) {
              final entry = entries[i];
              return _BrowseRow(
                entry: entry,
                rootPath: response.rootPath,
                relativePath: response.relativePath,
                isSelected: selectedNames.contains(entry.name),
                density: density,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Sortable column headers.  Click toggles direction (desc / asc / desc /
/// ...); active column shows the arrow indicator.  Plan 28 Phase A.
class _SortableColumnHeaderRow extends StatelessWidget {
  const _SortableColumnHeaderRow({
    required this.sortBy,
    required this.sortAsc,
    required this.onSort,
  });

  final BrowseSortColumn sortBy;
  final bool sortAsc;
  final ValueChanged<BrowseSortColumn> onSort;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // 24px icon column + 8px gap
          const SizedBox(width: 32),
          Expanded(
            child: _SortHeaderLabel(
              label: 'NAME',
              column: BrowseSortColumn.name,
              activeColumn: sortBy,
              ascending: sortAsc,
              onTap: () => onSort(BrowseSortColumn.name),
            ),
          ),
          SizedBox(
            width: 100,
            child: _SortHeaderLabel(
              label: 'SIZE',
              column: BrowseSortColumn.size,
              activeColumn: sortBy,
              ascending: sortAsc,
              onTap: () => onSort(BrowseSortColumn.size),
            ),
          ),
          SizedBox(
            width: 160,
            child: _SortHeaderLabel(
              label: 'MODIFIED',
              column: BrowseSortColumn.modified,
              activeColumn: sortBy,
              ascending: sortAsc,
              onTap: () => onSort(BrowseSortColumn.modified),
            ),
          ),
          const SizedBox(width: 80),
        ],
      ),
    );
  }
}

class _SortHeaderLabel extends StatefulWidget {
  const _SortHeaderLabel({
    required this.label,
    required this.column,
    required this.activeColumn,
    required this.ascending,
    required this.onTap,
  });

  final String label;
  final BrowseSortColumn column;
  final BrowseSortColumn activeColumn;
  final bool ascending;
  final VoidCallback onTap;

  @override
  State<_SortHeaderLabel> createState() => _SortHeaderLabelState();
}

class _SortHeaderLabelState extends State<_SortHeaderLabel> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.column == widget.activeColumn;
    final color = (isActive || _hovered)
        ? AppColors.violet
        : AppColors.textMutedV2;
    final style = AppTypography.captionV2.copyWith(
      color: color,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.4,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.label, style: style),
            const SizedBox(width: 4),
            if (isActive)
              Icon(
                widget.ascending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 12,
                color: color,
              ),
          ],
        ),
      ),
    );
  }
}

/// Grid-view body — fixed-size tiles (160 × 200) with thumbnail-or-icon
/// + name + small kind icon footer.  Plan 28 Phase A.
class _BrowseGridView extends StatelessWidget {
  const _BrowseGridView({
    required this.response,
    required this.entries,
    required this.selectedNames,
    required this.density,
  });

  final BrowseResponse response;
  final List<BrowseEntry> entries;
  final Set<String> selectedNames;
  final BrowseDensity density;

  @override
  Widget build(BuildContext context) {
    final (extent, mainExtent) = switch (density) {
      BrowseDensity.compact => (140.0, 160.0),
      BrowseDensity.cosy => (160.0, 180.0),
      BrowseDensity.comfortable => (180.0, 200.0),
    };
    return GridView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: AppSpacing.s14),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: extent,
        mainAxisExtent: mainExtent,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final entry = entries[i];
        return _BrowseGridTile(
          entry: entry,
          rootPath: response.rootPath,
          relativePath: response.relativePath,
          isSelected: selectedNames.contains(entry.name),
        );
      },
    );
  }
}

// ── Row ────────────────────────────────────────────────────────────────────

class _BrowseRow extends StatefulWidget {
  const _BrowseRow({
    required this.entry,
    required this.rootPath,
    required this.relativePath,
    required this.isSelected,
    required this.density,
  });

  final BrowseEntry entry;
  final String rootPath;
  final String relativePath;
  final bool isSelected;
  final BrowseDensity density;

  @override
  State<_BrowseRow> createState() => _BrowseRowState();
}

class _BrowseRowState extends State<_BrowseRow> {
  bool _hovered = false;
  DateTime? _lastTapAt;

  double get _verticalPad => switch (widget.density) {
        BrowseDensity.compact => 4,
        BrowseDensity.cosy => 6,
        BrowseDensity.comfortable => 8,
      };

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final iconData = _iconForKind(entry.kind);
    final iconColor = _colorForKind(entry.kind);
    final showHdrBadge = entry.media?.hdrFormat != null &&
        entry.media!.hdrFormat!.isNotEmpty;
    final bgColor = widget.isSelected
        ? const Color(0x1AA855F7)
        : (_hovered ? const Color(0x0DA855F7) : const Color(0x05FFFFFF));
    final borderColor = widget.isSelected
        ? const Color(0x66A855F7)
        : (_hovered ? const Color(0x1AA855F7) : const Color(0x0AFFFFFF));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        onSecondaryTapDown: (details) =>
            _showContextMenu(details.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: _verticalPad),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Icon(iconData, size: 18, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Tooltip(
                  message: entry.name,
                  waitDuration: const Duration(milliseconds: 800),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.name,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: entry.isHidden
                                ? AppColors.textFaint
                                : AppColors.textBody,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (entry.isHidden) ...[
                        const SizedBox(width: 6),
                        const _MutedTag(label: 'Hidden'),
                      ],
                      if (showHdrBadge) ...[
                        const SizedBox(width: 6),
                        _MutedTag(
                          label: entry.media!.hdrFormat!.toUpperCase(),
                          accent: true,
                        ),
                      ],
                      if (entry.media?.isStreaming == true) ...[
                        const SizedBox(width: 6),
                        const _MutedTag(label: '▶ live', accent: true),
                      ],
                      if (entry.media?.hasThumbnailFailed == true) ...[
                        const SizedBox(width: 6),
                        const Tooltip(
                          message: 'Thumbnail generation failed. '
                              'Use the right-click menu to retry.',
                          waitDuration: Duration(milliseconds: 400),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            size: 13,
                            color: AppColors.amber,
                          ),
                        ),
                      ],
                      if (entry.isIndexed) ...[
                        const SizedBox(width: 6),
                        _IndexedTag(indexedAtIso: entry.media?.indexedAtIso),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 100,
                child: Text(
                  entry.isDir ? '—' : _humanBytes(entry.sizeBytes),
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11.5,
                    color: AppColors.textMutedV2,
                  ),
                ),
              ),
              SizedBox(
                width: 160,
                child: Text(
                  _formatModified(entry.modifiedIso),
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11.5,
                    color: AppColors.textMutedV2,
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _ToolbarIconButton(
                    icon: Icons.folder_open_outlined,
                    tooltip: 'Reveal in file manager',
                    onTap: () => _revealInFileManager(),
                    compact: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Single-click → select; double-click within 300 ms → open.  Same
  /// `_lastTapAt` timestamp pattern `_LibraryCardState` uses (Flutter's
  /// `onDoubleTap` adds 300 ms latency to `onTap` while the arena
  /// disambiguates).  Ctrl/Cmd-click toggles membership; Shift-click
  /// extends from the anchor.  Plan 28 Phase C multi-select.
  void _handleTap() {
    final cubit = context.read<LibraryBrowseCubit>();
    final kbd = HardwareKeyboard.instance;
    final ctrl = kbd.isControlPressed || kbd.isMetaPressed;
    final shift = kbd.isShiftPressed;
    if (ctrl) {
      _lastTapAt = null;
      cubit.toggleSelection(widget.entry.name);
      return;
    }
    if (shift) {
      _lastTapAt = null;
      cubit.extendSelection(widget.entry.name);
      return;
    }
    final now = DateTime.now();
    if (_lastTapAt != null &&
        now.difference(_lastTapAt!).inMilliseconds < 300) {
      _lastTapAt = null;
      _handleOpen();
      return;
    }
    _lastTapAt = now;
    cubit.selectOnly(widget.entry.name);
  }

  void _handleOpen() {
    if (widget.entry.isDir) {
      final target = widget.relativePath.isEmpty
          ? widget.entry.name
          : '${widget.relativePath}/${widget.entry.name}';
      context.read<LibraryBrowseCubit>().navigateTo(target);
      return;
    }
    // File open → OS default app via url_launcher's Uri.file.
    _openInDefaultApp();
  }

  Future<void> _showContextMenu(Offset position) async {
    final cubit = context.read<LibraryBrowseCubit>();
    // Right-click on an unselected row also makes it the current
    // selection so the menu's "selected entry" actions are visually
    // accurate.
    if (!widget.isSelected) {
      cubit.selectOnly(widget.entry.name);
    }
    await showBrowseEntryContextMenu(
      context: context,
      position: position,
      entry: widget.entry,
      rootPath: widget.rootPath,
      relativePath: widget.relativePath,
    );
  }

  Future<void> _openInDefaultApp() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final absolute = _absolutePath();
    try {
      final uri = Uri.file(absolute);
      final ok = await launchUrl(uri);
      if (!ok) {
        messenger?.showSnackBar(
          SnackBar(content: Text('Could not open: ${widget.entry.name}')),
        );
      }
    } catch (e, st) {
      _log.e('open-in-default-app failed: $absolute',
          error: e, stackTrace: st);
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not open ${widget.entry.name}: $e')),
      );
    }
  }

  Future<void> _revealInFileManager() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final absolute = _absolutePath();
    final parent = widget.entry.isDir ? absolute : _parentOf(absolute);
    try {
      final ok = await launchUrl(Uri.file(parent));
      if (!ok) {
        messenger?.showSnackBar(
          SnackBar(content: Text('Could not open folder: $parent')),
        );
      }
    } catch (e, st) {
      _log.e('reveal-in-file-manager failed: $parent',
          error: e, stackTrace: st);
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not open folder: $e')),
      );
    }
  }

  String _absolutePath() {
    final separator = widget.rootPath.contains(r'\') ? r'\' : '/';
    final tail = widget.relativePath.isEmpty
        ? widget.entry.name
        : '${widget.relativePath}/${widget.entry.name}';
    final tailWithSep = tail.replaceAll('/', separator);
    return '${widget.rootPath}$separator$tailWithSep';
  }

  String _parentOf(String path) {
    final sep = path.contains(r'\') ? r'\' : '/';
    final idx = path.lastIndexOf(sep);
    if (idx <= 0) return path;
    return path.substring(0, idx);
  }
}

// ── Grid tile ──────────────────────────────────────────────────────────────

/// Grid-view tile for a single entry.  Top 60 % is the visual (icon or
/// real thumbnail when indexed media is ready); bottom 40 % is the
/// name + small kind icon footer.  Click semantics match `_BrowseRow`
/// (single-click selects, double-click opens).  Plan 28 Phase A.
class _BrowseGridTile extends StatefulWidget {
  const _BrowseGridTile({
    required this.entry,
    required this.rootPath,
    required this.relativePath,
    required this.isSelected,
  });

  final BrowseEntry entry;
  final String rootPath;
  final String relativePath;
  final bool isSelected;

  @override
  State<_BrowseGridTile> createState() => _BrowseGridTileState();
}

class _BrowseGridTileState extends State<_BrowseGridTile> {
  bool _hovered = false;
  DateTime? _lastTapAt;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final bgColor = widget.isSelected
        ? const Color(0x1AA855F7)
        : (_hovered ? const Color(0x0DA855F7) : const Color(0x05FFFFFF));
    final borderColor = widget.isSelected
        ? const Color(0x66A855F7)
        : (_hovered ? const Color(0x1AA855F7) : const Color(0x0AFFFFFF));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        onSecondaryTapDown: (details) =>
            _showContextMenu(details.globalPosition),
        child: Tooltip(
          message: entry.name,
          waitDuration: const Duration(milliseconds: 800),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top 60% — thumbnail OR kind icon
                Expanded(
                  flex: 6,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppRadii.md - 1),
                      topRight: Radius.circular(AppRadii.md - 1),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _GridTileVisual(
                          entry: entry,
                        ),
                        // Corner badges — top-right.  Failed-thumb
                        // warning icon piggy-backs on the indexed
                        // signal since only indexed entries can have
                        // a failure state.
                        if (entry.isHidden || entry.isIndexed)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Row(
                              children: [
                                if (entry.isHidden)
                                  const _MutedTag(label: 'Hidden'),
                                if (entry.isHidden && entry.isIndexed)
                                  const SizedBox(width: 4),
                                if (entry.media?.hasThumbnailFailed == true)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Tooltip(
                                      message:
                                          'Thumbnail generation failed.',
                                      waitDuration:
                                          Duration(milliseconds: 400),
                                      child: Icon(
                                        Icons.warning_amber_rounded,
                                        size: 13,
                                        color: AppColors.amber,
                                      ),
                                    ),
                                  ),
                                if (entry.isIndexed)
                                  _IndexedTag(
                                    indexedAtIso:
                                        entry.media?.indexedAtIso,
                                  ),
                              ],
                            ),
                          ),
                        if (entry.media?.isStreaming == true)
                          const Positioned(
                            top: 6,
                            left: 6,
                            child: _MutedTag(label: '▶ live', accent: true),
                          ),
                      ],
                    ),
                  ),
                ),
                // Bottom 40% — name + kind footer
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.name,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: entry.isHidden
                              ? AppColors.textFaint
                              : AppColors.textBody,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            _iconForKind(entry.kind),
                            size: 11,
                            color: _colorForKind(entry.kind),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            entry.isDir ? '—' : _humanBytes(entry.sizeBytes),
                            style: const TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 10,
                              color: AppColors.textMutedV2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap() {
    final cubit = context.read<LibraryBrowseCubit>();
    final kbd = HardwareKeyboard.instance;
    final ctrl = kbd.isControlPressed || kbd.isMetaPressed;
    final shift = kbd.isShiftPressed;
    if (ctrl) {
      _lastTapAt = null;
      cubit.toggleSelection(widget.entry.name);
      return;
    }
    if (shift) {
      _lastTapAt = null;
      cubit.extendSelection(widget.entry.name);
      return;
    }
    final now = DateTime.now();
    if (_lastTapAt != null &&
        now.difference(_lastTapAt!).inMilliseconds < 300) {
      _lastTapAt = null;
      _handleOpen();
      return;
    }
    _lastTapAt = now;
    cubit.selectOnly(widget.entry.name);
  }

  void _handleOpen() {
    if (widget.entry.isDir) {
      final target = widget.relativePath.isEmpty
          ? widget.entry.name
          : '${widget.relativePath}/${widget.entry.name}';
      context.read<LibraryBrowseCubit>().navigateTo(target);
      return;
    }
    final separator = widget.rootPath.contains(r'\') ? r'\' : '/';
    final tail = widget.relativePath.isEmpty
        ? widget.entry.name
        : '${widget.relativePath}/${widget.entry.name}';
    final absolute =
        '${widget.rootPath}$separator${tail.replaceAll('/', separator)}';
    launchUrl(Uri.file(absolute)).then((ok) {
      if (!ok && mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Could not open: ${widget.entry.name}')),
        );
      }
    });
  }

  Future<void> _showContextMenu(Offset position) async {
    final cubit = context.read<LibraryBrowseCubit>();
    if (!widget.isSelected) {
      cubit.selectOnly(widget.entry.name);
    }
    await showBrowseEntryContextMenu(
      context: context,
      position: position,
      entry: widget.entry,
      rootPath: widget.rootPath,
      relativePath: widget.relativePath,
    );
  }
}

/// The visual half of a grid tile — thumbnail if the media is indexed
/// and ready, otherwise a large kind icon on a tinted background.
class _GridTileVisual extends StatelessWidget {
  const _GridTileVisual({required this.entry});

  final BrowseEntry entry;

  @override
  Widget build(BuildContext context) {
    final hasThumb = entry.isIndexed &&
        entry.fileId != null &&
        entry.media?.hasThumbnailReady == true;
    if (hasThumb) {
      var base = GetIt.I<ApiClient>().localBaseUrl ?? '';
      if (base.endsWith('/')) base = base.substring(0, base.length - 1);
      final v = entry.media?.thumbnailGeneratedAtUnix ?? 0;
      final url = '$base/api/v1/files/${entry.fileId}/thumbnail?v=$v';
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _KindIconBackground(entry: entry),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _KindIconBackground(entry: entry),
      );
    }
    return _KindIconBackground(entry: entry);
  }
}

class _KindIconBackground extends StatelessWidget {
  const _KindIconBackground({required this.entry});

  final BrowseEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = _colorForKind(entry.kind);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.03),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _iconForKind(entry.kind),
          size: 44,
          color: color.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

/// One-shot icon button that cycles the listing density through the
/// three `BrowseDensity` modes (Compact → Cosy → Comfortable → ...).
/// Icon + tooltip update per mode.  Plan 28 Phase C.
class _DensityCycleButton extends StatelessWidget {
  const _DensityCycleButton({required this.density});

  final BrowseDensity density;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LibraryBrowseCubit>();
    final icon = switch (density) {
      BrowseDensity.compact => Icons.density_small_rounded,
      BrowseDensity.cosy => Icons.density_medium_rounded,
      BrowseDensity.comfortable => Icons.density_large_rounded,
    };
    final tooltip = switch (density) {
      BrowseDensity.compact => 'Density: Compact (click for Cosy)',
      BrowseDensity.cosy => 'Density: Cosy (click for Comfortable)',
      BrowseDensity.comfortable => 'Density: Comfortable (click for Compact)',
    };
    return _ToolbarIconButton(
      icon: icon,
      tooltip: tooltip,
      onTap: () {
        final next = switch (density) {
          BrowseDensity.compact => BrowseDensity.cosy,
          BrowseDensity.cosy => BrowseDensity.comfortable,
          BrowseDensity.comfortable => BrowseDensity.compact,
        };
        cubit.setDensity(next);
      },
    );
  }
}

class _ToolbarIconButton extends StatefulWidget {
  const _ToolbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.compact = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;
  final bool compact;

  @override
  State<_ToolbarIconButton> createState() => _ToolbarIconButtonState();
}

class _ToolbarIconButtonState extends State<_ToolbarIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final size = widget.compact ? 24.0 : 28.0;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true && enabled),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.tooltip,
          waitDuration: const Duration(milliseconds: 600),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: widget.active
                  ? const Color(0x1AA855F7)
                  : (_hovered
                      ? const Color(0x0DA855F7)
                      : Colors.transparent),
              border: Border.all(
                color: widget.active || _hovered
                    ? const Color(0x33A855F7)
                    : Colors.transparent,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: widget.compact ? 13 : 14,
              color: enabled
                  ? (widget.active || _hovered
                      ? AppColors.violet
                      : AppColors.textMutedV2)
                  : AppColors.textFaint,
            ),
          ),
        ),
      ),
    );
  }
}

class _MutedTag extends StatelessWidget {
  const _MutedTag({required this.label, this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppColors.violet : AppColors.textMutedV2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Variant of `_MutedTag` for the `Indexed` badge — long-hover reveals
/// the row's `indexed_at_iso` date so the operator can tell when the
/// scanner last touched the file.  Plan 28 §5.5 polish.
class _IndexedTag extends StatelessWidget {
  const _IndexedTag({this.indexedAtIso});

  /// ISO-8601 timestamp from `BrowseEntry.media.indexedAtIso`.  Null
  /// means the indexed-status came from a backfill row that pre-dated
  /// the media_files.created_at column — render the tag without a
  /// tooltip date.
  final String? indexedAtIso;

  @override
  Widget build(BuildContext context) {
    final tooltip = _formatIndexedTooltip(indexedAtIso);
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: const _MutedTag(label: 'Indexed', accent: true),
    );
  }

  static String _formatIndexedTooltip(String? iso) {
    if (iso == null || iso.isEmpty) {
      return 'Tracked in the streaming catalog';
    }
    try {
      final dt = DateTime.parse(iso).toLocal();
      final y = dt.year.toString();
      final mo = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final mi = dt.minute.toString().padLeft(2, '0');
      return 'Indexed $y-$mo-$d $h:$mi';
    } catch (_) {
      return 'Tracked in the streaming catalog';
    }
  }
}

IconData _iconForKind(BrowseKind kind) => switch (kind) {
      BrowseKind.directory => Icons.folder_rounded,
      BrowseKind.video => Icons.movie_outlined,
      BrowseKind.image => Icons.image_outlined,
      BrowseKind.audio => Icons.music_note_outlined,
      BrowseKind.pdf => Icons.picture_as_pdf_outlined,
      BrowseKind.other => Icons.insert_drive_file_outlined,
    };

Color _colorForKind(BrowseKind kind) => switch (kind) {
      BrowseKind.directory => AppColors.violet,
      BrowseKind.video => AppColors.violet,
      BrowseKind.image => AppColors.cyan,
      BrowseKind.audio => AppColors.pink,
      BrowseKind.pdf => AppColors.red,
      BrowseKind.other => AppColors.textMutedV2,
    };

String _humanBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final formatted = value >= 100 || unit == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$formatted ${units[unit]}';
}

String _formatModified(String iso) {
  if (iso.isEmpty) return '—';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays < 1) {
      // Today — show HH:mm
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return 'Today $h:$m';
    }
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    // ISO-ish absolute date
    final y = dt.year.toString();
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$mo-$d';
  } catch (_) {
    return '—';
  }
}
