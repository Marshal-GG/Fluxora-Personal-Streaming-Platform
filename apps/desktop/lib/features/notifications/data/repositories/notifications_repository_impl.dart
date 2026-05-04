import 'dart:async';

import 'package:fluxora_core/entities/app_notification.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_desktop/features/notifications/domain/repositories/notifications_repository.dart';

// Polling is the v1 transport for desktop notifications, matching the same
// design choice used by `SystemStatsCubit` — see that cubit's header for
// rationale (no WebSocket wrapper with HMAC-bearer auth on desktop yet).
// `WS /api/v1/ws/notifications` exists server-side; switch to it post-v1.
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
          if (onlyUnread) 'unread': 'true',
          'limit': '$limit',
        },
        // Server returns a bare JSON array (`response_model=list[...]`), not
        // a `{"notifications": [...]}` envelope.
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
  /// they arrive.  Duplicates (same `id`) are filtered client-side.
  ///
  /// `seen` is capped at [_seenCap] entries (FIFO eviction) so a long-running
  /// session doesn't accumulate IDs without bound. Each poll pulls at most
  /// `_pollLimit` rows, so the cap is generous enough that we never evict an
  /// ID we'd see again on the very next tick.
  @override
  Stream<AppNotification> liveStream() async* {
    final seen = <String>{};
    while (true) {
      await Future<void>.delayed(const Duration(seconds: 5));
      try {
        final items = await list(limit: _pollLimit);
        for (final n in items) {
          if (seen.add(n.id)) {
            if (seen.length > _seenCap) {
              seen.remove(seen.first);
            }
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

  static const int _pollLimit = 20;
  static const int _seenCap = 500;
}
