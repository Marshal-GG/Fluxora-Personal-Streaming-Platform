import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/library.dart';
import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_cubit.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_state.dart';
import 'package:fluxora_desktop/shared/widgets/stat_card.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LibraryCubit>(
      create: (_) => LibraryCubit(
        repository: GetIt.I<LibraryRepository>(),
      )..load(),
      child: const _LibraryView(),
    );
  }
}

// ── Main view ─────────────────────────────────────────────────────────────────

class _LibraryView extends StatelessWidget {
  const _LibraryView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => context.read<LibraryCubit>().load(),
          ),
        ],
      ),
      body: BlocBuilder<LibraryCubit, LibraryState>(
        builder: (context, state) => switch (state) {
          LibraryInitial() || LibraryLoading() =>
            const Center(child: CircularProgressIndicator()),
          LibraryLoaded() => _LoadedBody(state: state),
          LibraryFailure(:final message) => _ErrorBody(
              message: message,
              onRetry: () => context.read<LibraryCubit>().load(),
            ),
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddLibraryDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Library'),
      ),
    );
  }

  Future<void> _showAddLibraryDialog(BuildContext context) async {
    final nameController = TextEditingController();
    String type = 'movies';
    final cubit = context.read<LibraryCubit>();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Library'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Library Name'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Library Type'),
                    items: const [
                      DropdownMenuItem(value: 'movies', child: Text('Movies')),
                      DropdownMenuItem(value: 'tv', child: Text('TV Shows')),
                      DropdownMenuItem(value: 'music', child: Text('Music')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => type = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                  FilledButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty) return;
                    
                    final result = await FilePicker.getDirectoryPath();
                    if (result != null) {
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        try {
                          await cubit.createLibrary(nameController.text, type, [result]);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Library created successfully')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to create library: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    }
                  },
                  child: const Text('Select Folder & Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ── Loaded body ───────────────────────────────────────────────────────────────

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.state});

  final LibraryLoaded state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Stats row ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 180,
                child: StatCard(
                  label: 'Total Files',
                  value: '${state.files.length}',
                  icon: Icons.folder_outlined,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(
                width: 180,
                child: StatCard(
                  label: 'TMDB Enriched',
                  value: '${state.enrichedCount}',
                  icon: Icons.movie_filter_outlined,
                  color: AppColors.success,
                ),
              ),
              SizedBox(
                width: 180,
                child: StatCard(
                  label: 'In Progress',
                  value: '${state.resumingCount}',
                  icon: Icons.play_circle_outline,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Library filter chips ───────────────────────────────────────
        if (state.libraries.isNotEmpty)
          _LibraryFilterRow(
            libraries: state.libraries,
            selectedId: state.selectedLibraryId,
          ),

        const Divider(),

        // ── File list ─────────────────────────────────────────────────
        Expanded(
          child: state.visibleFiles.isEmpty
              ? const _EmptyState()
              : _FileTable(files: state.visibleFiles),
        ),
      ],
    );
  }
}

// ── Library filter chips ──────────────────────────────────────────────────────

class _LibraryFilterRow extends StatelessWidget {
  const _LibraryFilterRow({
    required this.libraries,
    required this.selectedId,
  });

  final List<Library> libraries;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          FilterChip(
            label: const Text('All'),
            selected: selectedId == null,
            onSelected: (_) =>
                context.read<LibraryCubit>().selectLibrary(null),
            selectedColor: AppColors.primary.withAlpha(40),
            checkmarkColor: AppColors.primary,
            labelStyle: TextStyle(
              color: selectedId == null
                  ? AppColors.primary
                  : AppColors.textSecondary,
              fontSize: 13,
            ),
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: selectedId == null
                  ? AppColors.primary.withAlpha(80)
                  : AppColors.surfaceRaised,
            ),
            shape: const StadiumBorder(),
          ),
          ...libraries.map(
            (lib) => FilterChip(
              label: Text(lib.name),
              selected: selectedId == lib.id,
              onSelected: (_) =>
                  context.read<LibraryCubit>().selectLibrary(lib.id),
              selectedColor: AppColors.primary.withAlpha(40),
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selectedId == lib.id
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontSize: 13,
              ),
              backgroundColor: AppColors.surface,
              side: BorderSide(
                color: selectedId == lib.id
                    ? AppColors.primary.withAlpha(80)
                    : AppColors.surfaceRaised,
              ),
              shape: const StadiumBorder(),
            ),
          ),
          if (selectedId != null)
            ActionChip(
              avatar: const Icon(Icons.sync, size: 16),
              label: const Text('Scan Folder'),
              onPressed: () async {
                if (context.mounted) {
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Scanning folder...')),
                    );
                    await context.read<LibraryCubit>().scanLibrary(selectedId!);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Scan complete!')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Scan failed: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              backgroundColor: AppColors.primary.withAlpha(20),
              shape: const StadiumBorder(),
            ),
        ],
      ),
    );
  }
}

