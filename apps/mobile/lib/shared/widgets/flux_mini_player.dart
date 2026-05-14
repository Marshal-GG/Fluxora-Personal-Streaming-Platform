/// `FluxMiniPlayer` — 64-px persistent bar that sits above the bottom
/// tabs whenever something is playing in the background.
///
/// Subscribes to the singleton [PlayerCubit] (`PlaybackProvider` per plan
/// §9.2) — visible when state is [PlayerReady], invisible otherwise.
/// Tap → push `/player`; close (X) → cubit.dismiss().
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_mobile/core/router/app_router.dart';
import 'package:fluxora_mobile/features/player/presentation/cubit/player_cubit.dart';
import 'package:fluxora_mobile/features/player/presentation/cubit/player_state.dart';

class FluxMiniPlayer extends StatelessWidget {
  const FluxMiniPlayer({super.key});

  static const double height = 64;

  @override
  Widget build(BuildContext context) {
    final cubit = GetIt.I<PlayerCubit>();
    return BlocBuilder<PlayerCubit, PlayerState>(
      bloc: cubit,
      builder: (context, state) {
        final ready = state is PlayerReady;
        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.bottomCenter,
          child: ready
              ? _Bar(
                  engine: state.engine,
                  title: state.fileName,
                  onTap: () => _resume(context, state),
                  onClose: cubit.dismiss,
                )
              : const SizedBox(width: double.infinity, height: 0),
        );
      },
    );
  }

  /// Resumes the fullscreen player route. The `MediaFile` `extra` is needed
  /// by the existing route schema; we synthesise a minimal one from the
  /// active state since the original `MediaFile` isn't carried in
  /// `PlayerReady`. The receiving screen calls `startStream` again, which
  /// is a no-op since the same session id is already active inside the
  /// singleton cubit (see `_disposeCurrentSession` no-op path).
  void _resume(BuildContext context, PlayerReady state) {
    // Push directly — the player screen consumes the singleton cubit so it
    // re-attaches to the live session without spinning up a new one.
    context.push(Routes.playerResume);
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.engine,
    required this.title,
    required this.onTap,
    required this.onClose,
  });

  final PlayerEngine engine;
  final String title;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          // The bar itself is a tap-to-expand affordance.  Title is
          // surfaced via the `value` so a screen reader announces "Now
          // playing: <title>.  Expand player." in one swipe.
          label: 'Now playing: $title. Expand player',
          button: true,
          container: true,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: FluxMiniPlayer.height,
              decoration: const BoxDecoration(
                color: Color(0xF008061A), // bgRoot 0.94
                border: Border(
                  top: BorderSide(color: AppColors.borderSubtle),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  // Poster / placeholder — decorative, hidden from a11y.
                  ExcludeSemantics(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.violetDeep, AppColors.violet],
                        ),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.movie_creation_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    // Already surfaced as part of the parent `Semantics.label`.
                    // Hide the inner Text so the screen reader doesn't read
                    // the title a second time after the bar's own label.
                    child: ExcludeSemantics(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTypography.body.copyWith(
                              color: AppColors.textBright,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          _TimeLine(engine: engine),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _PlayPauseButton(engine: engine),
                  Semantics(
                    label: 'Close mini player',
                    button: true,
                    child: IconButton(
                      tooltip: 'Close',
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.textMutedV2,
                        size: 20,
                      ),
                      onPressed: onClose,
                      splashRadius: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeLine extends StatelessWidget {
  const _TimeLine({required this.engine});

  final PlayerEngine engine;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: engine.positionStream,
      initialData: engine.position,
      builder: (context, posSnap) {
        return StreamBuilder<Duration>(
          stream: engine.durationStream,
          initialData: engine.duration,
          builder: (context, durSnap) {
            final pos = posSnap.data ?? Duration.zero;
            final dur = durSnap.data ?? Duration.zero;
            final value = (dur.inMilliseconds == 0)
                ? 0.0
                : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
            return SizedBox(
              height: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: const Color(0x33FFFFFF),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.violet),
                  minHeight: 3,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.engine});

  final PlayerEngine engine;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: engine.isPlayingStream,
      initialData: engine.isPlaying,
      builder: (context, snap) {
        final playing = snap.data ?? false;
        return Semantics(
          // State-dependent label — read by screen readers and refreshed
          // on every play/pause stream tick.
          label: playing ? 'Pause' : 'Play',
          button: true,
          child: IconButton(
            tooltip: playing ? 'Pause' : 'Play',
            icon: Icon(
              playing ? Icons.pause : Icons.play_arrow,
              color: AppColors.textBright,
            ),
            onPressed: () {
              if (engine.isPlaying) {
                engine.pause();
              } else {
                engine.play();
              }
            },
            splashRadius: 22,
          ),
        );
      },
    );
  }
}
