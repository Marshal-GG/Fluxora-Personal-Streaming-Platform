/// Audio + subtitles bottom sheet — two-tab `FluxBottomSheet`.
///
/// Reads `player.state.tracks` for the available audio + subtitle tracks
/// and `player.state.track` for the currently selected pair. Selection
/// dispatches `player.setAudioTrack` / `player.setSubtitleTrack` and
/// closes the sheet.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:media_kit/media_kit.dart' show AudioTrack, Player, SubtitleTrack;

class AudioSubsSheet extends StatefulWidget {
  const AudioSubsSheet({required this.player, super.key});

  final Player player;

  @override
  State<AudioSubsSheet> createState() => _AudioSubsSheetState();
}

class _AudioSubsSheetState extends State<AudioSubsSheet> {
  @override
  Widget build(BuildContext context) {
    final tracks = widget.player.state.tracks;
    final selectedAudio = widget.player.state.track.audio;
    final selectedSubtitle = widget.player.state.track.subtitle;

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
                  _TrackList<AudioTrack>(
                    tracks: tracks.audio,
                    selected: selectedAudio,
                    labelOf: (t, i) =>
                        t.title ?? t.language ?? 'Track ${i + 1}',
                    onTap: (t) {
                      widget.player.setAudioTrack(t);
                      Navigator.of(context).pop();
                    },
                  ),
                  _TrackList<SubtitleTrack>(
                    tracks: tracks.subtitle,
                    selected: selectedSubtitle,
                    labelOf: (t, i) =>
                        t.title ?? t.language ?? 'Subtitle ${i + 1}',
                    onTap: (t) {
                      widget.player.setSubtitleTrack(t);
                      Navigator.of(context).pop();
                    },
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
