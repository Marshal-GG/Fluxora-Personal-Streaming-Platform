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

import 'package:fluxora_desktop/core/router/app_router.dart';
import 'package:fluxora_desktop/features/library/domain/entities/browse_entry.dart';
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_desktop/features/library/data/services/library_events_service.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_browse_cubit.dart';
import 'package:fluxora_desktop/features/library/presentation/widgets/library_browse_context_menu.dart';
import 'package:fluxora_desktop/features/library/presentation/widgets/library_browse_count_footer.dart';
import 'package:fluxora_desktop/features/library/presentation/widgets/library_browse_detail_panel.dart';
import 'package:fluxora_desktop/features/library/presentation/widgets/library_browse_search_bar.dart';
import 'package:fluxora_desktop/features/library/presentation/widgets/library_browse_view_toggle.dart';
import 'package:fluxora_desktop/shared/widgets/flux_card.dart';
import 'package:fluxora_desktop/shared/widgets/flux_glass_popup_surface.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';

final _log = Logger();

class LibraryFilesScreen extends StatelessWidget {
  const LibraryFilesScreen({super.key, required this.libraryId});

  final String libraryId;

  @override
  Widget build(BuildContext context) {
    // Pull the events service from GetIt if registered; tests + early-
    // startup paths register it on demand.  Cubit gracefully no-ops on
    // null so we don't have to guard at every screen mount.
    final events = GetIt.I.isRegistered<LibraryEventsService>()
        ? GetIt.I<LibraryEventsService>()
        : null;
    return BlocProvider<LibraryBrowseCubit>(
      create: (_) => LibraryBrowseCubit(
        libraryId: libraryId,
        repository: GetIt.I<LibraryRepository>(),
        events: events,
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
    // Only fire body shortcuts when the body itself has primary focus.
    // If a child (URL-bar TextField, search field, etc.) has focus,
    // its keystrokes — including `/`, Enter, Backspace, arrows — must
    // reach it untouched.  Without this guard the body steals `/`
    // into the search box while the operator is typing a path, and
    // Backspace pops the directory stack instead of deleting a char.
    if (!_bodyFocus.hasPrimaryFocus) {
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
              verticalPadding: AppSpacing.s16,
            ),
          ),
          // (Type filters moved into the toolbar's `_FilterButton`
          // dropdown — no chip strip above the card any more.)
          const SizedBox(height: AppSpacing.s8),
          // Body card.  Encloses the URL/breadcrumb header + the
          // toggle-icon toolbar directly below it + a horizontal
          // divider that visually separates the header band from the
          // scrollable listing + the listing itself + the count
          // footer + the right detail panel — all inside one
          // continuous FluxCard surface so the header reads as part
          // of the same surface but the listing area sits in a
          // visually-distinct band below.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s28, 0, AppSpacing.s28, AppSpacing.s14,
              ),
              child: FluxCard(
                padding: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // URL / breadcrumb row — elevated band token gives
                    // a slightly lighter tint than the card surface.
                    Container(
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceBandHigh,
                        border: Border(
                          bottom: BorderSide(color: AppColors.borderSubtle),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.s14,
                        AppSpacing.s10,
                        AppSpacing.s14,
                        AppSpacing.s10,
                      ),
                      child: _BreadcrumbBar(searchFocusNode: _searchFocus),
                    ),
                    // Toolbar icon row — depressed band token gives a
                    // distinct darker stripe right below the URL row.
                    Container(
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceBandLow,
                        border: Border(
                          bottom: BorderSide(color: AppColors.borderSubtle),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s14,
                        vertical: AppSpacing.s8,
                      ),
                      child: const _ListingToolbar(),
                    ),
                    // Main split: listing on the left, detail panel
                    // on the right.  Vertical divider in between
                    // keeps the two halves readable without giving
                    // either its own background.
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.s12,
                                        ),
                                        child: BlocBuilder<LibraryBrowseCubit,
                                            LibraryBrowseState>(
                                          // Listing body only rebuilds
                                          // on a real change: state-type
                                          // flip OR a new response
                                          // object (identity changes
                                          // when a fetch lands).  Soft-
                                          // refresh's "refreshing flag
                                          // flip" with the same
                                          // response identity is
                                          // skipped — the strip above
                                          // already animates.
                                          buildWhen: (a, b) {
                                            if (a.runtimeType !=
                                                b.runtimeType) {
                                              return true;
                                            }
                                            if (a is LibraryBrowseLoaded &&
                                                b is LibraryBrowseLoaded) {
                                              return !identical(
                                                a.response,
                                                b.response,
                                              );
                                            }
                                            return true;
                                          },
                                          builder: (context, state) =>
                                              switch (state) {
                                            LibraryBrowseInitial() ||
                                            LibraryBrowseLoading() =>
                                              const _BrowseLoadingBody(),
                                            LibraryBrowseLoaded(
                                              :final response
                                            ) =>
                                              _BrowseBody(response: response),
                                            LibraryBrowseFailure(
                                              :final message
                                            ) =>
                                              _BrowseFailureBody(
                                                  message: message),
                                          },
                                        ),
                                      ),
                                      // Soft-refresh indicator — thin
                                      // violet bar at the very top of
                                      // the listing area while a
                                      // background re-fetch is in
                                      // flight.  Chrome stays mounted;
                                      // only this 2 px strip animates.
                                      const Positioned(
                                        top: 0,
                                        left: 0,
                                        right: 0,
                                        child: _RefreshIndicatorStrip(),
                                      ),
                                    ],
                                  ),
                                ),
                                const _CardFooterDivider(),
                                // Footer band — same depressed tint
                                // as the toolbar row above the
                                // listing so the scrollable body is
                                // bracketed by two matching darker
                                // stripes.
                                Container(
                                  decoration: const BoxDecoration(
                                    color: AppColors.surfaceBandLow,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.s14,
                                  ),
                                  child: const LibraryBrowseCountFooter(),
                                ),
                              ],
                            ),
                          ),
                          const _CardVerticalDivider(),
                          const LibraryBrowseDetailPanel(),
                        ],
                      ),
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
}

// (Page-header actions slot is empty for this screen — the only
// path-scoped action, "Open in Explorer", moved into the URL field
// as a trailing icon next to "Copy path"; the toggle icons (hide /
// refresh / density / view) live in `_ListingToolbar` inside the
// body card.)

// ── In-card listing toolbar — sits directly below the URL header ──────────

/// Toggle/refresh/density/view icons rendered inside the body card,
/// directly under the URL / breadcrumb header.  Placing them here keeps
/// the actions visually attached to the listing they operate on instead
/// of floating in the page header where the operator has to track them
/// against the breadcrumb separately.
class _ListingToolbar extends StatelessWidget {
  const _ListingToolbar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryBrowseCubit, LibraryBrowseState>(
      buildWhen: (a, b) {
        if (a.runtimeType != b.runtimeType) return true;
        if (a is LibraryBrowseLoaded && b is LibraryBrowseLoaded) {
          if (identical(a.response, b.response) &&
              a.refreshing != b.refreshing) {
            return false;
          }
        }
        return true;
      },
      builder: (context, _) {
        final cubit = context.read<LibraryBrowseCubit>();
        return Row(
          children: [
            // Left side: utility icon cluster (hide-hidden / refresh /
            // density / view toggle).  Right side: Filter dropdown.
            // Sort is column-header-only — click NAME / SIZE /
            // MODIFIED to sort.
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
            _ToolbarIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh',
              onTap: () => cubit.refresh(),
            ),
            const SizedBox(width: AppSpacing.s8),
            _DensityCycleButton(density: cubit.density),
            const SizedBox(width: AppSpacing.s10),
            const LibraryBrowseViewToggle(),
            const Spacer(),
            _FilterButton(cubit: cubit),
          ],
        );
      },
    );
  }
}

/// Pill-styled Filter dropdown on the left of the toolbar.
///
/// Trigger chip shows the active filter summary ("Filter" / "Filter:
/// Videos" / "Filter: Videos · Indexed" / "Filter: Indexed") + a
/// chevron-down to signal "click for more."  Active state (any non-
/// default filter) tints the chip violet so the operator can see at a
/// glance that a filter is applied.
///
/// Tapping the chip opens a sticky [_FilterPopup] anchored beneath it
/// via [OverlayPortal] + [CompositedTransformFollower].  The popup
/// stays mounted while the operator toggles kind / indexed-only — only
/// dismisses on tap-outside or a second click on the trigger.
class _FilterButton extends StatefulWidget {
  const _FilterButton({required this.cubit});

  final LibraryBrowseCubit cubit;

  @override
  State<_FilterButton> createState() => _FilterButtonState();
}

class _FilterButtonState extends State<_FilterButton> {
  final LayerLink _link = LayerLink();
  final OverlayPortalController _popup = OverlayPortalController();
  bool _hover = false;

