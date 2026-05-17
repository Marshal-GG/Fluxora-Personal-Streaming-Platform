/// Browse-endpoint domain types for the desktop folder-browser view.
///
/// Mirrors `services/browse_service.BrowseEntry` + `BrowseResponse` on
/// the server.  Lives under `apps/desktop` because mobile uses the
/// curated `media_files` catalog and doesn't browse the filesystem.
library;

import 'package:logger/logger.dart';

final _log = Logger();

enum BrowseKind {
  directory,
  video,
  image,
  audio,
  pdf,
  other;

  /// Tolerant parser — unknown server values map to [other] rather than
  /// throwing.  Future kinds (e.g. a `.docx` viewer) won't crash older
  /// clients.
  static BrowseKind fromWire(String raw) {
    return switch (raw) {
      'directory' => BrowseKind.directory,
      'video' => BrowseKind.video,
      'image' => BrowseKind.image,
      'audio' => BrowseKind.audio,
      'pdf' => BrowseKind.pdf,
      _ => BrowseKind.other,
    };
  }
}

/// Per-indexed-entry metadata block returned alongside the browse-entry
/// shape.  Phase A — pulled from `media_files` + `media_thumbnails` +
/// `stream_sessions` server-side in one JOIN so the desktop right
/// detail panel renders without a second HTTP call.
class IndexedMedia {
  const IndexedMedia({
    this.width,
    this.height,
    this.durationSec,
    this.codecName,
    this.hdrFormat,
    this.audioCodec,
    this.thumbnailStatus,
    this.thumbnailGeneratedAtUnix,
    this.indexedAtIso,
    this.isStreaming = false,
    this.posterUrl,
  });

  final int? width;
  final int? height;
  final double? durationSec;
  final String? codecName;
  final String? hdrFormat;     // HDR10 / HLG / DolbyVision / null
  final String? audioCodec;    // primary track's codec from audio_tracks
  /// 'pending' / 'generating' / 'ready' / 'failed' / 'skipped' / 'stale'
  /// — 'stale' is synthesised server-side when the source file was
  /// modified after the current thumbnail was rendered (worker has
  /// already been re-queued).
  final String? thumbnailStatus;
  final int? thumbnailGeneratedAtUnix;
  final String? indexedAtIso;
  /// True when an active `stream_sessions` row points at this file.
  /// Refreshes on the next browse request — client doesn't subscribe
  /// to a separate event stream for this (cheap to recompute).
  final bool isStreaming;

  /// TMDB poster art URL when the file has been enriched, null
  /// otherwise.  Already-resolved (absolute http(s) URL) — TMDB
  /// returns absolute URLs and the server stores them verbatim.
  /// Client renders this in preference to the extracted-frame
  /// thumbnail so the folder browser matches the library card
  /// mosaic (where `_library_aggregates` also prefers TMDB).
  final String? posterUrl;

  bool get hasThumbnailReady => thumbnailStatus == 'ready';
  bool get isThumbnailStale => thumbnailStatus == 'stale';
  bool get isThumbnailInFlight =>
      thumbnailStatus == 'pending' ||
      thumbnailStatus == 'generating' ||
      thumbnailStatus == 'stale';

  /// True only for the transient/recoverable `failed` state — the
  /// worker tried to extract and crashed (corrupt JXR, FFmpeg
  /// timeout, PyMuPDF couldn't open the PDF, etc.).  The "Regenerate
  /// thumbnail" right-click action retries.
  bool get hasThumbnailFailed => thumbnailStatus == 'failed';

  /// True for the permanent `skipped` state — the file's extension
  /// has no extractor (subtitles, archives, source files, plain text,
  /// etc.) or the extractor returned skipped (audio file without
  /// embedded art, encrypted PDF).  Distinct from `failed` because
  /// there's no action the operator can take; the UI must not badge
  /// these as errors.
  bool get isThumbnailSkipped => thumbnailStatus == 'skipped';

  static IndexedMedia? tryFromJson(Map<String, dynamic> json) {
    try {
      return IndexedMedia(
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
        durationSec: (json['duration_sec'] as num?)?.toDouble(),
        codecName: json['codec_name'] as String?,
        hdrFormat: json['hdr_format'] as String?,
        audioCodec: json['audio_codec'] as String?,
        thumbnailStatus: json['thumbnail_status'] as String?,
        thumbnailGeneratedAtUnix:
            (json['thumbnail_generated_at_unix'] as num?)?.toInt(),
        indexedAtIso: json['indexed_at_iso'] as String?,
        isStreaming: json['is_streaming'] as bool? ?? false,
        posterUrl: json['poster_url'] as String?,
      );
    } catch (e, st) {
      _log.w('IndexedMedia.tryFromJson — bad payload',
          error: e, stackTrace: st);
      return null;
    }
  }
}

