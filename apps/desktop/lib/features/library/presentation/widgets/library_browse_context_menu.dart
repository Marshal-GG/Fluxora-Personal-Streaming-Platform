import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fluxora_desktop/features/library/domain/entities/browse_entry.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_browse_cubit.dart';
import 'package:fluxora_desktop/shared/widgets/flux_glass_menu.dart';

final _log = Logger();

/// Show the right-click context menu for a folder-browser entry.
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
/// Renders against the shared glass popup chrome via [showFluxGlassMenu]
/// so the dropdown matches the Library page's Sort menu and the
/// per-card 3-dot menu visually.
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

  // Every file kind is indexable server-side now (the catalog needs
  // to reach arbitrary documents / archives so the mobile client can
  // surface them via `/files/{id}/content`).  Only the indexed-state
  // gate remains.
  final canIndex = !entry.isDir && !entry.isIndexed;
  final canUnindexFile =
      !entry.isDir && entry.isIndexed && entry.fileId != null;
  final canRegen = !entry.isDir && entry.isIndexed && entry.fileId != null;
  final canScanSubtree = entry.isDir;
  final canUnindexSubtree = entry.isDir;

  // The menu's layout delegate works in overlay-LOCAL coordinates, but
  // `details.globalPosition` (what gets passed in) is in global window
  // coordinates.  If the Overlay isn't at the window origin (e.g. the
  // FluxTitlebar / sidebar offset it), passing the raw global pointer
  // makes the menu drift right + down by the overlay's window offset.
  // Convert here so the menu anchors exactly at the pointer.
  final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
  final overlayBox = overlay is RenderBox ? overlay : null;
  final overlaySize = overlayBox?.size ?? MediaQuery.of(context).size;
  final localPos =
      overlayBox != null ? overlayBox.globalToLocal(position) : position;

  final items = <FluxGlassMenuItem<_BrowseMenuAction>>[
    const FluxGlassMenuItem(
      value: _BrowseMenuAction.open,
      label: 'Open',
      icon: Icons.open_in_new_rounded,
    ),
    const FluxGlassMenuItem(
      value: _BrowseMenuAction.reveal,
      label: 'Reveal in folder',
      icon: Icons.folder_open_outlined,
    ),
    const FluxGlassMenuItem(
      value: _BrowseMenuAction.copyPath,
      label: 'Copy path',
      icon: Icons.copy_rounded,
    ),
    const FluxGlassMenuItem(
      value: _BrowseMenuAction.copyName,
      label: 'Copy name',
      icon: Icons.text_fields_rounded,
    ),
    if (canIndex)
      const FluxGlassMenuItem(
        value: _BrowseMenuAction.indexFile,
        label: 'Index this file',
        icon: Icons.add_to_photos_outlined,
      ),
    if (canUnindexFile)
      const FluxGlassMenuItem(
        value: _BrowseMenuAction.unindexFile,
        label: 'Unindex this file',
        icon: Icons.remove_circle_outline_rounded,
        destructive: true,
      ),
    if (canRegen)
      const FluxGlassMenuItem(
        value: _BrowseMenuAction.regenerateThumb,
        label: 'Regenerate thumbnail',
        icon: Icons.refresh_rounded,
      ),
    if (canScanSubtree)
      const FluxGlassMenuItem(
        value: _BrowseMenuAction.scanSubtree,
        label: 'Scan this folder',
        icon: Icons.travel_explore_rounded,
      ),
    if (canUnindexSubtree)
      const FluxGlassMenuItem(
        value: _BrowseMenuAction.unindexSubtree,
        label: 'Unindex this folder',
        icon: Icons.layers_clear_outlined,
        destructive: true,
      ),
  ];

  final selected = await showFluxGlassMenu<_BrowseMenuAction>(
    context: context,
    position: RelativeRect.fromLTRB(
      localPos.dx,
      localPos.dy,
      overlaySize.width - localPos.dx,
      overlaySize.height - localPos.dy,
    ),
    items: items,
    width: 200,
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
    case _BrowseMenuAction.unindexFile:
      await _runUnindex(entry, cubit, messenger);
    case _BrowseMenuAction.regenerateThumb:
      await _runRegenerate(entry, cubit, messenger);
    case _BrowseMenuAction.scanSubtree:
      await _runScanSubtree(entry, cubit, messenger);
    case _BrowseMenuAction.unindexSubtree:
      await _runUnindexSubtree(entry, cubit, messenger);
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

Future<void> _runUnindex(
  BrowseEntry entry,
  LibraryBrowseCubit cubit,
  ScaffoldMessengerState? messenger,
) async {
  try {
    final ok = await cubit.unindexEntry(entry);
    if (!ok) return;
    messenger?.showSnackBar(
      SnackBar(content: Text('Unindexed ${entry.name} (file kept on disk)')),
    );
  } catch (e) {
    messenger?.showSnackBar(
      SnackBar(content: Text('Failed to unindex ${entry.name}: $e')),
    );
  }
}

Future<void> _runUnindexSubtree(
  BrowseEntry entry,
  LibraryBrowseCubit cubit,
  ScaffoldMessengerState? messenger,
) async {
  try {
    final removed = await cubit.unindexEntrySubtree(entry);
    final message = removed > 0
        ? 'Unindexed ${entry.name}: $removed file(s) removed from catalog '
            '(disk untouched)'
        : 'Unindexed ${entry.name}: nothing was indexed under it';
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  } catch (e) {
    messenger?.showSnackBar(
      SnackBar(content: Text('Unindex failed: $e')),
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
  unindexFile,
  regenerateThumb,
  scanSubtree,
  unindexSubtree,
}
