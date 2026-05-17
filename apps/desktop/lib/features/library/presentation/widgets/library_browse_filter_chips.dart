/// Folder-browser type-filter chip row.
///
/// Thin adapter around the shared [FluxFilterChips] widget — owns the
/// chip data (kind labels + icons + the `Indexed only` toggle) and
/// wires the visual state to [LibraryBrowseCubit].  The chip design
/// itself lives in `flux_filter_chips.dart` so the Library page + this
/// surface render identical pills.
///
/// Layout: 7 single-select kind chips (All / Folders / Videos / Images
/// / Audio / PDFs / Other) + a thin divider + an 8th independent
/// "Indexed only" toggle that layers on top so the operator can
/// combine, e.g., "Videos" + "Indexed only".  Plan 28 Phase B.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fluxora_desktop/features/library/presentation/cubit/library_browse_cubit.dart';
import 'package:fluxora_desktop/shared/widgets/flux_filter_chips.dart';
import 'package:fluxora_desktop/shared/widgets/flux_tab_bar.dart' show FluxTab;

class LibraryBrowseFilterChips extends StatelessWidget {
  const LibraryBrowseFilterChips({super.key});

  static const _indexedOnlyId = '__indexed_only__';

  static const _kindTabs = <FluxTab>[
    FluxTab(id: 'all', label: 'All', icon: Icons.apps_rounded),
    FluxTab(id: 'folders', label: 'Folders', icon: Icons.folder_outlined),
    FluxTab(id: 'videos', label: 'Videos', icon: Icons.movie_outlined),
    FluxTab(id: 'images', label: 'Images', icon: Icons.image_outlined),
    FluxTab(id: 'audio', label: 'Audio', icon: Icons.music_note_outlined),
    FluxTab(id: 'pdfs', label: 'PDFs', icon: Icons.picture_as_pdf_outlined),
    FluxTab(
      id: 'other',
      label: 'Other',
      icon: Icons.insert_drive_file_outlined,
    ),
  ];

  static BrowseKindFilter _idToFilter(String id) => switch (id) {
        'folders' => BrowseKindFilter.folders,
        'videos' => BrowseKindFilter.videos,
        'images' => BrowseKindFilter.images,
        'audio' => BrowseKindFilter.audio,
        'pdfs' => BrowseKindFilter.pdfs,
        'other' => BrowseKindFilter.other,
        _ => BrowseKindFilter.all,
      };

  static String _filterToId(BrowseKindFilter filter) => switch (filter) {
        BrowseKindFilter.folders => 'folders',
        BrowseKindFilter.videos => 'videos',
        BrowseKindFilter.images => 'images',
        BrowseKindFilter.audio => 'audio',
        BrowseKindFilter.pdfs => 'pdfs',
        BrowseKindFilter.other => 'other',
        BrowseKindFilter.all => 'all',
      };

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryBrowseCubit, LibraryBrowseState>(
      builder: (context, _) {
        final cubit = context.read<LibraryBrowseCubit>();
        final activeKindId = _filterToId(cubit.kindFilter);
        final indexedOnly = cubit.indexedOnly;
        return FluxFilterChips(
          tabs: _kindTabs,
          activeId: activeKindId,
          onChange: (id) => cubit.setKindFilter(_idToFilter(id)),
          trailing: [
            const FluxFilterChipsDivider(),
            FluxFilterChip(
              tab: FluxTab(
                id: _indexedOnlyId,
                label: 'Indexed only',
                icon: indexedOnly
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_outline_rounded,
              ),
              isActive: indexedOnly,
              onTap: () => cubit.setIndexedOnly(!indexedOnly),
            ),
          ],
        );
      },
    );
  }
}
