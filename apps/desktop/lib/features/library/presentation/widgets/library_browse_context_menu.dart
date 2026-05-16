import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_desktop/features/library/domain/entities/browse_entry.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_browse_cubit.dart';

final _log = Logger();

/// Show the right-click context menu for a folder-browser entry.  Plan
/// 28 §6.1 — every modern file browser has one and our muscle memory
/// expected it; Phase A shipped without.
///
/// Items are dispatched on entry kind + indexed status:
///   - Open                         (always)
///   - Reveal in folder             (always)
///   - Copy path                    (always)
///   - Copy name                    (always)
///   - Index this file              (files only, !is_indexed)
///   - Generate thumbnail           (indexed media files only)
///   - Scan this folder             (directories only)
///
/// Server endpoints used:
///   - POST /api/v1/library/{id}/index-file?path=...
///   - POST /api/v1/files/{id}/regenerate-thumbnail
///   - POST /api/v1/library/{id}/scan-subtree?path=...
Future<void> showBrowseEntryContextMenu({
  required BuildContext context,
  required Offset position,
  required BrowseEntry entry,
  required String rootPath,
  required String relativePath,
}) async {
  final cubit = context.read<LibraryBrowseCubit>();
  final messenger = ScaffoldMessenger.maybeOf(context);

  final absolutePath = _absolutePathFor(
    rootPath: rootPath,
    relativePath: relativePath,
    entry: entry,
  );

  final canIndex = !entry.isDir && !entry.isIndexed &&
      entry.kind != BrowseKind.other;
  final canRegen = !entry.isDir && entry.isIndexed && entry.fileId != null;
  final canScanSubtree = entry.isDir;

  final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
  final overlaySize = overlay is RenderBox
      ? overlay.size
      : MediaQuery.of(context).size;
  final selected = await showMenu<_BrowseMenuAction>(
    context: context,
    color: AppColors.bgRaised,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      overlaySize.width - position.dx,
      overlaySize.height - position.dy,
    ),
    items: <PopupMenuEntry<_BrowseMenuAction>>[
      _MenuItem(
        action: _BrowseMenuAction.open,
        icon: Icons.open_in_new_rounded,
        label: 'Open',
      ),
      _MenuItem(
        action: _BrowseMenuAction.reveal,
        icon: Icons.folder_open_outlined,
        label: 'Reveal in folder',
      ),
      _MenuItem(
        action: _BrowseMenuAction.copyPath,
        icon: Icons.copy_rounded,
        label: 'Copy path',
      ),
      _MenuItem(
        action: _BrowseMenuAction.copyName,
        icon: Icons.text_fields_rounded,
        label: 'Copy name',
      ),
      if (canIndex || canRegen || canScanSubtree)
        const PopupMenuDivider(),
      if (canIndex)
        _MenuItem(
          action: _BrowseMenuAction.indexFile,
          icon: Icons.add_to_photos_outlined,
          label: 'Index this file',
        ),
      if (canRegen)
        _MenuItem(
          action: _BrowseMenuAction.regenerateThumb,
          icon: Icons.refresh_rounded,
          label: 'Regenerate thumbnail',
        ),
      if (canScanSubtree)
        _MenuItem(
          action: _BrowseMenuAction.scanSubtree,
          icon: Icons.travel_explore_rounded,
          label: 'Scan this folder',
        ),
    ],
  );

  if (selected == null) return;

  switch (selected) {
    case _BrowseMenuAction.open:
      await _open(entry, relativePath, absolutePath, cubit, messenger);
    case _BrowseMenuAction.reveal:
      await _reveal(entry, absolutePath, messenger);
    case _BrowseMenuAction.copyPath:
      await Clipboard.setData(ClipboardData(text: absolutePath));
      messenger?.showSnackBar(
        const SnackBar(content: Text('Path copied to clipboard')),
      );
    case _BrowseMenuAction.copyName:
      await Clipboard.setData(ClipboardData(text: entry.name));
      messenger?.showSnackBar(
        const SnackBar(content: Text('Name copied to clipboard')),
      );
    case _BrowseMenuAction.indexFile:
      await _runIndex(entry, cubit, messenger);
    case _BrowseMenuAction.regenerateThumb:
      await _runRegenerate(entry, cubit, messenger);
    case _BrowseMenuAction.scanSubtree:
      await _runScanSubtree(entry, cubit, messenger);
  }
}

