import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fluxora_core/entities/stream_session.dart';
import 'package:fluxora_desktop/features/activity/domain/repositories/activity_repository.dart';

part 'activity_state.dart';
part 'activity_cubit.freezed.dart';

class ActivityCubit extends Cubit<ActivityState> {
  final ActivityRepository _repository;

  ActivityCubit(this._repository) : super(const ActivityState.initial());

  Future<void> loadSessions() async {
    emit(const ActivityState.loading());
    try {
      final sessions = await _repository.getActiveSessions();
      emit(ActivityState.loaded(sessions));
    } catch (e) {
      emit(ActivityState.error(e.toString()));
    }
  }

  Future<void> stopSession(String sessionId) async {
    try {
      await _repository.stopSession(sessionId);
      await loadSessions();
    } catch (e) {
      emit(ActivityState.error(e.toString()));
    }
  }
}