  // Chip height tuned to match the surrounding 28 px toolbar icon
  // buttons visually — slightly shorter so the rounded pill doesn't
  // dominate, but tall enough to read as a peer of the icon row.
  static const double _kButtonHeight = 26;

  void _toggle() {
    if (_popup.isShowing) {
      _popup.hide();
    } else {
      _popup.show();
    }
  }

  String _kindLabel(BrowseKindFilter kind) => switch (kind) {
        BrowseKindFilter.all => 'All',
        BrowseKindFilter.folders => 'Folders',
        BrowseKindFilter.videos => 'Videos',
        BrowseKindFilter.images => 'Images',
        BrowseKindFilter.audio => 'Audio',
        BrowseKindFilter.pdfs => 'PDFs',
        BrowseKindFilter.other => 'Other',
      };

  String _summary() {
    final c = widget.cubit;
    final parts = <String>[];
    if (c.kindFilter != BrowseKindFilter.all) {
      parts.add(_kindLabel(c.kindFilter));
    }
    if (c.indexedOnly) parts.add('Indexed');
    if (parts.isEmpty) return 'Filter';
    return 'Filter: ${parts.join(' · ')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cubit;
    final hasActive =
        c.kindFilter != BrowseKindFilter.all || c.indexedOnly;
    final fg = hasActive
        ? AppColors.violetSoft
        : (_hover ? AppColors.textBody : AppColors.textMutedV2);
    final bg = hasActive
        ? const Color(0x24A855F7)
        : (_hover ? const Color(0x08FFFFFF) : Colors.transparent);
    final border = hasActive
        ? const Color(0x4DA855F7)
        : AppColors.borderSubtle;

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _popup,
        overlayChildBuilder: (_) => _FilterPopup(
          link: _link,
          cubit: c,
          onDismiss: _popup.hide,
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: _kButtonHeight,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s10,
              ),
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_list_rounded, size: 12, color: fg),
                  const SizedBox(width: 6),
                  Text(
                    _summary(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      fontWeight:
                          hasActive ? FontWeight.w600 : FontWeight.w500,
                      color: fg,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down_rounded, size: 14, color: fg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sticky filter popover mounted via [OverlayPortal] beneath the
/// trigger.  Glass surface (via [FluxGlassPopupSurface]) so it matches
/// the row context menu + column picker visually.  Tap-outside via
/// [TapRegion] dismisses; clicking inside (selecting a kind, toggling
/// "Indexed only") does NOT dismiss — operator can rapid-fire toggle
/// multiple filters and see the listing update in place.
class _FilterPopup extends StatelessWidget {
  const _FilterPopup({
    required this.link,
    required this.cubit,
    required this.onDismiss,
  });

  final LayerLink link;
  final LibraryBrowseCubit cubit;
  final VoidCallback onDismiss;

  static const double _kWidth = 220;
  // Small vertical gap between the trigger's bottom edge and the
  // popup's top edge — large enough to read as "separate surface,"
  // small enough that the cursor's natural downward motion stays on
  // the popup without re-targeting.
  static const double _kGap = 6;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      // Anchored via CompositedTransformFollower below — Positioned
      // just hands the overlay a finite frame so it doesn't expand.
      // The Filter button sits on the RIGHT side of the toolbar, so
      // we right-align the popup to the trigger (popup's top-right
      // corner anchors to the trigger's bottom-right corner) so the
      // popup extends DOWN+LEFT and stays on-screen.
      left: 0,
      top: 0,
      width: _kWidth,
      child: CompositedTransformFollower(
        link: link,
        targetAnchor: Alignment.bottomRight,
        followerAnchor: Alignment.topRight,
        offset: const Offset(0, _kGap),
        showWhenUnlinked: false,
        child: Material(
          color: Colors.transparent,
          child: TapRegion(
            onTapOutside: (_) => onDismiss(),
            child: FluxGlassPopupSurface(
              width: _kWidth,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              // Rebuild on every cubit emission so the active checkmark
              // updates the same frame as the operator's tap.  Cheap —
              // the popup body is ~9 rows of static widgets.
              child: BlocBuilder<LibraryBrowseCubit, LibraryBrowseState>(
                bloc: cubit,
                builder: (_, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
                      child: Text(
                        'SHOW',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: AppColors.textMutedV2,
                        ),
                      ),
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.borderSubtle,
                    ),
                    for (final kind in BrowseKindFilter.values)
                      _FilterKindRow(
                        kind: kind,
                        isActive: cubit.kindFilter == kind,
                        onTap: () => cubit.setKindFilter(kind),
                      ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.borderSubtle,
                    ),
                    _FilterToggleRow(
                      label: 'Indexed only',
                      icon: cubit.indexedOnly
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_outline_rounded,
                      isActive: cubit.indexedOnly,
                      onTap: () => cubit.setIndexedOnly(!cubit.indexedOnly),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Single kind-filter row inside the [_FilterPopup].  Tap selects the
/// kind (single-select within the group) without dismissing the popup.
class _FilterKindRow extends StatefulWidget {
  const _FilterKindRow({
    required this.kind,
    required this.isActive,
    required this.onTap,
  });

  final BrowseKindFilter kind;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_FilterKindRow> createState() => _FilterKindRowState();
}

class _FilterKindRowState extends State<_FilterKindRow> {
  bool _hover = false;

  IconData _iconFor(BrowseKindFilter k) => switch (k) {
        BrowseKindFilter.all => Icons.apps_rounded,
        BrowseKindFilter.folders => Icons.folder_outlined,
        BrowseKindFilter.videos => Icons.movie_outlined,
        BrowseKindFilter.images => Icons.image_outlined,
        BrowseKindFilter.audio => Icons.music_note_outlined,
        BrowseKindFilter.pdfs => Icons.picture_as_pdf_outlined,
        BrowseKindFilter.other => Icons.insert_drive_file_outlined,
      };

  String _labelFor(BrowseKindFilter k) => switch (k) {
        BrowseKindFilter.all => 'All',
        BrowseKindFilter.folders => 'Folders',
        BrowseKindFilter.videos => 'Videos',
        BrowseKindFilter.images => 'Images',
        BrowseKindFilter.audio => 'Audio',
        BrowseKindFilter.pdfs => 'PDFs',
        BrowseKindFilter.other => 'Other',
      };

  @override
  Widget build(BuildContext context) {
    final fg = widget.isActive
        ? AppColors.violetSoft
        : (_hover ? AppColors.textBody : AppColors.textMutedV2);
    final bg = widget.isActive
        ? const Color(0x1AA855F7)
        : (_hover ? const Color(0x08FFFFFF) : Colors.transparent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(_iconFor(widget.kind), size: 14, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _labelFor(widget.kind),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight:
                        widget.isActive ? FontWeight.w600 : FontWeight.w500,
                    color: fg,
                  ),
                ),
              ),
              if (widget.isActive)
                const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: AppColors.violetSoft,
                )
              else
                const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }
}

/// Toggle row used for the "Indexed only" entry below the divider.
/// Same hover + active treatment as [_FilterKindRow] but the trailing
/// glyph is a check-on/off pair to communicate that it's a binary
/// toggle independent of the single-select group above.
class _FilterToggleRow extends StatefulWidget {
  const _FilterToggleRow({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_FilterToggleRow> createState() => _FilterToggleRowState();
}

class _FilterToggleRowState extends State<_FilterToggleRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.isActive
        ? AppColors.violetSoft
        : (_hover ? AppColors.textBody : AppColors.textMutedV2);
    final bg = widget.isActive
        ? const Color(0x1AA855F7)
        : (_hover ? const Color(0x08FFFFFF) : Colors.transparent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(widget.icon, size: 14, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight:
                        widget.isActive ? FontWeight.w600 : FontWeight.w500,
                    color: fg,
                  ),
                ),
              ),
              Icon(
                widget.isActive
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 14,
                color: fg,
              ),
            ],
          ),
        ),
      ),
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

  // ── Autocomplete plumbing ─────────────────────────────────────────────────
  // Suggestions popup anchored below the path field while editing.
  // `_fieldLink` anchors the OverlayPortal to the field's RenderBox;
  // `_suggestionsController` toggles the portal's visibility.

  final LayerLink _fieldLink = LayerLink();
  final OverlayPortalController _suggestionsController =
      OverlayPortalController();
  List<PathSuggestion> _suggestions = const [];
  int _highlightedSuggestion = -1;
  int _suggestionRequestSeq = 0;
  Timer? _suggestionDebounce;
  double _fieldWidth = 0;

  @override
  void initState() {
    super.initState();
    _pathController.addListener(_onPathTextChanged);
  }

  @override
  void dispose() {
    _suggestionDebounce?.cancel();
    _pathController.removeListener(_onPathTextChanged);
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
      _suggestions = const [];
      _highlightedSuggestion = -1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pathFocus.requestFocus();
      _suggestionsController.show();
      _scheduleSuggestionFetch();
    });
  }

  void _cancelEdit() {
    _suggestionDebounce?.cancel();
    if (_suggestionsController.isShowing) {
      _suggestionsController.hide();
    }
    setState(() {
      _editing = false;
      _validationError = null;
      _suggestions = const [];
      _highlightedSuggestion = -1;
    });
  }

  Future<void> _commitEdit({String? overrideInput}) async {
    final input = (overrideInput ?? _pathController.text).trim();
    final cubit = context.read<LibraryBrowseCubit>();
    _suggestionDebounce?.cancel();
    final ok = await cubit.navigateToAbsolute(input);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _validationError = 'Path is outside this library or does not exist';
      });
      return;
    }
    if (_suggestionsController.isShowing) {
      _suggestionsController.hide();
    }
    setState(() {
      _editing = false;
      _validationError = null;
      _suggestions = const [];
      _highlightedSuggestion = -1;
    });
  }

  void _onPathTextChanged() {
    if (!_editing) return;
    // Reset highlight on every keystroke so Tab/Enter completes to
    // the first match rather than a stale highlight pointing past
    // the new visible list.
    if (_highlightedSuggestion != -1) {
      setState(() => _highlightedSuggestion = -1);
    }
    _scheduleSuggestionFetch();
  }

  void _scheduleSuggestionFetch() {
    _suggestionDebounce?.cancel();
    _suggestionDebounce = Timer(
      const Duration(milliseconds: 120),
      _fetchSuggestions,
    );
  }

  Future<void> _fetchSuggestions() async {
    if (!_editing || !mounted) return;
    final seq = ++_suggestionRequestSeq;
    final input = _pathController.text;
    final cubit = context.read<LibraryBrowseCubit>();
    final result = await cubit.pathSuggestions(input);
    // Drop the response if a newer request has started while we were
    // awaiting, or the field has since exited edit mode.
    if (!mounted || seq != _suggestionRequestSeq || !_editing) return;
    setState(() {
      _suggestions = result;
      // Clamp the highlight: if it points past the new list, reset.
      if (_highlightedSuggestion >= result.length) {
        _highlightedSuggestion = -1;
      }
    });
  }

  /// Build the completed field text for picking [entry] —
  /// `<parentOfCurrentInput><separator><entry.name>`.  No trailing
  /// separator: the commit path strips it anyway and the visible URL
  /// reads as a finished destination (matches Explorer's autocomplete).
  String _completedPathFor(BrowseEntry entry) {
    final input = _pathController.text;
    final separator = input.contains(r'\') ? r'\' : '/';
    final slashIdx = _lastSeparatorIndex(input, separator);
    final parent = slashIdx == -1 ? input : input.substring(0, slashIdx + 1);
    return '$parent${entry.name}';
  }

  /// Used by Tab + tentative suggestion completions — writes the
  /// completion into the field but does NOT navigate, so the operator
  /// can keep typing.
  void _completeSuggestion(BrowseEntry entry) {
    final completed = _completedPathFor(entry);
    final separator = completed.contains(r'\') ? r'\' : '/';
    final withTrailing = '$completed$separator';
    _pathController.value = TextEditingValue(
      text: withTrailing,
      selection: TextSelection.collapsed(offset: withTrailing.length),
    );
    // Listener re-fetches suggestions for the new path.
    _pathFocus.requestFocus();
  }

  /// Suggestion CLICK / Enter handler — navigates DIRECTLY to the
  /// suggestion's relative path via `cubit.navigateTo(...)`, which
  /// bypasses [navigateToAbsolute]'s absolute-string-prefix matching
  /// (fragile across multi-root libraries / case mismatches / stale
  /// `rootPath` values).  The cubit already used this exact relative
  /// to fetch the suggestion from the server, so the path is
  /// guaranteed valid.  Updates the field text to the navigated
  /// destination + closes the popup + exits edit mode on success.
  Future<void> _pickSuggestion(PathSuggestion suggestion) async {
    final cubit = context.read<LibraryBrowseCubit>();
    _suggestionDebounce?.cancel();
    await cubit.navigateTo(suggestion.relativePath);
    if (!mounted) return;
    final landed = cubit.state;
    if (landed is! LibraryBrowseLoaded) {
      setState(() {
        _validationError = 'Could not open ${suggestion.entry.name}';
      });
      return;
    }
    if (_suggestionsController.isShowing) {
      _suggestionsController.hide();
    }
    setState(() {
      _editing = false;
      _validationError = null;
      _suggestions = const [];
      _highlightedSuggestion = -1;
    });
  }

  int _lastSeparatorIndex(String s, String sep) {
    // Match either separator regardless of which one the input used.
    final ix1 = s.lastIndexOf('/');
    final ix2 = s.lastIndexOf(r'\');
    if (ix1 == -1) return ix2;
    if (ix2 == -1) return ix1;
    return ix1 > ix2 ? ix1 : ix2;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryBrowseCubit, LibraryBrowseState>(
      // Breadcrumb only depends on the path itself + history.  Skip
      // rebuilds when only the refreshing flag flipped or a pure
      // pref re-emit fired with the same path.  History changes
      // (goBack / goForward / navigateTo) all change relativePath
      // too, so the path-change check covers them.
      buildWhen: (a, b) {
        if (a.runtimeType != b.runtimeType) return true;
        if (a is LibraryBrowseLoaded && b is LibraryBrowseLoaded) {
          return a.response.relativePath != b.response.relativePath ||
              a.response.rootPath != b.response.rootPath;
        }
        return true;
      },
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

        // Path field — same field-style chrome in both display and
        // edit modes so the bar always reads as an editable field and
        // size doesn't shift on toggle.  Display mode mounts the
        // breadcrumb chip row inside the field; edit mode swaps in a
        // bare TextField with no own decoration (the wrapper owns the
        // border / fill / radius).  Trailing icons (copy path +
        // open-in-explorer) live inside the field at its right edge
        // so they read as path actions instead of toolbar chrome.
        final pathField = _PathField(
          editing: _editing,
          validationError: _validationError,
          onTapDisplay: () => _beginEdit(state),
          trailing: [
            _ToolbarIconButton(
              icon: Icons.copy_rounded,
              tooltip: 'Copy absolute path',
              compact: true,
              onTap: () => _copyAbsolutePath(context, response),
            ),
            const SizedBox(width: 2),
            _ToolbarIconButton(
              icon: Icons.folder_open_outlined,
              tooltip: 'Open current folder in Explorer',
              compact: true,
              onTap: () => _openCurrentInFileManager(context, state),
            ),
          ],
          editChild: Focus(
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent || event is KeyRepeatEvent) {
                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  _cancelEdit();
                  return KeyEventResult.handled;
                }
                // Autocomplete keyboard nav.  Down/Up moves the
                // highlight through the visible suggestion list; Tab
                // completes to the highlighted entry (or the first
                // entry when nothing is highlighted yet).
                if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
                    _suggestions.isNotEmpty) {
                  setState(() {
                    _highlightedSuggestion =
                        (_highlightedSuggestion + 1)
                            .clamp(0, _suggestions.length - 1);
                  });
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
                    _suggestions.isNotEmpty) {
                  setState(() {
                    _highlightedSuggestion = _highlightedSuggestion <= 0
                        ? _suggestions.length - 1
                        : _highlightedSuggestion - 1;
                  });
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.tab &&
                    _suggestions.isNotEmpty) {
                  final pick = _highlightedSuggestion >= 0
                      ? _suggestions[_highlightedSuggestion]
                      : _suggestions.first;
                  _completeSuggestion(pick.entry);
                  return KeyEventResult.handled;
                }
                // Explicit Enter handler — `TextField.onSubmitted`
                // fires from the IME submit action but doesn't always
                // consume the key event, so the body-level Focus
                // handler ends up grabbing Enter for "open selected"
                // before the commit completes.  Swallowing Enter here
                // routes it through `_commitEdit` exclusively.  When
                // a suggestion is highlighted, navigate directly via
                // the suggestion's relative path — that's the path
                // the cubit already used to fetch the suggestion, so
                // it's guaranteed valid (no absolute-prefix-match
                // dance that breaks across multi-root libraries).
                if (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                  if (_highlightedSuggestion >= 0 &&
                      _highlightedSuggestion < _suggestions.length) {
                    _pickSuggestion(_suggestions[_highlightedSuggestion]);
                  } else {
                    _commitEdit();
                  }
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _pathController,
              focusNode: _pathFocus,
              // `onSubmitted` deliberately omitted — Enter is handled
              // by the wrapper Focus above so we don't double-fire
              // `_commitEdit` on platforms where EditableText calls
              // both the IME submit action AND lets the key bubble.
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                color: AppColors.textBright,
                height: 1.2,
              ),
              cursorColor: AppColors.violet,
              decoration: const InputDecoration(
                isDense: true,
                isCollapsed: true,
                border: InputBorder.none,
                hintText: r'D:\Library\Subdir',
                hintStyle: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  color: AppColors.textFaint,
                ),
              ),
            ),
          ),
          displayChild: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: chips),
          ),
        );

        // Wrap the path field in a CompositedTransformTarget + a
        // size-tracking LayoutBuilder so the suggestions OverlayPortal
        // can anchor itself directly below the field, matching its
        // width.  The OverlayPortal mounts a popup at root-overlay
        // level (escapes the FluxCard's clip) only while editing.
        final pathFieldWithSuggestions = LayoutBuilder(
          builder: (context, constraints) {
            // Cache width so the post-frame portal builder has it on
            // first paint.  Reading `constraints.maxWidth` here keeps
            // the popup in sync with field-width changes (sidebar
            // collapse, etc.) without extra plumbing.
            if (_fieldWidth != constraints.maxWidth) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _fieldWidth = constraints.maxWidth);
              });
            }
            return CompositedTransformTarget(
              link: _fieldLink,
              child: OverlayPortal(
                controller: _suggestionsController,
                overlayChildBuilder: (_) => _SuggestionsOverlay(
                  link: _fieldLink,
                  width: _fieldWidth > 0
                      ? _fieldWidth
                      : constraints.maxWidth,
                  // Offset Y by the field height (30) + a small gap.
                  verticalOffset: _PathFieldState._kHeight + 4,
                  suggestions: _suggestions,
                  highlighted: _highlightedSuggestion,
                  onPick: _pickSuggestion,
                  onHover: (i) => setState(() {
                    _highlightedSuggestion = i;
                  }),
                ),
                child: pathField,
              ),
            );
          },
        );

        // Cluster the path field + its trailing action buttons
        // (check / close in edit mode, edit-pencil otherwise) under
        // one `TapRegion` so a tap anywhere OUTSIDE this group while
        // editing cancels the edit.  Without grouping the buttons in
        // with the field, tapping the check button would fire the
        // outside-tap handler before the button's onTap and we'd
        // cancel instead of commit.
        //
        // The suggestions OverlayPortal mounts at root-overlay level
        // (outside this TapRegion's tree) so by default clicking a
        // suggestion fires `onTapOutside` and cancels the edit before
        // the suggestion's onTap runs.  The shared `groupId` ties both
        // regions into one "outside" — taps inside either count as
        // inside both.  Without this, suggestion clicks silently
        // close the dropdown instead of completing the path.
        final fieldCluster = TapRegion(
          groupId: _kPathFieldTapGroup,
          onTapOutside: _editing ? (_) => _cancelEdit() : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(child: pathFieldWithSuggestions),
              const SizedBox(width: AppSpacing.s6),
              if (_editing) ...[
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
              ] else
                _ToolbarIconButton(
                  icon: Icons.edit_rounded,
                  tooltip: 'Edit path',
                  onTap: () => _beginEdit(state),
                ),
            ],
          ),
        );

        return Row(
          children: [
            historyButtons,
            const SizedBox(width: AppSpacing.s4),
            upButton,
            const SizedBox(width: AppSpacing.s8),
            Expanded(child: fieldCluster),
            const SizedBox(width: AppSpacing.s10),
            LibraryBrowseSearchBar(
              width: 240,
              focusNode: widget.searchFocusNode,
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

/// Field-style wrapper that hosts either the breadcrumb chip row
/// (display mode) or a bare [TextField] (edit mode).  Same border /
/// fill / radius / height in both modes so the bar reads as an
/// editable field at rest AND doesn't change size on toggle.
///
/// Click anywhere on the field in display mode → enters edit mode
/// via [onTapDisplay].  Hover bumps the border to a subtle violet
/// tint; edit mode pins it to the full violet to match focus state.
///
/// [trailing] mounts trailing affordances (copy / open-in-explorer)
/// inside the field's right edge, separated from the breadcrumb /
/// TextField content by a thin vertical hairline.  Trailing widgets
/// receive their own clicks; the field's outer GestureDetector skips
/// pointer events on the trailing zone via per-button hit testing.
class _PathField extends StatefulWidget {
  const _PathField({
    required this.editing,
    required this.editChild,
    required this.displayChild,
    required this.onTapDisplay,
    this.trailing,
    this.validationError,
  });

  final bool editing;
  final Widget editChild;
  final Widget displayChild;
  final VoidCallback onTapDisplay;
  final List<Widget>? trailing;
  final String? validationError;

  @override
  State<_PathField> createState() => _PathFieldState();
}

class _PathFieldState extends State<_PathField> {
  bool _hovered = false;

  static const double _kHeight = 30;

  @override
  Widget build(BuildContext context) {
    final bool focusLook = widget.editing;
    final bool errored = widget.validationError != null;
    final Color borderColor = errored
        ? AppColors.red
        : (focusLook
            ? AppColors.violet
            : (_hovered
                ? AppColors.borderHover
                : AppColors.borderSubtle));
    final double borderWidth = focusLook ? 1.5 : 1;

    // The Container is the full hit area for the field — padding +
    // border + fill all live here so the whole rectangle (not just
    // the inner content) registers clicks.  Trailing affordances
    // (when provided) sit at the right edge with a thin hairline
    // separator; their own GestureDetectors take precedence over the
    // outer click-to-edit handler so tapping them runs the trailing
    // action instead of entering edit mode.
    final inner = widget.editing
        ? Align(
            alignment: Alignment.centerLeft,
            child: widget.editChild,
          )
        : widget.displayChild;

    final hasTrailing = widget.trailing != null && widget.trailing!.isNotEmpty;
    final Widget contentRow = Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(child: ClipRect(child: inner)),
        if (hasTrailing) ...[
          const SizedBox(width: AppSpacing.s6),
          const _PathFieldTrailingDivider(),
          const SizedBox(width: AppSpacing.s6),
          for (final t in widget.trailing!) t,
        ],
      ],
    );

    final Widget innerField = Container(
      height: _kHeight,
      decoration: BoxDecoration(
        color: AppColors.surfaceBandLow,
        border: Border.all(color: borderColor, width: borderWidth),
        borderRadius: BorderRadius.circular(AppRadii.sm - 1),
      ),
      padding: const EdgeInsets.only(
        left: AppSpacing.s10,
        right: AppSpacing.s4,
      ),
      alignment: Alignment.centerLeft,
      child: contentRow,
    );

    final Widget interactive = MouseRegion(
      cursor: widget.editing
          ? SystemMouseCursors.basic
          : SystemMouseCursors.text,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.editing
          ? innerField
          : Tooltip(
              message: 'Click to edit path',
              waitDuration: const Duration(milliseconds: 600),
              // GestureDetector wraps the whole Container so a click
              // anywhere inside the field's rectangle (including its
              // padding and the empty area to the right of the
              // breadcrumb chips) enters edit mode.
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTapDisplay,
                child: innerField,
              ),
            ),
    );

    if (widget.validationError == null) return interactive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        interactive,
        const SizedBox(height: 4),
        Text(
          widget.validationError!,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: AppColors.red,
          ),
        ),
      ],
    );
  }
}

