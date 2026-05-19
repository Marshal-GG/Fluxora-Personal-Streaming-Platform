/// FluxRefreshIndicatorStrip — 2-px violet `LinearProgressIndicator`
/// rendered at the top of a listing while a background fetch is in
/// flight.
///
/// Established for the folder browser's soft-refresh pattern
/// ([library_files_screen.dart]) where the existing card chrome
/// (URL bar, toolbar, listing, footer) stays mounted across
/// navigation + filter changes and only this thin strip surfaces the
/// in-flight fetch.  Pair with a "stale-while-revalidate" cubit that
/// emits the existing loaded state with a `refreshing: true` flag
/// instead of flipping back to a `*Loading` state.
///
/// **Shape:** 2 px tall.  When [refreshing] is `false` the slot
/// collapses to `SizedBox.shrink()` so the parent column doesn't
/// reserve dead space.
///
/// **Colour:** indeterminate violet on a transparent track — matches
/// the brand primary used everywhere else for in-flight affordances.
library;

import 'package:flutter/material.dart';

import 'package:fluxora_core/constants/app_colors.dart';

class FluxRefreshIndicatorStrip extends StatelessWidget {
  const FluxRefreshIndicatorStrip({
    super.key,
    required this.refreshing,
  });

  /// `true` while a background fetch is in flight.  Caller is
  /// responsible for wiring this to their cubit / bloc / stream
  /// (typically a `BlocBuilder` with a `buildWhen` that only fires
  /// when the refreshing flag flips).
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
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
  }
}
