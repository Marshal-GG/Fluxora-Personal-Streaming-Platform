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
