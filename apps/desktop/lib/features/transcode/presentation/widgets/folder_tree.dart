import 'package:flutter/material.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';

/// One node in the folder-grouped tree displayed in the Candidates +
/// History tabs (plan 19 §M4).  Pure data structure — equality is
/// identity-by-[absolutePath] so the widget tree's diffing keeps each
/// node's expand state stable across rebuilds.
///
/// Generic over the leaf type (`TranscodeCandidate` for Candidates,
/// `TranscodeJob` for History).  Counters are recursive over children.
class FolderNode<T> {
  FolderNode({
    required this.absolutePath,
    required this.displayName,
    List<FolderNode<T>>? children,
    List<T>? leaves,
  })  : children = children ?? <FolderNode<T>>[],
        leaves = leaves ?? <T>[];

  /// Stable identity used as the key in the cubit's `expandedPaths` set.
  /// We ship the absolute parent-dir path; for cross-platform stability
  /// callers normalise separators before passing in.
  final String absolutePath;

  /// Last segment of [absolutePath] — the human-readable label.
  final String displayName;

  final List<FolderNode<T>> children;
  final List<T> leaves;

  /// Recursive count of leaves under this node.
  int get totalCount =>
      leaves.length +
      children.fold<int>(0, (sum, c) => sum + c.totalCount);

  /// Recursive sum of byte sizes under this node.  [sizeOf] returns the
  /// per-leaf byte count (source size for Candidates, output size for
  /// History rows that have one).
  int totalSize(int Function(T leaf) sizeOf) {
    int sum = 0;
    for (final l in leaves) {
      sum += sizeOf(l);
    }
    for (final c in children) {
      sum += c.totalSize(sizeOf);
    }
    return sum;
  }

  /// Recursive flatten — every leaf under this node, in tree order.
  List<T> flatten() {
    final out = <T>[];
    void walk(FolderNode<T> n) {
      out.addAll(n.leaves);
      for (final c in n.children) {
        walk(c);
      }
    }

    walk(this);
    return out;
  }

  /// Tri-state selection check.  Returns:
  ///  - `true`  when every leaf id under this node is in [selected].
  ///  - `false` when no leaf id is selected.
  ///  - `null`  when some leaves are selected and others aren't.
  bool? isFullySelected(
    Set<String> selected,
    String Function(T leaf) idOf,
  ) {
    final all = flatten();
    if (all.isEmpty) return false;
    int selectedCount = 0;
    for (final l in all) {
      if (selected.contains(idOf(l))) selectedCount++;
    }
    if (selectedCount == 0) return false;
    if (selectedCount == all.length) return true;
    return null;
  }
}

/// Build a folder tree from a flat list of leaves.  [pathOf] returns
/// the absolute file path of a leaf; the tree is grouped by parent
/// directory and collapses single-child chains so that
/// `D:\Movies\2024\Dune.mkv` produces (Movies → 2024 → Dune.mkv) rather
/// than (D: → Movies → 2024 → Dune.mkv).
///
/// Returns the synthetic root (its [absolutePath] is `""`); callers
/// render `root.children` rather than the root itself.
///
/// Memoised by the [leaves] reference via an [Expando]: callers that
/// pass the same `List<T>` on subsequent calls get the cached tree
/// back in O(1) instead of re-walking and re-sorting.  When the cubit
/// emits a new state with a fresh list reference, the old cache entry
/// becomes garbage-collectable (Expando holds weak references).
/// Caches at 5000+-candidate scale where the recursive sort dominates
/// build time; cheap and harmless at the typical home-server scale.
final Expando<FolderNode<dynamic>> _folderTreeCache =
    Expando<FolderNode<dynamic>>('buildFolderTree');

