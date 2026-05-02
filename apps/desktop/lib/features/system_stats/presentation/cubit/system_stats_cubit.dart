import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/entities/system_stats.dart';
import 'package:fluxora_desktop/features/system_stats/domain/repositories/system_stats_repository.dart';

part 'system_stats_state.dart';

/// Polls `/api/v1/info/stats` on a 1.1 s interval and pushes each sample
/// into the state's ring buffer.
///
/// Polling is deliberately chosen over WebSocket for v1 — it ships with
/// existing `ApiClient` infrastructure and matches the prototype's update
/// cadence. Switch to WS only if multiple subscribers cause measurable
/// load, which is unlikely on a single-user desktop control panel.
class SystemStatsCubit extends Cubit<SystemStatsState> {
  SystemStatsCubit({required SystemStatsRepository repository})
      : _repository = repository,
        super(const SystemStatsState());

  final SystemStatsRepository _repository;
  Timer? _timer;

  static const Duration _interval = Duration(milliseconds: 1100);

  /// Kick off polling. Idempotent — calling twice does not double-poll.
  void start() {
    if (_timer != null) return;
    _tick();
    _timer = Timer.periodic(_interval, (_) => _tick());
  }

  /// Stop polling and release the timer. Call from `close()` or when the
  /// shell is torn down.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    try {
      final sample = await _repository.fetch();
      emit(state.pushSample(sample));
    } catch (e) {
      emit(state.withError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    stop();
    return super.close();
  }
}
