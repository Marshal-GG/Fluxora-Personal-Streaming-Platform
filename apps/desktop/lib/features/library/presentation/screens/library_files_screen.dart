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
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/widgets/flux_button.dart';

import 'package:fluxora_desktop/core/router/app_router.dart';
import 'package:fluxora_desktop/features/library/domain/entities/browse_entry.dart';
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_browse_cubit.dart';
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

class _LibraryBrowseView extends StatelessWidget {
  const _LibraryBrowseView();

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.s28, 0, AppSpacing.s28, AppSpacing.s10,
            ),
            child: _BreadcrumbBar(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s28),
              child: BlocBuilder<LibraryBrowseCubit, LibraryBrowseState>(
                builder: (context, state) => switch (state) {
                  LibraryBrowseInitial() ||
                  LibraryBrowseLoading() =>
                    const _BrowseLoadingBody(),
                  LibraryBrowseLoaded(:final response) =>
                    _BrowseListBody(response: response),
                  LibraryBrowseFailure(:final message) =>
                    _BrowseFailureBody(message: message),
                },
              ),
            ),
          ),
        ],
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
              onTap: () => cubit.navigateTo(
                loaded != null ? loaded.response.relativePath : '',
              ),
            ),
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

class _BreadcrumbBar extends StatelessWidget {
  const _BreadcrumbBar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryBrowseCubit, LibraryBrowseState>(
      builder: (context, state) {
        if (state is! LibraryBrowseLoaded) {
          return const SizedBox(height: 28);
        }
        final response = state.response;
        final cubit = context.read<LibraryBrowseCubit>();
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

        // Trailing icon row: "go up" (parent) + raw-path copy.
        return Row(
          children: [
            // Up button — disabled when at the root.
            _ToolbarIconButton(
              icon: Icons.arrow_upward_rounded,
              tooltip: response.parentPath == null
                  ? 'At library root'
                  : 'Go up one level',
              onTap: response.parentPath == null
                  ? null
                  : () => cubit.goUp(),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: chips),
              ),
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

class _BrowseListBody extends StatelessWidget {
  const _BrowseListBody({required this.response});

  final BrowseResponse response;

  @override
  Widget build(BuildContext context) {
    if (response.entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_off_outlined,
                size: 48, color: AppColors.textMutedV2),
            const SizedBox(height: AppSpacing.s12),
            Text(
              response.relativePath.isEmpty
                  ? 'This library is empty.'
                  : 'This folder is empty.',
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textMutedV2),
            ),
          ],
        ),
      );
    }

    // Column-header row — non-interactive in v1 (server-sorted dirs-first
    // then files-alphabetical).  Sort menu can land later.
    return Column(
      children: [
        const _ColumnHeaderRow(),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: AppSpacing.s14),
            itemCount: response.entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (_, i) {
              final entry = response.entries[i];
              return _BrowseRow(
                entry: entry,
                rootPath: response.rootPath,
                relativePath: response.relativePath,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ColumnHeaderRow extends StatelessWidget {
  const _ColumnHeaderRow();

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.captionV2.copyWith(
      color: AppColors.textMutedV2,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.4,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // 24px icon column + 8px gap
          const SizedBox(width: 32),
          Expanded(child: Text('NAME', style: style)),
          SizedBox(width: 100, child: Text('SIZE', style: style)),
          SizedBox(width: 160, child: Text('MODIFIED', style: style)),
          const SizedBox(width: 80, child: SizedBox()),
        ],
      ),
    );
  }
}

// ── Row ────────────────────────────────────────────────────────────────────

class _BrowseRow extends StatefulWidget {
  const _BrowseRow({
    required this.entry,
    required this.rootPath,
    required this.relativePath,
  });

  final BrowseEntry entry;
  final String rootPath;
  final String relativePath;

  @override
  State<_BrowseRow> createState() => _BrowseRowState();
}

class _BrowseRowState extends State<_BrowseRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final iconData = _iconForKind(entry.kind);
    final iconColor = _colorForKind(entry.kind);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0x0DA855F7)
                : const Color(0x05FFFFFF),
            border: Border.all(
              color: _hovered
                  ? const Color(0x1AA855F7)
                  : const Color(0x0AFFFFFF),
            ),
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
                      if (entry.isIndexed) ...[
                        const SizedBox(width: 6),
                        const _MutedTag(label: 'Indexed', accent: true),
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

  void _handleTap() {
    if (widget.entry.isDir) {
      final target = widget.relativePath.isEmpty
          ? widget.entry.name
          : '${widget.relativePath}/${widget.entry.name}';
      context.read<LibraryBrowseCubit>().navigateTo(target);
      return;
    }
    // File click — open with OS default app.  url_launcher's
    // `Uri.file(...)` resolves to `file://...` which Windows + macOS
    // + Linux all hand off to the registered viewer / player.
    _openInDefaultApp();
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

// ── Helpers ────────────────────────────────────────────────────────────────

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
