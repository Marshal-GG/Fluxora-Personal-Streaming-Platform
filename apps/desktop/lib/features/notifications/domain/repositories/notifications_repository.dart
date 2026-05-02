import 'package:fluxora_core/entities/app_notification.dart';

abstract class NotificationsRepository {
  Future<List<AppNotification>> list({bool onlyUnread = false, int limit = 50});
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<void> dismiss(String id);
  Stream<AppNotification> liveStream();
}
