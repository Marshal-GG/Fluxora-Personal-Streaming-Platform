import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_sizes.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_mobile/core/router/app_router.dart';
import 'package:fluxora_mobile/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_mobile/features/library/presentation/cubit/files_cubit.dart';
import 'package:fluxora_mobile/features/library/presentation/cubit/files_state.dart';
import 'package:fluxora_mobile/shared/widgets/media_card.dart';

class FilesScreen extends StatelessWidget {
  const FilesScreen({
    required this.libraryId,
    required this.libraryName,
    super.key,
  });

  final String libraryId;
  final String libraryName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FilesCubit>(
      create: (_) => FilesCubit(
        repository: GetIt.I<LibraryRepository>(),
      )..loadFiles(libraryId),
      child: _FilesView(libraryId: libraryId, libraryName: libraryName),
    );
  }
}

class _FilesView extends StatelessWidget {
  const _FilesView({
    required this.libraryId,
    required this.libraryName,
  });

  final String libraryId;
  final String libraryName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(libraryName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () =>
                context.read<FilesCubit>().loadFiles(libraryId),
          ),
        ],
      ),
      body: BlocBuilder<FilesCubit, FilesState>(
        builder: (context, state) => switch (state) {
          FilesInitial() || FilesLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
          FilesSuccess(:final files) when files.isEmpty =>
            const _EmptyView(),
          FilesSuccess(:final files) => ListView.separated(
              padding: const EdgeInsets.all(AppSizes.s4),
              itemCount: files.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSizes.s2),
              itemBuilder: (context, index) => MediaCard(
                file: files[index],
                onTap: () => context.push(
                  Routes.player,
                  extra: files[index],
                ),
              ),
            ),
          FilesFailure(:final message) => Center(
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
                    onPressed: () =>
                        context.read<FilesCubit>().loadFiles(libraryId),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
        },
      ),
    );
  }
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
            Icons.folder_open_outlined,
            size: 64,
            color: AppColors.textMuted,
          ),
          SizedBox(height: AppSizes.s4),
          Text(
            'No files in this library',
            style: AppTypography.headingMd,
          ),
          SizedBox(height: AppSizes.s2),
          Text(
            'Trigger a scan from the Control Panel\nto index your files.',
            style: AppTypography.bodyMd,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
