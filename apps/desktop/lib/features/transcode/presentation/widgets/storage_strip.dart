import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/widgets/flux_button.dart';

import 'package:fluxora_desktop/features/transcode/domain/entities/transcode_storage.dart';
import 'package:fluxora_desktop/features/transcode/presentation/cubit/transcode_cubit.dart';
import 'package:fluxora_desktop/features/transcode/presentation/cubit/transcode_state.dart';

/// Single-row storage info strip mounted at the top of the Transcode
/// screen — plan 19 §M3.  Reads from the cubit's `storage` slice which
/// the cubit polls every 5 s.  Wraps onto two lines under tight widths
/// (Wrap-based layout) so a narrow detached window still renders cleanly.
///
/// Renders four facts, in order:
///   1. Total transcoded size + file count.
///   2. Cache root (truncated middle), with `[Open]` button.
///   3. Free disk at the cache root.
///   4. Per-codec breakdown of source files needing transcoding.
class StorageStrip extends StatelessWidget {
  const StorageStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscodeCubit, TranscodeState>(
      buildWhen: (a, b) {
        if (a is! TranscodeLoaded || b is! TranscodeLoaded) return true;
        return a.storage != b.storage;
      },
      builder: (context, state) {
        if (state is! TranscodeLoaded) {
          // Render a low-height placeholder so the screen layout is
          // stable from the first frame instead of jumping when the
          // first poll lands.
          return const _Placeholder();
        }
        final storage = state.storage;
        if (storage == null) return const _Placeholder();
        return _StripBody(storage: storage);
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s14),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s18,
        vertical: AppSpacing.s14,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgRaised,
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Text(
        'Loading storage info…',
        style: AppTypography.bodySmall.copyWith(color: AppColors.textDim),
      ),
    );
  }
}

class _StripBody extends StatelessWidget {
  const _StripBody({required this.storage});

  final TranscodeStorage storage;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s14),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s18,
        vertical: AppSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgRaised,
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Wrap(
        spacing: AppSpacing.s24,
        runSpacing: AppSpacing.s10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _Fact(
            label: 'Transcoded',
            value:
                '${_formatBytes(storage.transcodedSizeBytes)} · ${storage.transcodedFileCount} file${storage.transcodedFileCount == 1 ? '' : 's'}',
          ),
          _CacheRootFact(path: storage.cacheRoot),
          _Fact(
            label: 'Free on disk',
            value: _formatBytes(storage.freeBytesAtCacheRoot),
          ),
          _Fact(
            label: 'Sources by codec',
            value: storage.byCodec.isEmpty
                ? 'none'
                : storage.byCodec.values
                    .map((b) =>
                        '${b.codec.toUpperCase()} ${b.count}')
                    .join(' · '),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textMutedV2,
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Text(
          value,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textBright,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CacheRootFact extends StatelessWidget {
  const _CacheRootFact({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Cache:',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textMutedV2,
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Tooltip(
            message: path,
            child: Text(
              path.isEmpty ? '—' : path,
              style: AppTypography.monoCaption.copyWith(
                color: AppColors.textBright,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        FluxButton(
          variant: FluxButtonVariant.ghost,
          size: FluxButtonSize.sm,
          icon: Icons.open_in_new_rounded,
          onPressed: path.isEmpty ? null : () => openPathInFileManager(path),
          child: const Text('Open'),
        ),
      ],
    );
  }
}

// ── Bytes formatter ─────────────────────────────────────────────────────────

/// Format bytes with three significant figures, switching between units.
/// Mirrors the helper in `candidates_tab.dart` — kept inline here so the
/// strip widget has no cross-file dependency on a tab-specific helper.
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  double v = bytes / 1024;
  int i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
}

// ── Path-open helper (top-level, exported for queue/history tabs) ───────────

final _pathOpenLog = Logger();

/// Open [path] in the platform's native file manager.
///
/// Uses `url_launcher`'s `file://` URI handler — the OS resolves the
/// scheme to the native opener (Explorer / Finder / xdg-open) without
/// us having to spawn a subprocess and decode its exit code.  The
/// previous `Process.start("explorer", ...)` shape returned non-zero
/// on Windows even when the launch succeeded, which made our error
/// handling unreliable; `launchUrl` returns a clean bool we can act on.
///
/// Surfaces a SnackBar via the supplied [messenger] when the launch
/// fails so the operator gets feedback instead of a silent no-op.
Future<void> openPathInFileManager(
  String path, {
  ScaffoldMessengerState? messenger,
}) async {
  try {
    final uri = Uri.file(path);
    final ok = await launchUrl(uri);
    if (!ok) {
      _pathOpenLog.w('launchUrl returned false for path: $path');
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not open path')),
      );
    }
  } catch (e, st) {
    _pathOpenLog.e('Failed to open path $path', error: e, stackTrace: st);
    messenger?.showSnackBar(
      SnackBar(content: Text('Could not open path: $e')),
    );
  }
}

/// Copy [path] to the OS clipboard.  Emits a small SnackBar via
/// [messenger] when supplied so the operator gets visible feedback.
Future<void> copyPathToClipboard(
  String path, {
  ScaffoldMessengerState? messenger,
}) async {
  await Clipboard.setData(ClipboardData(text: path));
  messenger?.showSnackBar(
    const SnackBar(content: Text('Path copied to clipboard')),
  );
}
