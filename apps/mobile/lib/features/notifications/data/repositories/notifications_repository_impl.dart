import 'dart:async';

import 'package:fluxora_core/entities/app_notification.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_mobile/features/notifications/domain/repositories/notifications_repository.dart';

// TODO(WS): Migrate from REST polling to WS /api/v1/ws/notifications once a
// shared WebSocket wrapper exists that handles HMAC-bearer auth like the
// server's `get_current_user_ws` dependency. Desktop sits on the same
// transitional polling path (see desktop NotificationsRepositoryImpl).
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
        // Server query param is `unread` (renamed from `unread_only` during
        // the desktop notifications-audit round); response body is a flat
        // `list[NotificationResponse]`, not a `{notifications: [...]}`
        // wrapper.  Both shapes were silently wrong before — `unread_only`
        // landed as an unknown query param (server defaulted to `unread=
        // false` and returned everything), and the wrapper indexing
        // crashed at runtime with "type 'String' is not a subtype of type
        // 'int' of 'index'".
        queryParameters: {
          if (onlyUnread) 'unread': 'true',
          'limit': '$limit',
        },
        fromJson: (json) => (json as List<dynamic>)
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
  /// they arrive. Duplicates (same `id`) are filtered client-side.
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
