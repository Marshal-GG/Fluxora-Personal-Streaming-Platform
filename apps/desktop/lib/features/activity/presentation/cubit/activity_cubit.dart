import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fluxora_core/entities/stream_session.dart';
import 'package:fluxora_desktop/features/activity/domain/repositories/activity_repository.dart';

part 'activity_state.dart';
part 'activity_cubit.freezed.dart';

class ActivityCubit extends Cubit<ActivityState> {
  final ActivityRepository _repository;
  Timer? _timer;

  /// Polls `/stream/sessions` every 2 s — same cadence as
  /// [TranscodingCubit].  Without polling the active-sessions list and
  /// per-session `progress_sec` only refresh when the operator reopens
  /// the Transcoding tab, which makes live transcodes appear stuck at
  /// 0% even when the mobile client is actively reporting progress.
  static const Duration _interval = Duration(seconds: 2);

  ActivityCubit(this._repository) : super(const ActivityState.initial());

  /// Fetch once immediately, then start polling.
  void start() {
    if (_timer != null) return;
    loadSessions();
    _timer = Timer.periodic(_interval, (_) => loadSessions());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> loadSessions() async {
    if (isClosed) return;
    // Only emit `loading` on first load — keep last-known state during
    // polls so the UI doesn't flicker back to a spinner every 2 s.
    if (state is _Initial) emit(const ActivityState.loading());
    try {
      final sessions = await _repository.getActiveSessions();
      if (isClosed) return;
      emit(ActivityState.loaded(sessions));
    } catch (e) {
      if (isClosed) return;
      // Preserve last-known state on subsequent poll errors so a brief
      // network hiccup doesn't blank out the table; only surface error
      // when nothing has loaded yet.
      if (state is _Initial || state is _Loading) {
        emit(ActivityState.error(e.toString()));
      }
    }
  }

  Future<void> stopSession(String sessionId) async {
    try {
      await _repository.stopSession(sessionId);
      await loadSessions();
    } catch (e) {
      if (isClosed) return;
      emit(ActivityState.error(e.toString()));
    }
  }

  @override
  Future<void> close() {
    stop();
    return super.close();
  }
}
