import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_notification.freezed.dart';
part 'app_notification.g.dart';

enum NotificationType {
  @JsonValue('info')
  info,
  @JsonValue('warning')
  warning,
  @JsonValue('error')
  error,
  @JsonValue('success')
  success,
}

enum NotificationCategory {
  @JsonValue('system')
  system,
  @JsonValue('client')
  client,
  @JsonValue('license')
  license,
  @JsonValue('transcode')
  transcode,
  @JsonValue('storage')
  storage,
}

@freezed
abstract class AppNotification with _$AppNotification {
  const factory AppNotification({
    required String id,
    required NotificationType type,
    required NotificationCategory category,
    required String title,
    required String message,
    String? relatedKind,
    String? relatedId,
    required String createdAt,
    String? readAt,
    String? dismissedAt,
  }) = _AppNotification;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);
}