// ── File table ────────────────────────────────────────────────────────────────

class _FileTable extends StatelessWidget {
  const _FileTable({required this.files});

  final List<MediaFile> files;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: files.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, i) => _FileTile(file: files[i]),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.file});

  final MediaFile file;

  @override
  Widget build(BuildContext context) {
    final hasMeta = file.posterUrl != null;
    final hasResume = file.resumeSec > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // ── TMDB enrichment indicator ──────────────────────────────
            Tooltip(
              message: hasMeta ? 'TMDB enriched' : 'Not enriched',
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasMeta ? AppColors.success : AppColors.surfaceRaised,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // ── File icon ─────────────────────────────────────────────
            Icon(
              _iconFor(file.extension),
              color: AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 14),

            // ── Title + metadata ──────────────────────────────────────
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.title ?? file.name,
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (file.title != null && file.title != file.name)
                    Text(
                      file.name,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // ── Overview snippet ──────────────────────────────────────
            if (file.overview != null && file.overview!.isNotEmpty)
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    file.overview!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
            else
              const Spacer(flex: 4),

            // ── Resume progress ───────────────────────────────────────
            SizedBox(
              width: 120,
              child: hasResume && file.durationSec != null
                  ? _ResumeCell(
                      resumeSec: file.resumeSec,
                      durationSec: file.durationSec!,
                    )
                  : const SizedBox.shrink(),
            ),

            // ── File size ─────────────────────────────────────────────
            SizedBox(
              width: 72,
              child: Text(
                _formatSize(file.sizeBytes),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String ext) => switch (ext) {
        '.mp4' || '.mkv' || '.avi' || '.mov' || '.webm' => Icons.movie_outlined,
        '.mp3' || '.flac' || '.aac' || '.wav' || '.m4a' => Icons.music_note_outlined,
        '.pdf' => Icons.picture_as_pdf_outlined,
        '.epub' || '.cbz' || '.cbr' => Icons.menu_book_outlined,
        _ => Icons.insert_drive_file_outlined,
      };

  String _formatSize(int bytes) {
    final mb = bytes / (1024 * 1024);
    if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
    return '${mb.toStringAsFixed(0)} MB';
  }
}

// ── Resume progress cell ──────────────────────────────────────────────────────

class _ResumeCell extends StatelessWidget {
  const _ResumeCell({required this.resumeSec, required this.durationSec});

  final double resumeSec;
  final double durationSec;

  @override
  Widget build(BuildContext context) {
    final progress = (resumeSec / durationSec).clamp(0.0, 1.0);
    final d = Duration(seconds: resumeSec.toInt());
    final label =
        d.inHours > 0 ? _fmt(d) : '${d.inMinutes}:${_pad(d.inSeconds.remainder(60))}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.warning,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            backgroundColor: AppColors.surfaceRaised,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.warning),
          ),
        ),
      ],
    );
  }

  String _fmt(Duration d) =>
      '${d.inHours}:${_pad(d.inMinutes.remainder(60))}:${_pad(d.inSeconds.remainder(60))}';

  String _pad(int n) => n.toString().padLeft(2, '0');
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_open_outlined,
              color: AppColors.textMuted, size: 48),
          const SizedBox(height: 12),
          Text(
            'No files found',
            style: AppTypography.bodyMd
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Trigger a scan from the Library panel to index your media.',
            style: AppTypography.caption
                .copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Error body ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined,
              color: AppColors.textMuted, size: 56),
          const SizedBox(height: 16),
          Text(
            message,
            style:
                AppTypography.bodyMd.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
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
