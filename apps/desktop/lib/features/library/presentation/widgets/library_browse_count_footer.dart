/// Live count summary strip for the library folder browser.
///
/// Reads the cubit's current state + UI prefs, re-runs the same
/// [applyBrowseFilters] predicate the body uses, and renders a single
/// line of muted text:
///
///   `12 folders · 47 files · 3 indexed · 1.2 GB visible`
///
/// Indexed + size segments are skipped when zero so non-media
/// libraries (e.g. all PDFs / docs) get a clean two-segment line.
/// Plan 28 Phase B.

library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';

import 'package:fluxora_desktop/features/library/presentation/cubit/library_browse_cubit.dart';

class LibraryBrowseCountFooter extends StatelessWidget {
  const LibraryBrowseCountFooter({super.key});

  /// Fixed strip height — matches the empty-state placeholder so the
  /// layout doesn't jump between Loading / Loaded.
  static const double kHeight = 28;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryBrowseCubit, LibraryBrowseState>(
      builder: (context, state) {
        if (state is! LibraryBrowseLoaded) {
          return const SizedBox(height: 24);
        }
        final cubit = context.read<LibraryBrowseCubit>();
        final filtered = applyBrowseFilters(
          state.response.entries,
          indexedOnly: cubit.indexedOnly,
          search: cubit.search,
          sortBy: cubit.sortBy,
          sortAsc: cubit.sortAsc,
          kindFilter: cubit.kindFilter,
        );

        final folderCount = filtered.where((e) => e.isDir).length;
        final fileCount = filtered.where((e) => !e.isDir).length;
        final indexedCount =
            filtered.where((e) => !e.isDir && e.isIndexed).length;
        final visibleBytes = filtered
            .where((e) => !e.isDir)
            .fold<int>(0, (sum, e) => sum + e.sizeBytes);

        final segments = <String>[
          _plural(folderCount, 'folder', 'folders'),
          _plural(fileCount, 'file', 'files'),
          if (indexedCount > 0) '$indexedCount indexed',
          if (visibleBytes > 0) '${_humanBytes(visibleBytes)} visible',
        ];

        return Container(
          height: kHeight,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
          child: Text(
            segments.join(' · '),
            style: AppTypography.captionV2.copyWith(
              color: AppColors.textMutedV2,
            ),
          ),
        );
      },
    );
  }
}

String _plural(int n, String singular, String plural) =>
    n == 1 ? '1 $singular' : '$n $plural';

/// Six-line byte-size formatter — shape copied from the same helper in
/// `library_files_screen.dart` (private there, so we re-declare it here
/// rather than make it public for one widget).
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