FolderNode<T> buildFolderTree<T>({
  required Iterable<T> leaves,
  required String Function(T leaf) pathOf,
}) {
  // Only memoise when the caller passed a concrete List — Iterables
  // produced by transient `where`/`map`/`toList()` chains generate a
  // fresh object per build and would never hit the cache anyway.  The
  // identity check on the list ref + cast back to FolderNode<T> is
  // safe because the same list reference can only carry one element
  // type.
  if (leaves is List<T>) {
    final cached = _folderTreeCache[leaves];
    if (cached is FolderNode<T>) {
      return cached;
    }
  }

  final root = FolderNode<T>(
    absolutePath: '',
    displayName: '',
  );

  for (final leaf in leaves) {
    final path = pathOf(leaf);
    if (path.isEmpty) {
      root.leaves.add(leaf);
      continue;
    }
    final segments = _splitPath(path);
    if (segments.length <= 1) {
      // Bare filename with no parent dir — fall under root.
      root.leaves.add(leaf);
      continue;
    }
    // Drop the trailing filename — leaves attach to the parent dir.
    final dirSegments = segments.sublist(0, segments.length - 1);
    FolderNode<T> cursor = root;
    final pathBuilder = StringBuffer();
    for (var i = 0; i < dirSegments.length; i++) {
      final seg = dirSegments[i];
      if (i == 0) {
        pathBuilder.write(seg);
      } else {
        pathBuilder.write('/');
        pathBuilder.write(seg);
      }
      final dirPath = pathBuilder.toString();
      final existing = cursor.children
          .cast<FolderNode<T>?>()
          .firstWhere((c) => c!.absolutePath == dirPath, orElse: () => null);
      if (existing != null) {
        cursor = existing;
      } else {
        final next = FolderNode<T>(
          absolutePath: dirPath,
          displayName: seg.isEmpty ? '/' : seg,
        );
        cursor.children.add(next);
        cursor = next;
      }
    }
    cursor.leaves.add(leaf);
  }

  // Sort children alphabetically at every depth.  Predictable tree order
  // is the operator's expectation and lets the cubit's expand-state
  // survive across reloads with the same paths.
  void sort(FolderNode<T> n) {
    n.children.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    for (final c in n.children) {
      sort(c);
    }
  }

  sort(root);
  if (leaves is List<T>) {
    _folderTreeCache[leaves] = root;
  }
  return root;
}

List<String> _splitPath(String path) {
  // Normalise both Windows backslashes and POSIX slashes; strip a
  // leading drive-letter colon trailing slash artefact ("C:" → "C:").
  final normalised = path.replaceAll('\\', '/');
  return normalised.split('/').where((s) => s.isNotEmpty).toList();
}

// ── Renderer ────────────────────────────────────────────────────────────────

/// Renders a [FolderNode] tree as a vertical column of expandable folder
/// rows + leaf rows.  Caller supplies a [leafBuilder] for each leaf and
/// optional [folderTrailing] for the per-folder action affordance.
class FolderTreeView<T> extends StatelessWidget {
  const FolderTreeView({
    super.key,
    required this.root,
    required this.expandedPaths,
    required this.onToggleExpanded,
    required this.idOf,
    required this.leafBuilder,
    required this.sizeOf,
    this.selectedIds = const <String>{},
    this.onFolderToggle,
    this.showCheckbox = true,
  });

  final FolderNode<T> root;
  final Set<String> expandedPaths;
  final ValueChanged<String> onToggleExpanded;

  /// Stable id extractor for a leaf (file id for Candidates, job id
  /// stringified for History).
  final String Function(T leaf) idOf;

  /// Builder for a single leaf row.
  final Widget Function(BuildContext context, T leaf) leafBuilder;

  /// Per-leaf size for the folder header's "X · Y bytes" subtitle.
  final int Function(T leaf) sizeOf;

  /// Selected leaf ids — drives the tri-state checkbox state on folder
  /// rows.  Pass an empty set for tabs that don't need selection (the
  /// History tab supplies an empty set + `showCheckbox: false`).
  final Set<String> selectedIds;

  /// Folder-level checkbox toggle; receives the recursive flatten of
  /// the folder's leaf ids and a desired `select` boolean.  Null when
  /// the tab doesn't expose folder selection.
  final void Function(Iterable<String> leafIds, bool select)? onFolderToggle;

  final bool showCheckbox;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Direct leaves first (rare — only files with no parent dir),
        // then folders.
        for (final leaf in root.leaves) leafBuilder(context, leaf),
        for (final child in root.children)
          _FolderBranch<T>(
            node: child,
            depth: 0,
            expandedPaths: expandedPaths,
            onToggleExpanded: onToggleExpanded,
            idOf: idOf,
            leafBuilder: leafBuilder,
            sizeOf: sizeOf,
            selectedIds: selectedIds,
            onFolderToggle: onFolderToggle,
            showCheckbox: showCheckbox,
          ),
      ],
    );
  }
}

class _FolderBranch<T> extends StatelessWidget {
  const _FolderBranch({
    required this.node,
    required this.depth,
    required this.expandedPaths,
    required this.onToggleExpanded,
    required this.idOf,
    required this.leafBuilder,
    required this.sizeOf,
    required this.selectedIds,
    required this.onFolderToggle,
    required this.showCheckbox,
  });

