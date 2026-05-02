// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcoding_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EncoderLoad _$EncoderLoadFromJson(Map<String, dynamic> json) => _EncoderLoad(
  encoder: json['encoder'] as String,
  activeSessions: (json['active_sessions'] as num).toInt(),
  gpuUtilizationPercent: (json['gpu_utilization_percent'] as num?)?.toDouble(),
  vramUsedMb: (json['vram_used_mb'] as num?)?.toInt(),
  cpuUtilizationPercent: (json['cpu_utilization_percent'] as num?)?.toDouble(),
);

Map<String, dynamic> _$EncoderLoadToJson(_EncoderLoad instance) =>
    <String, dynamic>{
      'encoder': instance.encoder,
      'active_sessions': instance.activeSessions,
      'gpu_utilization_percent': instance.gpuUtilizationPercent,
      'vram_used_mb': instance.vramUsedMb,
      'cpu_utilization_percent': instance.cpuUtilizationPercent,
    };

_ActiveTranscodeSession _$ActiveTranscodeSessionFromJson(
  Map<String, dynamic> json,
) => _ActiveTranscodeSession(
  id: json['id'] as String,
  clientId: json['client_id'] as String?,
  clientName: json['client_name'] as String?,
  mediaTitle: json['media_title'] as String?,
  inputCodec: json['input_codec'] as String?,
  outputCodec: json['output_codec'] as String?,
  fps: (json['fps'] as num?)?.toDouble(),
  speedX: (json['speed_x'] as num?)?.toDouble(),
  progress: (json['progress'] as num?)?.toDouble(),
);

Map<String, dynamic> _$ActiveTranscodeSessionToJson(
  _ActiveTranscodeSession instance,
) => <String, dynamic>{
  'id': instance.id,
  'client_id': instance.clientId,
  'client_name': instance.clientName,
  'media_title': instance.mediaTitle,
  'input_codec': instance.inputCodec,
  'output_codec': instance.outputCodec,
  'fps': instance.fps,
  'speed_x': instance.speedX,
  'progress': instance.progress,
};

_TranscodingStatus _$TranscodingStatusFromJson(Map<String, dynamic> json) =>
    _TranscodingStatus(
      activeEncoder: json['active_encoder'] as String,
      availableEncoders: (json['available_encoders'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      encoderLoads: (json['encoder_loads'] as List<dynamic>)
          .map((e) => EncoderLoad.fromJson(e as Map<String, dynamic>))
          .toList(),
      activeSessions: (json['active_sessions'] as List<dynamic>)
          .map(
            (e) => ActiveTranscodeSession.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );

Map<String, dynamic> _$TranscodingStatusToJson(
  _TranscodingStatus instance,
) => <String, dynamic>{
  'active_encoder': instance.activeEncoder,
  'available_encoders': instance.availableEncoders,
  'encoder_loads': instance.encoderLoads.map((e) => e.toJson()).toList(),
  'active_sessions': instance.activeSessions.map((e) => e.toJson()).toList(),
};
