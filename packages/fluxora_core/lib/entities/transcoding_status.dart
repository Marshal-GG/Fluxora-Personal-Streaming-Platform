import 'package:freezed_annotation/freezed_annotation.dart';

part 'transcoding_status.freezed.dart';
part 'transcoding_status.g.dart';

@freezed
abstract class EncoderLoad with _$EncoderLoad {
  const factory EncoderLoad({
    required String encoder,
    required int activeSessions,
    double? gpuUtilizationPercent,
    int? vramUsedMb,
    double? cpuUtilizationPercent,
    /// Underlying GPU engine name ("cuda" / "qsv" / "vaapi" / "videotoolbox"),
    /// or null for software encoders.  Drives the active-encoder strip's
    /// "GPU vs CPU" badge.
    String? gpuEngine,
    /// True if the encoder's last self-test passed; false if it failed; null
    /// if it hasn't been tested yet.  Software encoders always pass.
    bool? encoderTestPassed,
    /// First non-empty stderr line from the failed self-test.  Drives the
    /// failed-encoder modal copy.  Null on pass / not-yet-tested.
    String? encoderTestError,
    /// ISO-8601 UTC timestamp of the last self-test.  Surfaced as "tested
    /// HH:MM" in the encoder status panel so operators know when self-test
    /// data was last refreshed.
    String? encoderTestedAt,
  }) = _EncoderLoad;

  factory EncoderLoad.fromJson(Map<String, dynamic> json) =>
      _$EncoderLoadFromJson(json);
}

@freezed
abstract class ActiveTranscodeSession with _$ActiveTranscodeSession {
  const factory ActiveTranscodeSession({
    required String id,
    String? clientId,
    String? clientName,
    String? mediaTitle,
    String? inputCodec,
    String? outputCodec,
    double? fps,
    double? speedX,
    double? progress,
    /// Encoder this session is actually using (e.g. `h264_nvenc`).
    /// Differs from the operator's first-choice encoder when the chain
    /// fell over to a backup; null on stream-copy sessions (no encoder
    /// involved).  Drives the "Encoder" column in the active-sessions
    /// table.
    String? encoderUsed,
  }) = _ActiveTranscodeSession;

  factory ActiveTranscodeSession.fromJson(Map<String, dynamic> json) =>
      _$ActiveTranscodeSessionFromJson(json);
}

@freezed
abstract class TranscodingStatus with _$TranscodingStatus {
  const factory TranscodingStatus({
    required String activeEncoder,
    required List<String> availableEncoders,
    required List<EncoderLoad> encoderLoads,
    required List<ActiveTranscodeSession> activeSessions,
  }) = _TranscodingStatus;

  factory TranscodingStatus.fromJson(Map<String, dynamic> json) =>
      _$TranscodingStatusFromJson(json);
}
