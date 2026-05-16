/// Right-side detail panel for the library file browser.
///
/// Renders metadata for the currently-selected [BrowseEntry] — kind
/// header, thumbnail preview (for indexed media), path card, quick
/// stats grid, media-specific metadata block, and a row of actions
/// (`Open`, `Reveal in folder`, `Copy path`, plus a `Stream test`
/// affordance for indexed videos).
///
/// Subscribes to [LibraryBrowseCubit] and reads the cubit's
/// `selectedEntry` getter inside a [BlocBuilder] — the cubit re-emits
/// its `Loaded` state whenever selection changes, so the builder
/// rebuilds on every selection swap.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/widgets/flux_button.dart';

import 'package:fluxora_desktop/features/library/domain/entities/browse_entry.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_browse_cubit.dart';

final _log = Logger();

/// Fixed-width detail column rendered to the right of the browser body.
///
/// Width is 320 px including the 1-px left divider.  When nothing is
/// selected the panel falls back to a muted empty state.
class LibraryBrowseDetailPanel extends StatelessWidget {
  const LibraryBrowseDetailPanel({super.key});

  /// External pixel width — kept in a static so callers can lay out the
  /// browser body around the same constant without magic numbers.
  static const double kWidth = 320;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: kWidth,
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Color(0x0DFFFFFF)),
        ),
        color: Color(0x800D0B1C),
      ),
      child: BlocBuilder<LibraryBrowseCubit, LibraryBrowseState>(
        builder: (context, state) {
          final cubit = context.read<LibraryBrowseCubit>();
          final entry = cubit.selectedEntry;
          if (entry == null) {
            return const _EmptyState();
          }
          // Loaded state guaranteed when selectedEntry is non-null —
          // pull the response so the path card can build absolute paths.
          final response = state is LibraryBrowseLoaded ? state.response : null;
          if (response == null) {
            return const _EmptyState();
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.s20),
            child: _DetailBody(entry: entry, response: response),
          );
        },
      ),
    );
  }
}

// ─── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.s28),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 40,
              color: AppColors.textFaint,
            ),
            SizedBox(height: AppSpacing.s12),
            Text(
              'Select a file or folder to view details',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.textFaint,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Body ──────────────────────────────────────────────────────────────────

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.entry, required this.response});

  final BrowseEntry entry;
  final BrowseResponse response;

  @override
  Widget build(BuildContext context) {
    final absolutePath = _absolutePath(
      rootPath: response.rootPath,
      relativePath: response.relativePath,
      entryName: entry.name,
    );
    final showThumbnail = entry.isIndexed && entry.media != null;
    final showMediaBlock =
        entry.isIndexed && entry.media != null && !entry.isDir;
    final showStreamingBadge = entry.media?.isStreaming ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KindHeader(entry: entry),
        if (showThumbnail) ...[
          const SizedBox(height: AppSpacing.s16),
          _ThumbnailPreview(entry: entry),
        ],
        if (showStreamingBadge) ...[
          const SizedBox(height: AppSpacing.s12),
          const _StreamingBadge(),
        ],
        const SizedBox(height: AppSpacing.s18),
        Text(
          'Path',
          style: AppTypography.captionV2.copyWith(
            color: AppColors.textMutedV2,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.s6),
        _PathCard(absolutePath: absolutePath),
        const SizedBox(height: AppSpacing.s18),
        Text(
          'Quick Stats',
          style: AppTypography.h2.copyWith(color: AppColors.textBright),
        ),
        const SizedBox(height: AppSpacing.s10),
        _QuickStatsGrid(entry: entry),
        if (showMediaBlock) ...[
          const SizedBox(height: AppSpacing.s18),
          Text(
            'Media',
            style: AppTypography.h2.copyWith(color: AppColors.textBright),
          ),
          const SizedBox(height: AppSpacing.s10),
          _MediaMetadata(entry: entry),
        ],
        const SizedBox(height: AppSpacing.s20),
        _ActionsRow(entry: entry, absolutePath: absolutePath),
      ],
    );
  }
}

// ─── Kind header ───────────────────────────────────────────────────────────

class _KindHeader extends StatelessWidget {
  const _KindHeader({required this.entry});

