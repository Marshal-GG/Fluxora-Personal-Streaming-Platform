import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_browse_cubit.dart';

/// Two-icon segmented control for the library browser body view mode.
///
/// Left button = list view, right button = grid view.  Clicking either
/// dispatches [LibraryBrowseCubit.setViewMode]; the cubit re-emits and
/// the active button flips to the violet-tinted state.
class LibraryBrowseViewToggle extends StatelessWidget {
  const LibraryBrowseViewToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryBrowseCubit, LibraryBrowseState>(
      builder: (context, _) {
        final cubit = context.read<LibraryBrowseCubit>();
        final mode = cubit.viewMode;
        return Container(
          height: 28,
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: const Color(0x14FFFFFF)),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ToggleButton(
                  icon: Icons.view_list_rounded,
                  tooltip: 'List view',
                  active: mode == BrowseViewMode.list,
                  onTap: () => cubit.setViewMode(BrowseViewMode.list),
                ),
                _ToggleButton(
                  icon: Icons.grid_view_rounded,
                  tooltip: 'Grid view',
                  active: mode == BrowseViewMode.grid,
                  onTap: () => cubit.setViewMode(BrowseViewMode.grid),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ToggleButton extends StatefulWidget {
  const _ToggleButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends State<_ToggleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color iconColor;
    if (widget.active) {
      fill = const Color(0x1AA855F7);
      iconColor = AppColors.violet;
    } else if (_hovered) {
      fill = const Color(0x0DA855F7);
      iconColor = AppColors.violet;
    } else {
      fill = Colors.transparent;
      iconColor = AppColors.textMutedV2;
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.tooltip,
          waitDuration: const Duration(milliseconds: 600),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 28,
            height: 28,
            color: fill,
            child: Icon(widget.icon, size: 14, color: iconColor),
          ),
        ),
      ),
    );
  }
}