class BrowseEntry {
  const BrowseEntry({
    required this.name,
    required this.kind,
    required this.isDir,
    required this.isHidden,
    required this.sizeBytes,
    required this.modifiedIso,
    required this.mtimeUnix,
    required this.isIndexed,
    this.fileId,
    this.media,
  });

  /// Display name (file or directory basename).
  final String name;

  /// Server-classified kind by extension.  Drives the leading icon.
  final BrowseKind kind;

  /// Convenience flag — same as `kind == BrowseKind.directory` but
  /// preserved on the wire so a future kind that's directory-like
  /// (e.g. a bundle) can still be navigated.
  final bool isDir;

  /// Dotfile name OR Windows `FILE_ATTRIBUTE_HIDDEN` flag.  The browser
  /// only ever shows these when the operator toggles "Show hidden".
  final bool isHidden;

  /// On-disk file size in bytes (0 for directories).
  final int sizeBytes;

  /// ISO-8601 UTC mtime — formatted client-side via [DateTime.parse].
  final String modifiedIso;

  /// Raw mtime as a Unix timestamp.  Lets the client do its own
  /// stale-thumb comparisons without re-parsing the ISO string.
  final int mtimeUnix;

  /// True when a `media_files` row points at this absolute path —
  /// surfaces as a small "Indexed" badge in the UI.
  final bool isIndexed;

  /// The matched `media_files.id` (when `isIndexed`).  Used for
  /// stream-test / regenerate-thumbnail / open-via-streaming flows.
  final String? fileId;

  /// Phase A: when `isIndexed`, this carries width / height / codec /
  /// duration / HDR / audio codec / thumbnail status + generated_at /
  /// indexed_at + currently-streaming flag.  `null` for non-indexed
  /// entries and directories.
  final IndexedMedia? media;

  static BrowseEntry? tryFromJson(Map<String, dynamic> json) {
    try {
      final mediaJson = json['media'];
      return BrowseEntry(
        name: json['name'] as String,
        kind: BrowseKind.fromWire(json['kind'] as String? ?? 'other'),
        isDir: json['is_dir'] as bool? ?? false,
        isHidden: json['is_hidden'] as bool? ?? false,
        sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
        modifiedIso: json['modified_iso'] as String? ?? '',
        mtimeUnix: (json['mtime_unix'] as num?)?.toInt() ?? 0,
        isIndexed: json['is_indexed'] as bool? ?? false,
        fileId: json['file_id'] as String?,
        media: mediaJson is Map<String, dynamic>
            ? IndexedMedia.tryFromJson(mediaJson)
            : null,
      );
    } catch (e, st) {
      _log.w('BrowseEntry.tryFromJson — bad payload',
          error: e, stackTrace: st);
      return null;
    }
  }
}

class BrowseResponse {
  const BrowseResponse({
    required this.libraryId,
    required this.rootPath,
    required this.relativePath,
    required this.parentPath,
    required this.entries,
  });

  /// Library this response belongs to.  Echoed from the request.
  final String libraryId;

  /// Server-side absolute path of the matched root (for breadcrumb
  /// labelling — the leftmost segment of the trail).
  final String rootPath;

  /// Normalised relative path under the root.  Empty string at the
  /// root itself.
  final String relativePath;

  /// One level up from [relativePath].  `null` at the root (no back
  /// navigation possible).  Empty string means "back to the root".
  final String? parentPath;

  /// Directory contents (sorted dirs-first then files-alphabetical
  /// server-side).
  final List<BrowseEntry> entries;

  static BrowseResponse fromJson(Map<String, dynamic> json) {
    final entryList = json['entries'];
    final entries = <BrowseEntry>[];
    if (entryList is List) {
      for (final raw in entryList) {
        if (raw is Map<String, dynamic>) {
          final parsed = BrowseEntry.tryFromJson(raw);
          if (parsed != null) entries.add(parsed);
        }
      }
    }
    return BrowseResponse(
      libraryId: json['library_id'] as String? ?? '',
      rootPath: json['root_path'] as String? ?? '',
      relativePath: json['relative_path'] as String? ?? '',
      parentPath: json['parent_path'] as String?,
      entries: entries,
    );
  }
}
