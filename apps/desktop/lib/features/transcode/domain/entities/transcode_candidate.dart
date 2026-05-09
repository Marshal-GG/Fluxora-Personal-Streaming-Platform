import 'package:equatable/equatable.dart';

/// One file flagged for pre-transcode by `GET /api/v1/transcode/candidates`.
///
/// Source codec is `av1` or `vp9` — the server's WHERE clause excludes
/// HEVC and any file that already has a `transcoded_path`.
///
/// `est_output_size_bytes` is the server's pre-computed estimate
/// (2.0× source for AV1, 1.5× for VP9).  Keeping the math server-side
/// means the desktop never has to know which multiplier applies; it
/// just sums the field across selected rows.
class TranscodeCandidate extends Equatable {
  const TranscodeCandidate({
    required this.fileId,
    required this.name,
    required this.libraryId,
    required this.sizeBytes,
    required this.videoCodec,
    required this.durationSec,
    required this.estOutputSizeBytes,
  });

  final String fileId;
  final String name;
  final String libraryId;
  final int sizeBytes;

  /// Lower-cased codec id — `av1` or `vp9` for v1.
  final String videoCodec;

  /// Source duration in seconds, or null when ffprobe couldn't read it.
  final double? durationSec;

  /// Server-side estimate of the H.264 output size, in bytes.
  final int estOutputSizeBytes;

  factory TranscodeCandidate.fromJson(Map<String, dynamic> json) {
    final dynamic dur = json['duration_sec'];
    return TranscodeCandidate(
      fileId: json['file_id'] as String,
      name: json['name'] as String,
      libraryId: json['library_id'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
      videoCodec: (json['video_codec'] as String).toLowerCase(),
      durationSec: dur == null ? null : (dur as num).toDouble(),
      estOutputSizeBytes: (json['est_output_size_bytes'] as num).toInt(),
    );
  }

  @override
  List<Object?> get props => [
        fileId,
        name,
        libraryId,
        sizeBytes,
        videoCodec,
        durationSec,
        estOutputSizeBytes,
      ];
}
