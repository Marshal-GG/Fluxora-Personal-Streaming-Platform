import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_sizes.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/enums.dart';
import 'package:fluxora_core/entities/library.dart';
import 'package:fluxora_mobile/core/router/app_router.dart';
import 'package:fluxora_mobile/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_mobile/features/library/presentation/bloc/library_bloc.dart';
import 'package:fluxora_mobile/features/library/presentation/bloc/library_event.dart';
import 'package:fluxora_mobile/features/library/presentation/bloc/library_state.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LibraryBloc>(
      create: (_) => LibraryBloc(
        repository: GetIt.I<LibraryRepository>(),
      )..add(const LibraryStarted()),
      child: const _LibraryView(),
    );
  }
}

class _LibraryView extends StatelessWidget {
  const _LibraryView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Libraries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () =>
                context.read<LibraryBloc>().add(const LibraryRefreshed()),
          ),
        ],
      ),
      body: BlocBuilder<LibraryBloc, LibraryState>(
        builder: (context, state) => switch (state) {
          LibraryInitial() || LibraryLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
          LibrarySuccess(:final libraries) when libraries.isEmpty =>
            const _EmptyView(),
          LibrarySuccess(:final libraries) => _LibraryGrid(
              libraries: libraries,
            ),
          LibraryFailure(:final message) => _ErrorView(
              message: message,
              onRetry: () => context
                  .read<LibraryBloc>()
                  .add(const LibraryRefreshed()),
            ),
        },
      ),
    );
  }
}

class _LibraryGrid extends StatelessWidget {
  const _LibraryGrid({required this.libraries});

  final List<Library> libraries;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSizes.s4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSizes.s3,
        mainAxisSpacing: AppSizes.s3,
        childAspectRatio: 1.1,
      ),
      itemCount: libraries.length,
      itemBuilder: (context, index) =>
          _LibraryCard(library: libraries[index]),
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({required this.library});

  final Library library;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          context.go(Routes.libraryFiles(library.id), extra: library.name),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.s4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(color: AppColors.surfaceRaised),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    AppColors.primary.withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Icon(
                _iconFor(library.type),
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const Spacer(),
            Text(
              library.name,
              style: AppTypography.headingMd,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSizes.s1),
            Text(library.type.name, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(LibraryType type) => switch (type) {
        LibraryType.movies => Icons.movie_outlined,
        LibraryType.tv => Icons.tv_outlined,
        LibraryType.music => Icons.music_note_outlined,
        LibraryType.files => Icons.folder_outlined,
      };
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 64,
            color: AppColors.textMuted,
          ),
          SizedBox(height: AppSizes.s4),
          Text('No libraries yet', style: AppTypography.headingMd),
          SizedBox(height: AppSizes.s2),
          Text(
            'Add a library in the Fluxora Control Panel.',
            style: AppTypography.bodyMd,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.error,
            size: 48,
          ),
          const SizedBox(height: AppSizes.s4),
          Text(
            message,
            style: AppTypography.bodyMd,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.s4),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