/// 1-px hairline rendered between the breadcrumb / TextField inner
/// content and the trailing affordance cluster inside [_PathField].
class _PathFieldTrailingDivider extends StatelessWidget {
  const _PathFieldTrailingDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 1,
      height: 16,
      child: ColoredBox(color: AppColors.borderSubtle),
    );
  }
}

/// Suggestions popup anchored under the editable path field.
/// Mounted via `OverlayPortal` at root-overlay level so the FluxCard's
/// clip rect doesn't truncate it.  Uses `CompositedTransformFollower`
/// to track the field's position when the page scrolls or the layout
/// shifts mid-edit.
/// Shared `TapRegion.groupId` for the URL-bar field cluster + the
/// suggestions-overlay popup.  Two `TapRegion`s with the same group
/// are treated as one "outside" for tap detection — clicking a
/// suggestion no longer fires the field cluster's `onTapOutside`
/// (which would cancel edit mode before the suggestion's onTap
/// could run).  Top-level so both regions reference the same Object
/// identity without plumbing it through widget constructors.
final Object _kPathFieldTapGroup = Object();

class _SuggestionsOverlay extends StatelessWidget {
  const _SuggestionsOverlay({
    required this.link,
    required this.width,
    required this.verticalOffset,
    required this.suggestions,
    required this.highlighted,
    required this.onPick,
    required this.onHover,
  });

