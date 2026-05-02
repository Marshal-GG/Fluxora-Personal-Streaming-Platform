import 'package:equatable/equatable.dart';
import 'package:fluxora_core/entities/app_notification.dart';

sealed class NotificationsState extends Equatable {
  const NotificationsState();
}

final class NotificationsInitial extends NotificationsState {
  const NotificationsInitial();
  @override
  List<Object?> get props => [];
}

final class NotificationsLoading extends NotificationsState {
  const NotificationsLoading();
  @override
  List<Object?> get props => [];
}

final class NotificationsLoaded extends NotificationsState {
  const NotificationsLoaded({
    required this.items,
    required this.unreadCount,
  });
  final List<AppNotification> items;
  final int unreadCount;
  @override
  List<Object?> get props => [items, unreadCount];
}

final class NotificationsFailure extends NotificationsState {
  const NotificationsFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
