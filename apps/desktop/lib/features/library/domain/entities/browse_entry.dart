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

class BrowseEntry {
  const BrowseEntry({
    required this.name,
    required this.kind,
    required this.isDir,
    required this.isHidden,
    required this.sizeBytes,
    required this.modifiedIso,
    required this.isIndexed,
    this.fileId,
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

  /// True when a `media_files` row points at this absolute path —
  /// surfaces as a small "Indexed" badge in the UI.
  final bool isIndexed;

  /// The matched `media_files.id` (when `isIndexed`).  Reserved for
  /// future smart-dispatch flows (stream this file via the existing
  /// `/stream/start/{file_id}` endpoint).  v1 doesn't use it — every
  /// file click on desktop opens the OS default app.
  final String? fileId;

  static BrowseEntry? tryFromJson(Map<String, dynamic> json) {
    try {
      return BrowseEntry(
        name: json['name'] as String,
        kind: BrowseKind.fromWire(json['kind'] as String? ?? 'other'),
        isDir: json['is_dir'] as bool? ?? false,
        isHidden: json['is_hidden'] as bool? ?? false,
        sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
        modifiedIso: json['modified_iso'] as String? ?? '',
        isIndexed: json['is_indexed'] as bool? ?? false,
        fileId: json['file_id'] as String?,
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
