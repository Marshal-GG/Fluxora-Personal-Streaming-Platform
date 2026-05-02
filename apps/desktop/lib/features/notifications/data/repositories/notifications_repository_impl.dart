import 'dart:async';

import 'package:fluxora_core/entities/app_notification.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_desktop/features/notifications/domain/repositories/notifications_repository.dart';

// TODO(M8): Replace polling with WS /api/v1/ws/notifications once desktop
// gains a proper WebSocket wrapper that supports the same HMAC-bearer auth
// pattern used by the server's `get_current_user_ws` dependency.
class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;
  static final _log = Logger();

  @override
  Future<List<AppNotification>> list({
    bool onlyUnread = false,
    int limit = 50,
  }) =>
      _apiClient.get(
        Endpoints.notifications,
        queryParameters: {
          if (onlyUnread) 'unread_only': 'true',
          'limit': '$limit',
        },
        fromJson: (json) => (json['notifications'] as List<dynamic>)
            .map(
              (e) => AppNotification.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      );

  @override
  Future<void> markRead(String id) => _apiClient.post<void>(
        Endpoints.notificationRead(id),
      );

  @override
  Future<void> markAllRead() => _apiClient.post<void>(
        Endpoints.notificationsReadAll,
      );

  @override
  Future<void> dismiss(String id) => _apiClient.delete(
        Endpoints.notificationDismiss(id),
      );

  /// Polls [Endpoints.notifications] every 5 s, emitting new notifications as
  /// they arrive.  Duplicates (same `id`) are filtered client-side.
  @override
  Stream<AppNotification> liveStream() async* {
    final seen = <String>{};
    while (true) {
      await Future<void>.delayed(const Duration(seconds: 5));
      try {
        final items = await list(limit: 20);
        for (final n in items) {
          if (seen.add(n.id)) {
            yield n;
          }
        }
      } on ApiException catch (e, st) {
        _log.w('Notifications poll failed', error: e, stackTrace: st);
      } catch (e, st) {
        _log.w('Notifications poll failed', error: e, stackTrace: st);
      }
    }
  }
}
