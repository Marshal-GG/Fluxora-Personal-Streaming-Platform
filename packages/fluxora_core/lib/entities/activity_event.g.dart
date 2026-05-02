// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ActivityEvent _$ActivityEventFromJson(Map<String, dynamic> json) =>
    _ActivityEvent(
      id: json['id'] as String,
      type: json['type'] as String,
      actorKind: json['actor_kind'] as String?,
      actorId: json['actor_id'] as String?,
      targetKind: json['target_kind'] as String?,
      targetId: json['target_id'] as String?,
      summary: json['summary'] as String,
      payload: json['payload'] as Map<String, dynamic>?,
      createdAt: json['created_at'] as String,
    );

Map<String, dynamic> _$ActivityEventToJson(_ActivityEvent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'actor_kind': instance.actorKind,
      'actor_id': instance.actorId,
      'target_kind': instance.targetKind,
      'target_id': instance.targetId,
      'summary': instance.summary,
      'payload': instance.payload,
      'created_at': instance.createdAt,
    };