  final LayerLink link;
  final double width;
  final double verticalOffset;
  final List<PathSuggestion> suggestions;
  final int highlighted;
  final ValueChanged<PathSuggestion> onPick;
  final ValueChanged<int> onHover;

  static const double _kMaxHeight = 220;
  static const double _kRowHeight = 30;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final maxRows = (_kMaxHeight / _kRowHeight).floor();
    final visibleHeight = (suggestions.length * _kRowHeight)
        .clamp(0.0, maxRows * _kRowHeight)
        .toDouble();
    return Positioned(
      // Anchored via CompositedTransformFollower below — Positioned
      // just hands the overlay a finite frame so it doesn't expand.
      left: 0,
      top: 0,
      width: width,
      height: visibleHeight,
      child: CompositedTransformFollower(
        link: link,
        offset: Offset(0, verticalOffset),
        showWhenUnlinked: false,
        // Same `groupId` as the URL field cluster's TapRegion so
        // clicks on a suggestion don't count as "outside" the field
        // — which would otherwise fire `_cancelEdit()` and close
        // the dropdown before the suggestion's onTap could run.
        child: TapRegion(
          groupId: _kPathFieldTapGroup,
          child: Material(
            color: Colors.transparent,
            elevation: 0,
            child: FluxGlassPopupSurface(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: suggestions.length,
                itemExtent: _kRowHeight,
                itemBuilder: (_, i) {
                  final s = suggestions[i];
                  return _SuggestionRow(
                    entry: s.entry,
                    isHighlighted: i == highlighted,
                    onTap: () => onPick(s),
                    onHover: () => onHover(i),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.entry,
    required this.isHighlighted,
    required this.onTap,
    required this.onHover,
  });

  final BrowseEntry entry;
  final bool isHighlighted;
  final VoidCallback onTap;
  final VoidCallback onHover;

  @override
  Widget build(BuildContext context) {
    final bg = isHighlighted
        ? const Color(0x24A855F7)
        : Colors.transparent;
    final fg = isHighlighted
        ? AppColors.violetSoft
        : AppColors.textBody;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Icon(
                Icons.folder_outlined,
                size: 14,
                color: fg,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  entry.name,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    color: fg,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
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

/// 2-px violet progress strip pinned to the top of the listing area.
/// Visible only while a soft refresh is in flight — `state.refreshing`
/// flips true on commit, false when the new response lands.  The
/// widget is mounted continuously (no layout churn); only the
/// indeterminate `LinearProgressIndicator` paints inside.
class _RefreshIndicatorStrip extends StatelessWidget {
  const _RefreshIndicatorStrip();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryBrowseCubit, LibraryBrowseState>(
      buildWhen: (a, b) {
        final ar = a is LibraryBrowseLoaded && a.refreshing;
        final br = b is LibraryBrowseLoaded && b.refreshing;
        return ar != br;
      },
      builder: (context, state) {
        final refreshing = state is LibraryBrowseLoaded && state.refreshing;
        return SizedBox(
          height: 2,
          child: refreshing
              ? const LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.violet),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}

/// 1-px hairline rendered between the listing and the count footer
/// inside the body `FluxCard`.  Matches the subtle dividers the
/// Convert page uses inside its candidates card.
class _CardFooterDivider extends StatelessWidget {
  const _CardFooterDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 1,
      child: ColoredBox(color: AppColors.borderSubtle),
    );
  }
}

/// 1-px vertical separator between the listing column and the right
/// detail panel inside the body `FluxCard`.  Lets both halves share
/// the same card surface without giving the panel its own background.
class _CardVerticalDivider extends StatelessWidget {
  const _CardVerticalDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 1,
      child: ColoredBox(color: AppColors.borderSubtle),
    );
  }
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

class _BrowseListView extends StatefulWidget {
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
  State<_BrowseListView> createState() => _BrowseListViewState();
}

class _BrowseListViewState extends State<_BrowseListView> {
  /// Owned by this state so we can hand the same controller to both
  /// the [SingleChildScrollView] and the wrapping [Scrollbar].
  /// Scrollbar throws "ScrollController has no ScrollPosition
  /// attached" without an explicit controller shared with its
  /// associated Scrollable.
  late final ScrollController _hScroll = ScrollController();

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  /// Sum of all visible column widths + dividers + the leading kind-
  /// icon spacer + the body row's horizontal Padding + the body row's
  /// `AnimatedContainer` border + a small safety buffer.
  ///
  /// Body overhead: 12 px Padding each side (24) + 1 px Border each
  /// side (2) = 26 px.  Header overhead is only 24 px (no border).
  /// The extra 8 px on top absorbs (a) sub-pixel rounding when the
  /// device pixel ratio doesn't land on whole pixels, and (b) any
  /// hidden chrome we can't precisely measure from outside.
  double _totalTableWidth() {
    const double overhead = 26 + 8; // body row chrome + safety buffer
    double total = overhead + 32; // overhead + leading kind-icon spacer
    for (final col in persistedColumnOrder) {
      total += effectiveColumnWidth(col);
    }
    // Header row has N dividers: (N - 1) BETWEEN columns + 1 TRAILING
    // after the last column.  Body rows only have the inter-column
    // dividers — but they're zero-painted spacers, so sizing for the
    // wider header keeps both flush inside the same horizontal viewport.
    if (persistedColumnOrder.isNotEmpty) {
      total += persistedColumnOrder.length * _kColumnDividerWidth;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      // Recompute the table's total width whenever a column is
      // resized / reordered / toggled.
      valueListenable: columnsVersion,
      builder: (context, _, _) {
        return LayoutBuilder(
          builder: (ctx, constraints) {
            final totalWidth = _totalTableWidth();
            // When content fits the container, fill the container so
            // the table reads as flush.  When content exceeds the
            // container, grow to totalWidth and let
            // SingleChildScrollView scroll horizontally — header +
            // rows share the same scroll viewport so they stay in
            // lockstep without needing a shared ScrollController
            // across multiple Scrollables.
            final overflows = totalWidth > constraints.maxWidth;
            final tableWidth =
                overflows ? totalWidth : constraints.maxWidth;
            return Scrollbar(
              controller: _hScroll,
              thumbVisibility: overflows,
              child: SingleChildScrollView(
                controller: _hScroll,
                scrollDirection: Axis.horizontal,
                // No horizontal scroll physics when content fits —
                // avoids the scrollbar painting an idle thumb.
                physics: overflows
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: tableWidth,
                  height: constraints.maxHeight,
                  child: Column(
                    children: [
                      _SortableColumnHeaderRow(
                        sortBy: widget.sortBy,
                        sortAsc: widget.sortAsc,
                        onSort: widget.onSort,
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: ListView.separated(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.s14),
                          itemCount: widget.entries.length,
                          // No separator between rows — fully flat
                          // listing.  Per-row hover + selected tints
                          // are the only inter-row visual.  Removed
                          // the previous 1-px divider per operator
                          // feedback that the lines added noise.
                          separatorBuilder: (_, _) => const SizedBox.shrink(),
                          itemBuilder: (_, i) {
                            final entry = widget.entries[i];
                            return _BrowseRow(
                              entry: entry,
                              rootPath: widget.response.rootPath,
                              relativePath: widget.response.relativePath,
                              isSelected:
                                  widget.selectedNames.contains(entry.name),
                              density: widget.density,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Optional listing columns the operator can show/hide via the
/// right-click "column picker" menu on the column header row (matches
/// Windows Explorer / macOS Finder pattern).  `name` is always-on
/// (the entry's primary identifier — can't be turned off); every
/// other column toggles independently.
// Column enum + persisted statics + mutators live in
// `library_browse_cubit.dart` so they share the SecureStorage blob
// with the rest of the browse prefs (filter / sort / view / density).
// Re-import them here for the screen-local helpers below.

/// Visible operator-facing label for the column picker menu + the
/// column header itself.  Centralised so the menu and the header
/// share strings.
String _browseColumnLabel(BrowseColumn col) => switch (col) {
      BrowseColumn.name => 'Name',
      BrowseColumn.size => 'Size',
      BrowseColumn.modified => 'Modified',
      BrowseColumn.kind => 'Kind',
      BrowseColumn.indexed => 'Indexed',
      BrowseColumn.codec => 'Codec',
      BrowseColumn.dimensions => 'Dimensions',
      BrowseColumn.duration => 'Duration',
    };

/// Only a subset of columns are sortable client-side (we have the
/// data + a deterministic ordering for them).  Others render but
/// don't toggle sort on click.
BrowseSortColumn? _browseColumnSortKey(BrowseColumn col) => switch (col) {
      BrowseColumn.name => BrowseSortColumn.name,
      BrowseColumn.size => BrowseSortColumn.size,
      BrowseColumn.modified => BrowseSortColumn.modified,
      _ => null,
    };

/// Render the value of [col] for [entry] as a row cell.  Mirrors the
/// monospace-mono styling of the original Size + Modified cells so
/// every column reads as part of the same table family.  Returns an
/// em-dash for missing data (directories, unindexed files, missing
/// codec / dimensions / duration).
Widget _browseColumnCell(
  BrowseColumn col,
  BrowseEntry entry, {
  FolderSize? folderSize,
}) {
  const style = TextStyle(
    fontFamily: 'JetBrains Mono',
    fontSize: 11.5,
    color: AppColors.textMutedV2,
  );
  // Empty string when there's no data — operator asked for blank
  // cells instead of the em-dash placeholder so the listing reads as
  // sparse columns rather than a wall of dashes.
  String value;
  switch (col) {
    case BrowseColumn.name:
      // Name is rendered as the Expanded label cell, not here — this
      // branch exists for completeness.  Empty so the row doesn't
      // accidentally render a duplicate label.
      return const SizedBox.shrink();
    case BrowseColumn.size:
      // Directory fallback chain — most authoritative first:
      //   1. `folderSize` from the disk-walked cache (operator clicked
      //      "Compute size" on the detail panel — catches unindexed
      //      + hidden + freshly-added files).
      //   2. `entry.catalogedSizeBytes` server-side SUM of indexed
      //      descendants (instant, populated on every browse; misses
      //      unindexed / hidden files but covers the common case).
      //   3. blank when neither is available.
      // Files always use their mtime-cached `sizeBytes`.
      if (entry.isDir) {
        if (folderSize != null) {
          value = _humanBytes(folderSize.sizeBytes);
        } else if (entry.catalogedSizeBytes > 0) {
          value = _humanBytes(entry.catalogedSizeBytes);
        } else {
          value = '';
        }
      } else {
        value = _humanBytes(entry.sizeBytes);
      }
    case BrowseColumn.modified:
      value = _formatModified(entry.modifiedIso);
    case BrowseColumn.kind:
      value = switch (entry.kind) {
        BrowseKind.directory => 'Folder',
        BrowseKind.video => 'Video',
        BrowseKind.image => 'Image',
        BrowseKind.audio => 'Audio',
        BrowseKind.pdf => 'PDF',
        BrowseKind.other => 'Other',
      };
    case BrowseColumn.indexed:
      value = entry.isIndexed
          ? (entry.media?.indexedAtIso != null
              ? _formatModified(entry.media!.indexedAtIso!)
              : 'Yes')
          : '';
    case BrowseColumn.codec:
      value = entry.media?.codecName ?? '';
    case BrowseColumn.dimensions:
      final w = entry.media?.width;
      final h = entry.media?.height;
      value = (w != null && h != null) ? '$w × $h' : '';
    case BrowseColumn.duration:
      final secs = entry.media?.durationSec;
      value = (secs != null && secs > 0) ? _formatDurationShort(secs) : '';
  }
  final text = Text(
    value,
    style: style,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign:
        _isNumericBrowseColumn(col) ? TextAlign.right : TextAlign.left,
  );
  // Wrap in Align so the text actually sits at the right edge of the
  // cell when there's room left over (Text's textAlign alone only
  // matters when the Text widget is wider than its content).
  return Align(
    alignment: _isNumericBrowseColumn(col)
        ? Alignment.centerRight
        : Alignment.centerLeft,
    child: text,
  );
}

/// Format a duration in seconds as `Hh Mm` / `Mm Ss` / `Ss`.  Short
/// enough to fit a 90 px column without truncation.
String _formatDurationShort(double seconds) {
  final total = seconds.round();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}

/// Sortable column headers.  Click a sortable column toggles its
/// direction (desc / asc / desc / ...); active column shows the
/// arrow indicator.  Right-click anywhere on the row opens the
/// column picker menu (Windows Explorer pattern — checkable list of
/// available columns).
class _SortableColumnHeaderRow extends StatefulWidget {
  const _SortableColumnHeaderRow({
    required this.sortBy,
    required this.sortAsc,
    required this.onSort,
  });

  final BrowseSortColumn sortBy;
  final bool sortAsc;
  final ValueChanged<BrowseSortColumn> onSort;

  @override
  State<_SortableColumnHeaderRow> createState() =>
      _SortableColumnHeaderRowState();
}

class _SortableColumnHeaderRowState extends State<_SortableColumnHeaderRow> {
  /// Drives the column-picker popup's mount state.  Sticky — stays
  /// shown across multiple checkbox clicks; only dismissed by a tap
  /// outside the popup or another right-click on the header.
  final OverlayPortalController _pickerController = OverlayPortalController();

  /// Anchor position of the popup — captured from the right-click
  /// pointer position so the picker opens wherever the operator
  /// clicked (Explorer pattern).
  Offset _pickerPos = Offset.zero;

  void _openPicker(Offset globalPos) {
    setState(() => _pickerPos = globalPos);
    if (!_pickerController.isShowing) {
      _pickerController.show();
    }
  }

  void _closePicker() {
    if (_pickerController.isShowing) {
      _pickerController.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      // Rebuild whenever the column set or order changes so the
      // header reflects the new state on the same frame as the
      // picker checkbox is ticked or a column is dropped.
      valueListenable: columnsVersion,
      builder: (context, _, _) {
        // `persistedColumnOrder` IS the display order — Name is
        // always slot 0 (locked).
        final visible = persistedColumnOrder;
        return OverlayPortal(
          controller: _pickerController,
          overlayChildBuilder: (_) => _ColumnPickerPopup(
            position: _pickerPos,
            onDismiss: _closePicker,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onSecondaryTapDown: (details) =>
                _openPicker(details.globalPosition),
            child: Padding(
              // Horizontal-only outer padding — vertical breathing
              // room moved INTO each cell's AnimatedContainer (see
              // `_DraggableColumnHeader`) so the hover highlight
              // fills the full vertical band edge-to-edge.
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                // `stretch` here triggered `RenderRepaintBoundary
                // NEEDS-PAINT` cascade — `stretch` inside a parent with
                // unbounded max-height left the Draggable / AnimatedContainer
                // descendants' intrinsic-height path inconsistent across
                // layout passes.  Every cell already has the same intrinsic
                // height (padding 12 + label 16), so the default `center`
                // alignment paints identically and avoids the bug.
                children: [
                  // Name header sits flush with the body-row's icon
                  // column edge (operator ask) — header reads as the
                  // start of the column rather than aligning to the
                  // text after the icon.  The body's leading icon +
                  // gap (32 px) is contained inside the Name cell's
                  // own SizedBox below, so column widths still line
                  // up pixel-for-pixel between header + body.
                  for (var i = 0; i < visible.length; i++) ...[
                    if (i > 0)
                      _ResizableColumnDivider(leftColumn: visible[i - 1]),
                    SizedBox(
                      width: visible[i] == BrowseColumn.name
                          ? effectiveColumnWidth(visible[i]) + 32
                          : effectiveColumnWidth(visible[i]),
                      child: _DraggableColumnHeader(
                        column: visible[i],
                        child: _headerCell(visible[i]),
                      ),
                    ),
                  ],
                  // Trailing divider after the last column — gives the
                  // rightmost column its own resize handle and visually
                  // closes the header row so it doesn't trail off into
                  // empty space.
                  if (visible.isNotEmpty)
                    _ResizableColumnDivider(leftColumn: visible.last),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _headerCell(BrowseColumn col) {
    final sortKey = _browseColumnSortKey(col);
    return _SortHeaderLabel(
      label: _browseColumnLabel(col),
      column: sortKey,
      activeColumn: widget.sortBy,
      ascending: widget.sortAsc,
      onTap: sortKey == null ? null : () => widget.onSort(sortKey),
    );
  }
}

/// True for columns whose content reads as a number (sizes, durations,
/// timestamps, dimensions).  Numeric columns right-align in both the
/// header and the body so the units digit stacks vertically — matches
/// Windows Explorer / every other data-table convention.
bool _isNumericBrowseColumn(BrowseColumn col) => switch (col) {
      BrowseColumn.size ||
      BrowseColumn.modified ||
      BrowseColumn.duration ||
      BrowseColumn.dimensions =>
        true,
      _ => false,
    };

/// Outer width of every column divider — used by both [_ColumnDivider]
/// (body) and [_ResizableColumnDivider] (header) so header + body
/// dividers line up pixel-for-pixel column boundaries.
const double _kColumnDividerWidth = 9;

/// Invisible 9-px spacer between adjacent row-body cells.  Kept as
/// a SizedBox (not removed) so column boundaries line up pixel-for-
/// pixel with the resizable header divider.  Previously rendered a
/// 1-px hairline; removed per operator feedback that the inter-column
/// rules added noise.
class _ColumnDivider extends StatelessWidget {
  const _ColumnDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: _kColumnDividerWidth, height: 16);
  }
}

/// Header-row variant of [_ColumnDivider] — visually identical (same
/// 1 px line + 16 px height + 8 px margin) but wraps a 9-px wide
/// drag hit area centred on the line.  Drag the divider horizontally
/// to resize the column on its LEFT (the column whose right edge
/// this divider draws).  Matches the Windows Explorer pattern.
///
/// When the left column is Name and Name is still flexible
/// (Expanded), the first drag delta is used to lock Name's width
/// into [persistedColumnWidths] — Name becomes fixed-width
/// thereafter and the header switches from Expanded to SizedBox.
class _ResizableColumnDivider extends StatefulWidget {
  const _ResizableColumnDivider({required this.leftColumn});

  /// The column whose right edge this divider draws — drag resizes
  /// this column.
  final BrowseColumn leftColumn;

  @override
  State<_ResizableColumnDivider> createState() =>
      _ResizableColumnDividerState();
}

class _ResizableColumnDividerState extends State<_ResizableColumnDivider> {
  double? _dragStartWidth;
  bool _hover = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final highlight = _hover || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      // Same setState guard as the surrounding header / row MouseRegions
      // — keeps the mouse tracker from re-entering its update phase
      // recursively when sibling rebuilds happen mid-hover.
      onEnter: (_) {
        if (!_hover) setState(() => _hover = true);
      },
      onExit: (_) {
        if (_hover) setState(() => _hover = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {
          _dragStartWidth = effectiveColumnWidth(widget.leftColumn);
          setState(() => _dragging = true);
        },
        onHorizontalDragUpdate: (details) {
          final start = _dragStartWidth;
          if (start == null) return;
          resizeBrowseColumn(
            widget.leftColumn,
            start + details.localPosition.dx,
          );
        },
        onHorizontalDragEnd: (_) {
          _dragStartWidth = null;
          setState(() => _dragging = false);
        },
        child: SizedBox(
          // Matches the body-row divider's outer width so header +
          // body column boundaries line up pixel-for-pixel.  Header
          // dividers stay visible at rest as the drag affordance —
          // the operator needs to see WHERE the resize handle is.
          // Body-cell dividers are invisible (see [_ColumnDivider]).
          width: _kColumnDividerWidth,
          height: 16,
          child: Center(
            child: Container(
              width: highlight ? 2 : 1,
              height: 16,
              color: highlight
                  ? AppColors.violet
                  : AppColors.borderSubtle,
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a header cell with [Draggable] (carries the column id while
/// the operator is dragging) + [DragTarget] (accepts a drop and fires
/// [reorderBrowseColumn]).  Name is rendered without this wrapper —
/// it's pinned to slot 0 and never moves.
class _DraggableColumnHeader extends StatefulWidget {
  const _DraggableColumnHeader({
    required this.column,
    required this.child,
  });

  final BrowseColumn column;
  final Widget child;

  @override
  State<_DraggableColumnHeader> createState() => _DraggableColumnHeaderState();
}

class _DraggableColumnHeaderState extends State<_DraggableColumnHeader> {
  bool _hoveringDrop = false;
  bool _dropAfter = false; // false = left edge, true = right edge
  bool _dragging = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<BrowseColumn>(
      onWillAcceptWithDetails: (details) {
        if (details.data == widget.column) return false;
        if (details.data == BrowseColumn.name) return false;
        if (widget.column == BrowseColumn.name) return false;
        setState(() => _hoveringDrop = true);
        return true;
      },
      onMove: (details) {
        // Convert the candidate's global drop position into a local
        // x within this header cell.  Drops on the LEFT half →
        // insert moved column BEFORE target; RIGHT half → AFTER.
        // Matches Windows Explorer's column-reorder UX.
        final box = context.findRenderObject();
        if (box is! RenderBox) return;
        final local = box.globalToLocal(details.offset);
        final after = local.dx > box.size.width / 2;
        if (after != _dropAfter) {
          setState(() => _dropAfter = after);
        }
      },
      onLeave: (_) => setState(() => _hoveringDrop = false),
      onAcceptWithDetails: (details) {
        final after = _dropAfter;
        setState(() => _hoveringDrop = false);
        reorderBrowseColumn(
          details.data,
          widget.column,
          placeAfter: after,
        );
      },
      builder: (context, candidate, rejected) {
        return MouseRegion(
          cursor: _dragging
              ? SystemMouseCursors.grabbing
              : SystemMouseCursors.grab,
          onEnter: (_) {
            if (!_hovered) setState(() => _hovered = true);
          },
          onExit: (_) {
            if (_hovered) setState(() => _hovered = false);
          },
          child: Draggable<BrowseColumn>(
            data: widget.column,
            // Lock to the horizontal axis so the floating feedback
            // chip slides along the header row and never drifts up
            // or down into the listing — matches Explorer / Finder.
            axis: Axis.horizontal,
            // `deferToChild` (the default) only accepts hits where the
            // child actually paints — meaning empty space inside the
            // column cell (to the right of the label) wouldn't start
            // a drag.  `opaque` makes the Draggable's whole bounds
            // hit-testable, so the operator can grab anywhere in the
            // cell.  Inner sort-label tap + drag-pan still coexist
            // via the gesture arena (tap wins on click, pan wins on
            // slop crossover).
            hitTestBehavior: HitTestBehavior.opaque,
            onDragStarted: () => setState(() => _dragging = true),
            onDragEnd: (_) => setState(() => _dragging = false),
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s10,
                  vertical: AppSpacing.s4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgRaised,
                  border: Border.all(color: AppColors.violet),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  _browseColumnLabel(widget.column),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.violetSoft,
                  ),
                ),
              ),
            ),
            // "Held" state on the source cell while the operator is
            // dragging — depressed darker tint + violet outline so
            // the cell reads as picked-up, not gone.  Replaces the
            // bare opacity treatment which looked like a render glitch.
            childWhenDragging: SizedBox(
              width: double.infinity,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x1AA855F7),
                  border: Border.all(color: AppColors.violet),
                  borderRadius: BorderRadius.circular(AppRadii.xs),
                ),
                child: Opacity(
                  opacity: 0.55,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: widget.child,
                  ),
                ),
              ),
            ),
            // SizedBox + Align fill the column cell so the draggable
            // hit area covers the entire cell — empty space to the
            // right of the label is also a drag handle, matching
            // Explorer where you can grab anywhere on the column
            // header.  Without this the Draggable's bounds collapse
            // to the label's intrinsic Row(mainAxisSize: min) size
            // and the empty area wouldn't initiate a drag.
            //
            // The AnimatedContainer wraps the cell in a hover-tinted
            // band so the operator can see WHICH cell their cursor
            // is over — matches the body-row hover affordance.
            child: SizedBox(
              width: double.infinity,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                // Internal vertical padding gives the cell breathing
                // room AND extends the hover highlight to a band
                // that fills the visible header row — was just the
                // label's intrinsic height before, which read as a
                // half-height stripe under the text.
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: _hovered
                      ? const Color(0x0DA855F7)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.xs),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: widget.child,
                    ),
                    if (_hoveringDrop)
                      Positioned(
                        // Switch the indicator between the cell's
                        // left and right edge based on the drop side.
                        left: _dropAfter ? null : -1,
                        right: _dropAfter ? -1 : null,
                        top: -4,
                        bottom: -4,
                        width: 2,
                        child: const ColoredBox(color: AppColors.violet),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Sticky column-picker popup mounted via [OverlayPortal] at root-
/// overlay level (escapes the FluxCard's clip).  Stays open while the
/// operator toggles multiple columns; dismisses only on tap-outside
/// (via [TapRegion]) or programmatic close.
///
/// Internal `ValueListenableBuilder` against [columnsVersion] makes
/// the checkbox state inside the popup reflect each toggle on the
/// same frame — without it the popup would show stale check marks
/// because its own setState never fires (the toggle mutates a global
/// + a notifier, not a State field).
class _ColumnPickerPopup extends StatelessWidget {
  const _ColumnPickerPopup({
    required this.position,
    required this.onDismiss,
  });

  final Offset position;
  final VoidCallback onDismiss;

  static const double _kWidth = 240;

  @override
  Widget build(BuildContext context) {
    // Mounted inside the root Overlay's Stack via `OverlayPortal` —
    // returning a `Positioned` directly anchors the popup at the
    // click point.  An extra wrapper Stack was causing the popup to
    // drift horizontally because its loose layout placed the
    // Positioned child relative to its own (collapsed) bounds
    // instead of the root overlay's.
    final mq = MediaQuery.maybeOf(context);
    final screenW = mq?.size.width ?? double.infinity;
    final screenH = mq?.size.height ?? double.infinity;
    // Keep the popup on-screen — if the click is too close to the
    // right edge, anchor by right; same for bottom.
    final left = (position.dx + _kWidth > screenW)
        ? (screenW - _kWidth - 4)
        : position.dx;
    final approxHeight =
        56 + BrowseColumn.values.length * 32; // header + rows
    final top = (position.dy + approxHeight > screenH)
        ? (screenH - approxHeight - 4)
        : position.dy;
    return Positioned(
      left: left.clamp(0, screenW).toDouble(),
      top: top.clamp(0, screenH).toDouble(),
      child: TapRegion(
        onTapOutside: (_) => onDismiss(),
        child: Material(
          color: Colors.transparent,
          child: FluxGlassPopupSurface(
            width: _kWidth,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: ValueListenableBuilder<int>(
              valueListenable: columnsVersion,
              builder: (_, _, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Show columns',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: AppColors.textMutedV2,
                        ),
                      ),
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.borderSubtle,
                  ),
                  for (final col in BrowseColumn.values)
                    _ColumnCheckRow(
                      column: col,
                      isEnabled: isBrowseColumnEnabled(col),
                      isLocked: col == BrowseColumn.name,
                      onToggle: () => toggleBrowseColumn(col),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Single hoverable checkbox row inside the column picker popup.
/// Click toggles the column via [toggleBrowseColumn] without
/// dismissing the popup — operators can rapid-fire toggle multiple
/// columns and see the listing update in place.
class _ColumnCheckRow extends StatefulWidget {
  const _ColumnCheckRow({
    required this.column,
    required this.isEnabled,
    required this.isLocked,
    required this.onToggle,
  });

  final BrowseColumn column;
  final bool isEnabled;
  final bool isLocked;
  final VoidCallback onToggle;

  @override
  State<_ColumnCheckRow> createState() => _ColumnCheckRowState();
}

class _ColumnCheckRowState extends State<_ColumnCheckRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color labelColor =
        widget.isLocked ? AppColors.textFaint : AppColors.textBody;
    final Color iconColor = widget.isLocked
        ? AppColors.textFaint
        : (widget.isEnabled ? AppColors.violet : AppColors.textMutedV2);
    return MouseRegion(
      cursor: widget.isLocked
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: widget.isLocked
          ? null
          : (_) => setState(() => _hovered = true),
      onExit: widget.isLocked
          ? null
          : (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.isLocked ? null : widget.onToggle,
        child: Container(
          color: _hovered ? const Color(0x14A855F7) : Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 7,
          ),
          child: Row(
            children: [
              Icon(
                widget.isEnabled
                    ? Icons.check_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 16,
                color: iconColor,
              ),
              const SizedBox(width: 10),
              Text(
                _browseColumnLabel(widget.column),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
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

  /// `null` when this column isn't sortable client-side (e.g. Codec,
  /// Dimensions) — in that case the label renders without a hover
  /// affordance and click is a no-op.
  final BrowseSortColumn? column;
  final BrowseSortColumn activeColumn;
  final bool ascending;

  /// `null` when [column] is `null` — hover + click suppress.
  final VoidCallback? onTap;

  @override
  State<_SortHeaderLabel> createState() => _SortHeaderLabelState();
}

class _SortHeaderLabelState extends State<_SortHeaderLabel> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isSortable = widget.column != null && widget.onTap != null;
    final bool isActive =
        isSortable && widget.column == widget.activeColumn;
    final Color color = (isActive || (_hovered && isSortable))
        ? AppColors.violet
        : AppColors.textMutedV2;
    // Title-case labels — no extra letter-spacing tracking (that was
    // tuned for the previous ALL-CAPS treatment).
    final style = AppTypography.captionV2.copyWith(
      color: color,
      fontWeight: FontWeight.w500,
    );

    final inner = Row(
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
    );

    if (!isSortable) {
      // Non-sortable column — just render the label.  Right-click on
      // the row (handled by the parent header row) still opens the
      // column picker so the column can be hidden.
      return inner;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: inner,
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
    // Subscribe to column-toggle changes so the trailing cells
    // (Size / Modified / Kind / Codec / etc.) re-render the moment
    // the operator ticks a checkbox in the column picker — without
    // this, the row only picks up the new column set on its next
    // own-state rebuild (hover, selection change) which is what
    // caused the "only updates on hover" glitch.
    return ValueListenableBuilder<int>(
      valueListenable: columnsVersion,
      builder: (context, _, _) => _buildRowContent(),
    );
  }

  Widget _buildRowContent() {
    final entry = widget.entry;
    final iconData = _iconForKind(entry.kind);
    final iconColor = _colorForKind(entry.kind);
    final showHdrBadge = entry.media?.hdrFormat != null &&
        entry.media!.hdrFormat!.isNotEmpty;
    // Flat row treatment (Explorer-style) — transparent at rest, just
    // a subtle violet tint on hover + a stronger one when selected.
    // No card border + no rounded corners; the per-row separator (a
    // 1-px borderSubtle divider in `ListView.separated`'s
    // `separatorBuilder`) is the only visible chrome between rows.
    final bgColor = widget.isSelected
        ? const Color(0x1AA855F7)
        : (_hovered ? const Color(0x0DA855F7) : Colors.transparent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      // Guard against redundant setStates — Flutter's mouse tracker
      // can re-fire onEnter/onExit during the frame-update phase when
      // sibling widgets rebuild (1.1s SystemStats poll cascades down),
      // and a setState mid-update trips the `_debugDuringDeviceUpdate`
      // assertion in debug.
      onEnter: (_) {
        if (!_hovered) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        onSecondaryTapDown: (details) =>
            _showContextMenu(details.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: _verticalPad),
          color: bgColor,
          child: Row(
            children: [
              Icon(iconData, size: 18, color: iconColor),
              const SizedBox(width: 14),
              // Cells iterate `persistedColumnOrder` so the row body
              // matches the header column-for-column.  Name uses a
              // fixed SizedBox like every other column (was Expanded)
              // so resizing a fixed column doesn't shift the Name
              // divider as a side effect of Name absorbing freed
              // space.  ClipRect on the Name cell handles the case
              // where the name text + badges are wider than the
              // column — badges stay visible; the text ellipsises.
              for (var i = 0; i < persistedColumnOrder.length; i++) ...[
                if (i > 0) const _ColumnDivider(),
                SizedBox(
                  width: effectiveColumnWidth(persistedColumnOrder[i]),
                  child: persistedColumnOrder[i] == BrowseColumn.name
                      ? ClipRect(
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
                                    label: entry.media!.hdrFormat!
                                        .toUpperCase(),
                                    accent: true,
                                  ),
                                ],
                                if (entry.media?.isStreaming == true) ...[
                                  const SizedBox(width: 6),
                                  const _MutedTag(
                                      label: '▶ live', accent: true),
                                ],
                                if (entry.media?.hasThumbnailFailed ==
                                    true) ...[
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
                                  _IndexedTag(
                                    indexedAtIso:
                                        entry.media?.indexedAtIso,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : _browseColumnCell(
                          persistedColumnOrder[i],
                          entry,
                          // Directory entries route their size cell
                          // through the cubit's folder-size cache so
                          // a "Compute size" click in the detail panel
                          // populates the SIZE column inline.  Files
                          // ignore this param.
                          folderSize: (entry.isDir &&
                                  persistedColumnOrder[i] == BrowseColumn.size)
                              ? context
                                  .read<LibraryBrowseCubit>()
                                  .folderSizeFor(
                                    widget.relativePath.isEmpty
                                        ? entry.name
                                        : '${widget.relativePath}/${entry.name}',
                                  )
                              : null,
                        ),
                ),
              ],
              // Trailing-column reveal icon removed — duplicated the
              // "Open in Explorer" icon that now lives in the URL
              // field's trailing slot.  Right-click → Reveal in
              // folder still surfaces the per-entry path action.
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

  String _absolutePath() {
    final separator = widget.rootPath.contains(r'\') ? r'\' : '/';
    final tail = widget.relativePath.isEmpty
        ? widget.entry.name
        : '${widget.relativePath}/${widget.entry.name}';
    final tailWithSep = tail.replaceAll('/', separator);
    return '${widget.rootPath}$separator$tailWithSep';
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

/// The visual half of a grid tile — TMDB poster (when present) wins
/// over the extracted-frame thumbnail; falls back to a large kind icon
/// on a tinted background when neither is available.
class _GridTileVisual extends StatelessWidget {
  const _GridTileVisual({required this.entry});

  final BrowseEntry entry;

  @override
  Widget build(BuildContext context) {
    // Poster art always wins when present — TMDB's hand-curated art
    // beats a random video frame.  Matches the library card mosaic's
    // ranking in `_library_aggregates`.
    final poster = entry.media?.posterUrl;
    if (poster != null && poster.isNotEmpty) {
      return Image.network(
        poster,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            _GridTileGeneratedThumb(entry: entry),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _KindIconBackground(entry: entry),
      );
    }
    return _GridTileGeneratedThumb(entry: entry);
  }
}

/// Falls back to the per-file extracted-frame thumbnail when there's
/// no TMDB poster.  Extracted as its own widget so the poster path's
/// `errorBuilder` can reuse the same fallback shape if the TMDB URL
/// 404s (e.g. TMDB image host transient failure).
class _GridTileGeneratedThumb extends StatelessWidget {
  const _GridTileGeneratedThumb({required this.entry});

  final BrowseEntry entry;

  @override
  Widget build(BuildContext context) {
    final hasThumb = entry.isIndexed &&
        entry.fileId != null &&
        entry.media?.hasThumbnailReady == true;
    if (!hasThumb) return _KindIconBackground(entry: entry);
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
