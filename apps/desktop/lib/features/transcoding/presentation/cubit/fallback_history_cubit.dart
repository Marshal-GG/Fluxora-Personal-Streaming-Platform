import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/entities/fallback_event.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_desktop/features/transcoding/domain/repositories/transcoding_repository.dart';

/// Polls `/api/v1/transcoding/fallback-history` every 5 s.  Slower than
/// the 2 s `TranscodingCubit` because fallback events are rare; we only
/// need to refresh fast enough to surface a new event before the
/// operator's attention drifts.
sealed class FallbackHistoryState {
  const FallbackHistoryState();
}

final class FallbackHistoryInitial extends FallbackHistoryState {
  const FallbackHistoryInitial();
}

final class FallbackHistoryLoading extends FallbackHistoryState {
  const FallbackHistoryLoading();
}

final class FallbackHistoryLoaded extends FallbackHistoryState {
  const FallbackHistoryLoaded(this.events);
  final List<FallbackEvent> events;
}

final class FallbackHistoryFailure extends FallbackHistoryState {
  const FallbackHistoryFailure(this.message);
  final String message;
}

class FallbackHistoryCubit extends Cubit<FallbackHistoryState> {
  FallbackHistoryCubit({required TranscodingRepository repository})
      : _repository = repository,
        super(const FallbackHistoryInitial());

  final TranscodingRepository _repository;
  static final _log = Logger();
  Timer? _timer;

  static const Duration _interval = Duration(seconds: 5);

  void start() {
    if (_timer != null) return;
    _tick();
    _timer = Timer.periodic(_interval, (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() => _tick();

  Future<void> _tick() async {
    if (isClosed) return;
    if (state is FallbackHistoryInitial) {
      emit(const FallbackHistoryLoading());
    }
    try {
      final result = await _repository.fallbackHistory();
      if (isClosed) return;
      emit(FallbackHistoryLoaded(result.events));
    } catch (e, st) {
      _log.w('Fallback history poll failed', error: e, stackTrace: st);
      if (isClosed) return;
      // Keep the last-known state if we already have data; otherwise
      // surface the failure so the panel can show an error message.
      if (state is FallbackHistoryInitial ||
          state is FallbackHistoryLoading) {
        emit(FallbackHistoryFailure(e.toString()));
      }
    }
  }

  @override
  Future<void> close() {
    stop();
    return super.close();
  }
}
