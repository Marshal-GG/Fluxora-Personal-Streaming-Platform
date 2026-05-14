/// Music player screen.
///
/// Prototype spec (§ music-player): vertical gradient #1a0820 → #08061A,
/// 280×280 album-art placeholder, scrubber, play/pause + prev/next controls.
/// Backed by [MusicPlayerCubit] / [just_audio].  Prev/next are stubs in v1
/// (no queue); shuffle and queue icons are rendered but disabled.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_core/storage/secure_storage.dart';

import 'package:fluxora_mobile/features/viewer/presentation/cubit/music_player_cubit.dart';

class MusicPlayerScreen extends StatelessWidget {
  const MusicPlayerScreen({required this.file, super.key});

  final MediaFile file;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MusicPlayerCubit>(
      create: (_) => MusicPlayerCubit(
        secureStorage: GetIt.I<SecureStorage>(),
      )..start(file),
      child: _MusicPlayerView(file: file),
    );
  }
}

class _MusicPlayerView extends StatelessWidget {
  const _MusicPlayerView({required this.file});

  final MediaFile file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0820), Color(0xFF08061A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _AppBar(file: file),
              const SizedBox(height: 32),
              _AlbumArt(file: file),
              const SizedBox(height: 28),
              _TrackInfo(file: file),
              const SizedBox(height: 24),
              const _Scrubber(),
              const SizedBox(height: 32),
              const _Controls(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({required this.file});

  final MediaFile file;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down,
                color: AppColors.textBright, size: 28),
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Close',
          ),
          Expanded(
            child: Text(
              'Now Playing',
              style: AppTypography.captionV2.copyWith(
                color: AppColors.textMutedV2,
                letterSpacing: 0.8,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert,
                color: AppColors.textBright, size: 22),
            onPressed: () {},
            tooltip: 'More',
          ),
        ],
      ),
    );
  }
}

class _AlbumArt extends StatelessWidget {
  const _AlbumArt({required this.file});

  final MediaFile file;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B1D6B), Color(0xFF1A0C3C)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x60000000),
            blurRadius: 40,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: const Center(
        child: Icon(LucideIcons.music, size: 80, color: AppColors.violetTint),
      ),
    );
  }
}

class _TrackInfo extends StatelessWidget {
  const _TrackInfo({required this.file});

  final MediaFile file;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Text(
            file.title ?? file.name,
            style: AppTypography.h1.copyWith(
              color: AppColors.textBright,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${file.extension.toUpperCase().replaceAll('.', '')} Audio',
            style: AppTypography.captionV2
                .copyWith(color: AppColors.textMutedV2),
          ),
        ],
      ),
    );
  }
}

class _Scrubber extends StatelessWidget {
  const _Scrubber();

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MusicPlayerCubit, MusicPlayerState>(
      builder: (context, state) {
        final pos = state is MusicPlayerReady ? state.position : Duration.zero;
        final dur = state is MusicPlayerReady ? state.duration : Duration.zero;
        final frac = dur.inMilliseconds > 0
            ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.violet,
                  inactiveTrackColor: AppColors.borderSubtle,
                  thumbColor: AppColors.violet,
                  overlayColor: AppColors.pillBgPurple,
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  value: frac,
                  onChanged: (v) {
                    if (dur.inMilliseconds > 0) {
                      context.read<MusicPlayerCubit>().seekTo(
                            Duration(
                                milliseconds: (v * dur.inMilliseconds).round()),
                          );
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(pos),
                        style: AppTypography.micro
                            .copyWith(color: AppColors.textDim)),
                    Text(_fmt(dur),
                        style: AppTypography.micro
                            .copyWith(color: AppColors.textDim)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MusicPlayerCubit, MusicPlayerState>(
      builder: (context, state) {
        final isReady = state is MusicPlayerReady;
        final isPlaying = isReady && state.isPlaying;
        final isBuffering = isReady && state.isBuffering;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const IconButton(
                icon: Icon(LucideIcons.shuffle,
                    color: AppColors.textDim, size: 22),
                onPressed: null,
                tooltip: 'Shuffle (coming soon)',
              ),
              const IconButton(
                icon: Icon(LucideIcons.skipBack,
                    color: AppColors.textMutedV2, size: 26),
                onPressed: null,
                tooltip: 'Previous (no queue)',
              ),
              Semantics(
                button: true,
                label: isPlaying ? 'Pause' : 'Play',
                enabled: isReady,
                child: GestureDetector(
                  onTap: isReady
                      ? () => context.read<MusicPlayerCubit>().playPause()
                      : null,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.violet, AppColors.violetDeep],
                      ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x50A855F7),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: isBuffering
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 32,
                          ),
                  ),
                ),
              ),
              const IconButton(
                icon: Icon(LucideIcons.skipForward,
                    color: AppColors.textMutedV2, size: 26),
                onPressed: null,
                tooltip: 'Next (no queue)',
              ),
              const IconButton(
                icon: Icon(LucideIcons.listMusic,
                    color: AppColors.textDim, size: 22),
                onPressed: null,
                tooltip: 'Queue (coming soon)',
              ),
            ],
          ),
        );
      },
    );
  }
}
