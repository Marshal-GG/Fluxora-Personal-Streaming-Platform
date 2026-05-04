// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fallback_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FallbackEvent _$FallbackEventFromJson(Map<String, dynamic> json) =>
    _FallbackEvent(
      timestamp: json['timestamp'] as String,
      sessionId: json['session_id'] as String,
      requestedEncoder: json['requested_encoder'] as String,
      actualEncoder: json['actual_encoder'] as String,
      reason: json['reason'] as String,
    );

Map<String, dynamic> _$FallbackEventToJson(_FallbackEvent instance) =>
    <String, dynamic>{
      'timestamp': instance.timestamp,
      'session_id': instance.sessionId,
      'requested_encoder': instance.requestedEncoder,
      'actual_encoder': instance.actualEncoder,
      'reason': instance.reason,
    };

_FallbackHistory _$FallbackHistoryFromJson(Map<String, dynamic> json) =>
    _FallbackHistory(
      events:
          (json['events'] as List<dynamic>?)
              ?.map((e) => FallbackEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$FallbackHistoryToJson(_FallbackHistory instance) =>
    <String, dynamic>{
      'events': instance.events.map((e) => e.toJson()).toList(),
    };
