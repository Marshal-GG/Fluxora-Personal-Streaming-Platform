import 'package:fluxora_core/entities/app_notification.dart';

sealed class NotificationsState {
  const NotificationsState();
}

final class NotificationsInitial extends NotificationsState {
  const NotificationsInitial();
}

final class NotificationsLoading extends NotificationsState {
  const NotificationsLoading();
}

final class NotificationsLoaded extends NotificationsState {
  const NotificationsLoaded({
    required this.items,
    required this.unreadCount,
  });
  final List<AppNotification> items;
  final int unreadCount;
}

final class NotificationsFailure extends NotificationsState {
  const NotificationsFailure(this.message);
  final String message;
}