  final BrowseEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = _colorForKind(entry.kind);
    final icon = _iconForKind(entry.kind);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Center(
            child: Icon(icon, size: 20, color: color),
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.name,
                style: AppTypography.h2.copyWith(
                  color: AppColors.textBright,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _kindLabel(entry.kind, isDir: entry.isDir),
                style: AppTypography.captionV2.copyWith(
                  color: AppColors.textMutedV2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Thumbnail preview ─────────────────────────────────────────────────────

class _ThumbnailPreview extends StatelessWidget {
  const _ThumbnailPreview({required this.entry});

  final BrowseEntry entry;

  @override
  Widget build(BuildContext context) {
    final media = entry.media!;
    final isImage = entry.kind == BrowseKind.image;
    const width = 280.0;
    final height = isImage ? 280.0 : 158.0;

    if (media.isThumbnailInFlight) {
      return _ThumbnailPlaceholder(
        width: width,
        height: height,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.violet),
              ),
            ),
            SizedBox(height: AppSpacing.s10),
            Text(
              'Generating thumbnail…',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: AppColors.textMutedV2,
                height: 1.3,
              ),
            ),
          ],
        ),
      );
    }

    if (media.hasThumbnailFailed) {
      return _ThumbnailPlaceholder(
        width: width,
        height: height,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 28,
              color: AppColors.textFaint,
            ),
            SizedBox(height: AppSpacing.s8),
            Text(
              'Thumbnail unavailable',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: AppColors.textMutedV2,
                height: 1.3,
              ),
            ),
          ],
        ),
      );
    }

    if (!media.hasThumbnailReady || entry.fileId == null) {
      // No usable status — fall back to the same "unavailable" tile.
      return _ThumbnailPlaceholder(
        width: width,
        height: height,
        child: const Icon(
          Icons.image_outlined,
          size: 28,
          color: AppColors.textFaint,
        ),
      );
    }

    final url = _buildThumbnailUrl(
      fileId: entry.fileId!,
      cacheBust: media.thumbnailGeneratedAtUnix ?? 0,
    );
    if (url == null) {
      return _ThumbnailPlaceholder(
        width: width,
        height: height,
        child: const Icon(
          Icons.image_outlined,
          size: 28,
          color: AppColors.textFaint,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _ThumbnailPlaceholder(
            width: width,
            height: height,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.textMutedV2),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          _log.w('Thumbnail load failed: $url', error: error);
          return _ThumbnailPlaceholder(
            width: width,
            height: height,
            child: const Icon(
              Icons.broken_image_outlined,
              size: 28,
              color: AppColors.textFaint,
            ),
          );
        },
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder({
    required this.width,
    required this.height,
    required this.child,
  });

  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF14101F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: Center(child: child),
    );
  }
}

// ─── Streaming badge ───────────────────────────────────────────────────────

class _StreamingBadge extends StatelessWidget {
  const _StreamingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x1AA855F7),
        border: Border.all(color: const Color(0x33A855F7)),
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_arrow_rounded, size: 14, color: AppColors.violet),
          SizedBox(width: 6),
          Text(
            'Streaming live',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.violet,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Path card ─────────────────────────────────────────────────────────────

class _PathCard extends StatefulWidget {
  const _PathCard({required this.absolutePath});

  final String absolutePath;

  @override
  State<_PathCard> createState() => _PathCardState();
}

class _PathCardState extends State<_PathCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _copyPath,
        child: Tooltip(
          message: widget.absolutePath,
          waitDuration: const Duration(milliseconds: 600),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _hovered
                  ? const Color(0x0DA855F7)
                  : const Color(0x08FFFFFF),
              border: Border.all(
                color: _hovered
                    ? const Color(0x1AA855F7)
                    : const Color(0x0DFFFFFF),
              ),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.folder_outlined,
                  size: 12,
                  color: AppColors.violet,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.absolutePath,
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      color: AppColors.textBody,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.content_copy_rounded,
                  size: 12,
                  color:
                      _hovered ? AppColors.violet : AppColors.textMutedV2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyPath() async {
    await Clipboard.setData(ClipboardData(text: widget.absolutePath));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Path copied to clipboard')),
    );
  }
}

// ─── Quick stats grid ──────────────────────────────────────────────────────

class _QuickStatsGrid extends StatelessWidget {
  const _QuickStatsGrid({required this.entry});