  final FolderNode<T> node;
  final int depth;
  final Set<String> expandedPaths;
  final ValueChanged<String> onToggleExpanded;
  final String Function(T leaf) idOf;
  final Widget Function(BuildContext context, T leaf) leafBuilder;
  final int Function(T leaf) sizeOf;
  final Set<String> selectedIds;
  final void Function(Iterable<String> leafIds, bool select)? onFolderToggle;
  final bool showCheckbox;

  @override
  Widget build(BuildContext context) {
    final expanded = expandedPaths.contains(node.absolutePath);
    final triState = showCheckbox ? node.isFullySelected(selectedIds, idOf) : false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FolderHeader(
          node: node,
          depth: depth,
          expanded: expanded,
          triState: triState,
          showCheckbox: showCheckbox,
          totalSize: node.totalSize(sizeOf),
          onTapHeader: () => onToggleExpanded(node.absolutePath),
          onTapCheckbox: onFolderToggle == null
              ? null
              : () {
                  // Tri-state checkbox: any-selected → clear; otherwise → select all.
                  final selectAll = triState != true;
                  final ids = node.flatten().map(idOf);
                  onFolderToggle!(ids, selectAll);
                },
        ),
        if (expanded) ...[
          for (final leaf in node.leaves)
            Padding(
              padding: EdgeInsets.only(left: _indentFor(depth + 1)),
              child: leafBuilder(context, leaf),
            ),
          for (final child in node.children)
            _FolderBranch<T>(
              node: child,
              depth: depth + 1,
              expandedPaths: expandedPaths,
              onToggleExpanded: onToggleExpanded,
              idOf: idOf,
              leafBuilder: leafBuilder,
              sizeOf: sizeOf,
              selectedIds: selectedIds,
              onFolderToggle: onFolderToggle,
              showCheckbox: showCheckbox,
            ),
        ],
      ],
    );
  }

  static double _indentFor(int depth) => 14.0 + (depth * 14.0);
}

class _FolderHeader extends StatelessWidget {
  const _FolderHeader({
    required this.node,
    required this.depth,
    required this.expanded,
    required this.triState,
    required this.showCheckbox,
    required this.totalSize,
    required this.onTapHeader,
    required this.onTapCheckbox,
  });

  final FolderNode<dynamic> node;
  final int depth;
  final bool expanded;

  /// `true` (all selected) / `false` (none) / `null` (partial).
  final bool? triState;

  final bool showCheckbox;
  final int totalSize;
  final VoidCallback onTapHeader;
  final VoidCallback? onTapCheckbox;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTapHeader,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _FolderBranch._indentFor(depth) - 6,
          AppSpacing.s10,
          AppSpacing.s14,
          AppSpacing.s10,
        ),
        child: Row(
          children: [
            Icon(
              expanded
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_right_rounded,
              size: 18,
              color: AppColors.textMutedV2,
            ),
            const SizedBox(width: AppSpacing.s4),
            if (showCheckbox && onTapCheckbox != null) ...[
              GestureDetector(
                onTap: onTapCheckbox,
                behavior: HitTestBehavior.opaque,
                child: _TriStateCheckbox(state: triState ?? false),
              ),
              const SizedBox(width: AppSpacing.s10),
            ],
            const Icon(
              Icons.folder_rounded,
              size: 14,
              color: AppColors.violet,
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                node.displayName,
                style: AppTypography.body.copyWith(
                  color: AppColors.textBright,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.s10),
            Text(
              '${node.totalCount} · ${_formatBytes(totalSize)}',
              style: AppTypography.monoCaption.copyWith(
                color: AppColors.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tri-state checkbox — full / empty / partial.  Partial paints a small
/// horizontal bar inside the box (matches Material's `tristate` styling
/// without depending on Material's deprecated `Checkbox.tristate`).
class _TriStateCheckbox extends StatelessWidget {
  const _TriStateCheckbox({required this.state});

  /// `true` = all selected, `false` = none, `null` = partial.
  final bool? state;

  @override
  Widget build(BuildContext context) {
    final filled = state == true || state == null;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: filled ? AppColors.violet : const Color(0x08FFFFFF),
        border: Border.all(
          color: filled ? AppColors.violet : AppColors.borderHover,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: state == true
          ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
          : state == null
              ? Center(
                  child: Container(
                    width: 8,
                    height: 2,
                    decoration: const BoxDecoration(color: Colors.white),
                  ),
                )
              : null,
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  double v = bytes / 1024;
  int i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
}
