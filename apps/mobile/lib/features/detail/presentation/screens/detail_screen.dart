/// Title detail screen — hero + actions + synopsis (real data).
///
/// Phase A backfill: replaces `MockData.findById(id)` with a live
/// [DetailCubit] over `GET /api/v1/files/{id}`.  Quality badge composes
/// from `width` / `height` / `hdrFormat` (server migration 016 fields)
/// via the `MediaFile.qualityBadge` extension.
///
/// Cast / crew / similar-titles rails and the rich synopsis sit out
/// Phase A — they need server endpoints that land in Phase C.  The
/// "Episodes" entry-point also waits for Phase D's
/// `/shows/{tmdb_show_id}/episodes`.  Until then the screen renders a
/// movie-style "Play" / "Resume" primary action regardless of kind.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:fluxora_mobile/core/router/app_router.dart';
import 'package:fluxora_mobile/features/detail/presentation/cubit/detail_cubit.dart';
import 'package:fluxora_mobile/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_mobile/shared/widgets/gradients.dart';

class DetailScreen extends StatelessWidget {
  const DetailScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DetailCubit>(
      create: (_) => DetailCubit(
        repository: GetIt.I<LibraryRepository>(),
        fileId: id,
      )..load(),
      child: const _DetailBody(),
    );
  }
}

class _DetailBody extends StatefulWidget {
  const _DetailBody();

  @override
  State<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends State<_DetailBody> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DetailCubit, DetailState>(
      builder: (context, state) {
        return switch (state) {
          DetailLoading() => const _LoadingScaffold(),
          DetailFailure(:final message) =>
            _FailureScaffold(message: message),
          DetailLoaded(:final file) => _LoadedScaffold(
              file: file,
              expanded: _expanded,
              onToggleSynopsis: () =>
                  setState(() => _expanded = !_expanded),
            ),
        };
      },
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: FluxAppBar(
        transparent: true,
        title: '',
        onBack: () =>
            context.canPop() ? context.pop() : context.go(Routes.home),
      ),
      body: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.violet,
          ),
        ),
      ),
    );
  }
}

class _FailureScaffold extends StatelessWidget {
  const _FailureScaffold({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: FluxAppBar(
        transparent: true,
        title: '',
        onBack: () =>
            context.canPop() ? context.pop() : context.go(Routes.home),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 44, color: Color(0xFFF87171)),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: AppColors.textBright),
              ),
              const SizedBox(height: 12),
              FluxButton(
                variant: FluxButtonVariant.secondary,
                onPressed: () => context.read<DetailCubit>().load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadedScaffold extends StatelessWidget {
  const _LoadedScaffold({
    required this.file,
    required this.expanded,
    required this.onToggleSynopsis,
  });

  final MediaFile file;
  final bool expanded;
  final VoidCallback onToggleSynopsis;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: FluxAppBar(
        transparent: true,
        title: '',
        onBack: () =>
            context.canPop() ? context.pop() : context.go(Routes.home),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _Hero(file: file),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _PrimaryActions(file: file),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _SecondaryActions(),
          ),
          if (file.overview != null && file.overview!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _Synopsis(
                text: file.overview!,
                expanded: expanded,
                onToggle: onToggleSynopsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.file});

  final MediaFile file;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final gradient = AppGradientPlaceholders.forKey(file.id);
    final badge = file.qualityBadge;
    return SizedBox(
      height: 340 + topPadding,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
          if (file.posterUrl != null)
            Image.network(
              file.posterUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x00000000),
                  Color(0xFF08061A),
                ],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (badge != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FluxChip(badge, color: FluxChipColor.purple),
                  ),
                Text(
                  file.title ?? file.name,
                  style: AppTypography.displayV2.copyWith(
                    color: AppColors.textBright,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                _MetaRow(file: file),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.file});

  final MediaFile file;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (file.durationSec != null) _formatDuration(file.durationSec!),
      if (file.codecName != null) file.codecName!.toUpperCase(),
      if (file.tmdbShowId != null && file.seasonNumber != null &&
          file.episodeNumber != null)
        'S${file.seasonNumber!.toString().padLeft(2, '0')} ·'
            ' E${file.episodeNumber!.toString().padLeft(2, '0')}',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join('  ·  '),
      style: AppTypography.captionV2.copyWith(
        color: AppColors.textBody,
        fontSize: 12,
      ),
    );
  }

  static String _formatDuration(double seconds) {
    final total = seconds.round();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({required this.file});

  final MediaFile file;

  @override
  Widget build(BuildContext context) {
    final hasResume = file.resumeSec > 0;
    return Row(
      children: [
        Expanded(
          child: FluxButton(
            icon: Icons.play_arrow,
            onPressed: () {
              // M5 player wiring — push the player route with the file.
              // Phase A doesn't change playback semantics.
              context.push(Routes.player, extra: file);
            },
            child: Text(hasResume ? 'Resume' : 'Play'),
          ),
        ),
        if (hasResume) ...[
          const SizedBox(width: 10),
          FluxButton(
            variant: FluxButtonVariant.secondary,
            icon: Icons.replay,
            onPressed: () => _confirmStartOver(context, file),
            child: const Text('Start over'),
          ),
        ],
      ],
    );
  }

  /// Shows the "Start over?" confirmation, then dispatches the
  /// reset-progress request via the LibraryRepository.  Pulled out so
  /// the surrounding `Row` reads cleanly + so we can capture the
  /// pre-await BuildContext refs (`use_build_context_synchronously`).
  Future<void> _confirmStartOver(
    BuildContext context,
    MediaFile file,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<DetailCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceGlass,
        title: const Text(
          'Start over?',
          style: TextStyle(color: AppColors.textBright),
        ),
        content: Text(
          'Reset playback to 0:00 for "${file.title ?? file.name}". '
          'Your resume marker will be cleared.',
          style: AppTypography.body.copyWith(color: AppColors.textBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Start over'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await GetIt.I<LibraryRepository>().resetProgress(file.id);
      await cubit.load();
      messenger.showSnackBar(
        const SnackBar(content: Text('Progress reset.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not reset progress.')),
      );
    }
  }
}

class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _IconAction(icon: Icons.add, label: 'Watchlist'),
        ),
        Expanded(
          child: _IconAction(icon: Icons.download_outlined, label: 'Download'),
        ),
        Expanded(
          child: _IconAction(icon: Icons.share_outlined, label: 'Share'),
        ),
        Expanded(
          child: _IconAction(icon: Icons.cast, label: 'Cast'),
        ),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(icon, color: AppColors.textBright, size: 22),
              ),
              const SizedBox(height: 6),
              ExcludeSemantics(
                child: Text(
                  label,
                  style: AppTypography.captionV2.copyWith(
                    color: AppColors.textMutedV2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Synopsis extends StatelessWidget {
  const _Synopsis({
    required this.text,
    required this.expanded,
    required this.onToggle,
  });

  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: expanded ? null : 3,
          overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: AppTypography.body.copyWith(
            color: AppColors.textBody,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          button: true,
          label: expanded ? 'Show less synopsis' : 'Show more synopsis',
          child: GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Text(
              expanded ? 'Less' : 'More',
              style: AppTypography.captionV2.copyWith(
                color: AppColors.violetTint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
