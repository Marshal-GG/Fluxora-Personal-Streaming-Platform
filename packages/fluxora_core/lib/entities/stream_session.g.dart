// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stream_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$StreamSessionImpl _$$StreamSessionImplFromJson(Map<String, dynamic> json) =>
    _$StreamSessionImpl(
      id: json['id'] as String,
      fileId: json['file_id'] as String,
      clientId: json['client_id'] as String,
      startedAt: utcDateTimeFromJson(json['started_at'] as String),
      endedAt: utcDateTimeOrNullFromJson(json['ended_at'] as String?),
      connectionType:
          $enumDecode(_$ConnectionTypeEnumMap, json['connection_type']),
      bytesTransferred: (json['bytes_transferred'] as num?)?.toInt(),
      progressSec: (json['progress_sec'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$$StreamSessionImplToJson(_$StreamSessionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'file_id': instance.fileId,
      'client_id': instance.clientId,
      'started_at': utcDateTimeToJson(instance.startedAt),
      'ended_at': utcDateTimeOrNullToJson(instance.endedAt),
      'connection_type': _$ConnectionTypeEnumMap[instance.connectionType]!,
      'bytes_transferred': instance.bytesTransferred,
      'progress_sec': instance.progressSec,
    };

const _$ConnectionTypeEnumMap = {
  ConnectionType.lan: 'lan',
  ConnectionType.webrtcP2p: 'webrtc_p2p',
  ConnectionType.turnRelay: 'turn_relay',
};
