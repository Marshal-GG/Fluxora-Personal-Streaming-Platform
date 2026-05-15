/// Audio + subtitles bottom sheet — two-tab `FluxBottomSheet`.
///
/// **Audio tab**.  Lists the cubit's `availableAudioTracks` — the
/// server-supplied source-stream metadata captured in `PlayerReady`.
/// Tapping a row dispatches `PlayerCubit.selectAudioTrack(index)`
/// which switches the active audio track via the server-restart
/// path — no client-side libmpv-only call.  When the cubit list is
/// empty (older server omitting `audio_tracks`, or a single-track
/// file) AND we're on the MediaKitEngine path, we fall back to
/// reading media_kit's own track table — keeps the picker functional
/// on older server builds.
///
/// **Subtitles tab** — reads media_kit's track list directly via the
/// engine's `mediaKitPlayer` escape hatch.  On a non-MediaKit engine
/// (ExoPlayerEngine and future engines) this tab hides until those
/// engines plumb their own subtitle APIs through here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:media_kit/media_kit.dart' show AudioTrack, SubtitleTrack;
import 'package:fluxora_mobile/features/player/domain/entities/stream_start_response.dart';
import 'package:fluxora_mobile/features/player/presentation/cubit/player_cubit.dart';
import 'package:fluxora_mobile/features/player/presentation/cubit/player_state.dart';

class AudioSubsSheet extends StatefulWidget {
  const AudioSubsSheet({required this.engine, super.key});

  final PlayerEngine engine;

  @override
  State<AudioSubsSheet> createState() => _AudioSubsSheetState();
}

class _AudioSubsSheetState extends State<AudioSubsSheet> {
  @override
  Widget build(BuildContext context) {
    // libmpv-specific track tables — only readable on the
    // MediaKitEngine path.  Falling through with empty lists when the
    // engine isn't MediaKit means subtitles + the legacy audio
    // fallback list quietly disappear; the cubit-driven audio path
    // still works because it reads `availableAudioTracks` from the
    // server response and doesn't need a live media_kit handle.
    final mkEngine = widget.engine is MediaKitEngine
        ? widget.engine as MediaKitEngine
        : null;
    final tracks = mkEngine?.mediaKitPlayer.state.tracks;
    final selectedSubtitle = mkEngine?.mediaKitPlayer.state.track.subtitle;

    return DefaultTabController(
      length: 2,
      child: FluxBottomSheet(
        title: 'Audio & subtitles',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TabBar(
              indicatorColor: AppColors.violet,
              labelColor: AppColors.textBright,
              unselectedLabelColor: AppColors.textMutedV2,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                Tab(text: 'Audio'),
                Tab(text: 'Subtitles'),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 280,
              child: TabBarView(
                children: [
                  // Cubit-driven audio picker.  Falls back to
                  // media_kit's own track table when the cubit hasn't
                  // populated `availableAudioTracks` (older server
                  // build, or no active PlayerReady) — only available
                  // on the MediaKitEngine path.
                  BlocBuilder<PlayerCubit, PlayerState>(
                    builder: (context, state) {
                      if (state is PlayerReady &&
                          state.availableAudioTracks.isNotEmpty) {
                        return _AudioTrackList(
                          tracks: state.availableAudioTracks,
                          selectedIndex: state.selectedAudioTrackIndex,
                          onTap: (track) {
                            context.read<PlayerCubit>().selectAudioTrack(
                              track.index,
                            );
                            Navigator.of(context).pop();
                          },
                        );
                      }
                      // Fallback — older server build (no
                      // `audio_tracks` field) or no cubit metadata
                      // yet.  Reads media_kit's own track table.
                      // Hidden when the engine isn't MediaKit (the
                      // cubit-driven picker is the only supported
                      // path there).
                      if (mkEngine == null || tracks == null) {
                        return Center(
                          child: Text(
                            'No tracks available',
                            style: AppTypography.captionV2.copyWith(
                              color: AppColors.textDim,
                            ),
                          ),
                        );
                      }
                      final selectedAudio =
                          mkEngine.mediaKitPlayer.state.track.audio;
                      return _TrackList<AudioTrack>(
                        tracks: tracks.audio,
                        selected: selectedAudio,
                        labelOf: (t, i) =>
                            t.title ?? t.language ?? 'Track ${i + 1}',
                        onTap: (t) {
                          mkEngine.mediaKitPlayer.setAudioTrack(t);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                  if (mkEngine != null &&
                      tracks != null &&
                      selectedSubtitle != null)
                    _TrackList<SubtitleTrack>(
                      tracks: tracks.subtitle,
                      selected: selectedSubtitle,
                      labelOf: (t, i) =>
                          t.title ?? t.language ?? 'Subtitle ${i + 1}',
                      onTap: (t) {
                        mkEngine.mediaKitPlayer.setSubtitleTrack(t);
                        Navigator.of(context).pop();
                      },
                    )
                  else
                    Center(
                      child: Text(
                        'Subtitles unavailable',
                        style: AppTypography.captionV2.copyWith(
                          color: AppColors.textDim,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Picker rows for cubit-driven `AudioTrackInfo` entries.
/// Distinct from [_TrackList<AudioTrack>] because the cubit's
/// `AudioTrackInfo` carries server-supplied metadata (codec, channels,
/// language tag) and selection is by source-stream `index`, not by
/// `AudioTrack` identity.
class _AudioTrackList extends StatelessWidget {
  const _AudioTrackList({
    required this.tracks,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<AudioTrackInfo> tracks;
  final int selectedIndex;
  final ValueChanged<AudioTrackInfo> onTap;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return Center(
        child: Text(
          'No tracks available',
          style: AppTypography.captionV2.copyWith(color: AppColors.textDim),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: tracks.length,
      itemBuilder: (context, i) {
        final t = tracks[i];
        final isSelected = t.index == selectedIndex;
        return ListTile(
          dense: false,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            isSelected ? Icons.check_circle : Icons.circle_outlined,
            color: isSelected ? AppColors.violet : AppColors.textDim,
            size: 20,
          ),
          title: Text(
            t.labelFor(i + 1),
            style: AppTypography.body.copyWith(
              color: isSelected ? AppColors.textBright : AppColors.textBody,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          onTap: () => onTap(t),
        );
      },
    );
  }
}

class _TrackList<T> extends StatelessWidget {
  const _TrackList({
    required this.tracks,
    required this.selected,
    required this.labelOf,
    required this.onTap,
  });

  final List<T> tracks;
  final T selected;
  final String Function(T, int) labelOf;
  final ValueChanged<T> onTap;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return Center(
        child: Text(
          'No tracks available',
          style: AppTypography.captionV2.copyWith(color: AppColors.textDim),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: tracks.length,
      itemBuilder: (context, i) {
        final t = tracks[i];
        final isSelected = t == selected;
        return ListTile(
          dense: false,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            isSelected ? Icons.check_circle : Icons.circle_outlined,
            color: isSelected ? AppColors.violet : AppColors.textDim,
            size: 20,
          ),
          title: Text(
            labelOf(t, i),
            style: AppTypography.body.copyWith(
              color: isSelected ? AppColors.textBright : AppColors.textBody,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          onTap: () => onTap(t),
        );
      },
    );
  }
}
