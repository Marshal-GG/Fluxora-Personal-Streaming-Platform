// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppNotification _$AppNotificationFromJson(Map<String, dynamic> json) =>
    _AppNotification(
      id: json['id'] as String,
      type: $enumDecode(_$NotificationTypeEnumMap, json['type']),
      category: $enumDecode(_$NotificationCategoryEnumMap, json['category']),
      title: json['title'] as String,
      message: json['message'] as String,
      relatedKind: json['related_kind'] as String?,
      relatedId: json['related_id'] as String?,
      createdAt: json['created_at'] as String,
      readAt: json['read_at'] as String?,
      dismissedAt: json['dismissed_at'] as String?,
    );

Map<String, dynamic> _$AppNotificationToJson(_AppNotification instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$NotificationTypeEnumMap[instance.type]!,
      'category': _$NotificationCategoryEnumMap[instance.category]!,
      'title': instance.title,
      'message': instance.message,
      'related_kind': instance.relatedKind,
      'related_id': instance.relatedId,
      'created_at': instance.createdAt,
      'read_at': instance.readAt,
      'dismissed_at': instance.dismissedAt,
    };

const _$NotificationTypeEnumMap = {
  NotificationType.info: 'info',
  NotificationType.warning: 'warning',
  NotificationType.error: 'error',
  NotificationType.success: 'success',
};

const _$NotificationCategoryEnumMap = {
  NotificationCategory.system: 'system',
  NotificationCategory.client: 'client',
  NotificationCategory.license: 'license',
  NotificationCategory.transcode: 'transcode',
  NotificationCategory.storage: 'storage',
};
