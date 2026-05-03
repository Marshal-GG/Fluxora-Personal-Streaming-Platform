import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/library.dart';
import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_core/widgets/flux_button.dart';
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_cubit.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_state.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';
import 'package:fluxora_desktop/shared/widgets/stat_tile.dart';

class LibraryFilesScreen extends StatelessWidget {
  const LibraryFilesScreen({super.key, required this.libraryId});

  final String libraryId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LibraryCubit>(
      create: (_) => LibraryCubit(
        repository: GetIt.I<LibraryRepository>(),
      )..load(),
      child: _LibraryFilesView(libraryId: libraryId),
    );
  }
}

class _LibraryFilesView extends StatefulWidget {
  const _LibraryFilesView({required this.libraryId});

  final String libraryId;

  @override
  State<_LibraryFilesView> createState() => _LibraryFilesViewState();
}

class _LibraryFilesViewState extends State<_LibraryFilesView> {
  String _query = '';
  _Sort _sort = _Sort.nameAsc;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgRoot,
      child: BlocBuilder<LibraryCubit, LibraryState>(
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: AppSpacing.s28,
              right: AppSpacing.s28,
              bottom: AppSpacing.s28,
            ),
            child: switch (state) {
              LibraryInitial() ||
              LibraryLoading() =>
                const _Loading(),
              LibraryLoaded() => _buildLoaded(context, state),
              LibraryFailure(:final message) => _Error(
                  message: message,
                  onRetry: () => context.read<LibraryCubit>().load(),
                ),
            },
          );
        },
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, LibraryLoaded state) {
    final lib = state.libraries.cast<Library?>().firstWhere(
          (l) => l?.id == widget.libraryId,
          orElse: () => null,
        );
    if (lib == null) {
      return _Error(
        message: 'Library not found.',
        onRetry: () => context.go('/library'),
        retryLabel: 'Back to libraries',
      );
    }

    final files = state.files
        .where((f) => f.libraryId == widget.libraryId)
        .toList();
    final filtered = _filterAndSort(files, _query, _sort);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: lib.name,
          subtitle: lib.rootPaths.isNotEmpty ? lib.rootPaths.first : null,
          actions: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FluxButton(
                variant: FluxButtonVariant.secondary,
                icon: Icons.arrow_back_rounded,
                onPressed: () => context.go('/library'),
                child: const Text('Back'),
              ),
              const SizedBox(width: AppSpacing.s8),
              FluxButton(
                variant: FluxButtonVariant.primary,
                icon: Icons.refresh_rounded,
                onPressed: () async {
                  try {
                    final added =
                        await context.read<LibraryCubit>().scanLibrary(lib.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(added > 0
                              ? 'Scan complete — $added file(s) added'
                              : 'Scan complete — no new files'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Scan failed: $e')),
                      );
                    }
                  }
                },
                child: const Text('Scan'),
              ),
            ],
          ),
        ),

        // Stat tiles
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.insert_drive_file_outlined,
                label: 'Files',
                value: '${files.length}',
                color: AppColors.blue,
              ),
            ),
            const SizedBox(width: AppSpacing.s14),
            Expanded(
              child: StatTile(
                icon: Icons.storage_outlined,
                label: 'Total Size',
                value: _humanBytes(
                  files.fold<int>(0, (acc, f) => acc + f.sizeBytes),
                ),
                color: AppColors.emerald,
              ),
            ),
            const SizedBox(width: AppSpacing.s14),
            Expanded(
              child: StatTile(
                icon: Icons.auto_awesome_outlined,
                label: 'Enriched',
                value: '${files.where((f) => f.posterUrl != null).length}',
                color: AppColors.violet,
              ),
            ),
            const SizedBox(width: AppSpacing.s14),
            Expanded(
              child: StatTile(
                icon: Icons.refresh_rounded,
                label: 'Last Scan',
                value: lib.lastScanned != null
                    ? _relative(lib.lastScanned!)
                    : 'Never',
                color: AppColors.amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s18),

        // Search + sort row
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.textBright,
                ),
                decoration: InputDecoration(
                  hintText: 'Search files…',
                  hintStyle: AppTypography.bodySmall
                      .copyWith(color: AppColors.textFaint),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 16, color: AppColors.textMutedV2),
                  filled: true,
                  fillColor: const Color(0x08FFFFFF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    borderSide:
                        const BorderSide(color: Color(0x0DFFFFFF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    borderSide:
                        const BorderSide(color: Color(0x0DFFFFFF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    borderSide: const BorderSide(color: AppColors.violet),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s10),
            PopupMenuButton<_Sort>(
              tooltip: 'Sort',
              initialValue: _sort,
              onSelected: (v) => setState(() => _sort = v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: _Sort.nameAsc, child: Text('Name (A → Z)')),
                PopupMenuItem(value: _Sort.nameDesc, child: Text('Name (Z → A)')),
                PopupMenuItem(value: _Sort.sizeDesc, child: Text('Largest first')),
                PopupMenuItem(value: _Sort.sizeAsc, child: Text('Smallest first')),
                PopupMenuItem(value: _Sort.newest, child: Text('Newest first')),
                PopupMenuItem(value: _Sort.oldest, child: Text('Oldest first')),
              ],
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0x08FFFFFF),
                  border: Border.all(color: const Color(0x0DFFFFFF)),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sort_rounded,
                        size: 14, color: AppColors.textMutedV2),
                    const SizedBox(width: 6),
                    Text(_sortLabel(_sort),
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textBody)),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 14, color: AppColors.textMutedV2),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s14),

        // File list
        if (filtered.isEmpty)
          _EmptyState(hasQuery: _query.isNotEmpty)
        else
          _FilesTable(files: filtered),
      ],
    );
  }

  static String _sortLabel(_Sort s) => switch (s) {
        _Sort.nameAsc => 'Name (A → Z)',
        _Sort.nameDesc => 'Name (Z → A)',
        _Sort.sizeDesc => 'Largest first',
        _Sort.sizeAsc => 'Smallest first',
        _Sort.newest => 'Newest',
        _Sort.oldest => 'Oldest',
      };

  static List<MediaFile> _filterAndSort(
      List<MediaFile> input, String query, _Sort sort) {
    final q = query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? List<MediaFile>.from(input)
        : input
            .where((f) =>
                f.name.toLowerCase().contains(q) ||
                (f.title?.toLowerCase().contains(q) ?? false))
            .toList();
    switch (sort) {
      case _Sort.nameAsc:
        filtered.sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _Sort.nameDesc:
        filtered.sort((a, b) =>
            b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      case _Sort.sizeDesc:
        filtered.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
      case _Sort.sizeAsc:
        filtered.sort((a, b) => a.sizeBytes.compareTo(b.sizeBytes));
      case _Sort.newest:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _Sort.oldest:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    return filtered;
  }
}

enum _Sort { nameAsc, nameDesc, sizeDesc, sizeAsc, newest, oldest }

class _FilesTable extends StatelessWidget {
  const _FilesTable({required this.files});

  final List<MediaFile> files;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x05FFFFFF),
        border: Border.all(color: const Color(0x0DFFFFFF)),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s14, vertical: AppSpacing.s10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x0DFFFFFF))),
            ),
            child: const Row(
              children: [
                _HeaderCell('Name', flex: 4),
                _HeaderCell('Type', flex: 1),
                _HeaderCell('Size', flex: 1, align: TextAlign.right),
                _HeaderCell('Duration', flex: 1, align: TextAlign.right),
                _HeaderCell('Added', flex: 2, align: TextAlign.right),
              ],
            ),
          ),
          for (final f in files)
            _FileRow(file: f),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, {required this.flex, this.align});
  final String label;
  final int flex;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: align,
        style: AppTypography.captionV2.copyWith(
          color: AppColors.textMutedV2,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.file});

  final MediaFile file;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s14, vertical: AppSpacing.s10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x08FFFFFF))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                if (file.posterUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      file.posterUrl!,
                      width: 28,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _IconPlaceholder(),
                    ),
                  )
                else
                  const _IconPlaceholder(),
                const SizedBox(width: AppSpacing.s10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        file.title ?? file.name,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textBright,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        file.path,
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11,
                          color: AppColors.textFaint,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              file.extension.replaceFirst('.', '').toUpperCase(),
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textBody),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              _humanBytes(file.sizeBytes),
              textAlign: TextAlign.right,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textBody),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              file.durationSec != null
                  ? _formatDuration(file.durationSec!)
                  : '—',
              textAlign: TextAlign.right,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textBody),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _relative(file.createdAt),
              textAlign: TextAlign.right,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textMutedV2),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconPlaceholder extends StatelessWidget {
  const _IconPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0x14A855F7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: Icon(Icons.insert_drive_file_outlined,
            size: 14, color: AppColors.violetTint),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery});
  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasQuery ? Icons.search_off_rounded : Icons.folder_open_outlined,
            size: 56,
            color: AppColors.textFaint,
          ),
          const SizedBox(height: AppSpacing.s14),
          Text(
            hasQuery ? 'No files match your search' : 'No files in this library',
            style: AppTypography.body.copyWith(color: AppColors.textMutedV2),
          ),
          const SizedBox(height: AppSpacing.s6),
          Text(
            hasQuery
                ? 'Try a different keyword.'
                : 'Run a scan to pull files from disk.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textFaint),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.violet,
          ),
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Retry',
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                color: AppColors.textDim, size: 56),
            const SizedBox(height: 16),
            Text(
              message,
              style: AppTypography.body.copyWith(color: AppColors.textMutedV2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FluxButton(
              variant: FluxButtonVariant.secondary,
              icon: Icons.arrow_back_rounded,
              onPressed: onRetry,
              child: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

String _humanBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final formatted = value < 10
      ? value.toStringAsFixed(2)
      : value < 100
          ? value.toStringAsFixed(1)
          : value.toStringAsFixed(0);
  return '$formatted ${units[unitIndex]}';
}

String _formatDuration(double sec) {
  final s = sec.round();
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final ss = s % 60;
  if (h > 0) {
    return '${h}h ${m}m';
  }
  return '$m:${ss.toString().padLeft(2, '0')}';
}

String _relative(DateTime dt) {
  final diff = DateTime.now().toUtc().difference(dt.toUtc());
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
