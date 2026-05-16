import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_browse_cubit.dart';

/// In-place search box for the library file browser toolbar.
///
/// Every keystroke pumps [LibraryBrowseCubit.setSearch], which filters
/// the already-loaded directory listing client-side (case-insensitive
/// substring match against entry name).  No debounce — the filter is a
/// synchronous Dart `String.contains` over at most a few hundred entries.
///
/// The internal [TextEditingController] is kept in sync with the cubit's
/// [LibraryBrowseCubit.search] getter so that external resets (e.g. the
/// cubit clearing `search` to `''` on `navigateTo`) clear the visible
/// field as well.
class LibraryBrowseSearchBar extends StatefulWidget {
  const LibraryBrowseSearchBar({
    super.key,
    this.width = 260,
    this.focusNode,
  });

  /// Fixed pixel width of the search field — keeps the toolbar layout
  /// stable regardless of typed content.
  final double width;

  /// Optional externally-owned focus node so a parent keyboard handler
  /// can `requestFocus()` (e.g. screen-level `/` shortcut focuses the
  /// search field).  When null, an internal node is created.  Plan 28
  /// Phase B keyboard navigation.
  final FocusNode? focusNode;

  @override
  State<LibraryBrowseSearchBar> createState() => _LibraryBrowseSearchBarState();
}

class _LibraryBrowseSearchBarState extends State<LibraryBrowseSearchBar> {
  late final TextEditingController _controller;
  FocusNode? _ownFocusNode;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    final cubit = context.read<LibraryBrowseCubit>();
    _controller = TextEditingController(text: cubit.search);
  }

  @override
  void dispose() {
    _controller.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _syncFromCubit(String cubitSearch) {
    if (_controller.text == cubitSearch) return;
    // Preserve caret-at-end semantics on external resets — the only
    // realistic external value is `''` (cleared on navigation), so the
    // selection collapses to offset 0.
    _controller.value = TextEditingValue(
      text: cubitSearch,
      selection: TextSelection.collapsed(offset: cubitSearch.length),
    );
  }

  void _clear() {
    final cubit = context.read<LibraryBrowseCubit>();
    _controller.clear();
    cubit.setSearch('');
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LibraryBrowseCubit, LibraryBrowseState>(
      // Re-emit whenever the cubit's state object changes — the cubit
      // re-emits on every UI-pref tweak so this covers external search
      // resets (navigation, programmatic clears).
      listener: (context, _) {
        _syncFromCubit(context.read<LibraryBrowseCubit>().search);
      },
      child: SizedBox(
        width: widget.width,
        height: 32,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            final hasQuery = value.text.isNotEmpty;
            return TextField(
              controller: _controller,
              focusNode: _focusNode,
              cursorColor: AppColors.violet,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                color: AppColors.textBright,
              ),
              onChanged: (v) =>
                  context.read<LibraryBrowseCubit>().setSearch(v),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search this folder...',
                hintStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  color: AppColors.textDim,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 16,
                  color: AppColors.textMutedV2,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                suffixIcon: hasQuery
                    ? _ClearButton(onTap: _clear)
                    : null,
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
                filled: true,
                fillColor: const Color(0x0AFFFFFF),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm - 1),
                  borderSide: const BorderSide(color: Color(0x14FFFFFF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm - 1),
                  borderSide:
                      const BorderSide(color: AppColors.violet, width: 1.5),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Trailing clear-affordance — only mounted when there's a query to
/// clear so the field reads as a plain search box at rest.
class _ClearButton extends StatefulWidget {
  const _ClearButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ClearButton> createState() => _ClearButtonState();
}

class _ClearButtonState extends State<_ClearButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Tooltip(
          message: 'Clear search',
          waitDuration: const Duration(milliseconds: 600),
          child: SizedBox(
            width: 28,
            height: 28,
            child: Center(
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: _hovered ? AppColors.violet : AppColors.textMutedV2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