Future<void> _open(
  BrowseEntry entry,
  String parentRelativePath,
  String absolutePath,
  LibraryBrowseCubit cubit,
  ScaffoldMessengerState? messenger,
) async {
  if (entry.isDir) {
    final target = parentRelativePath.isEmpty
        ? entry.name
        : '$parentRelativePath/${entry.name}';
    await cubit.navigateTo(target);
    return;
  }
  try {
    final ok = await launchUrl(Uri.file(absolutePath));
    if (!ok) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not open: ${entry.name}')),
      );
    }
  } catch (e, st) {
    _log.e('open failed: $absolutePath', error: e, stackTrace: st);
    messenger?.showSnackBar(
      SnackBar(content: Text('Could not open ${entry.name}: $e')),
    );
  }
}

Future<void> _reveal(
  BrowseEntry entry,
  String absolutePath,
  ScaffoldMessengerState? messenger,
) async {
  final target = entry.isDir ? absolutePath : _parentOf(absolutePath);
  try {
    final ok = await launchUrl(Uri.file(target));
    if (!ok) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not open folder: $target')),
      );
    }
  } catch (e, st) {
    _log.e('reveal failed: $target', error: e, stackTrace: st);
    messenger?.showSnackBar(
      SnackBar(content: Text('Could not open folder: $e')),
    );
  }
}

Future<void> _runIndex(
  BrowseEntry entry,
  LibraryBrowseCubit cubit,
  ScaffoldMessengerState? messenger,
) async {
  try {
    final result = await cubit.indexEntry(entry);
    if (result == null) return;
    final detail = result.alreadyIndexed
        ? '${entry.name} was already indexed'
        : (result.enriched
            ? 'Indexed ${entry.name} + TMDB match'
            : 'Indexed ${entry.name}');
    messenger?.showSnackBar(SnackBar(content: Text(detail)));
  } catch (e) {
    messenger?.showSnackBar(
      SnackBar(content: Text('Failed to index ${entry.name}: $e')),
    );
  }
}

Future<void> _runRegenerate(
  BrowseEntry entry,
  LibraryBrowseCubit cubit,
  ScaffoldMessengerState? messenger,
) async {
  try {
    await cubit.regenerateEntryThumbnail(entry);
    messenger?.showSnackBar(
      SnackBar(content: Text('Queued thumbnail regeneration for ${entry.name}')),
    );
  } catch (e) {
    messenger?.showSnackBar(
      SnackBar(content: Text('Failed to regenerate thumbnail: $e')),
    );
  }
}

Future<void> _runScanSubtree(
  BrowseEntry entry,
  LibraryBrowseCubit cubit,
  ScaffoldMessengerState? messenger,
) async {
  try {
    final added = await cubit.scanEntrySubtree(entry);
    final message = added > 0
        ? 'Scanned ${entry.name}: $added new file(s)'
        : 'Scanned ${entry.name}: no new files';
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  } catch (e) {
    messenger?.showSnackBar(
      SnackBar(content: Text('Scan failed: $e')),
    );
  }
}

String _absolutePathFor({
  required String rootPath,
  required String relativePath,
  required BrowseEntry entry,
}) {
  final separator = rootPath.contains(r'\') ? r'\' : '/';
  final tail = relativePath.isEmpty
      ? entry.name
      : '$relativePath/${entry.name}';
  return '$rootPath$separator${tail.replaceAll('/', separator)}';
}

String _parentOf(String path) {
  final sep = path.contains(r'\') ? r'\' : '/';
  final idx = path.lastIndexOf(sep);
  if (idx <= 0) return path;
  return path.substring(0, idx);
}

enum _BrowseMenuAction {
  open,
  reveal,
  copyPath,
  copyName,
  indexFile,
  regenerateThumb,
  scanSubtree,
}

/// Compact-styled popup menu item.  Subclasses [PopupMenuItem] only so
/// callers can pass an icon + label without rebuilding the child Row
/// at every call site.  The child slot itself stays the same — Flutter
/// handles selection wiring through the inherited `onTap`.
class _MenuItem extends PopupMenuItem<_BrowseMenuAction> {
  _MenuItem({
    required _BrowseMenuAction action,
    required IconData icon,
    required String label,
  }) : super(
          value: action,
          height: 32,
          child: Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textMutedV2),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  color: AppColors.textBody,
                ),
              ),
            ],
          ),
        );
}
