import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fluxora_core/entities/converters.dart';

part 'media_file.freezed.dart';
part 'media_file.g.dart';

@freezed
abstract class MediaFile with _$MediaFile {
  const factory MediaFile({
    required String id,
    required String path,
    required String name,
    required String extension,
    required int sizeBytes,
    double? durationSec,
    String? libraryId,
    int? tmdbId,
    // TMDB-enriched metadata
    String? title,
    String? overview,
    String? posterUrl,
    // Resume playback position
    @JsonKey(name: 'last_progress_sec') @Default(0.0) double resumeSec,
    // FFprobe-derived video metadata (server migration 016).  Null on
    // non-video extensions and on rows scanned before the migration until
    // the next library scan touches them.
    int? width,
    int? height,
    String? codecName,
    /// 'HDR10' / 'HLG' / 'DolbyVision' / null (SDR).
    String? hdrFormat,
    // TV episode aggregation (server migration 016).  Populated by Phase D's
    // TMDB back-fill — null on movies and on TV files scanned before the
    // back-fill ran.
    int? tmdbShowId,
    int? seasonNumber,
    int? episodeNumber,
    @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
    required DateTime createdAt,
    @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
    required DateTime updatedAt,
  }) = _MediaFile;

  factory MediaFile.fromJson(Map<String, dynamic> json) =>
      _$MediaFileFromJson(json);
}

/// Classifies a [MediaFile] into a broad viewer category derived from the
/// file extension stored in [MediaFile.extension].  Kept as a pure extension
/// so no code-gen is needed when the set of known extensions grows.
enum MediaKind { video, photo, pdf, music, other }

extension MediaFileKind on MediaFile {
  MediaKind get kind {
    final ext = extension.toLowerCase().replaceAll('.', '');
    if (const {
      'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v', 'ts',
      'mpg', 'mpeg', 'rm', 'rmvb', '3gp', 'divx',
    }.contains(ext)) {
      return MediaKind.video;
    }
    if (const {
      'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif', 'bmp',
      'tiff', 'tif', 'avif',
    }.contains(ext)) {
      return MediaKind.photo;
    }
    if (ext == 'pdf') {
      return MediaKind.pdf;
    }
    if (const {
      'mp3', 'aac', 'flac', 'wav', 'ogg', 'm4a', 'opus', 'wma',
      'aiff', 'alac', 'ape', 'dsf',
    }.contains(ext)) {
      return MediaKind.music;
    }
    return MediaKind.other;
  }
}

/// Composes a "4K HDR" / "1080p" / "720p" / null badge from FFprobe-derived
/// metadata.  Returns null when no resolution is known (legacy rows / audio
/// files) so callers can fall through to a no-badge layout.
extension MediaFileQualityBadge on MediaFile {
  String? get qualityBadge {
    final h = height;
    final res = switch (h) {
      null => null,
      >= 2000 => '4K',
      >= 1400 => '1440p',
      >= 1000 => '1080p',
      >= 700 => '720p',
      >= 400 => '480p',
      _ => '${h}p',
    };
    final hdr = switch (hdrFormat) {
      'HDR10' => 'HDR',
      'HLG' => 'HLG',
      'DolbyVision' => 'DV',
      _ => null,
    };
    if (res == null && hdr == null) return null;
    if (res != null && hdr != null) return '$res $hdr';
    return res ?? hdr;
  }
}
