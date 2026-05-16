/// Type-filter chip row for the library folder browser.
///
/// Renders a horizontal `Wrap` of 7 single-select kind chips
/// (All / Folders / Videos / Images / Audio / PDFs / Other) followed
/// by a separator and an 8th "Indexed only" stacked toggle.  The
/// 8th chip is independent of the kind-filter group — it layers on
/// top so the operator can combine, e.g., "Videos" + "Indexed only".
///
/// Reads + writes [LibraryBrowseCubit] state via `setKindFilter` and
/// `setIndexedOnly`; wrapped in a [BlocBuilder] so the active highlight
/// re-renders when the cubit re-emits.  Plan 28 Phase B.

library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fluxora_core/constants/app_colors.dart';

import 'package:fluxora_desktop/features/library/presentation/cubit/library_browse_cubit.dart';

class LibraryBrowseFilterChips extends StatelessWidget {
  const LibraryBrowseFilterChips({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryBrowseCubit, LibraryBrowseState>(
      builder: (context, _) {
        final cubit = context.read<LibraryBrowseCubit>();
        final active = cubit.kindFilter;
        final indexedOnly = cubit.indexedOnly;
        return Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ChipButton(
              label: 'All',
              icon: Icons.apps_rounded,
              isActive: active == BrowseKindFilter.all,
              onTap: () => cubit.setKindFilter(BrowseKindFilter.all),
            ),
            _ChipButton(
              label: 'Folders',
              icon: Icons.folder_outlined,
              isActive: active == BrowseKindFilter.folders,
              onTap: () => cubit.setKindFilter(BrowseKindFilter.folders),
            ),
            _ChipButton(
              label: 'Videos',
              icon: Icons.movie_outlined,
              isActive: active == BrowseKindFilter.videos,
              onTap: () => cubit.setKindFilter(BrowseKindFilter.videos),
            ),
            _ChipButton(
              label: 'Images',
              icon: Icons.image_outlined,
              isActive: active == BrowseKindFilter.images,
              onTap: () => cubit.setKindFilter(BrowseKindFilter.images),
            ),
            _ChipButton(
              label: 'Audio',
              icon: Icons.music_note_outlined,
              isActive: active == BrowseKindFilter.audio,
              onTap: () => cubit.setKindFilter(BrowseKindFilter.audio),
            ),
            _ChipButton(
              label: 'PDFs',
              icon: Icons.picture_as_pdf_outlined,
              isActive: active == BrowseKindFilter.pdfs,
              onTap: () => cubit.setKindFilter(BrowseKindFilter.pdfs),
            ),
            _ChipButton(
              label: 'Other',
              icon: Icons.insert_drive_file_outlined,
              isActive: active == BrowseKindFilter.other,
              onTap: () => cubit.setKindFilter(BrowseKindFilter.other),
            ),
            // Visual separator between the single-select kind group and
            // the independent indexed-only stacked toggle.
            Container(
              width: 1,
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: const Color(0x14FFFFFF),
            ),
            _ChipButton(
              label: 'Indexed only',
              icon: indexedOnly
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_outline_rounded,
              isActive: indexedOnly,
              onTap: () => cubit.setIndexedOnly(!indexedOnly),
            ),
          ],
        );
      },
    );
  }
}

/// Single rounded-pill chip with active / inactive / hover-on-inactive
/// visual states.  Private to this file — drives both the kind group
/// and the indexed-only toggle off the same shape.
class _ChipButton extends StatefulWidget {
  const _ChipButton({
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
  State<_ChipButton> createState() => _ChipButtonState();
}

class _ChipButtonState extends State<_ChipButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    final hoverHighlight = _hovered && !isActive;

    final bgColor = isActive
        ? const Color(0x1AA855F7)
        : (hoverHighlight
            ? const Color(0x0DA855F7)
            : const Color(0x05FFFFFF));
    final borderColor = isActive
        ? const Color(0x66A855F7)
        : (hoverHighlight
            ? const Color(0x33A855F7)
            : const Color(0x0AFFFFFF));
    final fgColor = (isActive || hoverHighlight)
        ? AppColors.violet
        : AppColors.textMutedV2;
    final fontWeight = isActive ? FontWeight.w600 : FontWeight.w500;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding:
              const EdgeInsets.symmetric(horizontal: 7, vertical: 11),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 12.5, color: fgColor),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: fontWeight,
                  color: fgColor,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
