import 'package:equatable/equatable.dart';

/// Lifecycle status of a single transcode job, mirroring the
/// `transcode_jobs.status` CHECK constraint on the server.
enum TranscodeJobStatus {
  queued,
  running,
  done,
  failed,
  cancelled;

  static TranscodeJobStatus fromString(String raw) {
    switch (raw.toLowerCase()) {
      case 'queued':
        return TranscodeJobStatus.queued;
      case 'running':
        return TranscodeJobStatus.running;
      case 'done':
        return TranscodeJobStatus.done;
      case 'failed':
        return TranscodeJobStatus.failed;
      case 'cancelled':
        return TranscodeJobStatus.cancelled;
      default:
        // Unknown status from a forward-compatible server is treated as
        // queued so the row at least renders; the Queue tab will show it
        // and the operator can investigate.
        return TranscodeJobStatus.queued;
    }
  }

  bool get isTerminal =>
      this == TranscodeJobStatus.done ||
      this == TranscodeJobStatus.failed ||
      this == TranscodeJobStatus.cancelled;

  bool get isActive =>
      this == TranscodeJobStatus.queued ||
      this == TranscodeJobStatus.running;
}

/// One row from `GET /api/v1/transcode/jobs`.
///
/// `progressPct` is 0.0–100.0 (NOT 0.0–1.0) — match the server contract
/// verbatim and let the UI divide by 100 when feeding [FluxProgress].
class TranscodeJob extends Equatable {
  const TranscodeJob({
    required this.id,
    required this.fileId,
    required this.fileName,
    required this.status,
    required this.progressPct,
    required this.etaSec,
    required this.error,
    required this.outputPath,
    required this.encoder,
    required this.createdAt,
    required this.startedAt,
    required this.finishedAt,
    this.outputSizeBytes,
    this.srcSizeBytes,
    this.srcPath = '',
  });

  final int id;
  final String fileId;
  final String fileName;
  final TranscodeJobStatus status;

  /// 0.0–100.0.  Clamp at the render site, not here — preserve the raw
  /// number so the cubit can be tested against the wire shape.
  final double progressPct;

  final int? etaSec;
  final String? error;
  final String? outputPath;
  final String encoder;

  /// Epoch seconds (UTC).
  final int createdAt;
  final int? startedAt;
  final int? finishedAt;

  /// Actual H.264 sidecar size on disk, in bytes.  Set on `done` jobs;
  /// null on queued / running / failed / cancelled rows.  Used by the
  /// History tab's per-row "Source → Sidecar" size column to surface
  /// the actual output (no leading `~`) instead of the queue-time estimate.
  final int? outputSizeBytes;

  /// Source file size at job-creation time, in bytes.  Server stores
  /// this on the row so History rows can render the original size even
  /// after the source has been deleted / moved.  Null when missing.
  final int? srcSizeBytes;

  /// Absolute path of the source file.  Drives History-tab folder-tree
  /// grouping (plan 19 §M4).  Falls back to an empty string when an
  /// older server build doesn't surface it.
  final String srcPath;

  factory TranscodeJob.fromJson(Map<String, dynamic> json) {
    int? readNullableInt(String key) {
      final v = json[key];
      if (v == null) return null;
      return (v as num).toInt();
    }

    return TranscodeJob(
      id: (json['id'] as num).toInt(),
      fileId: json['file_id'] as String,
      fileName: json['file_name'] as String,
      status: TranscodeJobStatus.fromString(json['status'] as String),
      progressPct: (json['progress_pct'] as num).toDouble(),
      etaSec: readNullableInt('eta_sec'),
      error: json['error'] as String?,
      outputPath: json['output_path'] as String?,
      encoder: json['encoder'] as String,
      createdAt: (json['created_at'] as num).toInt(),
      startedAt: readNullableInt('started_at'),
      finishedAt: readNullableInt('finished_at'),
      outputSizeBytes: readNullableInt('output_size_bytes'),
      srcSizeBytes: readNullableInt('src_size_bytes'),
      srcPath: (json['src_path'] as String?) ?? '',
    );
  }

  @override
  List<Object?> get props => [
        id,
        fileId,
        fileName,
        status,
        progressPct,
        etaSec,
        error,
        outputPath,
        encoder,
        createdAt,
        startedAt,
        finishedAt,
        outputSizeBytes,
        srcSizeBytes,
        srcPath,
      ];
}
