import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:media_kit_video/media_kit_video.dart'
    show Video, VideoController, MaterialVideoControls;
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:fluxora_mobile/features/player/domain/repositories/player_repository.dart';
import 'package:fluxora_mobile/features/player/presentation/cubit/player_cubit.dart';
import 'package:fluxora_mobile/features/player/presentation/cubit/player_state.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({required this.file, super.key});

  final MediaFile file;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PlayerCubit>(
      create: (_) => PlayerCubit(
        repository: GetIt.I<PlayerRepository>(),
        secureStorage: GetIt.I<SecureStorage>(),
      )..startStream(file.id, file.title ?? file.name, file.resumeSec),
      child: _PlayerView(file: file),
    );
  }
}

class _PlayerView extends StatefulWidget {
  const _PlayerView({required this.file});

  final MediaFile file;

  @override
  State<_PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<_PlayerView> {
  bool _showResumeBanner = false;
  bool _showTransportBadge = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocConsumer<PlayerCubit, PlayerState>(
        listenWhen: (_, current) => current is PlayerReady,
        listener: (context, state) {
          if (state is PlayerReady) {
            if (state.resumeSec > 0) {
              setState(() => _showResumeBanner = true);
              // Auto-hide the resume banner after 4 seconds
              Future.delayed(const Duration(seconds: 4), () {
                if (mounted) setState(() => _showResumeBanner = false);
              });
            }
            // Show transport badge briefly on stream start
            setState(() => _showTransportBadge = true);
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted) setState(() => _showTransportBadge = false);
            });
          }
        },
        builder: (context, state) => switch (state) {
          PlayerInitial() || PlayerLoading() => const _LoadingView(),
          PlayerReady(:final controller, :final fileName, :final streamPath) =>
              Stack(
                children: [
                  _VideoView(controller: controller, fileName: fileName),
                  if (_showResumeBanner && state.resumeSec > 0)
                    _ResumeBanner(resumeSec: state.resumeSec),
                  if (_showTransportBadge)
                    _TransportBadge(streamPath: streamPath),
                ],
              ),
          PlayerFailure(:final message) => _ErrorView(message: message),
        },
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Starting stream…',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _VideoView extends StatelessWidget {
  const _VideoView({required this.controller, required this.fileName});

  final VideoController controller;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Video(
            controller: controller,
            controls: MaterialVideoControls,
          ),
        ),
        // Back button overlay
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black45,
              ),
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        // Title overlay at top
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(56, 8, 16, 0),
              child: Text(
                fileName,
                style: AppTypography.headingMd.copyWith(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResumeBanner extends StatelessWidget {
  const _ResumeBanner({required this.resumeSec});

  final double resumeSec;

  String get _formatted {
    final d = Duration(seconds: resumeSec.toInt());
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 72,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            'Resumed from $_formatted',
            style: AppTypography.bodyMd.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 48),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
}

/// A small, auto-dismissed chip that indicates which transport is active.
///
/// Shown briefly when the player first becomes ready, then fades out.
class _TransportBadge extends StatelessWidget {
  const _TransportBadge({required this.streamPath});

  final StreamPath streamPath;

  @override
  Widget build(BuildContext context) {
    final isWebRtc = streamPath == StreamPath.webRtc;
    return Positioned(
      bottom: 80,
      right: 16,
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isWebRtc
                ? Colors.deepPurple.withValues(alpha: 0.85)
                : Colors.black54,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isWebRtc ? Colors.deepPurpleAccent : Colors.white24,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isWebRtc ? Icons.cell_tower : Icons.stream,
                color: Colors.white,
                size: 14,
              ),
              const SizedBox(width: 5),
              Text(
                isWebRtc ? 'WebRTC' : 'HLS',
                style: AppTypography.label.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
