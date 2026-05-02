import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_desktop/features/recent_activity/domain/repositories/recent_activity_repository.dart';
import 'package:fluxora_desktop/features/recent_activity/presentation/cubit/recent_activity_state.dart';

class RecentActivityCubit extends Cubit<RecentActivityState> {
  RecentActivityCubit({required RecentActivityRepository repository})
      : _repository = repository,
        super(const RecentActivityInitial());

  final RecentActivityRepository _repository;
  static final _log = Logger();

  Timer? _pollTimer;
  bool _paused = false;

  /// Whether polling is currently paused by the user.
  bool get isPaused => _paused;

  /// Loads a small set (limit=4) for the Dashboard recent-activity card.
  Future<void> load() async {
    emit(const RecentActivityLoading());
    try {
      final events = await _repository.fetch(limit: 4);
      emit(RecentActivityLoaded(events));
    } on ApiException catch (e, st) {
      _log.e('RecentActivity load failed', error: e, stackTrace: st);
      emit(RecentActivityFailure(e.message));
    } catch (e, st) {
      _log.e('RecentActivity load failed', error: e, stackTrace: st);
      emit(const RecentActivityFailure('Unable to load recent activity.'));
    }
  }

  Future<void> refresh() => load();

  /// Loads a larger set (limit=200) for the full Activity screen, then starts
  /// a 5-second polling loop so the list stays live.
  Future<void> loadAll() async {
    emit(const RecentActivityLoading());
    await _fetchAll();
    _startPolling();
  }

  /// Pauses the live-polling loop. The current event list is preserved.
  void pause() {
    _paused = true;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Resumes the live-polling loop.
  void resume() {
    _paused = false;
    _startPolling();
  }

  void _startPolling() {
    if (_pollTimer != null) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_paused) _fetchAll();
    });
  }

  Future<void> _fetchAll() async {
    try {
      final events = await _repository.fetch(limit: 200);
      emit(RecentActivityLoaded(events));
    } on ApiException catch (e, st) {
      _log.e('RecentActivity loadAll failed', error: e, stackTrace: st);
      // Only surface failure on first load to avoid blanking a live list.
      if (state is RecentActivityInitial || state is RecentActivityLoading) {
        emit(RecentActivityFailure(e.message));
      }
    } catch (e, st) {
      _log.e('RecentActivity loadAll failed', error: e, stackTrace: st);
      if (state is RecentActivityInitial || state is RecentActivityLoading) {
        emit(const RecentActivityFailure('Unable to load activity.'));
      }
    }
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
