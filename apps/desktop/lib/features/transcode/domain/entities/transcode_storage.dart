import 'package:equatable/equatable.dart';

/// Per-codec breakdown of source files.  Keys arrive lower-cased on the
/// wire (`av1`, `vp9`, `hevc`, …) — store them verbatim and let the UI
/// decide how to render them (`UPPERCASE` for chip labels).
class TranscodeStorageCodecBreakdown extends Equatable {
  const TranscodeStorageCodecBreakdown({
    required this.codec,
    required this.count,
    required this.bytes,
  });

  final String codec;
  final int count;
  final int bytes;

  factory TranscodeStorageCodecBreakdown.fromJson(
    String codec,
    Map<String, dynamic> json,
  ) =>
      TranscodeStorageCodecBreakdown(
        codec: codec,
        count: (json['count'] as num).toInt(),
        bytes: (json['bytes'] as num).toInt(),
      );

  @override
  List<Object?> get props => [codec, count, bytes];
}

/// Snapshot of the server's transcoded-sidecar storage state, surfaced by
/// `GET /api/v1/transcode/storage` (plan 19 §M3).  The desktop polls this
/// every 5 s while the Transcode screen is mounted.
///
/// All sizes are bytes.  `cacheRoot` is the absolute on-disk path the
/// server resolves at request time — operators can change it from the
/// Settings page (plan 19 §M2, server-side).
class TranscodeStorage extends Equatable {
  const TranscodeStorage({
    required this.cacheRoot,
    required this.storageMode,
    required this.transcodedSizeBytes,
    required this.transcodedFileCount,
    required this.freeBytesAtCacheRoot,
    required this.byCodec,
  });

  final String cacheRoot;

  /// `dedicated` (default, separate cache root) or `inline` (sidecar
  /// nested next to source).  Future modes added defensively land in
  /// the same string field.
  final String storageMode;

  final int transcodedSizeBytes;
  final int transcodedFileCount;
  final int freeBytesAtCacheRoot;

  /// Codec → breakdown map, keyed by lower-cased codec id.  Empty when
  /// the cache is empty.
  final Map<String, TranscodeStorageCodecBreakdown> byCodec;

  factory TranscodeStorage.fromJson(Map<String, dynamic> json) {
    final raw = (json['by_codec'] as Map<String, dynamic>? ?? const {});
    final byCodec = <String, TranscodeStorageCodecBreakdown>{};
    raw.forEach((codec, data) {
      byCodec[codec.toLowerCase()] = TranscodeStorageCodecBreakdown.fromJson(
        codec.toLowerCase(),
        (data as Map<String, dynamic>),
      );
    });
    return TranscodeStorage(
      cacheRoot: json['cache_root'] as String? ?? '',
      storageMode: json['storage_mode'] as String? ?? 'dedicated',
      transcodedSizeBytes:
          (json['transcoded_size_bytes'] as num?)?.toInt() ?? 0,
      transcodedFileCount:
          (json['transcoded_file_count'] as num?)?.toInt() ?? 0,
      freeBytesAtCacheRoot:
          (json['free_bytes_at_cache_root'] as num?)?.toInt() ?? 0,
      byCodec: byCodec,
    );
  }

  @override
  List<Object?> get props => [
        cacheRoot,
        storageMode,
        transcodedSizeBytes,
        transcodedFileCount,
        freeBytesAtCacheRoot,
        byCodec,
      ];
}
