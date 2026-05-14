/// Files browser — categorized grid for a single library.
///
/// M11 rebuild: replaces the plain ListView with sections grouped by
/// [MediaKind] (Videos / Photos / PDFs / Music / Other).  Each section
/// is a horizontal scroll strip; tapping a file routes to the
/// appropriate viewer for its kind.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:logger/logger.dart';

import 'package:fluxora_mobile/core/router/app_router.dart';
import 'package:fluxora_mobile/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_mobile/features/library/presentation/cubit/files_cubit.dart';
import 'package:fluxora_mobile/features/library/presentation/cubit/files_state.dart';

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
  const _FilesView({required this.libraryId, required this.libraryName});

  final String libraryId;
  final String libraryName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppColors.bgRaised,
        title: Text(
          libraryName,
          style: AppTypography.h2.copyWith(color: AppColors.textBright),
        ),
        iconTheme: const IconThemeData(color: AppColors.textBright),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<FilesCubit>().loadFiles(libraryId),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: BlocBuilder<FilesCubit, FilesState>(
        builder: (context, state) => switch (state) {
          FilesInitial() || FilesLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
          FilesSuccess(:final files) when files.isEmpty => const _EmptyView(),
          FilesSuccess(:final files) => _BrowserBody(files: files),
          FilesFailure(:final message) => _FailureView(
              message: message,
              onRetry: () => context.read<FilesCubit>().loadFiles(libraryId),
            ),
        },
      ),
    );
  }
}

class _BrowserBody extends StatelessWidget {
  const _BrowserBody({required this.files});

  final List<MediaFile> files;

  @override
  Widget build(BuildContext context) {
    final byKind = <MediaKind, List<MediaFile>>{};
    for (final f in files) {
      byKind.putIfAbsent(f.kind, () => []).add(f);
    }

    const order = [
      MediaKind.video,
      MediaKind.photo,
      MediaKind.pdf,
      MediaKind.music,
      MediaKind.other,
    ];

    final sections = order.where((k) => byKind.containsKey(k)).toList();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: sections.length,
      itemBuilder: (context, i) {
        final kind = sections[i];
        return _KindSection(kind: kind, files: byKind[kind]!);
      },
    );
  }
}

class _KindSection extends StatelessWidget {
  const _KindSection({required this.kind, required this.files});

  final MediaKind kind;
  final List<MediaFile> files;

  static String _label(MediaKind k) => switch (k) {
        MediaKind.video => 'Videos',
        MediaKind.photo => 'Photos',
        MediaKind.pdf => 'Documents',
        MediaKind.music => 'Music',
        MediaKind.other => 'Other files',
      };

  static IconData _icon(MediaKind k) => switch (k) {
        MediaKind.video => LucideIcons.clapperboard,
        MediaKind.photo => LucideIcons.image,
        MediaKind.pdf => LucideIcons.fileText,
        MediaKind.music => LucideIcons.music,
        MediaKind.other => LucideIcons.file,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(_icon(kind), size: 16, color: AppColors.violetTint),
                const SizedBox(width: 8),
                Text(
                  '${_label(kind)} (${files.length})',
                  style: AppTypography.h2
                      .copyWith(color: AppColors.textBright),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: files.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) =>
                  _FileChip(file: files[i], kind: kind),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileChip extends StatelessWidget {
  const _FileChip({required this.file, required this.kind});

  static final _log = Logger();

  final MediaFile file;
  final MediaKind kind;

  static IconData _kindIcon(MediaKind k) => switch (k) {
        MediaKind.video => LucideIcons.play,
        MediaKind.photo => LucideIcons.image,
        MediaKind.pdf => LucideIcons.fileText,
        MediaKind.music => LucideIcons.music,
        MediaKind.other => LucideIcons.file,
      };

  void _onTap(BuildContext context) {
    switch (kind) {
      case MediaKind.video:
        context.push(Routes.player, extra: file);
      case MediaKind.photo:
        context.push(Routes.photoViewer, extra: file);
      case MediaKind.pdf:
        context.push(Routes.docViewer, extra: file);
      case MediaKind.music:
        context.push(Routes.musicPlayer, extra: file);
      case MediaKind.other:
        _openInExternal(context);
    }
  }

  Future<void> _openInExternal(BuildContext context) async {
    // Capture the messenger before any async gaps so we can surface a
    // failure SnackBar even if the user navigates away mid-download.
    final messenger = ScaffoldMessenger.of(context);
    final storage = GetIt.I<SecureStorage>();
    final serverUrl = await storage.getServerUrl();
    final token = await storage.getAuthToken();
    if (serverUrl == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Server not configured.')),
      );
      return;
    }
    final url = '$serverUrl/api/v1/files/${file.id}/content';

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      if (token != null) {
        request.headers.set('Authorization', 'Bearer $token');
      }
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final dir = await getTemporaryDirectory();
      final dest = File('${dir.path}/${file.name}');
      await response.pipe(dest.openWrite());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(dest.path)],
          subject: file.title ?? file.name,
        ),
      );
    } catch (e, st) {
      _log.e('Open-in failed for ${file.id}', error: e, stackTrace: st);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open in external app.')),
      );
    } finally {
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open ${file.title ?? file.name}',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _onTap(context),
        child: Container(
          width: 130,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0x0DFFFFFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_kindIcon(kind), size: 22, color: AppColors.violetTint),
              const Spacer(),
              Text(
                file.title ?? file.name,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textBright),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                file.extension.toUpperCase().replaceAll('.', ''),
                style: AppTypography.micro
                    .copyWith(color: AppColors.textDim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_open_outlined,
              size: 64, color: AppColors.textDim),
          const SizedBox(height: 16),
          const Text('No files in this library', style: AppTypography.h2),
          const SizedBox(height: 8),
          Text(
            'Trigger a scan from the Control Panel\nto index your files.',
            style: AppTypography.body
                .copyWith(color: AppColors.textMutedV2),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.textDim),
            const SizedBox(height: 16),
            Text(
              message,
              style: AppTypography.body
                  .copyWith(color: AppColors.textMutedV2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