  final BrowseEntry entry;

  @override
  Widget build(BuildContext context) {
    final isFile = !entry.isDir;
    final extension = isFile ? _extensionOf(entry.name) : null;
    return Column(
      children: [
        _GridRow(
          left: _StatCell(
            label: 'Size',
            value: entry.isDir ? '—' : _humanBytes(entry.sizeBytes),
          ),
          right: _StatCell(
            label: 'Modified',
            value: _formatModified(entry.modifiedIso),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        _GridRow(
          left: _StatCell(
            label: 'Kind',
            value: _kindLabel(entry.kind, isDir: entry.isDir),
          ),
          right: _StatCell(
            label: 'Hidden',
            value: entry.isHidden ? 'Yes' : 'No',
          ),
        ),
        if (isFile) ...[
          const SizedBox(height: AppSpacing.s8),
          _GridRow(
            left: _StatCell(
              label: 'Extension',
              value: extension == null || extension.isEmpty ? '—' : extension,
            ),
            right: _StatCell(
              label: 'Indexed',
              value: entry.isIndexed ? 'Yes' : 'No',
            ),
          ),
        ],
      ],
    );
  }
}

class _GridRow extends StatelessWidget {
  const _GridRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: AppSpacing.s10),
        Expanded(child: right),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.captionV2.copyWith(
            color: AppColors.textMutedV2,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textBody,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─── Media metadata block ──────────────────────────────────────────────────

class _MediaMetadata extends StatelessWidget {
  const _MediaMetadata({required this.entry});

  final BrowseEntry entry;

  @override
  Widget build(BuildContext context) {
    final media = entry.media!;
    final rows = <Widget>[];

    void addRow({required String label, Widget? value, String? text}) {
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMutedV2,
                  fontWeight: FontWeight.w400,
                ),
              ),
              value ??
                  Text(
                    text ?? '—',
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      color: AppColors.textBody,
                      height: 1.4,
                    ),
                  ),
            ],
          ),
        ),
      );
    }

    switch (entry.kind) {
      case BrowseKind.video:
        final dimensions = (media.width != null && media.height != null)
            ? '${media.width} × ${media.height}'
            : '—';
        addRow(label: 'Dimensions', text: dimensions);
        addRow(
          label: 'Codec',
          text: media.codecName == null
              ? '—'
              : media.codecName!.toUpperCase(),
        );
        addRow(
          label: 'Duration',
          text: _formatDuration(media.durationSec),
        );
        addRow(
          label: 'HDR',
          value: _HdrBadge(format: media.hdrFormat),
        );
      case BrowseKind.audio:
        addRow(
          label: 'Codec',
          text: media.audioCodec == null
              ? (media.codecName?.toUpperCase() ?? '—')
              : media.audioCodec!.toUpperCase(),
        );
      case BrowseKind.image:
        final dimensions = (media.width != null && media.height != null)
            ? '${media.width} × ${media.height}'
            : '—';
        addRow(label: 'Dimensions', text: dimensions);
      case BrowseKind.directory:
      case BrowseKind.pdf:
      case BrowseKind.other:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x05FFFFFF),
        border: Border.all(color: const Color(0x0AFFFFFF)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

class _HdrBadge extends StatelessWidget {
  const _HdrBadge({required this.format});

  final String? format;

  @override
  Widget build(BuildContext context) {
    final raw = format?.trim();
    late final String label;
    late final Color color;
    if (raw == null || raw.isEmpty) {
      label = 'SDR';
      color = AppColors.textMutedV2;
    } else {
      final upper = raw.toUpperCase();
      if (upper.contains('DV') || upper.contains('DOLBY')) {
        label = 'DV';
        color = const Color(0xFFF59E0B); // amber
      } else if (upper.contains('HLG')) {
        label = 'HLG';
        color = AppColors.cyan;
      } else if (upper.contains('HDR')) {
        label = upper.contains('10') ? 'HDR10' : 'HDR';
        color = AppColors.violet;
      } else {
        label = upper;
        color = AppColors.violet;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─── Action buttons row ────────────────────────────────────────────────────

class _ActionsRow extends StatefulWidget {
  const _ActionsRow({required this.entry, required this.absolutePath});

  final BrowseEntry entry;
  final String absolutePath;

  @override
  State<_ActionsRow> createState() => _ActionsRowState();
}

class _ActionsRowState extends State<_ActionsRow> {
  bool _streamTestInFlight = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final isFile = !entry.isDir;
    final canStreamTest = isFile &&
        entry.isIndexed &&
        entry.kind == BrowseKind.video &&
        entry.fileId != null;

    return Wrap(
      spacing: AppSpacing.s8,
      runSpacing: AppSpacing.s8,
      children: [
        FluxButton(
          icon: Icons.open_in_new_rounded,
          size: FluxButtonSize.sm,
          onPressed: _openEntry,
          child: const Text('Open'),
        ),
        FluxButton(
          icon: Icons.folder_open_outlined,
          size: FluxButtonSize.sm,
          variant: FluxButtonVariant.secondary,
          onPressed: _revealInFolder,
          child: const Text('Reveal in folder'),
        ),
        FluxButton(
          icon: Icons.content_copy_rounded,
          size: FluxButtonSize.sm,
          variant: FluxButtonVariant.secondary,
          onPressed: _copyPath,
          child: const Text('Copy path'),
        ),
        if (canStreamTest)
          FluxButton(
            icon: Icons.play_circle_outline_rounded,
            size: FluxButtonSize.sm,
            variant: FluxButtonVariant.secondary,
            onPressed: _streamTestInFlight ? null : _runStreamTest,
            child:
                Text(_streamTestInFlight ? 'Testing…' : 'Stream test'),
          ),
      ],
    );
  }

  void _openEntry() {
    final entry = widget.entry;
    if (entry.isDir) {
      // Navigate into the folder via the cubit (matches the row's
      // double-click behaviour).  Build the new relative path by
      // joining the response's current path with the entry name.
      final cubit = context.read<LibraryBrowseCubit>();
      final state = cubit.state;
      if (state is! LibraryBrowseLoaded) return;
      final current = state.response.relativePath;
      final target = current.isEmpty ? entry.name : '$current/${entry.name}';
      cubit.navigateTo(target);
      return;
    }
    _launchUri(Uri.file(widget.absolutePath));
  }

  void _revealInFolder() {
    final parent = _parentOf(widget.absolutePath);
    _launchUri(Uri.file(parent));
  }

  Future<void> _launchUri(Uri uri) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) {
        messenger?.showSnackBar(
          SnackBar(content: Text('Could not open: ${uri.toFilePath()}')),
        );
      }
    } catch (e, st) {
      _log.e('launchUrl failed: $uri', error: e, stackTrace: st);
      if (mounted) {
        messenger?.showSnackBar(
          SnackBar(content: Text('Could not open: $e')),
        );
      }
    }
  }

  Future<void> _copyPath() async {
    await Clipboard.setData(ClipboardData(text: widget.absolutePath));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Path copied to clipboard')),
    );
  }

  Future<void> _runStreamTest() async {
    final entry = widget.entry;
    final fileId = entry.fileId;
    if (fileId == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _streamTestInFlight = true);
    try {
      final api = GetIt.I<ApiClient>();
      final started = await api.post<Map<String, dynamic>>(
        '/api/v1/stream/start/$fileId',
      );
      final sessionId = started['session_id'] as String?;
      final codec = (started['codec'] as String? ??
              entry.media?.codecName ??
              '')
          .toUpperCase();
      // Best-effort cleanup.  Failure here is non-fatal — surface the
      // start outcome to the operator regardless.
      if (sessionId != null) {
        try {
          await api.delete('/api/v1/stream/$sessionId');
        } catch (e, st) {
          _log.w('Stream-test cleanup failed for $sessionId',
              error: e, stackTrace: st);
        }
      }
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            codec.isEmpty ? 'Stream test OK' : 'Stream test OK · $codec',
          ),
        ),
      );
    } catch (e, st) {
      _log.e('Stream test failed for $fileId', error: e, stackTrace: st);
      if (mounted) {
        messenger?.showSnackBar(
          SnackBar(content: Text('Stream test failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _streamTestInFlight = false);
      }
    }
  }
}

// ─── Helpers ───────────────────────────────────────────────────────────────

IconData _iconForKind(BrowseKind kind) => switch (kind) {
      BrowseKind.directory => Icons.folder_rounded,
      BrowseKind.video => Icons.movie_outlined,
      BrowseKind.image => Icons.image_outlined,
      BrowseKind.audio => Icons.music_note_outlined,
      BrowseKind.pdf => Icons.picture_as_pdf_outlined,
      BrowseKind.other => Icons.insert_drive_file_outlined,
    };

Color _colorForKind(BrowseKind kind) => switch (kind) {
      BrowseKind.directory => AppColors.violet,
      BrowseKind.video => AppColors.violet,
      BrowseKind.image => AppColors.cyan,
      BrowseKind.audio => AppColors.pink,
      BrowseKind.pdf => AppColors.red,
      BrowseKind.other => AppColors.textMutedV2,
    };

String _kindLabel(BrowseKind kind, {required bool isDir}) {
  if (isDir) return 'Folder';
  return switch (kind) {
    BrowseKind.directory => 'Folder',
    BrowseKind.video => 'Video file',
    BrowseKind.image => 'Image file',
    BrowseKind.audio => 'Audio file',
    BrowseKind.pdf => 'PDF document',
    BrowseKind.other => 'File',
  };
}

/// Build an absolute path from the response's `rootPath` + `relativePath`
/// + entry name.  Mirrors `_BrowseRowState._absolutePath` in
/// `library_files_screen.dart` so the two surfaces agree on what a row's
/// absolute path actually is on disk.
String _absolutePath({
  required String rootPath,
  required String relativePath,
  required String entryName,
}) {
  final separator = rootPath.contains(r'\') ? r'\' : '/';
  final tail = relativePath.isEmpty
      ? entryName
      : '$relativePath/$entryName';
  final tailWithSep = tail.replaceAll('/', separator);
  return '$rootPath$separator$tailWithSep';
}

String _parentOf(String path) {
  final sep = path.contains(r'\') ? r'\' : '/';
  final idx = path.lastIndexOf(sep);
  if (idx <= 0) return path;
  return path.substring(0, idx);
}

/// File extension (lower-case, including the leading dot) or empty string
/// when the name has no extension.
String _extensionOf(String name) {
  final idx = name.lastIndexOf('.');
  if (idx <= 0 || idx == name.length - 1) return '';
  return name.substring(idx).toLowerCase();
}

/// Human-readable byte count.  Mirrors the top-level `humanBytes` in
/// `library_screen.dart` — duplicated here so the panel stays
/// self-contained (we can't import from another screen file).
String _humanBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final formatted = value >= 100 || unit == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$formatted ${units[unit]}';
}

/// Relative-time formatter — same shape as
/// `library_files_screen.dart::_formatModified` so list rows and the
/// detail panel render mtime identically.
String _formatModified(String iso) {
  if (iso.isEmpty) return '—';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays < 1) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return 'Today $h:$m';
    }
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final y = dt.year.toString();
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$mo-$d';
  } catch (_) {
    return '—';
  }
}

/// Format a duration in seconds as `1h 47m 30s` (omits leading zero
/// segments — `90s` becomes `1m 30s`, `45s` stays `45s`).  Returns the
/// dash glyph when the input is null or non-positive.
String _formatDuration(double? seconds) {
  if (seconds == null || seconds <= 0) return '—';
  final total = seconds.round();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final parts = <String>[];
  if (h > 0) parts.add('${h}h');
  if (m > 0 || h > 0) parts.add('${m}m');
  parts.add('${s}s');
  return parts.join(' ');
}

/// Build the thumbnail URL by joining the resolved local base URL with
/// the standard `/api/v1/files/{file_id}/thumbnail` endpoint.  Returns
/// `null` when no local base URL is configured — caller falls back to a
/// placeholder tile.
String? _buildThumbnailUrl({
  required String fileId,
  required int cacheBust,
}) {
  String? base;
  try {
    base = GetIt.I<ApiClient>().localBaseUrl;
  } catch (e, st) {
    _log.w('ApiClient not registered when building thumbnail URL',
        error: e, stackTrace: st);
    return null;
  }
  if (base == null || base.isEmpty) return null;
  final trimmed = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  return '$trimmed/api/v1/files/$fileId/thumbnail?v=$cacheBust';
}
