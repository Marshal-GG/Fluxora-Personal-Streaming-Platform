import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/entities/app_notification.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_desktop/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:fluxora_desktop/features/notifications/presentation/cubit/notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({required NotificationsRepository repository})
      : _repository = repository,
        super(const NotificationsInitial());

  final NotificationsRepository _repository;
  StreamSubscription<AppNotification>? _liveSub;
  static final _log = Logger();

  /// Load notifications and subscribe to live updates.
  Future<void> start() async {
    await _load();
    _liveSub?.cancel();
    _liveSub = _repository.liveStream().listen(
      _onLive,
      onError: (Object e, StackTrace st) =>
          _log.w('Live notification error', error: e, stackTrace: st),
    );
  }

  Future<void> _load() async {
    emit(const NotificationsLoading());
    try {
      final items = await _repository.list();
      _emitLoaded(items);
    } on ApiException catch (e, st) {
      _log.e('Notifications load failed', error: e, stackTrace: st);
      emit(NotificationsFailure(e.message));
    } catch (e, st) {
      _log.e('Notifications load failed', error: e, stackTrace: st);
      emit(const NotificationsFailure('Unable to reach server.'));
    }
  }

  void _onLive(AppNotification n) {
    final current = state;
    if (current is! NotificationsLoaded) return;
    final alreadyPresent = current.items.any((i) => i.id == n.id);
    if (alreadyPresent) return;
    _emitLoaded([n, ...current.items]);
  }

  void _emitLoaded(List<AppNotification> items) {
    final unread = items.where((i) => i.readAt == null).length;
    emit(NotificationsLoaded(items: items, unreadCount: unread));
  }

  Future<void> markRead(String id) async {
    try {
      await _repository.markRead(id);
      final current = state;
      if (current is! NotificationsLoaded) return;
      final updated = current.items
          .map((n) => n.id == id
              ? n.copyWith(readAt: DateTime.now().toIso8601String())
              : n)
          .toList();
      _emitLoaded(updated);
    } catch (e, st) {
      _log.e('markRead failed', error: e, stackTrace: st);
    }
  }

  Future<void> markAllRead() async {
    try {
      await _repository.markAllRead();
      final current = state;
      if (current is! NotificationsLoaded) return;
      final now = DateTime.now().toIso8601String();
      final updated = current.items
          .map((n) => n.readAt == null ? n.copyWith(readAt: now) : n)
          .toList();
      _emitLoaded(updated);
    } catch (e, st) {
      _log.e('markAllRead failed', error: e, stackTrace: st);
    }
  }

  Future<void> dismiss(String id) async {
    try {
      await _repository.dismiss(id);
      final current = state;
      if (current is! NotificationsLoaded) return;
      _emitLoaded(current.items.where((n) => n.id != id).toList());
    } catch (e, st) {
      _log.e('dismiss failed', error: e, stackTrace: st);
    }
  }

  @override
  Future<void> close() {
    _liveSub?.cancel();
    return super.close();
  }
}
